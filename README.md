# PlanIT

PlanIT is an offline-capable personal-finance mobile application built around an auditable financial ledger. It tracks owned accounts, expenses, income, transfers, debts, reimbursements, merchants, products, recurring commitments, goals, and trustworthy analytics.

The planning documents in [`plans/`](plans/) are the product source of truth. Implementation decisions and resolved assumptions are recorded in [`docs/`](docs/).

## Architecture

- Flutter mobile app using Riverpod, go_router, Dio, Drift/SQLite, and decimal-safe money values.
- FastAPI modular monolith with explicit domain/application/persistence boundaries.
- PostgreSQL as the authoritative financial store.
- S3-compatible private object storage behind a provider-neutral adapter.
- Offline outbox plus idempotency keys for retry-safe financial writes.

## Repository layout

```text
backend/   FastAPI service, domain rules, SQLAlchemy, Alembic, tests
mobile/    Flutter application and local/offline data layer
infra/     Reproducible local infrastructure
docs/      Architecture, contracts, data dictionary, ADRs, operations
plans/     Product specification and technical blueprint
```

## Current milestone

Milestone 0 establishes the architecture, development environment, money primitives, error contract, database foundation, mobile shell, and automated tests. Feature work then proceeds in ledger dependency order.

See [`docs/development.md`](docs/development.md) for setup and commands and
[`docs/implementation-roadmap.md`](docs/implementation-roadmap.md) for the ordered delivery plan.
