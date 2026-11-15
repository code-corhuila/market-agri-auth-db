-- Renewable sessions (api-contract D-C2): the refresh token is opaque, valid 7 days and single
-- use. Only its SHA-256 (64 lowercase hex characters) is stored, so a copy of the table cannot
-- be replayed. A reuse of a used token revokes every token of the user.
CREATE TABLE auth.refresh_token (
    id         uuid        NOT NULL DEFAULT gen_random_uuid(),
    user_id    uuid        NOT NULL,
    token_hash text        NOT NULL,
    expires_at timestamptz NOT NULL,
    used_at    timestamptz,           -- set when it is exchanged for a new pair (rotation)
    revoked_at timestamptz,           -- set by logout or by the reuse rule
    created_at timestamptz NOT NULL DEFAULT now(),

    CONSTRAINT pk_refresh_token PRIMARY KEY (id),
    CONSTRAINT chk_refresh_token_token_hash_format       CHECK (token_hash ~ '^[0-9a-f]{64}$'),
    CONSTRAINT chk_refresh_token_expires_after_creation  CHECK (expires_at > created_at)
);
