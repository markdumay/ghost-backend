#!/bin/bash

BACKUP_DIR=/var/mariadb/backup
DAY_DIR="$BACKUP_DIR"/`date +%Y-%m`/
TARGET_DIR="$DAY_DIR"`date +%d_%Hh_full`/
USER=$(cat /run/secrets/db_backup_user)
PASSWORD=$(cat /run/secrets/db_backup_password)

if [ -z "$USER" ] || [ -z "$PASSWORD" ] ; then
    echo "ERROR: Database credentials not available, cannot run full backup"
    exit 1
fi

# delete backup directories older than 14 hours
# TODO: fix find: '/var/mariadb/backup/*': No such file or directory
find "$BACKUP_DIR"/* -type d -mmin +$((60*14)) -exec rm -rf {} \;

if [ -e "$TARGET_DIR" ] ; then
    printf "[`date --iso-8601=ns`] Directory $TARGET_DIR already exists\n"
else
    mkdir -p "$TARGET_DIR"

    SECONDS=0

    mariabackup --backup --target-dir="$TARGET_DIR" --user="$USER" --password="$PASSWORD"
    
    printf "completed in $SECONDS seconds\n"
    printf "$TARGET_DIR" > "$DAY_DIR"last_completed_backup
fi