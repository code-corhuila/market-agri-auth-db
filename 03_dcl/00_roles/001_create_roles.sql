-- NOLOGIN roles carry permissions. The auth_app login and password belong to infra.
DO $$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'auth_reader') THEN
        CREATE ROLE auth_reader NOLOGIN;
    END IF;
    IF NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'auth_writer') THEN
        CREATE ROLE auth_writer NOLOGIN;
    END IF;
END
$$;
