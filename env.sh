#!/bin/bash
source ./.env
root_password="$MYSQL_ROOT_PASSWORD"
if [ -z "$root_password" ]; then
  echo "MYSQL_ROOT_PASSWORD is empty"
  exit 1
fi