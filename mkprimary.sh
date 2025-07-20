#!/bin/bash

if [ -z "$BASH_VERSION" ]; then
    exec bash "$0" "$@"
fi
# Get the directory where the script is located
SCRIPT_DIR=$(dirname "$(readlink -f "$0")")
# Navigate to the script's directory
cd "$SCRIPT_DIR" || exit
#convert slave to primary

if [ "$(grep -c "server-id[[:space:]]*=[[:space:]]*1$" mysql/conf.d/001-server.cnf)" -eq 1 ]; then
    echo "This is master server already"
    exit 1
fi
#confirmation
read -p "Are you sure to convert this server to primary? (y/n) " -r
if [[ ! $REPLY =~ ^[Yy]$ ]]
then
    echo "cancelled"
    exit 1
fi
source ./env.sh
docker compose exec -T db mysql -u root -p"$MYSQL_ROOT_PASSWORD" -e "STOP REPLICA; RESET REPLICA; SHOW SLAVE STATUS\G"
echo "Change server id to 1"
sed -i "s/server-id[[:space:]]*=[[:space:]]*[^ ]*/server-id = 1/g" mysql/conf.d/001-server.cnf
sed -i "s/MYSQL_PORT=.*/MYSQL_PORT=/" .env

echo "Restart"
docker compose up -d --force-recreate

