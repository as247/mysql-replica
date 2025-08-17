#!/bin/bash

# Switch to bash if not already
if [ -z "$BASH_VERSION" ]; then exec bash "$0" "$@"; fi

# Get the directory where this script is located
SCRIPT_DIR=$(realpath "$(dirname "$(readlink -f "$0")")")

# Load environment variables
source "$SCRIPT_DIR/.envload"

# Ensure MYSQL_DATABASE and MYSQL_ROOT_PASSWORD are set
if [ -z "$MYSQL_DATABASE" ] || [ -z "$MYSQL_ROOT_PASSWORD" ]; then
  echo "❌ MYSQL_DATABASE or MYSQL_ROOT_PASSWORD not set. Check $SCRIPT_DIR/.env"
  exit 1
fi

# Determine backup file name
cleanup_file=""
if [ -z "$1" ]; then
  mkdir -p "$SCRIPT_DIR/backup"
  timestamp=$(date +%Y%m%d_%H%M%S)
  backup_file="$SCRIPT_DIR/backup/${timestamp}-${MYSQL_DATABASE}.sql.gz"
  cleanup_file="yes"
else
  backup_file="$1"
  [[ "$backup_file" != *.gz ]] && backup_file="${backup_file}.gz"
fi

# Prepare Docker Compose command
dockerCmd=(docker compose -f "$SCRIPT_DIR/docker-compose.yml")

# Perform backup
echo "📦 Backing up database '$MYSQL_DATABASE' to:"
echo "   $backup_file"
start=$(date +%s)

if "${dockerCmd[@]}" exec -T db mysqldump -u root -p"$MYSQL_ROOT_PASSWORD" \
    --single-transaction --complete-insert "$MYSQL_DATABASE" | gzip -c > "$backup_file"; then
  echo "✅ Backup completed"
else
  echo "❌ Backup failed"
  rm -f "$backup_file"
  exit 2
fi

end=$(date +%s)
echo "⏱️ Duration: $((end - start)) seconds"

# Clean up old backups
if [ "$cleanup_file" == "yes" ]; then
  echo "🧹 Cleaning up old backups (older than 7 days)..."
  find "$SCRIPT_DIR/backup" -type f -mtime +7 -name '*.sql.gz' -delete
fi
