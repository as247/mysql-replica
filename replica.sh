#!/bin/bash
if [ -z "$BASH_VERSION" ]; then
    exec bash "$0" "$@"
fi
# Get the directory where the script is located
SCRIPT_DIR=$(dirname "$(readlink -f "$0")")
# Navigate to the script's directory
cd "$SCRIPT_DIR" || exit
# check server id
if [ "$(grep -c "server-id[[:space:]]*=[[:space:]]*1$" mysql/conf.d/001-server.cnf)" -eq 1 ]; then
    echo "This is master server"
    suggest_server_id=$(curl -s ifconfig.me | tr -d . | rev | cut -c 1-4 | rev)
    # set server_id with prompt
    read -p "Enter server id[$suggest_server_id]: " server_id
    if [ -z "$server_id" ]; then
        server_id=$suggest_server_id
        read -p "Are you sure to use server id: $server_id?" -r
        if [[ ! $REPLY =~ ^[Yy]$ ]]
        then
            echo "cancelled"
            exit 1
        fi
    fi

    # check if server id is number
    if ! [[ "$server_id" =~ ^[0-9]+$ ]]; then
        echo "Server id is not a number"
        exit 1
    fi

    # set server id to conf
    sed -i "s/server-id[[:space:]]*=[[:space:]]*[^ ]*/server-id = $server_id/g" mysql/conf.d/001-server.cnf
fi
if [ "$(grep -c "server-id[[:space:]]*=[[:space:]]*1$" mysql/conf.d/001-server.cnf)" -eq 1 ]; then
    echo "This is master server"
    exit 1
fi

#Prepare env
source ./prepare.sh
echo "Prepare replica init files"
cp mysql/init/replica/*.* mysql/init
echo "Replica init file prepared. Starting service"
docker compose up -d

