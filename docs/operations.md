# PlanIT operations

## Privacy-safe observability

The API emits one JSON event per request with a request ID, HTTP method, route template,
status, and duration. It deliberately excludes query strings, authorization headers,
request/response bodies, receipt contents, passwords, and token values. `Server-Timing`
and `X-Request-ID` response headers support diagnosis without exposing private data.

Set `PLANIT_LOG_LEVEL` to `DEBUG`, `INFO`, `WARNING`, or `ERROR`. Production should use
`INFO` unless a time-bounded incident procedure calls for another level. Logs must go to
an access-controlled platform with a documented retention period.

## Backups and restore drills

Database snapshots are infrastructure backups and must be encrypted by the deployment
platform. Object storage needs an independent versioned backup policy. Never place a
production dump in Git.

From the repository root, create a local Compose backup:

```sh
sh infra/scripts/backup-postgres.sh planit-backup.dump
```

Restore into a separate verification database; the script refuses the live `planit`
database and PostgreSQL system databases:

```sh
sh infra/scripts/restore-postgres.sh planit-backup.dump planit_restore
```

After validating row counts and a representative financial report, remove the temporary
database. CI performs this dump/restore/schema check on every change, so restoration is
continuously exercised rather than left as an untested runbook.

## User-controlled exports and deletion

- `GET /api/v1/privacy/export.csv?data_type=transactions` supports optional inclusive
  `date_from` and `date_to` filters.
- `GET /api/v1/privacy/export.csv?data_type=accounts` captures calculated balances and
  accepts an optional `as_of` timestamp.
- `GET /api/v1/privacy/backup.json` produces a portable, owner-scoped data copy. It omits
  password hashes, refresh tokens, idempotency state, storage keys, and private image bytes.
- `DELETE /api/v1/privacy/profile` requires the current password and the exact confirmation
  phrase `DELETE MY PLANIT DATA`. Private objects are deleted before the database profile;
  any object-store failure aborts the database deletion for a safe retry.

Export responses are non-cacheable. A database backup is the authoritative disaster
recovery mechanism; the portable JSON export is designed for user access and future
provider-neutral import tooling, not direct database replacement.

## Optional automation

OCR and bank import are provider-neutral interfaces under `backend/app/integrations`.
They default to disabled implementations that fail closed while manual entry continues
to work. Enabling a provider later requires a privacy review, explicit secrets, contract
tests, idempotent imports, and a clear cost/consent decision; Milestone 8 adds no paid
service dependency.
