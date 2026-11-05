-- Credentials and the single role of a user (06-data/models.md, Service: auth).
-- `user` is an SQL keyword, hence the name. No foreign keys here: they go in 04_alter.
CREATE TABLE auth.user_account (
    id            uuid        NOT NULL DEFAULT gen_random_uuid(),
    name          text        NOT NULL,
    email         text        NOT NULL,  -- the Email value object lower-cases and trims it first (INV-002)
    password_hash text        NOT NULL,  -- bcrypt, never returned or logged (INV-003, NFR-032)
    role          text        NOT NULL,  -- set once at registration, never updated (INV-001)
    created_at    timestamptz NOT NULL DEFAULT now(),
    updated_at    timestamptz NOT NULL DEFAULT now(),  -- set by the application on UPDATE
    deleted_at    timestamptz,                         -- soft delete: ids held by other domains never dangle

    CONSTRAINT pk_user_account PRIMARY KEY (id),
    CONSTRAINT chk_user_account_name_length      CHECK (char_length(btrim(name)) BETWEEN 1 AND 150),
    CONSTRAINT chk_user_account_email_normalized CHECK (email = lower(btrim(email))),
    CONSTRAINT chk_user_account_email_length     CHECK (char_length(email) BETWEEN 3 AND 255),
    -- A bcrypt hash of cost 12 or more: a plain password or a weaker hash never reaches the table.
    CONSTRAINT chk_user_account_password_hash_bcrypt CHECK (
        password_hash ~ '^\$2[aby]\$(1[2-9]|2[0-9]|3[01])\$[./A-Za-z0-9]{53}$'),
    CONSTRAINT chk_user_account_role CHECK (role IN ('PRODUCER', 'BUYER', 'ADMIN'))
);
