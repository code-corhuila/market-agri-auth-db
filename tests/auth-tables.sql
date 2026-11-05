-- HU-PLAT-003 · F2: the table rules of the auth schema (06-data/models.md, auth-service
-- data model, api-contract D-C2 and D-C35). Run by db-ci after the first update; everything is
-- rolled back at the end.
\set ON_ERROR_STOP on
BEGIN;

-- Fails the run unless the statement is refused by exactly the expected constraint.
CREATE FUNCTION pg_temp.expect_refused(stmt text, expected text) RETURNS void
LANGUAGE plpgsql AS $$
DECLARE
    got text;
BEGIN
    EXECUTE stmt;
    RAISE EXCEPTION 'FAIL: accepted, % should refuse it: %', expected, stmt;
EXCEPTION WHEN check_violation OR unique_violation OR foreign_key_violation THEN
    GET STACKED DIAGNOSTICS got = CONSTRAINT_NAME;
    IF got IS DISTINCT FROM expected THEN
        RAISE EXCEPTION 'FAIL: refused by %, expected %: %', got, expected, stmt;
    END IF;
    RAISE NOTICE 'ok: % refuses it', expected;
END $$;

CREATE FUNCTION pg_temp.expect(ok boolean, what text) RETURNS void
LANGUAGE plpgsql AS $$
BEGIN
    IF ok IS NOT TRUE THEN
        RAISE EXCEPTION 'FAIL: %', what;
    END IF;
    RAISE NOTICE 'ok: %', what;
END $$;

-- A valid user insert; any column can be overridden by replacing its value.
CREATE FUNCTION pg_temp.user_insert(email text, name text DEFAULT 'Ana Ruiz', role text DEFAULT 'PRODUCER',
        password_hash text DEFAULT '$2a$12$abcdefghijklmnopqrstuuJ0Hf6YxRrqd0fTq2zXQh1kq8lQe7m8K')
RETURNS text LANGUAGE sql AS $$
    SELECT format('INSERT INTO auth.user_account (name, email, password_hash, role) VALUES (%L, %L, %L, %L)',
                  name, email, password_hash, role);
$$;

-- 1. A valid user is accepted with its defaults (AC1).
DO $$ BEGIN EXECUTE pg_temp.user_insert('test.uno@example.test'); END $$;
SELECT pg_temp.expect(
    (SELECT id IS NOT NULL AND created_at IS NOT NULL AND updated_at IS NOT NULL AND deleted_at IS NULL
     FROM auth.user_account WHERE email = 'test.uno@example.test'),
    'a valid user gets its id, created_at and updated_at, and is active');

-- 2. One account per email, stored already lower-cased and trimmed (AC2, INV-002).
SELECT pg_temp.expect_refused(pg_temp.user_insert('test.uno@example.test'), 'uq_user_account_email');
SELECT pg_temp.expect_refused(pg_temp.user_insert('Test.Dos@example.test'), 'chk_user_account_email_normalized');
SELECT pg_temp.expect_refused(pg_temp.user_insert(' test.dos@example.test'), 'chk_user_account_email_normalized');
SELECT pg_temp.expect_refused(pg_temp.user_insert(repeat('a', 251) || '@x.co'), 'chk_user_account_email_length');

-- 3. A single role out of three; SERVICE is a token role, never a user (AC3, INV-001).
SELECT pg_temp.expect_refused(pg_temp.user_insert('test.tres@example.test', role => 'SERVICE'), 'chk_user_account_role');
SELECT pg_temp.expect_refused(pg_temp.user_insert('test.tres@example.test', role => 'producer'), 'chk_user_account_role');

-- 4. Name 1-150 after trim.
SELECT pg_temp.expect_refused(pg_temp.user_insert('test.cuatro@example.test', name => '   '), 'chk_user_account_name_length');
SELECT pg_temp.expect_refused(pg_temp.user_insert('test.cuatro@example.test', name => repeat('n', 151)), 'chk_user_account_name_length');

-- 5. Only a bcrypt hash of cost >= 12 is stored, never a password (INV-003).
SELECT pg_temp.expect_refused(pg_temp.user_insert('test.cinco@example.test', password_hash => 'Productor123'),
       'chk_user_account_password_hash_bcrypt');
SELECT pg_temp.expect_refused(pg_temp.user_insert('test.cinco@example.test',
       password_hash => '$2a$10$abcdefghijklmnopqrstuuJ0Hf6YxRrqd0fTq2zXQh1kq8lQe7m8K'),
       'chk_user_account_password_hash_bcrypt');

-- 6. Refresh tokens (D-C2): only the SHA-256 hex of the opaque token, one row per token,
--    always of an existing user, expiring after it was issued.
INSERT INTO auth.refresh_token (user_id, token_hash, expires_at)
SELECT id, repeat('a', 64), now() + interval '7 days' FROM auth.user_account WHERE email = 'test.uno@example.test';
SELECT pg_temp.expect(
    (SELECT id IS NOT NULL AND used_at IS NULL AND revoked_at IS NULL FROM auth.refresh_token
     WHERE token_hash = repeat('a', 64)),
    'a new refresh token is neither used nor revoked');
SELECT pg_temp.expect_refused(format(
       'INSERT INTO auth.refresh_token (user_id, token_hash, expires_at) VALUES (%L, %L, now() + interval ''7 days'')',
       (SELECT id FROM auth.user_account WHERE email = 'test.uno@example.test'), repeat('a', 64)),
       'uq_refresh_token_token_hash');
SELECT pg_temp.expect_refused(format(
       'INSERT INTO auth.refresh_token (user_id, token_hash, expires_at) VALUES (gen_random_uuid(), %L, now() + interval ''7 days'')',
       repeat('b', 64)), 'fk_refresh_token_user_account');
SELECT pg_temp.expect_refused(format(
       'INSERT INTO auth.refresh_token (user_id, token_hash, expires_at) VALUES (%L, %L, now() + interval ''7 days'')',
       (SELECT id FROM auth.user_account WHERE email = 'test.uno@example.test'), 'the-token-itself'),
       'chk_refresh_token_token_hash_format');
SELECT pg_temp.expect_refused(format(
       'INSERT INTO auth.refresh_token (user_id, token_hash, expires_at) VALUES (%L, %L, now() - interval ''1 minute'')',
       (SELECT id FROM auth.user_account WHERE email = 'test.uno@example.test'), repeat('c', 64)),
       'chk_refresh_token_expires_after_creation');

-- 7. Registration keys (D-C35): 8-128 characters, used once, pointing to an existing user.
INSERT INTO auth.idempotency_key (key_value, user_id)
SELECT 'registro-0001', id FROM auth.user_account WHERE email = 'test.uno@example.test';
SELECT pg_temp.expect_refused(format(
       'INSERT INTO auth.idempotency_key (key_value, user_id) VALUES (%L, %L)', 'registro-0001',
       (SELECT id FROM auth.user_account WHERE email = 'test.uno@example.test')), 'pk_idempotency_key');
SELECT pg_temp.expect_refused(format(
       'INSERT INTO auth.idempotency_key (key_value, user_id) VALUES (%L, %L)', 'corta',
       (SELECT id FROM auth.user_account WHERE email = 'test.uno@example.test')), 'chk_idempotency_key_key_value_length');
SELECT pg_temp.expect_refused(
       'INSERT INTO auth.idempotency_key (key_value, user_id) VALUES (''registro-0002'', gen_random_uuid())',
       'fk_idempotency_key_user_account');

-- 8. auth_app may change rows but never delete them (AC5; deletes run as the migration user).
SELECT pg_temp.expect(
    has_table_privilege('auth_app', 'auth.user_account', 'SELECT, INSERT, UPDATE')
    AND NOT has_table_privilege('auth_app', 'auth.user_account', 'DELETE')
    AND NOT has_table_privilege('auth_app', 'auth.refresh_token', 'DELETE')
    AND NOT has_table_privilege('auth_app', 'auth.idempotency_key', 'DELETE'),
    'auth_app reads, inserts and updates, without DELETE');

ROLLBACK;
\echo 'auth-tables: all checks passed'
