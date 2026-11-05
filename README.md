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
.github/workflows/db-ci.yml       rebuild, isolation, full rollback, and rebuild
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
