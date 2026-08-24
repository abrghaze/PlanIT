# ADR 0002: Ledger, money, and offline authority

- Status: Accepted
- Date: 2026-08-24

## Decision

- Store money as `NUMERIC(19,4)` / Python `Decimal` / decimal strings / a Dart decimal value object.
- Store movement amount as positive and direction as `INFLOW` or `OUTFLOW`.
- Derive balances from immutable opening balance plus posted movements.
- Correct posted history with reversal/replacement entries.
- Keep PostgreSQL authoritative while Drift stores local projections and a transactional outbox.
- Show pending effects explicitly until the server acknowledges them.
- Require idempotency keys for balance-affecting writes.

## Consequences

Financial behavior is explainable and retry-safe. Offline UX is responsive but must distinguish provisional and canonical totals. More implementation effort is accepted in exchange for trust and auditability.
