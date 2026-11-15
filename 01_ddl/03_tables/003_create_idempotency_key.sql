-- The database half of idempotent registration (E-01, D-C35): the user and its key are inserted
-- in ONE transaction; a repeated key rolls back and answers 200 with the original user.
-- Registration is anonymous, so the key alone identifies the intent (catalog and transactions
-- also scope it by the caller's sub). The client sends a random value.
CREATE TABLE auth.idempotency_key (
    key_value  text        NOT NULL,  -- the Idempotency-Key header
    user_id    uuid        NOT NULL,
    created_at timestamptz NOT NULL DEFAULT now(),

    CONSTRAINT pk_idempotency_key PRIMARY KEY (key_value),
    CONSTRAINT chk_idempotency_key_key_value_length CHECK (char_length(key_value) BETWEEN 8 AND 128)
);
