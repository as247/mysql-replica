#!/bin/bash
#switch to bash if run by sh
if [ -z "$BASH_VERSION" ]; then
    exec bash "$0" "$@"
fi
# Get the directory where the script is located
SCRIPT_DIR=$(dirname "$(readlink -f "$0")")
# Navigate to the script's directory
cd "$SCRIPT_DIR" || exit

if [ ! -f mysql.env ]; then
  echo "mysql.env not found"
  exit 1
fi
root_password=""
source ./env.sh
#cd to backup.sh dir
cd "$(dirname "$0")"
mkdir -p backup
backup_file="backup/$(date +%Y%m%d_%H%M%S)-$MYSQL_DATABASE.sql"

docker compose exec -T db mysqldump -u root -p"$root_password" --single-transaction --complete-insert "$MYSQL_DATABASE" > "$backup_file"
gzip "$backup_file"
echo "Backup saved to $backup_file.gz"
#clean old backups
find backup -type f -mtime +7 -name '*.gz' -delete
