#!/bin/bash

#======================================================================================================================
# Title         : mysqldump-local.sh
# Description   : Executes or restores a full local mariadb backup
# Author        : Mark Dumay
# Date          : June 17th, 2020
# Version       : 1.0.0
# Usage         : ./mysqldump-local.sh [OPTIONS] COMMAND
# Repository    : https://github.com/markdumay/ghost-backend.git
#======================================================================================================================

#======================================================================================================================
# Variables
#======================================================================================================================
COMMAND=''
BACKUP_DIR=''
USER=''
PASSWORD=''
BACKUP_FILENAME=''
BACKUP_FILENAME_FLAG='false'
DELTA_FLAG='false'
FORCE='false'


#======================================================================================================================
# Helper Functions
#======================================================================================================================

# Display usage message
usage() {
    echo "Create a backup or restore from a local mariadb"
    echo
    echo "Usage: $0 [OPTIONS] COMMAND"
    echo
    echo "Options:"
    echo "  -b, --backup NAME      Name of the backup (defaults to 'DATABASE_backup_Ymd_HhMmSs.sql')"
    echo "  -d, --database         Database name (defaults to '$MYSQL_DATABASE')"
    echo "  -f, --force            Force restore (bypass confirmation check)"
    echo "  -p, --password         Database user password (instead of input from '$MYSQL_ROOT_PASSWORD_FILE')"
    echo
    echo "Commands:"
    echo "  backup [PATH]          Create a local backup of PATH"
    echo "  restore [PATH]         Restore a local backup from PATH"
    echo
}

# Prints current progress to the console
print_status() {
    echo "$(date -u '+%Y-%m-%d %T') $1"
}

# Display error message and terminate with non-zero error
terminate() {
    print_status "ERROR: $1"
    echo
    exit 1
}

# Validate backup directory is available
validate_backup_dir() {
    # check PATH is provided
    if [ -z "$BACKUP_DIR" ] || [ "${BACKUP_DIR:0:1}" == "-" ] ; then
        usage
        terminate "$1"
    fi

    # cut trailing '/'
    if [ "${BACKUP_DIR:0-1}" == "/" ] ; then
        BACKUP_DIR="${BACKUP_DIR%?}"
    fi

    # check PATH exists
    if [ ! -d "$BACKUP_DIR" ] ; then
        usage
        terminate "$2"
    fi
}

# Validates provided backup filename
validate_backup_filename() {
    # check filename is provided
    if [ -z "$BACKUP_FILENAME" ] || [ "${BACKUP_FILENAME:0:1}" == "-" ] ; then
        usage
        terminate "$1"
    fi

    # split into directory and filename if applicable
    # TODO: test
    BASEPATH=$(dirname "$BACKUP_FILENAME")
    if [ -z "$BASEPATH" ] || [ "$BASEPATH" != "." ]; then
        ABS_PATH_AND_FILE=$(readlink -f "$DOCKER_BACKUP_FILENAME")
        BACKUP_DIR=$(dirname "$ABS_PATH_AND_FILE")
        BACKUP_FILENAME=$(basename "$ABS_PATH_AND_FILE")
    fi
}

# Validate database
validate_database() {
    # check DATABASE is provided
    if [ -z "$DATABASE" ] || [ "${DATABASE:0:1}" == "-" ] ; then
        usage
        terminate "$1"
    fi
}

# Validate password
validate_password() {
    # check PASSWORD is provided
    if [ -z "$PASSWORD" ] || [ "${PASSWORD:0:1}" == "-" ] ; then
        usage
        terminate "$1"
    fi
}

# verify mysqld is running
validate_mysqld() {
    IS_SQL_RUNNING=$(ps -u mysql | grep 'mysqld')
    if [ -z "$IS_SQL_RUNNING" ] ; then
        terminate "MariaDB needs to be running for the backup to run"
    fi
}

# Retrieve and validate arguments if not provided already
read_arguments() {
    if [ -z "$DATABASE" ] ; then
        DATABASE="$MYSQL_DATABASE"
    fi

    if [ -z "$PASSWORD" ] ; then
        PASSWORD=$(cat "$MYSQL_ROOT_PASSWORD_FILE" 2> /dev/null)
    fi

    if [ -z "$DATABASE" ] || [ -z "$PASSWORD" ] ; then
        usage
        terminate "ERROR: Database name or password not provided / available"
    fi
}

# ask user to confirm restore unless forced
confirm_operation() {
    if [ "$FORCE" != 'true' ] ; then
        echo
        echo "WARNING! This operation will:"
        echo "  - Remove all existing database files"
        echo "  - Restore the database from available backups"
        echo
        read -p "Are you sure you want to continue? [y/N] " CONFIRMATION

        if [ "$CONFIRMATION" != 'y' ] && [ "$CONFIRMATION" != 'Y' ] ; then
            exit
        fi 
    fi
}

#======================================================================================================================
# Workflow Functions
#======================================================================================================================

# execute full backup
execute_backup() {
    # define target backup filename
    if [ -z "$BACKUP_FILENAME" ] ; then
        TARGET_PATH_FILE="$BACKUP_DIR/$DATABASE"_backup_`date +%Y%m%d_%Hh%Mm%Ss`.sql
    else
        TARGET_PATH_FILE="$BACKUP_DIR/$BACKUP_FILENAME"
    fi

    # dump the database data to an SQL script
    SECONDS=0
    mysqldump "$DATABASE" -p${PASSWORD} > ${TARGET_PATH_FILE}
    RESULT="$?"
    if [ "$RESULT" == 0 ] ; then
        print_status "Completed backup to '$TARGET_PATH_FILE' in $SECONDS sec"
    else
        terminate "Could not execute backup (duration: $SECONDS sec)"
    fi
}

# execute restore from latest full backup
execute_restore() {
    # define source backup filename
    if [ -z "$BACKUP_FILENAME" ] ; then
        # identify last full backup
        SOURCE_BACKUP=$(find ${BACKUP_DIR}/${DATABASE}_backup_* | sort | tail -1)
        if [ -z "$SOURCE_BACKUP" ] ; then
            terminate "No database backup found in directory '$BACKUP_DIR'"
        fi
    else
        SOURCE_BACKUP="$BACKUP_DIR/$BACKUP_FILENAME"
    fi

    # restore the database
    SECONDS=0
    mysql "$DATABASE" -p${PASSWORD} < "$SOURCE_BACKUP"
    RESULT="$?"
    if [ "$RESULT" == 0 ] ; then
        print_status "Completed restore from '$SOURCE_BACKUP' in $SECONDS seconds"
    else
        terminate "Could not execute restore (duration: $SECONDS sec)"
    fi
}

#======================================================================================================================
# Main Script
#======================================================================================================================

# Test if script has root privileges, exit otherwise
if [[ $(id -u) -ne 0 ]]; then
    usage
    terminate "You need to be root to run this script"
fi

# Process and validate command-line arguments
while [ "$1" != "" ]; do
    case "$1" in
        -b | --backup )
            shift
            BACKUP_FILENAME="$1"
            BACKUP_FILENAME_FLAG='true'
            validate_backup_filename "Filename not provided"
            ;;
        -d | --database )
            shift
            USER="$1"
            validate_database "No valid database provided"
            ;;
        -f | --force )
            FORCE='true'
            ;;
        -p | --password )
            shift
            PASSWORD="$1"
            validate_password "No valid password provided"
            ;;
        -h | --help )
            usage
            exit
            ;;
        backup | restore )
            COMMAND="$1"
            shift
            BACKUP_DIR="$1"
            validate_backup_dir "Path not specified" "Path not found"
            ;;
        * )
            usage
            terminate "Unrecognized parameter ($1)"
    esac
    shift
done

# Execute workflows
case "$COMMAND" in
    backup )
        read_arguments
        validate_mysqld
        execute_backup
        ;;
    restore )
        read_arguments
        validate_mysqld
        confirm_operation
        execute_restore
        ;;
    * )
        usage
        terminate "No command specified"
esac