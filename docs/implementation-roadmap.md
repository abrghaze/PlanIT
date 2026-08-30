# Implementation roadmap

Each milestone must leave the repository runnable and may advance only after its invariants, migration, API contract, offline behavior, and tests agree.

**Delivery status:** Milestones 0 through 7 are complete in release `0.8.0`.

| Milestone | Scope | Exit criteria |
|---|---|---|
| 0 — Foundation | Architecture, configuration, error contract, decimal money, initial ledger schema, app shell, CI | Strict static checks; empty PostgreSQL upgrade/downgrade cycle; live health/readiness; backend unit/integration tests; Flutter format/analyze/unit/widget gates and debug builds; container smoke test |
| 1 — Identity and accounts | Registration, login/refresh/logout, account lifecycle, balance read models | Ownership tests, token rotation/reuse detection, account concurrency, local cache |
| 2 — Core ledger | Expense and income create/edit-draft/post/reverse flows, categories and tags | Posted immutability, balance correctness, idempotent offline retry |
| 3 — Transfers and corrections | Same/cross-currency transfers, fees, reconciliation, Keep Total Fixed | Atomic pairs, stale-preview protection, neutral analytics treatment |
| 4 — Debts and sharing | People, receivables/payables, lend/borrow-now, repayment, shared expenses, refunds | Overpayment/refund/share caps under concurrent requests |
| 5 — Purchase intelligence | Merchants, locations, products, itemized purchases, private receipt media | Searchable snapshots, totals validation, signed media lifecycle |
| 6 — Analytics and dashboard | Net position, cash flow, spending/income, trends, merchant/product views | One classification matrix, FX warnings, timezone-correct aggregates |
| 7 — Planning | Recurring commitments, subscriptions, savings goals and reminders | Deduplicated occurrences, reliable progress and due-state handling |
| 8 — Advanced and release | OCR/bank adapter seams, anomaly insights, accessibility, performance, privacy export/deletion | Threat review, backup/restore drill, observability, store-ready builds |

The next implementation slice is Milestone 8. Planning occurrences and manual
goal allocations are authoritative metadata; analytics remain disposable read
models over canonical financial facts.
