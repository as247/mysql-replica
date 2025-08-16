#!/bin/bash
SCRIPT_DIR=$(dirname "$(readlink -f "$0")")
source "$SCRIPT_DIR/.env"
root_password="$MYSQL_ROOT_PASSWORD"
if [ -z "$root_password" ]; then
  echo "MYSQL_ROOT_PASSWORD is empty"
  exit 1
fi