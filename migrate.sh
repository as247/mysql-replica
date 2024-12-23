#!/bin/bash
if [ -z "$BASH_VERSION" ]; then
    exec bash "$0" "$@"
fi
# Get the directory where the script is located
SCRIPT_DIR=$(dirname "$(readlink -f "$0")")

# Navigate to the script's directory
cd "$SCRIPT_DIR" || exit
# Folder name without the path
FOLDER_NAME=$(basename "$SCRIPT_DIR")

source ./env.sh
externalIP=$(curl -s4 ifconfig.me)

if [ "$1" == "master" ]; then
    #get master status as update query
    MYSQL_OUTPUT=$(docker compose exec -T db mysql -u root -p"$root_password" -e "SHOW MASTER STATUS\G")
    if [ $? -eq 0 ]; then
        # Extract log file and log position from the output
        LOG_FILE=$(echo "$MYSQL_OUTPUT" | awk 'NR==2{print $2}')
        LOG_POS=$(echo "$MYSQL_OUTPUT" | awk 'NR==3{print $2}')
        # Generate the CHANGE MASTER TO statement
        CHANGE_SQL="CHANGE REPLICATION SOURCE TO SOURCE_HOST='$externalIP', SOURCE_PORT=$MYSQL_REPLICA_PORT, SOURCE_USER='$MYSQL_REPLICA_USER', SOURCE_PASSWORD='$MYSQL_REPLICA_PASSWORD', SOURCE_LOG_FILE='$LOG_FILE', SOURCE_LOG_POS=$LOG_POS;"
        echo "$CHANGE_SQL"
    else
        echo "Failed to retrieve master status. Check your MySQL credentials or connection."
    fi
    exit 0
fi

echo "Backing up $MYSQL_DATABASE for slave"
backup_file="mysql/init/150-import-$MYSQL_DATABASE.sql"
docker compose exec -T db mysqldump -u root -p"$MYSQL_ROOT_PASSWORD" --single-transaction --complete-insert --source-data=1 "$MYSQL_DATABASE" > "$backup_file"
gzip -f "$backup_file"
echo "Backup done"
echo "Update REPLICA_HOST to $externalIP"
sed -i "s/MYSQL_REPLICA_HOST=.*/MYSQL_REPLICA_HOST=\"$externalIP\"/" .env
echo "Update REPLICA_PORT to $MYSQL_PORT"
sed -i "s/MYSQL_REPLICA_PORT=.*/MYSQL_REPLICA_PORT=\"$MYSQL_PORT\"/" .env

echo "Creating package for slave"
tar -zcf "../$FOLDER_NAME.tar.gz" --exclude=mysql/data --exclude=mysql/log --exclude=backup --exclude=.idea -C .. "$FOLDER_NAME"
echo "Package created: $FOLDER_NAME.tar.gz"