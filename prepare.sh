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
isReset="no"
if [ "$1" == "--reset" ]; then
  isReset="yes"
fi
passwordLength=20
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
if [ $isReset == "yes" ]; then
  echo "Regenerate passwords"
  if [ $MYSQL_PORT -ne 0 ]; then
    #Mysql port is set, so we need to reset it
    MYSQL_PORT=""
  fi
  MYSQL_IMAGE=""
  MYSQL_REPLICA_PASSWORD=""
  MYSQL_ROOT_PASSWORD=""
  MYSQL_PASSWORD=""
fi
if [ -z "$MYSQL_IMAGE" ]; then
  # Set default MySQL image based on architecture
  if [ "$architecture" == "x86_64" ]; then
    MYSQL_IMAGE="mysql:8.0.42-debian"
  else
    MYSQL_IMAGE="mysql:8.0.42"
  fi
fi
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
if [ $isReset == "yes" ]; then
  if [ $PHPMYADMIN_PORT -ne 0 ]; then
      #PhpMyAdmin port is set, so we need to reset it
      PHPMYADMIN_PORT=""
  fi
fi
#if PHPMYADMIN_PORT is not set then set it to 8800
if [ -z "$PHPMYADMIN_PORT" ]; then
  #ask for phpmyadmin port
  PHPMYADMIN_DEFAULT_PORT=$(find_free_port 8800 9000)
  if [ $? -ne 0 ]; then
    echo "No free port found in the range 8800-9000"
    exit 1
  fi
  read -p "Enter phpmyadmin port (default $PHPMYADMIN_DEFAULT_PORT): " PHPMYADMIN_PORT
  if [ -z "$PHPMYADMIN_PORT" ]; then
    PHPMYADMIN_PORT=$PHPMYADMIN_DEFAULT_PORT
  fi
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

#echo "Generate random password for MYSQL_REPLICA_PASSWORD"
if [ -z "$MYSQL_REPLICA_PASSWORD" ]; then
  MYSQL_REPLICA_PASSWORD=$(< /dev/urandom tr -dc '[:upper:]' | head -c 1)$(< /dev/urandom tr -dc '[:lower:]' | head -c 1)$(< /dev/urandom tr -dc '0-9' | head -c 1)$(< /dev/urandom tr -dc '[:alnum:]' | head -c "$((passwordLength - 3))"; echo)

fi
#echo "Generate random password for MYSQL_ROOT_PASSWORD"
if [ -z "$MYSQL_ROOT_PASSWORD" ]; then
  MYSQL_ROOT_PASSWORD=$(< /dev/urandom tr -dc '[:upper:]' | head -c 1)$(< /dev/urandom tr -dc '[:lower:]' | head -c 1)$(< /dev/urandom tr -dc '0-9' | head -c 1)$(< /dev/urandom tr -dc '[:alnum:]' | head -c "$((passwordLength - 3))"; echo)
fi

#echo "Generate random password for MYSQL_PASSWORD"
if [ -z "$MYSQL_PASSWORD" ]; then
  MYSQL_PASSWORD=$(< /dev/urandom tr -dc '[:upper:]' | head -c 1)$(< /dev/urandom tr -dc '[:lower:]' | head -c 1)$(< /dev/urandom tr -dc '0-9' | head -c 1)$(< /dev/urandom tr -dc '[:alnum:]' | head -c "$((passwordLength - 3))"; echo)
fi

if [ $MYSQL_PORT -ne 0 ]; then
  echo "Expose mysql on port $MYSQL_PORT"
  # Uncomment only lines between #dbports-start and #dbports-end
    sed -i '/#dbports-start/,/#dbports-end/ {
      /#dbports-start/b
      /#dbports-end/b
      s/^\([[:space:]]*\)#/\1/
    }' docker-compose.yml

else
  echo "Disable mysql port mapping in docker-compose.yml"
  # Comment only lines between #dbports-start and #dbports-end
    sed -i '/#dbports-start/,/#dbports-end/ {
      /#dbports-start/b
      /#dbports-end/b
      s/^\([[:space:]]*\)\([^#[:space:]]\)/\1#\2/
    }' docker-compose.yml
fi

if [ $PHPMYADMIN_PORT -ne 0 ]; then
  echo "Enable phpmyadmin($PHPMYADMIN_PORT) in docker-compose.yml"
  # Uncomment only lines between #phpmyadmin-start and #phpmyadmin-end
  sed -i '/#phpmyadmin-start/,/#phpmyadmin-end/ {
    /#phpmyadmin-start/b
    /#phpmyadmin-end/b
    s/^\([[:space:]]*\)#/\1/
  }' docker-compose.yml
else
  echo "Disable phpmyadmin in docker-compose.yml"
  # Comment only lines between #phpmyadmin-start and #phpmyadmin-end
  sed -i '/#phpmyadmin-start/,/#phpmyadmin-end/ {
    /#phpmyadmin-start/b
    /#phpmyadmin-end/b
    s/^\([[:space:]]*\)\([^#[:space:]]\)/\1#\2/
  }' docker-compose.yml
fi




mkdir -p mysql/data/mysql
mkdir -p mysql/data/log
# Check if data and log dir empty or not if not empty then try to empty it with confirmation
if [ "$(ls -A mysql/data/mysql)" ]; then
    if [ "$isReset" == "yes" ]; then
        echo "Resetting data/mysql and data/log directories"
        docker compose down
        rm -rf mysql/data/*
        mkdir -p mysql/data/mysql
        mkdir -p mysql/data/log
    else
        echo "Data directory is not empty, if you want to empty it run this script again with --reset option"
    fi
fi

chown -R 999:999 mysql/data

MYSQL_ROOT_HOST=$IP_ADDRESS_PREFIX.%

#Write to .env file
echo "MYSQL_IMAGE=$MYSQL_IMAGE" > .env
echo "MYSQL_PORT=$MYSQL_PORT" >> .env
echo "IP_ADDRESS_PREFIX=$IP_ADDRESS_PREFIX" >> .env
echo "PHPMYADMIN_PORT=$PHPMYADMIN_PORT" >> .env
echo "MYSQL_ROOT_HOST=\"$MYSQL_ROOT_HOST\"" >> .env
echo "MYSQL_REPLICA_HOST=\"$MYSQL_REPLICA_HOST\"" >> .env
echo "MYSQL_REPLICA_PORT=\"$MYSQL_REPLICA_PORT\"" >> .env
echo "MYSQL_REPLICA_USER=repl_user" >> .env
echo "MYSQL_REPLICA_PASSWORD=\"$MYSQL_REPLICA_PASSWORD\"" >> .env
echo "MYSQL_ROOT_PASSWORD=\"$MYSQL_ROOT_PASSWORD\"" >> .env
echo "MYSQL_DATABASE=\"$MYSQL_DATABASE\"" >> .env
echo "MYSQL_USER=\"$MYSQL_USER\"" >> .env
echo "MYSQL_PASSWORD=\"$MYSQL_PASSWORD\"" >> .env


# Color ANSI
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
BOLD='\033[1m'
NC='\033[0m' # No Color (reset)

echo -e "${GREEN}${BOLD}Mysql prepared${NC}"
echo -e "${CYAN}You can start the mysql server by running 'docker compose up -d --force-recreate'${NC}"
echo -e "${YELLOW}********************************************************${NC}"
echo -e "${BOLD}MySQL Image:${NC} ${BLUE}$MYSQL_IMAGE${NC}"
echo -e "${BOLD}MySQL port:${NC} ${BLUE}$MYSQL_PORT${NC}"
echo -e "${BOLD}Root password:${NC} ${RED}$MYSQL_ROOT_PASSWORD${NC}"
echo -e "${YELLOW}********************************************************${NC}"
echo -e "${BOLD}* Host:${NC} ${BLUE}$IP_ADDRESS_PREFIX.2${NC}"
echo -e "${BOLD}* Name:${NC} ${BLUE}$MYSQL_DATABASE${NC}"
echo -e "${BOLD}* User:${NC} ${BLUE}$MYSQL_USER${NC}"
echo -e "${BOLD}* Pass:${NC} ${RED}$MYSQL_PASSWORD${NC}"
echo -e "${YELLOW}********************************************************${NC}"

if [ "$PHPMYADMIN_PORT" -ne 0 ]; then
  echo -e "${GREEN}PhpMyAdmin is enabled on port ${PHPMYADMIN_PORT}${NC}"
  echo -e "${CYAN}You can access it at http://127.0.0.1:${PHPMYADMIN_PORT}${NC}"
else
  echo -e "${RED}PhpMyAdmin is disabled${NC}"
fi

# rename init/100-set-replica.sql.txt to init/100-set-replica.sql if server id in conf.d/001-server.cnf is not 1
#if [ "$(grep -c "server-id[[:space:]]*=[[:space:]]*1" conf.d/001-server.cnf)" -eq 0 ]; then
#     mv init/100-set-replica.sql.txt init/100-set-replica.sql
#fi

