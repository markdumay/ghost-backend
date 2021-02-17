#!/bin/bash

#=======================================================================================================================
# Title         : create_backup_user.sh
# Description   : Creates a backup user for a mariadb server using Docker secrets
# Author        : Mark Dumay
# Date          : February 16th, 2021
# Version       : 1.0.1
# Usage         : create_backup_user.sh
# Repository    : https://github.com/markdumay/ghost-backend.git
# Comments      : Expects Docker secrets 'db_backup_user', 'db_backup_password', and 'db_root_password'
#=======================================================================================================================

#=======================================================================================================================
# Constants
#=======================================================================================================================

readonly DATABASE="$MYSQL_DATABASE"
readonly USER=$(cat /run/secrets/db_backup_user)
readonly PASSWORD=$(cat /run/secrets/db_backup_password)
readonly ROOT_PASSWORD=$(cat /run/secrets/db_root_password)


#=======================================================================================================================
# Helper Functions
#=======================================================================================================================

#=======================================================================================================================
# Print current progress to the console with a timestamp as prefix.
#=======================================================================================================================
# Arguments:
#   $1 - Progress message to display.
# Outputs:
#   Writes message to stdout.
#=======================================================================================================================
print_status() {
    echo "$(date -u '+%Y-%m-%d %T') 0 $1"
}

#=======================================================================================================================
# Displays error message on console and terminates with non-zero error.
#=======================================================================================================================
# Arguments:
#   $1 - Error message to display.
# Outputs:
#   Writes error message to stderr, non-zero exit code.
#=======================================================================================================================
terminate() {
    print_status "[Error] $1"
    echo
    exit 1
}


#=======================================================================================================================
# Main Script
#=======================================================================================================================

#=======================================================================================================================
# Entrypoint for the script.
#=======================================================================================================================
main() {
    if [ -z "${DATABASE}" ] || [ -z "${USER}" ] || [ -z "${PASSWORD}" ] || [ -z "${ROOT_PASSWORD}" ]; then
        terminate "Database credentials not available, cannot create backup user"
    fi

    # TODO: improve script to add backup user
    print_status "[Note] Creating mariadb backup user '${USER}' for database"
    mysql -uroot -p"${ROOT_PASSWORD}" -e "CREATE USER '${USER}'@'localhost' IDENTIFIED BY '${PASSWORD}';"
    mysql -uroot -p"${ROOT_PASSWORD}" -e \
        "GRANT RELOAD, PROCESS, LOCK TABLES, REPLICATION CLIENT ON *.* TO '${USER}'@'localhost';"
    mysql -uroot -p"${ROOT_PASSWORD}" -e "FLUSH PRIVILEGES;"
}

main "$@"