# ADR 0001: Modular monolith and provider-neutral storage

- Status: Accepted
- Date: 2026-08-24

## Decision

Use a Flutter mobile application and one FastAPI modular monolith backed by PostgreSQL. Keep domain/application boundaries inside the monolith and use one database transaction for cross-feature financial writes. Define media through an S3-compatible adapter.

For local development, use Garage rather than MinIO. MinIO was named in the blueprint, but its upstream repository was archived in 2026. Garage remains actively maintained and preserves the required S3 contract. Production storage is selected operationally without changing domain code.

## Consequences

- Deployment and local debugging remain straightforward.
- Atomic financial operations do not cross service boundaries.
- Feature modules can be extracted later only if measured scale or team ownership justifies it.
- Storage adapter contract tests are required because S3-compatible providers differ at edge cases.
