#!/bin/bash
# Switch to bash if not already
if [ -z "$BASH_VERSION" ]; then exec bash "$0" "$@"; fi
# Get the directory where this script is located
SCRIPT_DIR=$(realpath "$(dirname "$(readlink -f "$0")")")

source "$SCRIPT_DIR/.envload"

if [ -z "$1" ]; then
  echo "Usage: restore.sh <backup_file>"
  exit 1
fi

restore_file="$1"
if [ ! -f "$restore_file" ]; then
  echo "❌ File $restore_file not found"
  exit 1
fi

# Ensure MYSQL_DATABASE and MYSQL_ROOT_PASSWORD are set
if [ -z "$MYSQL_DATABASE" ] || [ -z "$MYSQL_ROOT_PASSWORD" ]; then
  echo "❌ MYSQL_DATABASE or MYSQL_ROOT_PASSWORD not set. Check $SCRIPT_DIR/.env"
  exit 1
fi

echo "Restoring from $restore_file"

dropTables_file="$SCRIPT_DIR/mysql/helpers/droptables.sql"
dockerCmd=(docker compose -f "$SCRIPT_DIR/docker-compose.yml")

echo "Dropping all tables in $MYSQL_DATABASE..."
if ! "${dockerCmd[@]}" exec -T db mysql -u root -p"$MYSQL_ROOT_PASSWORD" "$MYSQL_DATABASE" < "$dropTables_file"; then
  echo "❌ Failed to drop tables"
  exit 2
fi

echo "Restoring data..."
start=$(date +%s)
if [[ "$restore_file" == *.gz ]]; then
  gunzip -c "$restore_file" | "${dockerCmd[@]}" exec -T db mysql -u root -p"$MYSQL_ROOT_PASSWORD" "$MYSQL_DATABASE"
else
  "${dockerCmd[@]}" exec -T db mysql -u root -p"$MYSQL_ROOT_PASSWORD" "$MYSQL_DATABASE" < "$restore_file"
fi
end=$(date +%s)

echo "✅ Restore done in $((end - start)) seconds"
