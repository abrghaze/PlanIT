# PlanIT threat model

## Assets and trust boundaries

PlanIT protects credentials, refresh sessions, financial history, debt relationships,
receipts, exports, and backups. The mobile process, HTTPS API, PostgreSQL database, and
private object store are separate trust boundaries. External OCR or banking providers are
outside the trusted system and are disabled by default.

## Principal threats and controls

| Threat | Control | Verification |
|---|---|---|
| Account enumeration and password guessing | Generic failures, Argon2id including dummy verification, persistent login throttling | Identity integration and password unit tests |
| Access/refresh token theft | Short access lifetime, opaque hashed rotating refresh tokens, replay-chain revocation, OS secure storage | Token rotation/reuse and secure-store tests |
| Cross-user object access | User ID only from authenticated principal; owner predicates and composite database constraints | Cross-owner API and cache tests |
| Duplicate or reordered offline writes | Stable UUID idempotency keys, canonical request hashes, owner-ordered outbox | Replay/conflict and local queue tests |
| Financial-history tampering | Draft-only edits, posted reversals, row locks, optimistic versions, audit events | Ledger, transfer, correction, debt, and sharing tests |
| Receipt disclosure | Private bucket, owner check, short-lived signed URL, MIME/size validation | Media lifecycle and ownership tests |
| Sensitive logging | JSON allowlist of route template, status, duration, and request ID; no body/query/header serialization | Logging unit test |
| Export leakage | Bearer authentication, owner-scoped query, `no-store`, attachment response, no credential/storage fields | Privacy export integration test |
| Accidental or hostile erasure | Current password plus exact phrase; media deletion must succeed before database cascade | Deletion and media-cleanup integration test |
| Backup failure or unsafe restore | Encrypted deployment backups, restore only to a separate target, CI dump/restore drill | Containers CI job |
| Malicious automation provider | No provider by default; protocol boundary, fail-closed adapter, manual fallback | Provider-seam unit tests |
| Opaque or misleading anomaly claims | Deterministic median rule, minimum history, plain-language explanation, source link; no automated financial action | Analytics insight unit and mobile contract tests |

## Residual deployment responsibilities

The deployer must supply a real HTTPS API hostname, high-entropy secrets, managed database
and object-store encryption, access-controlled log retention, backup encryption/retention,
Android/iOS signing identities, and app-store privacy disclosures. These secrets and legal
decisions do not belong in Git. Before enabling OCR or banking, perform a provider-specific
data-flow review, obtain explicit user consent, and add idempotent contract tests.
