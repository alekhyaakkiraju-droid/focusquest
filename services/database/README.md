# FocusQuest Database Migrations

PostgreSQL schema for all FocusQuest service domains, managed with [golang-migrate](https://github.com/golang-migrate/migrate).

## Layout

```
services/database/
├── migrations/          # Versioned SQL migrations (000–010)
├── tests/
│   └── schema_test.sh   # Integration test against Docker Postgres
├── Makefile
└── README.md
```

## Prerequisites

- Docker (for local integration tests)
- Go 1.22+ (to install the `migrate` CLI via `make install-migrate`)
- Optional: [golang-migrate](https://github.com/golang-migrate/migrate) installed globally

## Quick start (local Docker Postgres)

From `services/database/`:

```bash
make postgres-up    # starts postgres:16 on localhost:54329
make migrate-up     # apply all migrations
make test           # run schema integration tests
make clean          # stop the test container
```

Default connection string:

```
postgres://focusquest:focusquest@localhost:54329/focusquest?sslmode=disable
```

Override the port with `POSTGRES_PORT=5433 make postgres-up`.

## Manual migrate commands

```bash
export DATABASE_URL="postgres://focusquest:focusquest@localhost:54329/focusquest?sslmode=disable"

migrate -path migrations -database "$DATABASE_URL" up
migrate -path migrations -database "$DATABASE_URL" down 1
migrate -path migrations -database "$DATABASE_URL" version
```

## Cloud SQL (us-central1 / europe-west1)

Apply the same migration files to each regional Cloud SQL instance. Use IAM-authenticated or Secret Manager–backed credentials; never commit passwords.

Example (via Cloud SQL Auth Proxy):

```bash
cloud-sql-proxy PROJECT:REGION:INSTANCE &
export DATABASE_URL="postgres://USER:PASSWORD@127.0.0.1:5432/focusquest?sslmode=disable"
make migrate-up
```

Run migrations in both `us-central1` and `europe-west1` so schemas stay identical for dual-region deployment.

## Schema domains

| Migration | Domain | Tables |
|-----------|--------|--------|
| 000 | Extensions | `pgcrypto` |
| 001 | Auth | `users`, `child_profiles`, `refresh_tokens`, `oauth_links` |
| 002 | Timer | `focus_sessions`, `break_records` |
| 003 | Quest | `quests`, `quest_progress`, `xp_ledger`, `badges`, `streaks` |
| 004 | Curriculum | `ib_pyp_themes`, `ib_subject_areas`, `teks_standards`, `quest_curriculum_tags` |
| 005 | Coin economy | `coin_ledger`, `avatar_items`, `avatar_purchases` |
| 006 | Session config | `child_session_config` |
| 007 | Notification | `notification_log`, `device_tokens`, `notification_preferences` |
| 008 | Compliance | `consent_records`, `data_deletion_requests`, `audit_log` |
| 009 | Analytics | `daily_summaries`, `weekly_reports` |
| 010 | Premium | `subscription_tiers`, `premium_content_flags` |

## Design notes

- All primary keys are UUIDs with `gen_random_uuid()` (requires `pgcrypto`).
- Child-related foreign keys use `ON DELETE RESTRICT` — deletions go through the Compliance Service.
- `child_profiles` enforces a maximum of 5 children per parent via trigger.
- `child_profiles.display_name` and `age_range` are marked for application-layer encryption in WO-005.
- `badges.ib_learner_attribute` maps to the 10 IB Learner Profile attributes.
- `child_session_config` defaults: `min_duration_sec=300`, `max_duration_sec=900`, `daily_cap_minutes=120`.

## CI

- `ci/tests/schema_config_test.sh` — contract tests that migration SQL defines required tables/constraints.
- `services/database/tests/schema_test.sh` — integration test (Docker Postgres + migrate up + table verification).

Run all CI checks from the repo root:

```bash
bash ci/tests/run_all_tests.sh
```
