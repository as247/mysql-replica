#!/bin/bash
if [ -z "$BASH_VERSION" ]; then
    exec bash "$0" "$@"
fi

# Get the directory where the script is located
SCRIPT_DIR=$(dirname "$(readlink -f "$0")")
# Navigate to the script's directory
cd "$SCRIPT_DIR" || exit
# get a shell to mysql
source ./env.sh
if [ "$1" == "master" ]; then
  #get master status as update query
  docker compose exec -T db mysql -h localhost -u root -p"$MYSQL_ROOT_PASSWORD" -e "SHOW MASTER STATUS\G"
else
  docker compose exec -T db mysql -h localhost -u root -p"$MYSQL_ROOT_PASSWORD" -e "SHOW REPLICA STATUS\G"
fi
