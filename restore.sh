#!/bin/bash
#switch to bash if run by sh
if [ -z "$BASH_VERSION" ]; then
    exec bash "$0" "$@"
fi
# Get the directory where the script is located
SCRIPT_DIR=$(dirname "$(readlink -f "$0")")
SCRIPT_DIR=$(realpath "$SCRIPT_DIR")

source $SCRIPT_DIR/env.sh
restore_file=""
if [ -z "$1" ]; then
  echo "Usage: restore.sh <backup_file>"
  exit 1
else
  restore_file="$1"
fi
if [ ! -f "$restore_file" ]; then
  echo "File $restore_file not found"
  exit 1
fi
echo "Restore $restore_file"
#drop all tables
echo "Drop all tables"
dropTables_file="mysql/helpers/droptables.sql"
docker compose exec -T db mysql -u root -p"$MYSQL_ROOT_PASSWORD" "$MYSQL_DATABASE" < "$dropTables_file"
echo "Restoring"
#check if file is gzip
if [[ "$restore_file" == *.gz ]]; then
  gunzip -c "$restore_file" | docker compose exec -T db mysql -u root -p"$MYSQL_ROOT_PASSWORD" "$MYSQL_DATABASE"
else
  docker compose exec -T db mysql -u root -p"$MYSQL_ROOT_PASSWORD" "$MYSQL_DATABASE" < "$restore_file"
fi
echo "Restore done"