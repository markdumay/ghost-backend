#!/bin/sh

DATABASE="$MYSQL_DATABASE"
USER=$(cat /run/secrets/db_backup_user)
PASSWORD=$(cat /run/secrets/db_backup_password)
ROOT_PASSWORD=$(cat /run/secrets/db_root_password)

if [ -z "$DATABASE" ] || [ -z "$USER" ] || [ -z "$PASSWORD" ] || [ -z "$ROOT_PASSWORD" ]; then
    echo "ERROR: Database credentials not available, cannot create backup user"
    exit 1
fi

echo "Creating mariadb backup user for database '$DATABASE'"
mysql -uroot -p"$ROOT_PASSWORD" -e "CREATE USER '$USER'@'localhost' IDENTIFIED BY '$PASSWORD';"
mysql -uroot -p"$ROOT_PASSWORD" -e "GRANT RELOAD, PROCESS, LOCK TABLES, REPLICATION CLIENT ON *.* TO '$USER'@'localhost';"
mysql -uroot -p"$ROOT_PASSWORD" -e "FLUSH PRIVILEGES;"