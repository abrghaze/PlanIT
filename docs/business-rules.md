# Financial business rules and resolved assumptions

This document converts open questions in the product specification into safe initial behavior. Changes require an ADR, tests, and coordinated API/database/mobile updates.

## Locked definitions

- **Money in accounts** is the headline total: included owned-account balances converted to the user's base currency.
- **Personal net position** is money in accounts plus open receivables minus open payables.
- **Gross account flow** includes every posted inflow/outflow, including owned transfers and debt principal.
- **Personal spending** includes expenses and transfer fees, less linked refunds and recoverable shared-expense portions. It excludes owned transfers, loan principal, debt repayments, and reconciliation adjustments.
- **Income** includes genuine income only. Borrowed principal, debt repayments, transfers, refunds, and reconciliation adjustments are excluded.

## Money and rounding

- API amounts are decimal strings plus an uppercase three-letter currency code.
- PostgreSQL uses `NUMERIC(19,4)`. Four fractional digits are the authoritative arithmetic scale.
- Input with more than four fractional digits is rejected instead of silently rounded.
- Derived multiplication/division uses round-half-even to four decimals.
- Stored movement amounts are non-negative. `INFLOW` or `OUTFLOW` determines account effect.
- Currency-specific display precision is a presentation concern; it never changes stored arithmetic history.

## Accounts and opening balances

- Cash is a normal account type.
- An account has `opened_at` and an immutable opening balance after its first posted movement.
- Opening balance is stored exactly once on the account; it is not duplicated as a ledger movement.
- A later correction uses reconciliation or an explicit adjustment; it does not rewrite the opening balance.
- Active accounts accept postings. Archived accounts are hidden/read-only but restorable. Closed accounts reject postings; reopening requires an audited policy action.
- `include_in_total` controls headline reporting without deleting history.

## Posted ledger

- Drafts may be edited or discarded and have no balance effect.
- Posted balance-affecting fields are immutable.
- Correction creates a linked reversal and optional replacement. Metadata explicitly designated as non-financial may be versioned in place.
- Balance at time `T` equals opening balance plus posted movement effects whose effective time is at or before `T`.

## Transfers and reallocation

- A transfer creates linked source and destination movements atomically. Principal is KPI-neutral.
- A fee is a separate outflow classified as spending.
- Cross-currency transfer requires explicit source amount, destination amount, currencies, and effective FX rate.
- Keep Total Fixed is same-currency only in V1. The user explicitly selects participating accounts and a balancing account, reviews the result, then commits.
- Commit creates one internal transfer pair between the balancing account and each changed non-balancing account plus immutable session/line audit records.
- Preview includes a version/fingerprint of source balances. Commit fails with `STALE_BALANCE` if they changed.

## Reconciliation

- Reconciliation compares the calculated ledger balance with a user-entered real balance at an effective time.
- `delta = actual - calculated`; commit creates exactly one adjustment movement plus one reconciliation and audit record.
- Reconciliation is excluded from normal income/spending unless a later auditable reclassification identifies its real cause.

## Debts and shared expenses

- Existing receivable/payable creates only a debt position.
- Lend-now creates an account outflow and receivable atomically. Borrow-now creates an account inflow and payable atomically.
- Principal repayments create/attach the matching cash movement and debt payment atomically. Overpayment is rejected.
- One shared-expense share per person per source transaction creates one reimbursement receivable.
- Total active shares cannot exceed the eligible gross expense amount.

## Refunds

- Refunds are inflows linked to an original posted expense and are capped by remaining refundable amount.
- MVP accepts an amount-level refund. The schema/API will allow item-level allocations later without changing the ledger entry.
- If an expense has reimbursement shares, a refund that would make active shares exceed the remaining gross expense is rejected until shares are adjusted in the same reviewed workflow. The server never silently changes another person's obligation.

## Currency conversion

- Original amounts and transaction FX rates are immutable.
- Current consolidated totals use the latest user-approved rate effective at or before the calculation time.
- Historical reporting uses the latest approved rate effective at or before each reporting boundary unless the transaction stores its own rate.
- Missing rates produce a partial-total warning; the app does not invent or silently use a rate of one.

## Initial product choices

- Multiple currencies, manual exchange rates, cash accounts, optional merchant branches, seeded-plus-custom categories, and optional product detail are supported from the foundation.
- Reconciliation adjustments remain analytics-neutral.
- Loan principal appears in cash-flow views but not income/spending.
- Shared expenses create one receivable per person.
- Product quantities and unit prices are optional in quick entry; if item rows are supplied, each row must have a description or product and a valid line total.
- OCR, bank synchronization, household sharing, advanced budgets, and automated anomaly detection are later phases.
