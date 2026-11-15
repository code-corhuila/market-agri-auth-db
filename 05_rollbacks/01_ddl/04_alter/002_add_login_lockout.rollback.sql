ALTER TABLE auth.user_account
    DROP CONSTRAINT chk_user_account_failed_login_count,
    DROP COLUMN locked_until,
    DROP COLUMN failed_login_count;
