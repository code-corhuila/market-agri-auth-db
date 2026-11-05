-- Foreign keys inside the auth schema only. auth_app has no DELETE, so RESTRICT makes an
-- accidental physical delete of a user fail while it still has tokens or a registration key.
ALTER TABLE auth.refresh_token
    ADD CONSTRAINT fk_refresh_token_user_account
    FOREIGN KEY (user_id) REFERENCES auth.user_account (id) ON DELETE RESTRICT;

ALTER TABLE auth.idempotency_key
    ADD CONSTRAINT fk_idempotency_key_user_account
    FOREIGN KEY (user_id) REFERENCES auth.user_account (id) ON DELETE RESTRICT;
