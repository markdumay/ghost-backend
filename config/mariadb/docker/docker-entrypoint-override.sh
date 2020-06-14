#!/bin/bash

#======================================================================================================================
# Title         : docker-entrypoint-override.sh
# Description   : Automates local and cloud backups of mariadb
# Author        : Mark Dumay
# Date          : June 14th, 2020
# Version       : 1.0.0
# Usage         : ENTRYPOINT ["docker-entrypoint-override.sh", "docker-entrypoint.sh"]
# Repository    : https://github.com/markdumay/ghost-backend.git
#======================================================================================================================

#======================================================================================================================
# Constants
#======================================================================================================================

BACKUP_DIR=/var/mariadb/backup
REPOSITORY="restic/restic"
DOWNLOAD_GITHUB="https://github.com/$REPOSITORY/releases/download"
GITHUB_API="https://api.github.com/repos/$REPOSITORY/releases/latest"
INSTALL_DIR="/usr/bin/restic"
DEFAULT_RESTIC_VERSION='0.9.6'
TEMP_DIR=/tmp/restic


#======================================================================================================================
# Helper Functions
#======================================================================================================================

# Prints current progress to the console
print_status () {
    echo "$(date -u '+%Y-%m-%d %T') 0 $1"
}


#======================================================================================================================
# Workflow Functions
#======================================================================================================================

# Install backup cron jobs
execute_install_backup_cron() {
    if [ "$LOCAL_BACKUP" == 'true' ] ; then
        mkdir -p "$BACKUP_DIR"

        print_status "[Note] Adding backup cron jobs"
        print_status "[Note] View the cron logs in '/var/log/backup-*.log'"

        # Add cronjob for backup-inc.sh if not scheduled yet
        CRON_INC=$(crontab -l 2> /dev/null | grep -q "backup-inc")
        if [ -z "$CRON_INC"] ; then
            (crontab -l 2> /dev/null; echo "30 * * * * backup-inc.sh >> /var/log/backup-inc.log 2>&1") | crontab -
        fi

        # Add cronjob for backup-full.sh if not scheduled yet
        CRON_FULL=$(crontab -l 2> /dev/null | grep -q "backup-full")
        if [ -z "$CRON_FULL" ] ; then
            (crontab -l 2> /dev/null; echo "0 0,12 * * * backup-full.sh >> /var/log/backup-full.log 2>&1") | crontab -
        fi
    fi
}

# Install restic cron jobs
execute_install_restic_cron() {
    if [ "$REMOTE_BACKUP" == 'true' ] ; then
        print_status "[Note] Adding restic cron jobs"
        print_status "[Note] View the cron log in '/var/log/restic.log'"

        # Add cronjob for restic backup.sh if not scheduled yet
        CRON_INC=$(crontab -l 2> /dev/null | grep -q "restic-remote.sh backup")
        if [ -z "$CRON_INC"] ; then
            (crontab -l 2> /dev/null; echo "45 * * * * restic-remote.sh backup $BACKUP_DIR >> /var/log/restic.log 2>&1") | crontab -
        fi

        # Add cronjob for restic prune if not scheduled yet
        CRON_UPDATE=$(crontab -l 2> /dev/null | grep -q "restic prune")
        if [ -z "$CRON_UPDATE" ] ; then
            (crontab -l 2> /dev/null; echo "15 1 * * * restic prune >> /var/log/restic.log 2>&1") | crontab -
        fi

        # Add cronjob for restic self-update if not scheduled yet
        CRON_UPDATE=$(crontab -l 2> /dev/null | grep -q "restic update")
        if [ -z "$CRON_UPDATE" ] ; then
            (crontab -l 2> /dev/null; echo "15 4 * * * restic update >> /var/log/restic.log 2>&1") | crontab -
        fi
    fi
}

# Download and install latest restic binary
execute_download_install_restic() {
    # Detect latest available stable restic version
    VERSION=$(curl -s "$GITHUB_API" | grep "tag_name" | egrep -o "[0-9]+.[0-9]+.[0-9]+")
    if [ -z "$VERSION" ] ; then
        print_status "[Warning] Could not detect Restic versions available for download, setting default value"
        VERSION="$DEFAULT_RESTIC_VERSION"
    fi

    # prepare temp download directory
    mkdir -p "$TEMP_DIR"
    rm -rf "$TEMP_DIR"/*

    # Download and install targeted restic binary
    OS=$(uname -s | tr -s '[:upper:]' '[:lower:]')
    ARCH=$(uname -m | sed "s/x86_64/amd64/g")
    RESTIC_URL="${DOWNLOAD_GITHUB}/v${VERSION}/restic_${VERSION}_${OS}_${ARCH}.bz2"
    RESPONSE=$(curl -L -s "$RESTIC_URL" --write-out %{http_code} -o "$TEMP_DIR/restic.bz2")

    if [ "$RESPONSE" != 200 ] ; then
        print_status "[Error] Restic binary could not be downloaded"
    else
        bunzip2 "$TEMP_DIR/restic.bz2"
        chown root:root "$TEMP_DIR"/restic && chmod +x "$TEMP_DIR"/restic
        cp "$TEMP_DIR"/restic "$INSTALL_DIR"
        print_status "[Note] Installed $(restic version)"
    fi

    # remove temp download directory
    rm -rf "$TEMP_DIR"
}


#======================================================================================================================
# Main Script
#======================================================================================================================

# Set default values for flags and variables
if [ -z "$LOCAL_BACKUP" ]; then LOCAL_BACKUP='false'; fi
if [ -z "$REMOTE_BACKUP" ]; then REMOTE_BACKUP='false'; fi

# Convert selected environment variables to lower case
LOCAL_BACKUP=$(echo "$LOCAL_BACKUP" | tr -s '[:upper:]' '[:lower:]')
REMOTE_BACKUP=$(echo "$REMOTE_BACKUP" | tr -s '[:upper:]' '[:lower:]')

# TODO: configure logrotate
# TODO: add notifications
# mail -s "$HOSTNAME backup $(test $? -eq 0 && echo 'successful' || echo 'failed') on $(date +%d-%m-%Y\ %R)" 'admin@markdumay.com' <<< "$(restic snapshots)"

# Execute workflows
execute_install_backup_cron
execute_download_install_restic
execute_install_restic_cron

# Run container as daemon
exec "$@"