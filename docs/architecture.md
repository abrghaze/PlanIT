# PlanIT architecture

This document describes the approved target architecture. Through Milestone 4,
the backend implements configuration, request/error handling, identity and rotating
sessions, authenticated ownership, account lifecycle/balance use cases, PostgreSQL
repositories, audit helpers, and the idempotency transaction coordinator. The
mobile app implements its shell, secure session storage, registration/sign-in,
account, core-ledger, transfer, reconciliation, reallocation, debt, sharing, and refund management, an owner-scoped Drift v2 projection,
compile-time API configuration, exact money values, and an ordered transactional
outbox for generic transactions and specialized financial commit operations.

## Source-of-truth order

1. `plans/PlanIT_Personal_Finance_App_Product_Spec_v0.2.docx` defines business intent.
2. `plans/PlanIT_Personal_Finance_App_Technical_Architecture_and_Diagrams_v1.0.docx` defines the approved technical direction.
3. Accepted architecture decision records in `docs/adr/` resolve implementation details.
4. Code and generated OpenAPI/migrations must conform to the above. A mismatch is a defect, not an undocumented design change.

## Runtime architecture

PlanIT is a modular monolith, not a collection of microservices.

```text
Flutter app
  presentation -> application state -> domain -> repository contracts
                                        |
                         Drift cache + outbox / Dio API adapter
                                        |
                                FastAPI /api/v1
  routers -> application services -> domain policies -> repositories
                                        |
                         PostgreSQL + private S3-compatible storage
```

PostgreSQL is authoritative for synchronized financial history. Drift is a local,
owner-scoped projection and hosts the ordered Milestone 4 outbox.
Cached aggregates are disposable read models; credentials are never stored there.

## Backend boundaries

- `api`: transport validation, authentication dependencies, status codes, and response mapping. Routers contain no financial math.
- `application`: use cases and transaction boundaries. A financial operation is committed through one unit of work.
- `domain`: pure entities, money values, policies, classifications, and invariants. It has no FastAPI or SQLAlchemy imports.
- `infrastructure`: SQLAlchemy repositories, database sessions, object storage, token implementation, and observability adapters.
- `analytics`: centralized read models and classification-aware SQL. Dashboards do not duplicate formulas.

Feature modules are identity, ledger/accounts, debts/sharing, catalog, recurring/goals, media, and analytics. Cross-module balance-affecting writes are coordinated by an application service inside one database transaction.

## Mobile boundaries

- `presentation`: screens, reusable widgets, forms, charts, accessibility, and route composition.
- `application`: Riverpod notifiers/controllers that coordinate use cases and expose immutable view state.
- `domain`: decimal money values, entities, policies, and repository interfaces.
- `data`: DTO mapping, Dio clients, Drift tables/DAOs, secure-token adapter, and synchronization engine.

The UI reads local data immediately. Server-acknowledged balances and provisional pending effects are visually distinct. The client never presents a pending high-risk operation as permanently posted.

## Financial write protocol

1. The mobile client generates an entity UUID and `client_operation_id` UUID.
2. It writes the local entity and outbox row atomically.
3. The request includes `Idempotency-Key` and a canonical request body.
4. The server authenticates the user, hashes the canonical body, and locks/looks up `(user_id, scope, key)`.
5. The domain operation, audit event, and idempotency result commit atomically.
6. A retry with the same key/body returns the stored canonical result. The same key with a different body returns `IDEMPOTENCY_CONFLICT`.
7. The mobile client replaces provisional state with the canonical response and marks the outbox row acknowledged.

Outbox rows are processed in creation order so a queued post cannot overtake its
draft creation. Retryable failures retain the same operation UUID and use bounded
exponential backoff. Financial 404/409/422 responses are parked as visible
conflicts for review rather than retried with a newly generated identity. Cached
account balances refresh only after canonical server acknowledgment. A user may
retry the same operation ID after repairing the cause, or explicitly discard the
local operation and reload canonical server state.

## Security and privacy

- Ownership always comes from authenticated server context; client `user_id` values are never authoritative.
- Access JWTs are short-lived. Opaque refresh tokens rotate, and only their hashes are stored server-side.
- Mobile tokens live in Keychain/Keystore-backed secure storage, never Drift.
- Logs use request/correlation IDs and structured metadata but exclude credentials, authorization headers, transaction notes, receipt content, and full financial payloads.
- Media buckets are private. Upload/read operations use short-lived signed URLs after ownership checks.
- Posted financial rows are reversed, not hard-deleted. Full profile erasure is a separate, deliberate privacy workflow.

## Storage implementation note

The blueprint named MinIO for local development. Its upstream repository was archived in 2026, creating a maintenance and security risk. PlanIT keeps a generic S3 adapter and uses Garage for local S3-compatible development. Production may use AWS S3, Cloudflare R2, Backblaze B2, Garage, or another compatible managed service after operational review. No domain code depends on the provider.
