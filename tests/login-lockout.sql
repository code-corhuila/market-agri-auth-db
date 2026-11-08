-- HU-AUTH-005: the lockout state of user_account (FR-009, api-contract E-02 row 4, D-C29).
-- auth-api counts consecutive failed logins and locks the account for 15 minutes after the 5th.
-- Run by db-ci after the first update; everything is rolled back at the end.
\set ON_ERROR_STOP on
BEGIN;

CREATE FUNCTION pg_temp.expect(ok boolean, what text) RETURNS void
LANGUAGE plpgsql AS $$
BEGIN
    IF ok IS NOT TRUE THEN
        RAISE EXCEPTION 'FAIL: %', what;
    END IF;
    RAISE NOTICE 'ok: %', what;
END $$;

-- 1. A new user starts unlocked: no failures, no lock.
INSERT INTO auth.user_account (name, email, password_hash, role)
VALUES ('Ana Ruiz', 'bloqueo.uno@example.test',
        '$2a$12$abcdefghijklmnopqrstuuJ0Hf6YxRrqd0fTq2zXQh1kq8lQe7m8K', 'PRODUCER');
SELECT pg_temp.expect(
    (SELECT failed_login_count = 0 AND locked_until IS NULL
     FROM auth.user_account WHERE email = 'bloqueo.uno@example.test'),
    'a new user has failed_login_count 0 and no locked_until');

-- 2. The count is never negative.
DO $$
DECLARE
    got text;
BEGIN
    UPDATE auth.user_account SET failed_login_count = -1 WHERE email = 'bloqueo.uno@example.test';
    RAISE EXCEPTION 'FAIL: a negative failed_login_count was accepted';
EXCEPTION WHEN check_violation THEN
    GET STACKED DIAGNOSTICS got = CONSTRAINT_NAME;
    IF got IS DISTINCT FROM 'chk_user_account_failed_login_count' THEN
        RAISE EXCEPTION 'FAIL: refused by %, expected chk_user_account_failed_login_count', got;
    END IF;
    RAISE NOTICE 'ok: chk_user_account_failed_login_count refuses a negative count';
END $$;

-- 3. Both columns are required to hold: the count is NOT NULL, the lock is a point in time.
SELECT pg_temp.expect(
    (SELECT bool_and(CASE column_name WHEN 'failed_login_count' THEN is_nullable = 'NO' AND data_type = 'integer'
                                      WHEN 'locked_until' THEN is_nullable = 'YES'
                                           AND data_type = 'timestamp with time zone' END)
            AND count(*) = 2
     FROM information_schema.columns
     WHERE table_schema = 'auth' AND table_name = 'user_account'
       AND column_name IN ('failed_login_count', 'locked_until')),
    'failed_login_count is an integer NOT NULL and locked_until a nullable timestamptz');

-- 4. auth_app keeps the lockout state: it updates both columns (and still deletes nothing).
SELECT pg_temp.expect(
    has_column_privilege('auth_app', 'auth.user_account', 'failed_login_count', 'UPDATE')
    AND has_column_privilege('auth_app', 'auth.user_account', 'locked_until', 'UPDATE')
    AND NOT has_table_privilege('auth_app', 'auth.user_account', 'DELETE'),
    'auth_app updates failed_login_count and locked_until');

ROLLBACK;
\echo 'login-lockout: all checks passed'
