-- HU-PLAT-003 · D-20: seed users for dev and qa (AC4), so the real login accepts the same
-- credentials as the front's simulated mode and catalog's seed products keep their owners.
--   * same UUIDs, names, emails and roles as the simulated users of market-agri-front
--   * Luis Gómez, the second producer of catalog's seeds
--   * each password of the README matches its bcrypt hash (pgcrypto, installed by infra)
--   * the seed is idempotent: running it again changes nothing (Anexo A, rule 11)
-- db-ci builds the schema without --contexts, so the dev/qa seeds are applied. Rolled back.
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

CREATE TEMP TABLE seed_user (id uuid PRIMARY KEY, name text, email text, password text, role text);
INSERT INTO seed_user VALUES
    ('0b6f2c7e-4a51-4c1e-9d0e-2f1c3a7b9e10', 'Ana Ruiz',       'productor@market-agri.test',  'Productor123', 'PRODUCER'),
    ('3c2b1a09-8f7e-4d6c-9b5a-4e3d2c1b0a99', 'Luis Gómez',     'productor2@market-agri.test', 'Productor123', 'PRODUCER'),
    ('6a1d9b2c-3e4f-4a5b-8c6d-7e8f9a0b1c2d', 'Carlos Pérez',   'comprador@market-agri.test',  'Comprador123', 'BUYER'),
    ('9f8e7d6c-5b4a-4c3d-9e2f-1a0b9c8d7e6f', 'Administración', 'admin@market-agri.test',      'Admin123',     'ADMIN');

-- 1. The four users, with the same id, name, email and role.
SELECT pg_temp.expect(
    (SELECT count(*) FROM auth.user_account u JOIN seed_user s
       ON s.id = u.id AND s.name = u.name AND s.email = u.email AND s.role = u.role
     WHERE u.deleted_at IS NULL) = 4,
    'the four seed users, same id, name, email and role');

-- 2. The documented passwords log in: each matches its hash.
SELECT pg_temp.expect(
    (SELECT count(*) FROM auth.user_account u JOIN seed_user s ON s.id = u.id
     WHERE crypt(s.password, u.password_hash) = u.password_hash) = 4,
    'each seed password matches its bcrypt hash');

-- 3. ADMIN exists only as a seed (FR-008).
SELECT pg_temp.expect(
    (SELECT count(*) FROM auth.user_account WHERE role = 'ADMIN') = 1,
    'exactly one ADMIN, the seeded one');

-- 4. Idempotent: the same seed again leaves the same rows.
CREATE TEMP TABLE before_rerun AS SELECT * FROM auth.user_account;
-- db-ci feeds this file to psql from the repository root, so the path starts there.
\i 02_dml/00_inserts/001_seed_users.sql
SELECT pg_temp.expect(
    NOT EXISTS ((SELECT id, name, email, password_hash, role FROM auth.user_account
                 EXCEPT SELECT id, name, email, password_hash, role FROM before_rerun)
                UNION ALL
                (SELECT id, name, email, password_hash, role FROM before_rerun
                 EXCEPT SELECT id, name, email, password_hash, role FROM auth.user_account)),
    'running the seed again changes nothing (INSERT ... ON CONFLICT ... DO UPDATE)');

ROLLBACK;
\echo 'seed-users: all checks passed'
