#!/usr/bin/env sh
set -eu

output_path="${1:-planit-backup.dump}"
compose_file="${PLANIT_COMPOSE_FILE:-infra/docker-compose.yml}"

docker compose -f "$compose_file" exec -T postgres \
  pg_dump --username=planit --dbname=planit --format=custom > "$output_path"

printf 'Backup written to %s\n' "$output_path"
