# Development guide

## Prerequisites

- Python 3.11 or 3.12
- Flutter stable with the Android/iOS toolchains required for the target platform
- Docker Engine with Docker Compose
- Git

## Backend

```powershell
python -m venv .venv
.\.venv\Scripts\Activate.ps1
python -m pip install --upgrade pip
python -m pip install -e ".\backend[dev]"
Copy-Item .env.example .env
python -m pytest backend/tests
python -m uvicorn app.main:app --app-dir backend --reload
```

Quality checks:

```powershell
python -m ruff check backend
python -m ruff format --check backend
python -m mypy backend/app
```

## Infrastructure and migrations

```powershell
docker compose -f infra/docker-compose.yml up -d postgres
python -m alembic -c backend/alembic.ini upgrade head
python -m alembic -c backend/alembic.ini current
```

To build and run the API plus PostgreSQL in containers:

```powershell
docker compose -f infra/docker-compose.yml up --build -d api
docker compose -f infra/docker-compose.yml exec api python -m alembic -c alembic.ini upgrade head
```

Never edit an applied migration. Add a new migration, review generated constraints/indexes, test upgrade from zero, and provide a downgrade where safe.

## Mobile

```powershell
Set-Location mobile
flutter pub get
dart run build_runner build --delete-conflicting-outputs
flutter analyze
flutter test
flutter run --dart-define=PLANIT_API_BASE_URL=http://10.0.2.2:8000/api/v1
```

Use `127.0.0.1` for an iOS simulator and the development machine's LAN address for a physical device as appropriate.

## Environment policy

- `.env` is local-only and never committed.
- CI uses ephemeral PostgreSQL and test-only secrets.
- Staging uses synthetic data and production-like managed services.
- Production secrets come from a managed secret store. Startup fails if placeholder secrets or debug mode are detected.

## Definition of done

A financial feature is not done until domain invariants, atomic persistence, authorization, idempotency, audit behavior, offline state, API schemas, migrations, and both unit and database/API tests agree.
