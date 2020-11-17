#!/bin/bash

#======================================================================================================================
# Title         : docker-entrypoint-override.sh
# Description   : Automates local and cloud backups of mariadb
# Author        : Mark Dumay
# Date          : June 16th, 2020
# Version       : 1.0.0
# Usage         : ENTRYPOINT ["docker-entrypoint-override.sh", "docker-entrypoint.sh"]
# Repository    : https://github.com/markdumay/ghost-backend.git
#======================================================================================================================

#======================================================================================================================
# Constants
#======================================================================================================================

readonly BIN=/usr/local/bin
readonly BACKUP_DIR=/var/mariadb/backup
readonly BACKUP_LOG=/var/log/mysqldump.log
readonly RESTIC_LOG=/var/log/restic.log
readonly REPOSITORY="restic/restic"
readonly DOWNLOAD_GITHUB="https://github.com/$REPOSITORY/releases/download"
readonly GITHUB_API="https://api.github.com/repos/$REPOSITORY/releases/latest"
readonly INSTALL_DIR="/usr/bin/restic"
readonly DEFAULT_RESTIC_VERSION='0.9.6'
readonly TEMP_DIR=/tmp/restic


#======================================================================================================================
# Helper Functions
#======================================================================================================================

# Prints current progress to the console
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
            print_status "[Info] Disabling backups"
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

# Download and install latest restic binary
execute_download_install_restic() {
    # Detect latest available stable restic version
    VERSION=$(curl -s "${GITHUB_API}" | grep "tag_name" | grep -Eo "[0-9]+.[0-9]+.[0-9]+")
    if [ -z "${VERSION}" ] ; then
        print_status "[Warning] Could not detect Restic versions available for download, setting default value"
        VERSION="${DEFAULT_RESTIC_VERSION}"
    fi

    # prepare temp download directory
    mkdir -p "${TEMP_DIR}"
    rm -rf "${TEMP_DIR}"/*

    # Download and install targeted restic binary
    OS=$(uname -s | tr -s '[:upper:]' '[:lower:]')
    ARCH=$(uname -m | sed "s/x86_64/amd64/g")
    RESTIC_URL="${DOWNLOAD_GITHUB}/v${VERSION}/restic_${VERSION}_${OS}_${ARCH}.bz2"
    RESPONSE=$(curl -L -s "${RESTIC_URL}" --write-out '%{http_code}' -o "${TEMP_DIR}/restic.bz2")

    if [ "$RESPONSE" != 200 ] ; then
        print_status "[Error] Restic binary could not be downloaded"
    else
        bunzip2 "${TEMP_DIR}/restic.bz2"
        chown root:root "${TEMP_DIR}"/restic && chmod +x "${TEMP_DIR}"/restic
        cp "${TEMP_DIR}"/restic "${INSTALL_DIR}"
        print_status "[Note] Installed $(restic version)"
    fi

    # remove temp download directory
    rm -rf "${TEMP_DIR}"
}

# Initialize cron daemon if either local backup or remote backup is flagged
execute_start_cron() {
    if [ "${LOCAL_BACKUP}" = 'true' ] || [ "${REMOTE_BACKUP}" = 'true' ] ; then
        update-rc.d cron defaults
        /etc/init.d/cron start
        CRON_RUNNING=$(service cron status | grep 'cron is running')
        if [ -n "${CRON_RUNNING}" ] ; then
            print_status "[Note] Initialized cron daemon"
        else
            print_status "[Error] Cron daemon not running / initialized"
        fi
    fi
}

#======================================================================================================================
# Main Script
#======================================================================================================================

# Execute workflows
validate_backup_settings
execute_install_backup_cron
execute_download_install_restic
execute_install_restic_cron
execute_start_cron

# Run container as daemon
exec "$@"