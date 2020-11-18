#!/bin/bash

#======================================================================================================================
# Title         : docker-entrypoint-override.sh
# Description   : Automates local and cloud backups of mariadb
# Author        : Mark Dumay
# Date          : November 17th, 2020
# Version       : 1.1.0
# Usage         : ENTRYPOINT ["docker-entrypoint-override.sh", "docker-entrypoint.sh"]
# Repository    : https://github.com/markdumay/ghost-backend.git
#======================================================================================================================

#======================================================================================================================
# Constants
#======================================================================================================================
readonly BIN='/usr/local/bin'
readonly BACKUP_DIR='/var/mariadb/backup'
readonly BACKUP_LOG='/var/log/mysqldump.log'
readonly RESTIC_LOG='/var/log/restic.log'


#======================================================================================================================
# Variables
#======================================================================================================================
backup_interval=5 # TODO: change to 30 minutes; make ENV setting

# mysqldump-local.sh: echo "0,30 * * * *"
# restic-remote.sh backup: echo "45 * * * *"
# restic-remote.sh prune: "15 1 * * *"
# restic-remote.sh update: "15 4 * * *"


#======================================================================================================================
# Helper Functions
#======================================================================================================================

#======================================================================================================================
# Print current progress with timestamp to the console.
#======================================================================================================================
# Arguments:
#   $1 - Progress message to display.
# Outputs:
#   Writes message to stdout.
#======================================================================================================================
print_status () {
    echo "$(date -u '+%Y-%m-%d %T') 0 $1"
}

# Validate and initialize local & remote backup settings
validate_backup_settings() {
    # Set default value if needed
    if [ -z "${BACKUP}" ]; then BACKUP='none'; fi

    # Convert environment variables to lower case
    BACKUP=$(echo "${BACKUP}" | tr -s '[:upper:]' '[:lower:]')

    # Set backup flags based upon $BACKUP setting
    case "${BACKUP}" in
        none )
            LOCAL_BACKUP='false'
            REMOTE_BACKUP='false'
            print_status "[Note] Disabling backups"
            ;;
        local )
            LOCAL_BACKUP='true'
            REMOTE_BACKUP='false'
            print_status "[Note] Enabling local backup"
            ;;
        remote )
            LOCAL_BACKUP='true'
            REMOTE_BACKUP='true'
            print_status "[Note] Enabling local and remote backup"
            ;;
        * )
            LOCAL_BACKUP='false'
            REMOTE_BACKUP='false'
            print_status "[Warning] Backup setting not recognized, disabling all backups"
    esac
}

#======================================================================================================================
# Workflow Functions
#======================================================================================================================

# Install mysqldump cron jobs if LOCAL_BACKUP is flagged
execute_install_backup_cron() {
    if [ "${LOCAL_BACKUP}" = 'true' ] ; then
        mkdir -p "${BACKUP_DIR}"

        print_status "[Note] Adding backup cron job"
        print_status "[Note] View the cron logs in '${BACKUP_LOG}'"

        # Add cronjob for full backup if not scheduled yet
        CRON_FULL=$(crontab -l 2> /dev/null | grep "mysqldump-local.sh backup")
        if [ -z "${CRON_FULL}" ] ; then
            (crontab -l 2> /dev/null; \
                echo "0,30 * * * * ${BIN}/mysqldump-local.sh backup ${BACKUP_DIR} >> ${BACKUP_LOG} 2>&1") | crontab -
        fi
    fi
}


# Install restic cron jobs if REMOTE_BACKUP is flagged
execute_install_restic_cron() {
    if [ "${REMOTE_BACKUP}" = 'true' ] ; then
        print_status "[Note] Adding restic cron jobs"
        print_status "[Note] View the cron log in '${RESTIC_LOG}'"

        # Add cronjob for restic backup.sh if not scheduled yet
        CRON_INC=$(crontab -l 2> /dev/null | grep "restic-remote.sh backup")
        if [ -z "${CRON_INC}" ] ; then
            (crontab -l 2> /dev/null; \
                echo "45 * * * * $BIN/restic-remote.sh backup ${BACKUP_DIR} >> ${RESTIC_LOG} 2>&1") | crontab -
        fi

        # Add cronjob for restic prune if not scheduled yet
        CRON_UPDATE=$(crontab -l 2> /dev/null | grep "restic-remote.sh prune")
        if [ -z "${CRON_UPDATE}" ] ; then
            (crontab -l 2> /dev/null; echo "15 1 * * * ${BIN}/restic-remote.sh prune >> ${RESTIC_LOG} 2>&1") | crontab -
        fi

        # Add cronjob for restic self-update if not scheduled yet
        CRON_UPDATE=$(crontab -l 2> /dev/null | grep "restic-remote.sh update")
        if [ -z "${CRON_UPDATE}" ] ; then
            (crontab -l 2> /dev/null; echo "15 4 * * * $BIN/restic-remote.sh update >> ${RESTIC_LOG} 2>&1") | crontab -
        fi
    fi
}

execute_scheduled_backup() {
    while true
    do 
        sleep "${backup_interval}"
        print_status "[Note] Invoking local backup"
        # Execute backup command and redirect its output to the current terminal / log
        mysqldump-local.sh backup "${BACKUP_DIR}" > /proc/$$/fd/1 || print_status "[Warning] Local backup failed"
    done
}

#======================================================================================================================
# Main Script
#======================================================================================================================

#======================================================================================================================
# Entrypoint for the script.
#======================================================================================================================
main() {
    # Execute workflows
    validate_backup_settings
    execute_install_backup_cron
    execute_install_restic_cron

    # Run container as daemon
    # TODO: fix parameter validation
    if [ "${BACKUP}" == 'local' ] || [ "${BACKUP}" == 'remote' ]; then
        exec "$@" & execute_scheduled_backup
    else
        exec "$@"
    fi
}

main "$@"