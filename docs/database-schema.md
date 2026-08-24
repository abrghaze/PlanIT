# Database strategy and data dictionary

PostgreSQL is the authoritative store. IDs are UUIDs, timestamps are `TIMESTAMPTZ` in UTC, and money is `NUMERIC(19,4)`. Every user-owned aggregate has an ownership path that can be checked server-side. Posted financial history is append-oriented.

The identity/control and ledger/account tables below are present in the Milestone 0
foundation. Catalog, purchase detail, debts/sharing, automation, goals, and media
tables describe the approved later-milestone schema and are not migrated yet.

## Identity and control

| Table | Purpose | Critical fields and rules |
|---|---|---|
| `users` | Identity and preferences | unique normalized email, display name, base currency, IANA timezone, status |
| `refresh_sessions` | Rotating sessions | hashed opaque token, device label, expiry/revocation, replacement link |
| `idempotency_keys` | Retry-safe writes | unique `(user_id, scope, key)`, request hash, stored status/body, expiry |
| `audit_events` | Security/business trace | actor, entity reference, action, redacted before/after JSON, request/operation IDs |

## Ledger and accounts

| Table | Purpose | Critical fields and rules |
|---|---|---|
| `accounts` | Owned money containers | currency, immutable opening balance after posting, opened time, inclusion/negative policy, lifecycle, version |
| `transactions` | One account movement | positive amount, `INFLOW/OUTFLOW`, classification kind, status, effective time, optional parent/reversal links, unique client operation ID |
| `transfers` | Atomic transfer grouping | unique source/destination transaction IDs, optional unique fee transaction, source/destination amounts, explicit FX rate |
| `balance_reconciliations` | Real-balance correction | calculated/actual/delta, effective time, unique adjustment transaction |
| `reallocation_sessions` | Fixed-total commit | same currency, fixed total, balancing account, preview fingerprint |
| `reallocation_lines` | Per-account audit | composite key `(session_id, account_id)`, before/target/delta |
| `exchange_rates` | Approved conversion facts | base/quote, positive rate, effective time, source; unique scoped pair/time |

At Milestone 0, `transactions` is indexed by `(user_id, occurred_at, id)`,
`(account_id, occurred_at, id)`, parent, and reversal. The unique
`(user_id, client_operation_id)` constraint supplies the retry-safety lookup.
Category and merchant-location indexes are added with those later schema columns.
Database checks enforce positive amounts, known type/effect combinations, coherent
reversal links, and positive entity versions. Transaction-spanning totals are
enforced under row locks in application services. Composite foreign keys prevent a
transaction from naming an account owned by another user or using a different
currency; a reversal is constrained to its original user, account, and currency.

## Catalog and purchase detail

| Table | Purpose | Critical fields and rules |
|---|---|---|
| `categories` | Hierarchical accounting/product classification | user-scoped or seeded, parent ownership/type compatibility, version |
| `merchants` | Brand/business identity | normalized searchable name, optional category, notes, version |
| `merchant_locations` | Optional branch | merchant ownership, branch/location data, optional coordinates |
| `products` | Family/variant identity | optional parent family, brand/variant, positive normalized size, compatible unit, optional barcode |
| `transaction_items` | Purchase facts | product optional, immutable description snapshot, positive quantity, unit price, discount, line total |
| `tags` / `transaction_tags` | Context independent of category | unique active normalized name per user; composite link key |
| media link tables | Private image relationships | ordered links from verified media assets to transactions, products, merchants |

## Debts and sharing

| Table | Purpose | Critical fields and rules |
|---|---|---|
| `people` | Counterparties | user-scoped contact metadata, version |
| `debts` | Receivable/payable position | direction, origin type, optional origin movement, original amount/currency, status, due date |
| `debt_payments` | Settlement history | unique transaction ID, positive amount, payment time; sum cannot exceed principal |
| `shared_expense_shares` | Recoverable expense portion | unique `(transaction_id, person_id)`, positive amount, unique linked receivable debt |

Remaining debt is derived from principal less valid payments. Status is deterministic except an explicit cancellation/write-off with an audit reason.

## Automation, goals, and media

| Table | Purpose | Critical fields and rules |
|---|---|---|
| `recurring_rules` | Subscription/bill/income template | schedule, timezone, next due, reminder/auto-create mode, version |
| `recurring_occurrences` | Scheduler deduplication | unique `(rule_id, scheduled_for)`, optional generated transaction |
| `savings_goals` | Non-spending target | target amount/currency/date, linked account or manual progress, status |
| `media_assets` | Private object metadata | owner, storage key, MIME, size, checksum, lifecycle/finalized state |

## Integrity and deletion

- Foreign keys are restrictive for financial facts. Metadata may use nullable references when historical snapshots preserve meaning.
- Hard deletion is limited to safe drafts, unattached pending media, and the deliberate full-profile privacy workflow.
- Financial corrections use reversal/replacement and audit links.
- Cross-row invariants use PostgreSQL transactions and row locks: transfer completeness, debt overpayment, refund cap, shared-share cap, stale previews, and idempotency.
- Each migration is tested from an empty database and from the previous release head.
