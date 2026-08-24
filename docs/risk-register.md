# Initial risk register

| Risk | Consequence | Foundation response |
|---|---|---|
| Binary floating-point money | Irreconcilable balances and inconsistent clients | Four-decimal `NUMERIC`/`Decimal`/scaled-integer values; decimal strings over JSON |
| Duplicate offline retries | Financial operations posted more than once | Stable operation UUIDs, server idempotency records, canonical request hashes |
| Editable posted history | Audit trail and balances become untrustworthy | Draft-only edits; posted correction by linked reversal/replacement |
| Multi-row partial writes | One-sided transfers, debts, or reconciliations | One application transaction and row locks around each financial use case |
| Stale reallocation preview | Total or account balances unexpectedly change | Source fingerprint plus lock-and-recheck during commit |
| Missing/incorrect FX rates | Misleading consolidated wealth | User-approved effective rates and explicit partial-total warnings |
| Refund/shared-expense interaction | Recovered amount exceeds the remaining purchase | Lock source, refunds, and shares; reject until reviewed together |
| Optimistic offline presentation | User mistakes pending writes for posted money | Display provisional effects separately until canonical acknowledgement |
| Sensitive financial data in logs/media | Privacy and security breach | Redacted structured logs, private buckets, short-lived signed URLs |
| Archived MinIO upstream | Unmaintained local dependency | Provider-neutral S3 adapter; active Garage release for local development |
| Mobile SDK absent on this workstation | Native build errors cannot be observed locally | CI installs Flutter stable; generate/review native runners before feature work |
