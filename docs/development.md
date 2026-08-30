# Development guide

## Prerequisites

- Python 3.11.9 (the exact version exercised by CI)
- Flutter 3.47.1 with the Android/iOS toolchain required for the target platform
- Docker Engine with Docker Compose
- Git

## Backend with PostgreSQL

Start PostgreSQL first. The committed local defaults match this container:

```powershell
docker compose -f infra/docker-compose.yml up -d --wait postgres
Copy-Item .env.example .env
```

Then install, migrate, and test the backend from the repository root:

```powershell
python -m venv .venv
.\.venv\Scripts\Activate.ps1
python -m pip install --upgrade pip
python -m pip install -e ".\backend[dev]"
python -m pip check
python -m alembic -c backend/alembic.ini upgrade head
python -m alembic -c backend/alembic.ini check
python -m pytest backend/tests
python -m uvicorn app.main:app --app-dir backend --reload
```

The test suite includes PostgreSQL integration tests and therefore requires the
migrated database selected by `PLANIT_DATABASE_URL`; SQLite is not a substitute.
Check liveness at `http://127.0.0.1:8000/api/v1/health` and database readiness at
`http://127.0.0.1:8000/api/v1/ready`.

Quality checks:

```powershell
python -m ruff check backend
python -m ruff format --check backend
python -m mypy backend/app
```

## Migration verification

```powershell
python -m alembic -c backend/alembic.ini upgrade head
python -m alembic -c backend/alembic.ini check
python -m alembic -c backend/alembic.ini current
```

CI additionally upgrades an empty PostgreSQL database, downgrades it to `base`,
and upgrades it again. Only run that destructive cycle against a disposable
database.

To build and run the API plus PostgreSQL in containers:

```powershell
docker compose -f infra/docker-compose.yml up --build --wait api
Invoke-RestMethod http://127.0.0.1:8000/api/v1/health
Invoke-RestMethod http://127.0.0.1:8000/api/v1/ready
docker compose -f infra/docker-compose.yml down
```

The API container waits for PostgreSQL and applies Alembic migrations before
starting FastAPI. Add `--volumes` to the final command only when intentionally
discarding local PostgreSQL data. The optional Garage service is started with
`--profile media` after its local credentials are bootstrapped.

Never edit an applied migration. Add a new migration, review generated constraints/indexes, test upgrade from zero, and provide a downgrade where safe.

## Mobile

```powershell
Set-Location mobile
flutter pub get --enforce-lockfile
dart format --output=none --set-exit-if-changed lib test
flutter analyze --no-pub
dart run build_runner build
flutter test --no-pub
flutter build apk --debug --no-pub
flutter run --dart-define=PLANIT_API_BASE_URL=http://10.0.2.2:8000/api/v1
```

Use `127.0.0.1` for an iOS simulator and the development machine's LAN address for a physical device as appropriate.

`pubspec.lock` is committed and CI pins Flutter 3.47.1. Drift's generated
`app_database.g.dart` is also committed; `dart run build_runner build` must leave
the worktree unchanged. Schema version 3 stores the owner-scoped account and
transaction projections, categories, tags, transaction-tag links, shops,
branches, products, item snapshots, merchant references, and a transactional
outbox. Milestone 4 debt, repayment, share, and refund commands use
that durable outbox and refresh canonical server projections after acknowledgment.
Local tests cover atomic enqueue, operation ordering, and stable operation IDs
across retries. The web runner includes dependency-matched
`drift_worker.js` and `sqlite3.wasm` assets for the local projection.

## Environment policy

- `.env` is local-only and never committed.
- CI uses ephemeral PostgreSQL and test-only secrets.
- Staging uses synthetic data and production-like managed services.
- Production secrets come from a managed secret store. Startup fails if token, database, or configured S3 credentials are placeholders, or if debug mode is enabled.
- Staging/production CORS origins must use HTTPS, and token lifetimes must be positive.
- Flutter release builds must receive an HTTPS `PLANIT_API_BASE_URL`; the HTTP default is local-debug only.

## Definition of done

A financial feature is not done until domain invariants, atomic persistence, authorization, idempotency, audit behavior, offline state, API schemas, migrations, and both unit and database/API tests agree.
