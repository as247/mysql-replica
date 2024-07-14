#!/bin/bash
#switch to bash if run by sh
if [ -z "$BASH_VERSION" ]; then
    exec bash "$0" "$@"
fi
# Get the directory where the script is located
SCRIPT_DIR=$(dirname "$(readlink -f "$0")")
# Navigate to the script's directory
cd "$SCRIPT_DIR" || exit

root_password=""
source ./env.sh
mkdir -p backup
#check backup file from argument
if [ -z "$1" ]; then
  backup_file="backup/$(date +%Y%m%d_%H%M%S)-$MYSQL_DATABASE.sql.gz"
else
  backup_file="$1"
  #if file name not end with .gz then add it
  if [[ "$backup_file" != *.gz ]]; then
    backup_file="$backup_file.gz"
  fi
fi


docker compose exec -T db mysqldump -u root -p"$root_password" --single-transaction --complete-insert "$MYSQL_DATABASE" | gzip -c > "$backup_file"
echo "Backup saved to $backup_file"
#clean old backups
find backup -type f -mtime +7 -name '*.gz' -delete
