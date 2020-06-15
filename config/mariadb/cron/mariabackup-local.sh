#!/bin/bash

#======================================================================================================================
# Title         : mariabackup-local.sh
# Description   : Executes an incremental and full local mariadb backup
# Author        : Mark Dumay
# Date          : June 15th, 2020
# Version       : 1.0.0
# Usage         : ./mariabackup-localc.sh [OPTIONS] COMMAND
# Repository    : https://github.com/markdumay/ghost-backend.git
# Comments      : Inspired by https://afreshcloud.com/sysadmin/mariabackup-bash-scripts
#======================================================================================================================

#======================================================================================================================
# Constants
#======================================================================================================================
USER_SECRET='/run/secrets/db_backup_user'
PASSWORD_SECRET='/run/secrets/db_backup_password'


#======================================================================================================================
# Variables
#======================================================================================================================
COMMAND=''
BACKUP_DIR=''
USER=''
PASSWORD=''
DELTA_FLAG='false'


#======================================================================================================================
# Helper Functions
#======================================================================================================================

# Display usage message
usage() {
    echo "Create a backup or restore from a local mariadb"
    echo
    echo "Usage: $0 COMMAND"
    echo
    echo "Options:"
    echo "  -d, --delta            Create a delta backup (instead of default full backup)"
    echo "  -u, --user             Database username (instead of input from /run/secrets/db_backup_user)"
    echo "  -p, --password         Database user password (instead of input from /run/secrets/db_backup_password)"
    echo
    echo "Commands:"
    echo "  backup [PATH]          Create a local backup of PATH"
    echo "  restore [PATH]         Restore a local backup from PATH"
    echo
}

# Prints current progress to the console
print_status() {
    echo "[00] $(date -u '+%Y-%m-%d %T') $1"
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

# Validate username
validate_user() {
    # check USER is provided
    if [ -z "$USER" ] || [ "${USER:0:1}" == "-" ] ; then
        usage
        terminate "$1"
    fi
}

# Validate password
validate_user() {
    # check USER is provided
    if [ -z "$PASSWORD" ] || [ "${PASSWORD:0:1}" == "-" ] ; then
        usage
        terminate "$1"
    fi
}

# Read and validate credentials from secrets if not provided as arguments already
read_credentials() {
    if [ -z "$USER" ] ; then
        USER=$(cat "$USER_SECRET" 2> /dev/null)
    fi

    if [ -z "$PASSWORD" ] ; then
        PASSWORD=$(cat "$PASSWORD_SECRET" 2> /dev/null)
    fi

    if [ -z "$USER" ] || [ -z "$PASSWORD" ] ; then
        usage
        terminate "ERROR: Database credentials not provided"
    fi
}

#======================================================================================================================
# Workflow Functions
#======================================================================================================================

# execute full backup
execute_backup_full() {
    DAY_DIR="$BACKUP_DIR"/`date +%Y-%m`/
    TARGET_DIR="$DAY_DIR"`date +%d_%Hh_full`/

    if [ -e "$TARGET_DIR" ] ; then
        terminate "Directory '$TARGET_DIR' already exists"
    fi

    mkdir -p "$TARGET_DIR"
    SECONDS=0

    mariabackup --backup --target-dir="$TARGET_DIR" --user="$USER" --password="$PASSWORD"

    RESULT="$?"
    if [ "$RESULT" == 0 ] ; then
        print_status "Completed full backup in $SECONDS seconds"
        printf "$TARGET_DIR" > "$DAY_DIR"last_completed_backup
    else
        terminate "Cannot execute full backup (duration: $SECONDS seconds)"
    fi
}

# execute delta backup
execute_backup_delta() {
    DAY_DIR="$BACKUP_DIR"/`date +%Y-%m`/
    TARGET_DIR="$DAY_DIR"`date +%d_%Hh%Mm_inc`/

    if [ -e "$TARGET_DIR" ] ; then
        terminate "Directory '$TARGET_DIR' already exists"
    else
        mkdir -p "$DAY_DIR"

        if [ -e "$DAY_DIR"last_completed_backup ] ; then
            BASE_DIR=$(head -n 1 "$DAY_DIR"last_completed_backup)

            if [ -z "$BASE_DIR" ] ; then
                terminate "Base dir is an empty string"
            else
                mkdir -p "$TARGET_DIR"

                SECONDS=0

                mariabackup --backup \
                    --target-dir="$TARGET_DIR" --incremental-basedir="$BASE_DIR" --user="$USER" --password="$PASSWORD"

                RESULT="$?"
                if [ "$RESULT" == 0 ] ; then
                    print_status "Completed delta backup in $SECONDS seconds"
                    printf "$TARGET_DIR" > "$DAY_DIR"last_completed_backup
                else
                    terminate "Cannot execute full backup (duration: $SECONDS seconds)"
                fi
            fi
        else
            terminate "No base dir for incremental backup"
        fi
    fi
}

# execute full or delta backup pending command-line arguments
execute_backup() {
    # delete backup directories older than 14 hours
    find ${BACKUP_DIR}/* -type d -mmin +$((60*14)) -exec rm -rf {} \; 

    if [ "$DELTA_FLAG" == 'true' ] ; then
        execute_backup_delta
    else
        execute_backup_full
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
        -d | --delta )
            DELTA_FLAG='true'
            ;;
        -u | --user )
            shift
            USER="$1"
            validate_user "No valid username provided"
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
# TODO: add restore workflow
case "$COMMAND" in
    backup )
        read_credentials
        execute_backup
        ;;
    restore )
        ;;
    * )
        usage
        terminate "No command specified"
esac