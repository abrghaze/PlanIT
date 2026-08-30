# Initial risk register

| Risk | Consequence | Mitigation |
|---|---|---|
| Binary floating-point money | Irreconcilable balances and inconsistent clients | Four-decimal `NUMERIC`/`Decimal`/scaled-integer values; decimal strings over JSON |
| Duplicate offline retries | Financial operations posted more than once | Stable operation UUIDs, server idempotency records, canonical request hashes |
| Editable posted history | Audit trail and balances become untrustworthy | Draft-only edits; posted correction by linked reversal/replacement |
| Multi-row partial writes | One-sided transfers, debts, or reconciliations | One application transaction and row locks around each financial use case |
| Stale reallocation preview | Total or account balances unexpectedly change | Source fingerprint plus lock-and-recheck during commit |
| Missing/incorrect FX rates | Misleading consolidated wealth | User-approved effective rates and explicit partial-total warnings |
| Refund/shared-expense interaction | Recovered amount exceeds the remaining purchase | Lock source, refunds, and shares; reject until reviewed together |
| Optimistic offline presentation | User mistakes pending writes for posted money | Display provisional effects separately until canonical acknowledgement |
| Outbox dependency reordering | A post/reversal reaches the server before its prerequisite draft | One owner-ordered queue, atomic local entity/outbox writes, deterministic creation timestamps |
| Permanent financial sync rejection | Endless retries hide a version or validation conflict | Park 404/409/422 operations as visible conflicts; retain payload/operation ID for review |
| Sensitive financial data in logs/media | Privacy and security breach | Redacted structured logs, private buckets, short-lived signed URLs |
| Unrecoverable database incident | Permanent loss of financial history | Encrypted backups, protected restore targets, documented runbook, and a full dump/restore drill in CI |
| Incomplete profile erasure | Private data survives an account deletion request | Password plus exact phrase, object deletion before database cascade, owner-isolation and media-cleanup integration tests |
| Optional provider lock-in or surprise cost | Core workflows depend on a paid OCR/banking service | Provider-neutral contracts, disabled defaults, manual-entry fallback, and explicit consent/cost review before enablement |
| Credential stuffing or account enumeration | Account takeover and privacy leakage | Generic login failures, Argon2id verification including dummy hashes, persistent keyed throttling |
| Refresh-token theft or replay | Long-lived unauthorized access | Opaque hashed rotating tokens, replacement-chain replay detection and revocation, auditable session events |
| Cross-owner API/cache access | One user sees another user's financial data | Server-derived ownership, not-found masking, composite constraints, owner-partitioned Drift queries and tests |
| Concurrent account edits | Silent lost updates | Row locks plus required optimistic `version`; stale writes return `VERSION_CONFLICT` |
| Archived MinIO upstream | Unmaintained local dependency | Provider-neutral S3 adapter; active Garage release for local development |
| Android SDK absent on this workstation | Android artifacts cannot be compiled locally | CI pins Flutter 3.47.1 and builds both a debug APK and release-mode App Bundle after format, analysis, generated-code, and test gates |
