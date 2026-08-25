# PlanIT

PlanIT is an offline-capable personal-finance mobile application built around an auditable financial ledger. It tracks owned accounts, expenses, income, transfers, debts, reimbursements, merchants, products, recurring commitments, goals, and trustworthy analytics.

The planning documents in [`plans/`](plans/) are the product source of truth. Implementation decisions and resolved assumptions are recorded in [`docs/`](docs/).

> **Implementation status:** release `0.2.0` completes Milestone 1. The tested
> application now includes identity/session security, owner-scoped account
> lifecycle APIs and balance read models, plus a secure mobile sign-in flow and
> owner-isolated Drift account cache. Core transaction entry begins in Milestone 2.

## Approved target architecture

- Flutter mobile app using Riverpod, go_router, Dio, Drift/SQLite, and decimal-safe money values.
- FastAPI modular monolith with explicit domain/application/persistence boundaries.
- PostgreSQL as the authoritative financial store.
- S3-compatible private object storage behind a provider-neutral adapter.
- Offline outbox plus server idempotency keys for retry-safe financial writes.

## Repository layout

```text
backend/   FastAPI service, domain rules, SQLAlchemy, Alembic, tests
mobile/    Flutter application and local/offline data layer
infra/     Reproducible local infrastructure
docs/      Architecture, contracts, data dictionary, ADRs, operations
plans/     Product specification and technical blueprint
```

## Current milestone

Milestones 0 and 1 are complete. The current release provides:

- Argon2id registration/login and short-lived JWT access tokens.
- Opaque hashed refresh tokens with rotation, replay detection, chain revocation, logout, and database-backed login throttling.
- Authenticated account create/list/read/update/balance endpoints with server-derived ownership, idempotent creation, optimistic concurrency, lifecycle policies, and audit events.
- Ledger-derived account balances and database enforcement of opening-field immutability after posted activity.
- Flutter registration/sign-in/logout, secure OS token storage, owner-scoped Drift caching, offline cache reads, exact four-decimal money, and account management screens.

Milestone 2 adds draft/post/reverse expense and income workflows on top of this identity and account foundation.

See [`docs/development.md`](docs/development.md) for setup and commands and
[`docs/implementation-roadmap.md`](docs/implementation-roadmap.md) for the ordered delivery plan.
