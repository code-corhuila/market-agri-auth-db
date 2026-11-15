-- Seed users for dev and qa only (D-20): main starts without users.
-- Same UUIDs, names, emails and passwords as the simulated users of market-agri-front, so the
-- real login accepts what the simulated one did; Luis Gómez is the second producer of
-- catalog's seed products. Development passwords (README): bcrypt hashes of cost 12.
-- ADMIN exists only here (FR-008). Idempotent (Anexo A, rule 11): running it again leaves the
-- same rows.
INSERT INTO auth.user_account (id, name, email, password_hash, role, created_at, updated_at)
VALUES
    ('0b6f2c7e-4a51-4c1e-9d0e-2f1c3a7b9e10', 'Ana Ruiz', 'productor@market-agri.test',
     '$2a$12$yHcEDghcNSsOFt4XSsWEWO0AVS2aUhwG.ZAjAu4hfONWrdvM4lnSC', 'PRODUCER',
     '2026-10-01T12:00:00Z', '2026-10-01T12:00:00Z'),
    ('3c2b1a09-8f7e-4d6c-9b5a-4e3d2c1b0a99', 'Luis Gómez', 'productor2@market-agri.test',
     '$2a$12$CE6zxJiEh12Px1f0FVSieeLz8RZHWlqdX5Uj1gWyo8Y2BTcN7SZg.', 'PRODUCER',
     '2026-10-01T12:00:00Z', '2026-10-01T12:00:00Z'),
    ('6a1d9b2c-3e4f-4a5b-8c6d-7e8f9a0b1c2d', 'Carlos Pérez', 'comprador@market-agri.test',
     '$2a$12$m/WZIO4tOpAG1fFS2jdZwOFia.yyyDjcAF1lvcsEJ4KbSakwKplHy', 'BUYER',
     '2026-10-01T12:00:00Z', '2026-10-01T12:00:00Z'),
    ('9f8e7d6c-5b4a-4c3d-9e2f-1a0b9c8d7e6f', 'Administración', 'admin@market-agri.test',
     '$2a$12$5UKyucJaXqG9XJJDfv2RZe.z9JhbfOsfq1VZbMq.2mcKkyJ0wsQuq', 'ADMIN',
     '2026-10-01T12:00:00Z', '2026-10-01T12:00:00Z')
ON CONFLICT (id) DO UPDATE SET
    name          = EXCLUDED.name,
    email         = EXCLUDED.email,
    password_hash = EXCLUDED.password_hash,
    role          = EXCLUDED.role,
    updated_at    = EXCLUDED.updated_at,
    deleted_at    = NULL;
