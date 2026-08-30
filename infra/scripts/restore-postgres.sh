#!/usr/bin/env sh
set -eu

dump_path="${1:?Pass the backup dump path as the first argument.}"
target_database="${2:-planit_restore}"
compose_file="${PLANIT_COMPOSE_FILE:-infra/docker-compose.yml}"

case "$target_database" in
  planit|postgres|template0|template1)
    printf 'Refusing to overwrite protected database: %s\n' "$target_database" >&2
    exit 2
    ;;
esac

docker compose -f "$compose_file" exec -T postgres \
  dropdb --username=planit --if-exists "$target_database"
docker compose -f "$compose_file" exec -T postgres \
  createdb --username=planit "$target_database"
docker compose -f "$compose_file" exec -T postgres \
  pg_restore --username=planit --dbname="$target_database" --exit-on-error --no-owner < "$dump_path"
docker compose -f "$compose_file" exec -T postgres \
  psql --username=planit --dbname="$target_database" --tuples-only --command \
  'SELECT version_num FROM alembic_version;'

printf 'Restore verified in database %s\n' "$target_database"
