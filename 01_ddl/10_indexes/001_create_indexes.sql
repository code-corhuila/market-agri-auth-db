-- Each index names the query or rule it serves (Anexo A, rule 3). The tables are new and empty,
-- so CONCURRENTLY is not needed.

-- E-02 login lookup by email; one account per email (INV-002, EMAIL_ALREADY_REGISTERED)
CREATE UNIQUE INDEX uq_user_account_email
    ON auth.user_account (email);

-- E-03 refresh: the token is found by its hash; one row per token
CREATE UNIQUE INDEX uq_refresh_token_token_hash
    ON auth.refresh_token (token_hash);

-- D-C2 reuse rule: revoke every live token of a user; also the foreign key index
CREATE INDEX idx_refresh_token_user_id
    ON auth.refresh_token (user_id);

-- Foreign key column (rule 3)
CREATE INDEX idx_idempotency_key_user_id
    ON auth.idempotency_key (user_id);
