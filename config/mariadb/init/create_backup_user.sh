#!/bin/bash

#======================================================================================================================
# Title         : create_backup_user.sh
# Description   : Creates a backup user for a maria database server
# Author        : Mark Dumay
# Date          : June 17th, 2020
# Version       : 1.0.0
# Usage         : create_backup_user.sh
# Repository    : https://github.com/markdumay/ghost-backend.git
# Comments      : Expects Docker secrets 'db_backup_user', 'db_backup_password', and 'db_root_password'
#======================================================================================================================

#======================================================================================================================
# Constants
#======================================================================================================================

DATABASE="$MYSQL_DATABASE"
USER=$(cat /run/secrets/db_backup_user)
PASSWORD=$(cat /run/secrets/db_backup_password)
ROOT_PASSWORD=$(cat /run/secrets/db_root_password)


#======================================================================================================================
# Helper Functions
#======================================================================================================================

# Prints current progress to the console
print_status() {
    echo "$(date -u '+%Y-%m-%d %T') 0 $1"
}

# Display error message and terminate with non-zero error
terminate() {
    print_status "[Error] $1"
    echo
    exit 1
}


#======================================================================================================================
# Main Script
#======================================================================================================================

if [ -z "$DATABASE" ] || [ -z "$USER" ] || [ -z "$PASSWORD" ] || [ -z "$ROOT_PASSWORD" ]; then
    terminate "Database credentials not available, cannot create backup user"
fi

print_status "[Note] Creating mariadb backup user '$USER' for database"
mysql -uroot -p"$ROOT_PASSWORD" -e "CREATE USER '$USER'@'localhost' IDENTIFIED BY '$PASSWORD';"
mysql -uroot -p"$ROOT_PASSWORD" -e "GRANT RELOAD, PROCESS, LOCK TABLES, REPLICATION CLIENT ON *.* TO '$USER'@'localhost';"
mysql -uroot -p"$ROOT_PASSWORD" -e "FLUSH PRIVILEGES;"