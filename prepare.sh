#!/bin/bash
if [ -z "$BASH_VERSION" ]; then
    exec bash "$0" "$@"
fi
# Get the directory where the script is located
SCRIPT_DIR=$(dirname "$(readlink -f "$0")")
# Navigate to the script's directory
cd "$SCRIPT_DIR" || exit
if [ -f .env ]; then
  source ./.env
fi
if [ ! -f docker-compose.yml ]; then
  cp docker-compose-sample.yml docker-compose.yml
fi
architecture=$(uname -m)
passwordLength=20
if [ "$architecture" == "x86_64" ]; then
  MYSQL_IMAGE="mysql:8.0.38-debian"
else
  MYSQL_IMAGE="mysql:8.0.38"
fi
find_free_port() {
    local start_port=$1
    local end_port=$2

    for (( port=start_port; port<=end_port; port++ )); do
        # Try to bind to the port using nc (netcat)
        nc -z localhost $port 2>/dev/null
        if [ $? -ne 0 ]; then
            echo $port
            return 0
        fi
    done

    echo "No free port found in the range $start_port-$end_port"
    return 1
}
#if MYSQL_PORT is not set then set it to 33306
if [ -z "$MYSQL_PORT" ]; then
  #Mysql default port is free port > 3306
  #try to scan for free port

  MYSQL_DEFAULT_PORT=$(find_free_port 3307 3500)
  if [ $? -ne 0 ]; then
    echo "No free port found in the range 3307-3500"
    exit 1
  fi

  #ask for mysql port
  read -p "Enter mysql port (default $MYSQL_DEFAULT_PORT): " MYSQL_PORT
  if [ -z "$MYSQL_PORT" ]; then
    MYSQL_PORT=$MYSQL_DEFAULT_PORT
  fi
fi

#Ask for ip address prefix if not set
if [ -z "$IP_ADDRESS_PREFIX" ]; then
  read -p "Enter ip address prefix (default 172.20.0): " IP_ADDRESS_PREFIX
  if [ -z "$IP_ADDRESS_PREFIX" ]; then
    IP_ADDRESS_PREFIX="172.20.0"
  fi
fi

#Ask if user want to use phpmyadmin
if [ -z "$PHPMYADMIN_PORT" ]; then
  read -p "Do you want to use phpmyadmin? (y/n) " -r
  if [[ $REPLY =~ ^[Yy]$ ]]
  then
      PHPMYADMIN_PORT=""
  else
      PHPMYADMIN_PORT=0
  fi
fi
#if PHPMYADMIN_PORT is not set then set it to 8801
if [ -z "$PHPMYADMIN_PORT" ]; then
  #ask for phpmyadmin port
  PHPMYADMIN_DEFAULT_PORT=$(find_free_port 8802 9000)
  if [ $? -ne 0 ]; then
    echo "No free port found in the range 8802-9000"
    exit 1
  fi
  read -p "Enter phpmyadmin port (default $PHPMYADMIN_DEFAULT_PORT): " PHPMYADMIN_PORT
  if [ -z "$PHPMYADMIN_PORT" ]; then
    PHPMYADMIN_PORT=$PHPMYADMIN_DEFAULT_PORT
  fi
fi

if [ $PHPMYADMIN_PORT -ne 0 ]; then
  echo "PHPMYADMIN_PORT=$PHPMYADMIN_PORT"
else
  #remove phpmyadmin from docker-compose.yml
  #remove string between #phpmyadmin-start and #phpmyadmin-end
  sed -i '/#phpmyadmin-start/,/#phpmyadmin-end/d' docker-compose.yml
fi


  #echo "Generate random password for MYSQL_REPLICA_PASSWORD"
if [ -z "$MYSQL_REPLICA_PASSWORD" ]; then
  MYSQL_REPLICA_PASSWORD=$(< /dev/urandom tr -dc '[:upper:]' | head -c 1)$(< /dev/urandom tr -dc '[:lower:]' | head -c 1)$(< /dev/urandom tr -dc '0-9' | head -c 1)$(< /dev/urandom tr -dc '[:alnum:]' | head -c "$((passwordLength - 3))"; echo)

fi

#echo "Generate random password for MYSQL_ROOT_PASSWORD"
if [ -z "$MYSQL_ROOT_PASSWORD" ]; then
  MYSQL_ROOT_PASSWORD=$(< /dev/urandom tr -dc '[:upper:]' | head -c 1)$(< /dev/urandom tr -dc '[:lower:]' | head -c 1)$(< /dev/urandom tr -dc '0-9' | head -c 1)$(< /dev/urandom tr -dc '[:alnum:]' | head -c "$((passwordLength - 3))"; echo)
fi

#set MYSQL_DATABASE
if [ -z "$MYSQL_DATABASE" ]; then
  read -p "Enter mysql database name (default mydb): " MYSQL_DATABASE
  if [ -z "$MYSQL_DATABASE" ]; then
    MYSQL_DATABASE="mydb"
  fi
fi
#set MYSQL_USER
if [ -z "$MYSQL_USER" ]; then
  read -p "Enter mysql user name (default myuser): " MYSQL_USER
  if [ -z "$MYSQL_USER" ]; then
    MYSQL_USER="myuser"
  fi
fi
  #echo "Generate random password for MYSQL_PASSWORD"
if [ -z "$MYSQL_PASSWORD" ]; then
  MYSQL_PASSWORD=$(< /dev/urandom tr -dc '[:upper:]' | head -c 1)$(< /dev/urandom tr -dc '[:lower:]' | head -c 1)$(< /dev/urandom tr -dc '0-9' | head -c 1)$(< /dev/urandom tr -dc '[:alnum:]' | head -c "$((passwordLength - 3))"; echo)
fi


MYSQL_ROOT_HOST=$IP_ADDRESS_PREFIX.%
MYSQL_HOST=$IP_ADDRESS_PREFIX.%
#Write to .env file
echo "MYSQL_IMAGE=$MYSQL_IMAGE" > .env
echo "MYSQL_PORT=$MYSQL_PORT" >> .env
echo "IP_ADDRESS_PREFIX=$IP_ADDRESS_PREFIX" >> .env
echo "PHPMYADMIN_PORT=$PHPMYADMIN_PORT" >> .env
echo "MYSQL_ROOT_HOST=\"$MYSQL_ROOT_HOST\"" >> .env
echo "MYSQL_REPLICA_HOST=" >> .env
echo "MYSQL_REPLICA_PORT=" >> .env
echo "MYSQL_REPLICA_USER=repl_user" >> .env
echo "MYSQL_REPLICA_PASSWORD=\"$MYSQL_REPLICA_PASSWORD\"" >> .env
echo "MYSQL_ROOT_PASSWORD=\"$MYSQL_ROOT_PASSWORD\"" >> .env
echo "MYSQL_DATABASE=\"$MYSQL_DATABASE\"" >> .env
echo "MYSQL_USER=\"$MYSQL_USER\"" >> .env
echo "MYSQL_PASSWORD=\"$MYSQL_PASSWORD\"" >> .env

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
echo "Mysql prepared"
echo "You can start the mysql server by running 'docker compose up -d'"
echo "********************************************************"
echo "Public port: $MYSQL_PORT"
echo "Root password: $MYSQL_ROOT_PASSWORD"
echo "*********************************************************"
echo "* Host: $IP_ADDRESS_PREFIX.2"
echo "* Name: $MYSQL_DATABASE"
echo "* User: $MYSQL_USER"
echo "* Pass: $MYSQL_PASSWORD"
echo "*********************************************************"

# rename init/100-set-replica.sql.txt to init/100-set-replica.sql if server id in conf.d/001-server.cnf is not 1
#if [ "$(grep -c "server-id[[:space:]]*=[[:space:]]*1" conf.d/001-server.cnf)" -eq 0 ]; then
#     mv init/100-set-replica.sql.txt init/100-set-replica.sql
#fi

