#!/bin/bash

#======================================================================================================================
# Title         : mysqldump-local.sh
# Description   : Executes or restores a full local mariadb backup
# Author        : Mark Dumay
# Date          : November 18th, 2020
# Version       : 1.1.0
# Usage         : ./mysqldump-local.sh [OPTIONS] COMMAND
# Repository    : https://github.com/markdumay/ghost-backend.git
#======================================================================================================================

#======================================================================================================================
# Constants
#======================================================================================================================
readonly RED='\e[31m' # Red color
readonly NC='\e[m'    # No color / reset
readonly BOLD='\e[1m' # Bold font


#======================================================================================================================
# Variables
#======================================================================================================================
command=''
backup_dir=''
backup_filename=''
user=''
database=''
password=''
force='false'


#======================================================================================================================
# Helper Functions
#======================================================================================================================

#======================================================================================================================
# Display usage message.
#======================================================================================================================
# Globals:
#   - MYSQL_DATABASE
#   - MYSQL_BACKUP_USER_FILE
#   - MYSQL_BACKUP_PASSWORD_FILE
# Outputs:
#   Writes message to stdout.
#======================================================================================================================
usage() {
    echo "Create a backup or restore from a local mariadb"
    echo
    echo "Usage: $0 [OPTIONS] COMMAND"
    echo
    echo "Options:"
    echo "  -b, --backup NAME      Name of the backup (defaults to 'DATABASE_backup_Ymd_HhMmSs.sql')"
    echo "  -d, --database         Database name (defaults to 'MYSQL_DATABASE')"
    echo "  -f, --force            Force restore (bypass confirmation check)"
    echo "  -u, --user             Database user name (defaults to 'MYSQL_BACKUP_USER_FILE')"
    echo "  -p, --password         Database user password (defaults to 'MYSQL_BACKUP_PASSWORD_FILE')"
    echo
    echo "Commands:"
    echo "  backup [PATH]          Create a local backup at PATH"
    echo "  restore [PATH]         Restore a local backup from PATH"
    echo
}

#======================================================================================================================
# Displays error message on console and terminates with non-zero error.
#======================================================================================================================
# Arguments:
#   $1 - Error message to display.
# Outputs:
#   Writes error message to stderr, non-zero exit code.
#======================================================================================================================
terminate() {
    printf "${RED}${BOLD}%s${NC}\n" "$(date -u '+%Y-%m-%d %T') 0 [Error] $1"
    exit 1
}

#======================================================================================================================
# Print current progress with timestamp to the console.
#======================================================================================================================
# Arguments:
#   $1 - Progress message to display.
# Outputs:
#   Writes message to stdout.
#======================================================================================================================
print_status() {
    echo "$(date -u '+%Y-%m-%d %T') 0 [Note] $1"
}

#======================================================================================================================
# Validate and standardize provided backup directory.
#======================================================================================================================
# Globals:
#   - backup_dir
# Outputs:
#   Standardized backup_dir, or non-zero exit code if backup_dir not provided.
#======================================================================================================================
validate_backup_dir() {
    # check backup_dir is provided
    if [ -z "${backup_dir}" ] || [ "${backup_dir:0:1}" == "-" ] ; then
        usage
        terminate "$1"
    fi

    # cut trailing '/'
    if [ "${backup_dir:0-1}" == "/" ] ; then
        backup_dir="${backup_dir%?}"
    fi

    # check PATH exists
    if [ ! -d "$backup_dir" ] ; then
        usage
        terminate "$2"
    fi
}

#======================================================================================================================
# Validate and standardize provided backup filename. Updates backup_dir if the provided filename contains a qualified
# path.
#======================================================================================================================
# Globals:
#   - backup_dir
#   - backup_filename
# Outputs:
#   Standardized backup_filename and updated backup_dir, or non-zero exit code if backup_filename not provided.
#======================================================================================================================
validate_backup_filename() {
    # check filename is provided
    if [ -z "${backup_filename}" ] || [ "${backup_filename:0:1}" == "-" ] ; then
        usage
        terminate "$1"
    fi

    # split into directory and filename if applicable
    filename=$(basename "${backup_filename}")
    if [ "${filename}" != "${backup_filename}" ] ; then
        abs_path_and_file=$(readlink -f "${backup_filename}")
        backup_dir=$(dirname "${abs_path_and_file}")
        backup_filename=$(basename "${abs_path_and_file}")
    fi
}

#======================================================================================================================
# Validate provided database name.
#======================================================================================================================
# Globals:
#   - database
# Outputs:
#   Non-zero exit code if database name not provided.
#======================================================================================================================
validate_database() {
    if [ -z "${database}" ] || [ "${database:0:1}" == "-" ] ; then
        usage
        terminate "$1"
    fi
}

#======================================================================================================================
# Validate provided user name.
#======================================================================================================================
# Globals:
#   - user
# Outputs:
#   Non-zero exit code if user name not provided.
#======================================================================================================================
validate_user() {
    if [ -z "${user}" ] || [ "${user:0:1}" == "-" ] ; then
        usage
        terminate "$1"
    fi
}

#======================================================================================================================
# Validate provided password.
#======================================================================================================================
# Globals:
#   - password
# Outputs:
#   Non-zero exit code if password not provided.
#======================================================================================================================
validate_password() {
    # check PASSWORD is provided
    if [ -z "${password}" ] || [ "${password:0:1}" == "-" ] ; then
        usage
        terminate "$1"
    fi
}

#======================================================================================================================
# Verifies MySQL daemon (mysqld) is running. The daemon is required for backup and restore operations.
#======================================================================================================================
# Outputs:
#   Non-zero exit code if mysqld not running.
#======================================================================================================================
validate_mysqld() {
    if ! pgrep -f 'mysqld' > /dev/null; then
        terminate "MariaDB is not running"
    fi
}

#======================================================================================================================
# Initializes the database name, user name, and password. If not provided on the command line, the variables are
# read from the environment variables instead.
#======================================================================================================================
# Globals:
#   - MYSQL_DATABASE
#   - MYSQL_BACKUP_USER_FILE
#   - MYSQL_BACKUP_PASSWORD_FILE
#   - database
#   - user
#   - password
# Outputs:
#   Non-zero exit code if either database, user, or password is missing.
#======================================================================================================================
read_arguments() {
    if [ -z "${database}" ] ; then
        database="${MYSQL_DATABASE}"
    fi

    if [ -z "${user}" ] ; then
        user=$(cat "${MYSQL_BACKUP_USER_FILE}" 2> /dev/null)
    fi

    if [ -z "${password}" ] ; then
        password=$(cat "${MYSQL_BACKUP_PASSWORD_FILE}" 2> /dev/null)
    fi

    if [ -z "${database}" ] || [ -z "${user}" ] || [ -z "${password}" ] ; then
        usage
        terminate "Database, user, or password not provided"
    fi
}

#======================================================================================================================
# Prompts the user to confirm the operation, unless forced.
#======================================================================================================================
# Globals:
#   - force
# Outputs:
#   Terminates with zero exit code if user does not confirm the operation.
#======================================================================================================================
confirm_operation() {
        if [ "${force}" != 'true' ] ; then
        echo
        echo "WARNING! This operation will:"
        echo "  - Remove all existing database files"
        echo "  - Restore the database from available backups"
        echo
        read -r -p "Are you sure you want to continue? [y/N] " answer

        if [ "${answer}" != 'y' ] && [ "${answer}" != 'Y' ] ; then
            exit
        fi 
    fi
}

#======================================================================================================================
# Workflow Functions
#======================================================================================================================

#======================================================================================================================
# Executes a full backup of the database and exports it as an SQL script. The backup filename is generated using the 
# current UTC date and time if no backup filename is provided. The backup uses the provided credentials and database 
# name.
#======================================================================================================================
# Globals:
#   - backup_dir
#   - backup_filename
#   - database
#   - user
#   - password
# Outputs:
#   Terminates with non-zero exit code if the database backup failed.
#======================================================================================================================
execute_backup() {
    # define target backup filename
    local target_path_file
    if [ -z "${backup_filename}" ] ; then
        target_path_file="${backup_dir}/${database}_backup_$(date -u +%Y%m%d_%Hh%Mm%Ss).sql"
    else
        target_path_file="${backup_dir}/${backup_filename}"
    fi

    # dump the database data to an SQL script
    SECONDS=0
    mysqldump "${database}" "-u${user}" "-p${password}" > "${target_path_file}"
    result="$?"
    if [ "${result}" == 0 ] ; then
        elapsed="${SECONDS}"
        [ "${elapsed}" -eq 0 ] && elapsed='<1'
        print_status "Completed backup to '${target_path_file}' in ${elapsed} sec"
    else
        terminate "Could not execute backup (duration: ${SECONDS} sec)"
    fi
}

#======================================================================================================================
# Restores the database from a full backup (SQL script). The latest available backup is used, unless a specific backup 
# name is provided. The restore uses the provided credentials and database name.
#======================================================================================================================
# Globals:
#   - backup_dir
#   - backup_filename
#   - database
#   - user
#   - password
# Outputs:
#   Terminates with non-zero exit code if the database backup failed.
#======================================================================================================================
execute_restore() {
    # define source backup filename
    if [ -z "${backup_filename}" ] ; then
        # identify last full backup
        source_backup=$(find "${backup_dir}"/"${database}"_backup_* | sort | tail -1)
        if [ -z "${source_backup}" ] ; then
            terminate "No database backup found in directory '${backup_dir}'"
        fi
    else
        source_backup="${backup_dir}/${backup_filename}"
    fi

    # restore the database
    SECONDS=0
    mysql "${database}" "-u${user}" "-p${password}" < "${source_backup}"
    result="$?"
    if [ "${result}" == 0 ] ; then
        print_status "Completed restore from '${source_backup}' in ${SECONDS} seconds"
    else
        terminate "Could not execute restore (duration: ${SECONDS} sec)"
    fi
}

#======================================================================================================================
# Main Script
#======================================================================================================================

#======================================================================================================================
# Entrypoint for the script. 
#======================================================================================================================
main() {
    # Process and validate command-line arguments
    while [ "$1" != "" ]; do
        case "$1" in
            -b | --backup )
                shift
                backup_filename="$1"
                validate_backup_filename "Filename not provided"
                ;;
            -d | --database )
                shift
                user="$1"
                validate_database "No valid database provided"
                ;;
            -f | --force )
                force='true'
                ;;
            -u | --user )
                shift
                user="$1"
                validate_user "No valid user provided"
                ;;
            -p | --password )
                shift
                password="$1"
                validate_password "No valid password provided"
                ;;
            -h | --help )
                usage
                exit
                ;;
            backup | restore )
                command="$1"
                shift
                backup_dir="$1"
                validate_backup_dir "Path not specified" "Path not found"
                ;;
            * )
                usage
                terminate "Unrecognized parameter ($1)"
        esac
        shift
    done

    # Execute workflows
    case "${command}" in
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
}

main "$@"