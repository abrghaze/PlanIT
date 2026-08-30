# Release checklist

CI proves formatting, static analysis, generated code, backend and mobile tests, migration
upgrade/check/downgrade, a debug APK, a release-mode Android App Bundle, live container
health/readiness, and a PostgreSQL dump/restore drill.

Before publishing a production build:

1. Set the release API URL with `--dart-define=PLANIT_API_BASE_URL=https://…/api/v1`.
2. Configure protected Android/iOS signing credentials in the release environment.
3. Use non-placeholder API, JWT, database, and private object-storage secrets.
4. Confirm TLS, database/object encryption, backup retention, and restore access controls.
5. Complete app-store privacy, data-deletion, screenshots, support URL, and age-rating forms.
6. Test registration, offline startup, one ledger write/sync, export, and deletion in staging
   with synthetic data; never test destructive workflows against a real user.
7. Record the CI run, commit SHA, migration revision, artifact checksum, and rollback owner.

The repository intentionally does not contain signing keys or production service URLs.
