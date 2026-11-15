# market-agri-auth-db

PostgreSQL schema and Liquibase migrations for the **auth** domain of Marketplace Agrícola Huila.

This repository owns the `auth` schema, its domain roles, grants, and migrations. The PostgreSQL
instance, persistent volume, and `auth_app` login belong to `market-agri-infra` (Anexo J, ADR-010).
The API connects as `auth_app`; it does not own or run schema migrations (ADR-011).

Governance, ADRs and the data model live in
[`market-agri-docs`](https://github.com/code-corhuila/market-agri-docs): see
[ADR-010](https://github.com/code-corhuila/market-agri-docs/blob/main/05-architecture/decisions/records/ADR-010-data-isolation.md)
(data isolation: one instance, one schema per domain) and
[ADR-011](https://github.com/code-corhuila/market-agri-docs/blob/main/05-architecture/decisions/records/ADR-011-migrations-liquibase.md)
(migrations with Liquibase, only in the `-db` repository).

## Layout

```
changelog/changelog-master.yaml   Liquibase entry point
01_ddl/                           schema and future structural changes
02_dml/                           data migrations
03_dcl/                           auth_reader/writer roles and grants
04_tcl/                           transaction control and recovery scripts
05_rollbacks/                     rollback SQL mirroring forward changes
deploy/compose.yml                deliberate Liquibase runner, included by infra
.github/workflows/db-ci.yml       rebuild, isolation, table rules, full rollback, rebuild, seeds
tests/                            SQL checks of the table rules and the seeds, run by db-ci
```

## Rules

1. Domain objects live in `auth`; only the Liquibase control tables live in `public`.
2. Every SQL changeset has a rollback file under the matching `05_rollbacks/` path. Never edit an
   applied changeset; make corrections in a new changeset.
3. `auth_app` receives `auth_writer`; the application login and its secret are created by infra,
   never stored here. No auth-domain role receives privileges on another schema.
4. `auth_writer` has no `DELETE`, on purpose (same rule as `market-agri-catalog-db` and
   `market-agri-transactions-db`): a state change is an `UPDATE` or a new row. A changeset that needs
   to delete data runs as the migration user, not as `auth_app`.
5. Keep database deployment separate from API startup. Migrate first, then deploy the API.
6. Seeds are idempotent (`INSERT … ON CONFLICT … DO UPDATE`). **Seed users run only in dev and
   qa** (`contextFilter: "dev,qa"`): the runner passes `--contexts=${ENV}`, so `main` starts
   without users. Their rollback fails on purpose once a seed user has refresh tokens.

## Data dictionary

Spec: `market-agri-docs` `06-data/models.md` (*Service: auth*), the auth-service data model,
`07-api/api-contract.md` D-C2 (refresh tokens) and D-C35 (idempotent creation).

| Table | Purpose | Main rules |
|---|---|---|
| `user_account` | Credentials and the single role | `email` unique, stored lower-cased and trimmed (INV-002); `role` `PRODUCER`/`BUYER`/`ADMIN`, never updated (INV-001); `password_hash` only a bcrypt hash of cost ≥ 12 (INV-003); `name` 1–150; `deleted_at` so ids held by other domains never dangle |
| `refresh_token` | Renewable sessions (D-C2) | only the SHA-256 of the opaque token (64 hex), unique; `expires_at` after creation; `used_at` / `revoked_at` mark the single use and the revocation; FK `RESTRICT` to the user |
| `idempotency_key` | The key each registration was created with (E-01, D-C35) | primary key `key_value` (8–128): registration is anonymous, so there is no owner; FK `RESTRICT` to the user |

Not in this schema yet: `farm_profile` (no endpoint in this delivery) and the login lockout state
of FR-009 (HU-AUTH-005). Expired refresh tokens and old keys are not purged yet (`auth_app` has no
`DELETE`). The rules are tested in `tests/auth-tables.sql` and the seeds in `tests/seed-users.sql`,
both run by `db-ci.yml` (step 3b).

## Seed users (dev and qa only)

The same accounts as the simulated mode of `market-agri-front`, plus the second producer of
catalog's seed products. Development passwords, never used outside dev and qa.

| Name | Email | Password | Role |
|---|---|---|---|
| Ana Ruiz | `productor@market-agri.test` | `Productor123` | `PRODUCER` |
| Luis Gómez | `productor2@market-agri.test` | `Productor123` | `PRODUCER` |
| Carlos Pérez | `comprador@market-agri.test` | `Comprador123` | `BUYER` |
| Administración | `admin@market-agri.test` | `Admin123` | `ADMIN` |

## Run it

From `market-agri-infra`, after the auth include and environment variable are configured:

```bash
docker compose --env-file env/dev.env --profile tooling config
docker compose --env-file env/dev.env run --rm auth-db-migrate
docker compose --env-file env/dev.env run --rm auth-db-migrate status --verbose
docker compose --env-file env/dev.env run --rm auth-db-migrate rollback-count 1
```

## Branching

Work enters `develop` through a child branch and Pull Request. Promotion to `qa` and `main` follows the
project Git guide and uses re-application with `cherry-pick -x`; do not merge permanent branches.
