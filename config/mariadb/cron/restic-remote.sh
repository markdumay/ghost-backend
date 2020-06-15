#!/bin/bash

#======================================================================================================================
# Title         : restic-remote.sh
# Description   : Executes an incremental restic backup
# Author        : Mark Dumay
# Date          : June 15th, 2020
# Version       : 1.0.0
# Usage         : ./restic-inc.sh COMMAND
# Repository    : https://github.com/markdumay/ghost-backend.git
#======================================================================================================================

#======================================================================================================================
# Constants
#======================================================================================================================

SECRET_PREFIX="STAGE_"
PRUNE_ARG='keep-daily 7'


#======================================================================================================================
# Variables
#======================================================================================================================
COMMAND=''
BACKUP_DIR=''


#======================================================================================================================
# Helper Functions
#======================================================================================================================

# Display usage message
usage() { 
    echo "Usage: $0 COMMAND" 
    echo
    echo "Commands:"
    echo "  backup [PATH]          Create a remote backup of PATH"
    echo "  prune                  Prunes snapshots according to rotation schedule ($PRUNE_ARG)"
    echo "  update                 Update the restic binary"
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

# Validates backup directory is available
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

# Validate key availability of key environment variables
validate_env() {
    if [ -z "$RESTIC_REPOSITORY" ] ; then
        terminate "Please specify 'RESTIC_REPOSITORY' environment variable"
    fi

    if [ -z "$RESTIC_PASSWORD_FILE" ] ; then
        terminate "Please specify 'RESTIC_PASSWORD_FILE' environment variable"
    fi
}

# Export Docker secrets with '$SECRET_PREFIX' as environment variables without displaying errors
stage_env() {
    export $(grep -vH --null '^#' /run/secrets/$SECRET_PREFIX* 2> /dev/null | tr '\0' '=' \
        | sed 's/^\/run\/secrets\///g' | sed "s/$SECRET_PREFIX//g")
}


#======================================================================================================================
# Workflow Functions
#======================================================================================================================

# initialize restic repository if needed
execute_init_repository() {
    restic -r "$RESTIC_REPOSITORY" snapshots > /dev/null
    RESULT="$?" # exit code 0 means a snapshot is available and thus the repository is already initialized
    if [ "$RESULT" != 0 ] ; then
        restic -r "$RESTIC_REPOSITORY" init
        RESULT="$?"
        if [ "$RESULT" != 0 ] ; then
            terminate "Cannot initialize restic repository"
        else
            print_status "Initialized restic repository"
        fi
    fi
}

# execute restic backup
execute_backup() {
    SECONDS=0
    restic -r "$RESTIC_REPOSITORY" --verbose backup "$BACKUP_DIR" --cleanup-cache
    RESULT="$?"
    if [ "$RESULT" == 0 ] ; then
        print_status "Completed restic backup in $SECONDS seconds"
    else
        terminate "Cannot execute restic backup (duration: $SECONDS seconds)"
    fi
}

# execute restic prune
execute_prune() {
    SECONDS=0
    restic -r "$RESTIC_REPOSITORY" --verbose forget --${PRUNE_ARG} --prune
    RESULT="$?"
    if [ "$RESULT" == 0 ] ; then
        print_status "Completed restic pruning in $SECONDS seconds"
    else
        terminate "Cannot execute restic prune (duration: $SECONDS seconds)"
    fi
}

# execute restic self-update
execute_update() {
    restic self-update
    RESULT="$?"
    if [ "$RESULT" == 0 ] ; then
        print_status "Completed restic self-update"
    else
        terminate "Cannot self-update restic"
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
        -h | --help )
            usage
            exit
            ;;
        backup )
            COMMAND="$1"
            shift
            BACKUP_DIR="$1"
            validate_backup_dir "Path not specified" "Path not found"
            ;;
        prune )
            COMMAND="$1"
            ;;
        update )
            COMMAND="$1"
            ;;
        * )
            usage
            terminate "Unrecognized parameter ($1)"
    esac
    shift
done

# Execute workflows
# TODO: add restore command and workflow
case "$COMMAND" in
    backup )
        validate_env
        stage_env
        execute_init_repository
        execute_backup
        ;;
    prune )
        validate_env
        stage_env
        execute_init_repository
        execute_prune
        ;;
    update )
        execute_update
        ;;
    * )
        usage
        terminate "No command specified"
esac