-- The lockout state of a user (HU-AUTH-005, FR-009, api-contract E-02 row 4): consecutive failed
-- logins and, after the 5th, when the lock ends (15 minutes). auth-api counts and locks in one
-- atomic UPDATE and resets the count on a successful login. Existing users start unlocked.
ALTER TABLE auth.user_account
    ADD COLUMN failed_login_count integer NOT NULL DEFAULT 0,
    ADD COLUMN locked_until       timestamptz,
    ADD CONSTRAINT chk_user_account_failed_login_count CHECK (failed_login_count >= 0);
