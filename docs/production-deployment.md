# Production deployment

PlanIT production consists of a signed mobile application, the version-matched API image,
PostgreSQL, private S3-compatible object storage, and an HTTPS reverse proxy or platform
load balancer. The repository stays provider-neutral and contains no live credentials.

## Platform requirements

- A container runtime compatible with Docker Compose or the equivalent service definition.
- PostgreSQL 18 with encrypted storage, automated backups, point-in-time recovery, and a
  private network path from the API.
- A private, non-public S3-compatible bucket with server-side encryption, lifecycle rules,
  and credentials restricted to that bucket.
- An HTTPS hostname for the API. The mobile build is compiled against the final URL, so it
  must not be changed casually after publication.
- A TLS proxy that limits request sizes and forwards to port 8000. Only `/api/v1/*` needs to
  be public; production OpenAPI and interactive docs are disabled.

## Deploy an immutable release

1. Copy `infra/production.env.example` to a protected file named `production.env` outside
   the Git checkout. Replace every `REPLACE_...` value and choose the exact versioned GHCR
   image produced by the release workflow. Do not deploy `latest`.
2. Validate interpolation without printing the resolved configuration into logs:

   ```sh
   docker compose --env-file /secure/production.env \
     -f infra/docker-compose.production.yml config --quiet
   ```

3. Pull and start the release. The migration container must finish successfully before the
   API starts:

   ```sh
   docker compose --env-file /secure/production.env \
     -f infra/docker-compose.production.yml pull
   docker compose --env-file /secure/production.env \
     -f infra/docker-compose.production.yml up -d --wait
   ```

4. Verify `GET https://your-api.example/api/v1/health` reports the intended version and
   environment, then verify `/ready`. Run the staging acceptance checks from the release
   checklist before directing production traffic to the new instance.

The image runs as UID/GID 10001, drops Linux capabilities, uses a read-only root filesystem,
and receives only a small temporary filesystem. The Compose port binds to loopback by
default for a same-host TLS proxy. If a managed load balancer must connect directly, override
`PLANIT_API_BIND_ADDRESS` only after configuring the platform firewall.

## Rollback

Application rollback means restoring the previous immutable image and matching mobile/API
compatibility. Database rollback is a separate, higher-risk operation: Alembic downgrades
must first be exercised against a fresh restore of the production backup. Never downgrade
the live database merely because a new container failed health checks; first restore the
previous API image, which must remain backward-compatible with the just-applied migration.

Before every release, record the previous image digest, current Alembic revision, backup ID,
restore owner, and traffic-switch procedure. See `docs/operations.md` for restore drills.

## Horizontal scaling and scheduled work

API containers are stateless and may be replicated behind the load balancer. Run migrations
as one exclusive job before scaling the API. Run the recurring-occurrence worker as one
bounded scheduled job; duplicate protection exists, but overlapping schedulers still waste
capacity and complicate incident analysis.
