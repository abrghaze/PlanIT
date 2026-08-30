# Release checklist

CI proves formatting, static analysis, generated code, backend and mobile tests, migration
upgrade/check/downgrade, a debug APK, a release-mode Android App Bundle, live container
health/readiness, a PostgreSQL dump/restore drill, synchronized release versions, and valid
local/production Compose configuration.

Before publishing a production build:

1. Set the release API URL with `--dart-define=PLANIT_API_BASE_URL=https://…/api/v1`.
2. Configure protected Android/iOS signing credentials in the release environment.
3. Use non-placeholder API, JWT, database, and private object-storage secrets.
4. Confirm TLS, database/object encryption, backup retention, and restore access controls.
5. Complete app-store privacy, data-deletion, screenshots, support URL, and age-rating forms.
6. Test registration, offline startup, one ledger write/sync, export, and deletion in staging
   with synthetic data; never test destructive workflows against a real user.
7. Record the CI run, commit SHA, migration revision, artifact checksum, and rollback owner.
8. Add protected GitHub Actions secrets for `PLANIT_PRODUCTION_API_URL`,
   `PLANIT_ANDROID_KEYSTORE_BASE64`, `PLANIT_ANDROID_KEYSTORE_PASSWORD`,
   `PLANIT_ANDROID_KEY_ALIAS`, and `PLANIT_ANDROID_KEY_PASSWORD`.
9. Push a strict `vMAJOR.MINOR.PATCH` tag only from a green `main` commit. The release
   workflow re-runs all checks, builds and smoke-tests the immutable API image, publishes it
   to GHCR, creates the signed `.aab`, records its SHA-256 checksum, and creates the GitHub
   release. A missing/partial secret fails before publication.
10. Deploy the exact versioned image using `docs/production-deployment.md`; confirm the
    `/health` version and `/ready` status before traffic switching.

The repository intentionally does not contain signing keys or production service URLs.
The automated workflow currently publishes Android. iOS distribution remains intentionally
manual until an Apple Developer team, bundle ownership, certificates, and App Store Connect
credentials exist.
