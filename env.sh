#!/bin/bash
if [ ! -f mysql.env ]; then
  echo "mysql.env not found"
  exit 1
fi
source ./.env
source ./mysql.env
root_password="$MYSQL_ROOT_PASSWORD"
if [ -z "$root_password" ]; then
  echo "MYSQL_ROOT_PASSWORD is empty"
  exit 1
fi