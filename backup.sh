#!/bin/bash
#switch to bash if run by sh
if [ -z "$BASH_VERSION" ]; then
    exec bash "$0" "$@"
fi
# Get the directory where the script is located
SCRIPT_DIR=$(dirname "$(readlink -f "$0")")
#make script directory absolute
SCRIPT_DIR=$(realpath "$SCRIPT_DIR")

source "$SCRIPT_DIR/env.sh"
#check backup file from argument
cleanup_file=""
if [ -z "$1" ]; then
  mkdir -p "$SCRIPT_DIR/backup"
  backup_file="$SCRIPT_DIR/backup/$(date +%Y%m%d_%H%M%S)-$MYSQL_DATABASE.sql.gz"
  cleanup_file="yes"
else
  backup_file="$1"
  #if file name not end with .gz then add it
  if [[ "$backup_file" != *.gz ]]; then
    backup_file="$backup_file.gz"
  fi
fi

dockerCmd="docker compose -f $SCRIPT_DIR/docker-compose.yml"
$dockerCmd exec -T db mysqldump -u root -p"$MYSQL_ROOT_PASSWORD" --single-transaction --complete-insert "$MYSQL_DATABASE" | gzip -c > "$backup_file"
echo "Backup saved to $backup_file"
if [ -n "$cleanup_file" ]; then
  echo "Cleanup old backups"
  # delete files older than 7 days
  find "$SCRIPT_DIR/backup" -type f -mtime +7 -name '*.sql.gz' -delete
fi
