-- Removes the four seed users of 001_seed_users.sql, by their fixed ids.
-- Fails on purpose (ON DELETE RESTRICT) if a seed user already has refresh tokens or a
-- registration key: in qa, demo data that was used is not rolled back.
DELETE FROM auth.user_account
WHERE id IN ('0b6f2c7e-4a51-4c1e-9d0e-2f1c3a7b9e10', '3c2b1a09-8f7e-4d6c-9b5a-4e3d2c1b0a99',
             '6a1d9b2c-3e4f-4a5b-8c6d-7e8f9a0b1c2d', '9f8e7d6c-5b4a-4c3d-9e2f-1a0b9c8d7e6f');
