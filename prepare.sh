#!/bin/bash
if [ -z "$BASH_VERSION" ]; then
    exec bash "$0" "$@"
fi
# Get the directory where the script is located
SCRIPT_DIR=$(dirname "$(readlink -f "$0")")
# Navigate to the script's directory
cd "$SCRIPT_DIR" || exit
source ./.env
architecture=$(uname -m)
passwordLength=16
if [ "$architecture" == "x86_64" ]; then
  MYSQL_IMAGE="mysql:8.0.34-debian"
else
  MYSQL_IMAGE="mysql:8.0.34"
fi
#if MYSQL_PORT is not set then set it to 33306
if [ -z "$MYSQL_PORT" ]; then
  MYSQL_PORT=33306
fi
#if PHPMYADMIN_PORT is not set then set it to 8801
if [ -z "$PHPMYADMIN_PORT" ]; then
  PHPMYADMIN_PORT=8801
fi
chmod +x *.sh
echo "MYSQL_IMAGE=$MYSQL_IMAGE" > .env
echo "MYSQL_PORT=$MYSQL_PORT" >> .env
echo "PHPMYADMIN_PORT=$PHPMYADMIN_PORT" >> .env

if [ ! -f mysql.env ]; then
  echo "mysql.env not found, copying from mysql.env.example"
  cp mysql.env.example mysql.env
  echo "Generate random password for MYSQL_ROOT_PASSWORD"
  root_password=$(tr -dc A-Za-z0-9 </dev/urandom | head -c $passwordLength; echo)
  sed -i "s/MYSQL_ROOT_PASSWORD=.*/MYSQL_ROOT_PASSWORD=\"$root_password\"/" mysql.env
  echo "Generate random password for MYSQL_REPLICA_PASSWORD"
  replica_password=$(tr -dc A-Za-z0-9 </dev/urandom | head -c $passwordLength; echo)
  sed -i "s/MYSQL_REPLICA_PASSWORD=.*/MYSQL_REPLICA_PASSWORD=\"$replica_password\"/" mysql.env
  echo "Generate random password for MYSQL_PASSWORD"
  password=$(tr -dc A-Za-z0-9 </dev/urandom | head -c $passwordLength; echo)
  sed -i "s/MYSQL_PASSWORD=.*/MYSQL_PASSWORD=\"$password\"/" mysql.env


fi

mkdir -p mysql/data
mkdir -p mysql/log
# Check if data and log dir empty or not if not empty then try to empty it with confirmation
if [ "$(ls -A mysql/data)" ]; then
    read -p "mysql/data is not empty, do you want to empty it? (y/n) " -r

    if [[ $REPLY =~ ^[Yy]$ ]]
    then
        docker compose down
        rm -rf mysql/data/*
        rm -rf mysql/log/*
    else
        echo "Keep existing data"
    fi
fi

chown -R 999:999 mysql/data
chown -R 999:999 mysql/log
echo "Tiny mysql is ready"
# rename init/100-set-replica.sql.txt to init/100-set-replica.sql if server id in conf.d/001-server.cnf is not 1
#if [ "$(grep -c "server-id[[:space:]]*=[[:space:]]*1" conf.d/001-server.cnf)" -eq 0 ]; then
#     mv init/100-set-replica.sql.txt init/100-set-replica.sql
#fi

