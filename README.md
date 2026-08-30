# PlanIT

PlanIT is an offline-capable personal-finance mobile application built around an auditable financial ledger. It tracks owned accounts, expenses, income, transfers, debts, reimbursements, merchants, products, recurring commitments, goals, and trustworthy analytics.

The planning documents in [`plans/`](plans/) are the product source of truth. Implementation decisions and resolved assumptions are recorded in [`docs/`](docs/).

> **Implementation status:** release `0.6.0` completes Milestone 5. The tested
> application now adds searchable shops/branches, reusable product variants,
> exact itemized purchases, offline purchase caches, and private signed receipt media.

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

Milestones 0 through 5 are complete. The current release provides:

- Argon2id registration/login and short-lived JWT access tokens.
- Opaque hashed refresh tokens with rotation, replay detection, chain revocation, logout, and database-backed login throttling.
- Authenticated account create/list/read/update/balance endpoints with server-derived ownership, idempotent creation, optimistic concurrency, lifecycle policies, and audit events.
- Ledger-derived account balances and database enforcement of opening-field immutability after posted activity.
- Flutter registration/sign-in/logout, secure OS token storage, owner-scoped Drift caching, offline cache reads, exact four-decimal money, and account management screens.
- Expense and income draft/edit/post/reverse APIs with row locking, negative-balance checks, optimistic concurrency, audit events, and database-enforced posted immutability.
- Per-user seeded/custom categories, independent transaction tags, Activity search/filter/detail screens, and category/tag settings.
- A Drift v2 ledger projection and ordered transactional outbox. Offline entries appear immediately, retry with stable operation UUIDs, and never alter displayed account balances before server acknowledgment.
- Atomic owned-account transfers with linked out/in movements, explicit FX amounts and rates, optional spending-classified fees, and immutable group integrity.
- Effective-time balance reconciliation with one neutral adjustment and protection against historical corrections that would make the current balance invalid.
- Same-currency Keep Total Fixed reallocation with an explicit balancing account, reviewed before/target balances, one internal transfer per changed account, and atomic server commit.
- Mobile preview/confirm screens and a visible FIFO pending-operation queue with retry, conflict review, and safe local discard behavior.
- Owned people and receivable/payable positions for existing debts or immediate lend/borrow cash movements.
- Atomic debt repayments with deterministic status/remaining amounts and database-backed concurrent overpayment protection.
- Shared-expense receivables that preserve the original gross expense, enforce one share per person, and reject concurrent over-allocation.
- Linked refund inflows with category/tag continuity and database-enforced refund/share caps.
- Mobile debt list/detail/create/repay screens plus expense share/refund flows, all delivered through the durable financial outbox.
- Searchable merchant brands with optional branches and owner-safe transaction references.
- Reusable product families/variants, barcode and package-size metadata, including gram/millilitre normalization.
- Itemized expense entry with exact quantity/price/discount arithmetic, explicit unspecified-item balancing, immutable posted snapshots, and offline item caching.
- Private JPEG/PNG/WebP media reservations, five-minute signed URLs, verified finalization, and mobile receipt upload independent from product/transaction creation.

Milestone 6 adds trustworthy analytics and merchant/product views over these facts.

See [`docs/development.md`](docs/development.md) for setup and commands and
[`docs/implementation-roadmap.md`](docs/implementation-roadmap.md) for the ordered delivery plan.
