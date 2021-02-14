#!/bin/sh

#======================================================================================================================
# Title         : docker-entrypoint-override.sh
# Description   : Initializes Ghost with default Casper theme
# Author        : Mark Dumay
# Date          : February 13th, 2020
# Version       : 1.2.0
# Usage         : ENTRYPOINT ["docker-entrypoint-override.sh"]
# Repository    : https://github.com/markdumay/ghost-backend.git
#======================================================================================================================

#======================================================================================================================
# Constants
#======================================================================================================================
readonly CONTENT_FOLDERS='/apps /data /images /logs /settings /themes'
readonly INSTALL_DIR='/var/lib/ghost'
readonly CONTENT_BASE_DIR='/var/lib/ghost/content'


#======================================================================================================================
# Variables
#======================================================================================================================
pid=0


#======================================================================================================================
# Helper Functions
#======================================================================================================================

#======================================================================================================================
# Print current progress to the console with a timestamp as prefix.
#======================================================================================================================
# Arguments:
#   $1 - Progress message to display.
# Outputs:
#   Writes message to stdout.
#======================================================================================================================
print_status () {
    echo "[$(date -u '+%Y-%m-%d %T')] $1"
}


#======================================================================================================================
# Workflow Functions
#======================================================================================================================

#======================================================================================================================
# Downloads and installs the latest available Casper theme.
#======================================================================================================================
# Outputs:
#   Files written to '/var/lib/ghost/content/themes/casper/'.
#======================================================================================================================
execute_download_install_casper() {
    local version
    local check

    if [ "${THEMES}" = 'true' ] ; then
        print_status "INFO Downloading default theme (Casper)"

        # Detect latest available stable Casper version
        version=$(curl -s "$GITHUB_API" | grep "tag_name" | grep -Eo "[0-9]+.[0-9]+.[0-9]+")
        if [ -z "${version}" ] ; then
            print_status "WARNING Could not detect Casper versions available for download, setting default value"
            version="${DEFAULT_CASPER_VERSION}"
        fi

        # Download and extract latest Casper theme
        mkdir -p "${GHOST_CONTENT}"/themes/casper
        curl -sSL "${DOWNLOAD_GITHUB}/${version}.tar.gz" | tar -C "${INSTALL_DIR}/" -xz --strip 1
        check=$(cat "${INSTALL_DIR}"/package.json 2> /dev/null | grep "\"version\"" | grep -Eo "[0-9]+.[0-9]+.[0-9]+")
        
        # Validate intallation
        if [ "${check}" = "${version}" ] ; then
            print_status "INFO Installed Casper theme: v${version}"
        else
            print_status "ERROR Could not install Casper theme: v${version}"
        fi
    else
        print_status "INFO Skipping downloading of default theme, set THEMES=true to override"
    fi
}


#======================================================================================================================
# Main Script
#======================================================================================================================

#======================================================================================================================
# Remove the deployed nginx configuration files. Typically invoked during a graceful shutdown triggered by SIGTERM, 
# SIGINT, and SIGQUIT.
#======================================================================================================================
# Outputs:
#   Files removed from '/etc/nginx/templates/' and '/etc/nginx/templates/snippets'.
#======================================================================================================================
# shellcheck disable=SC2001
cleanup() {
    # Store exit code
    err=$?

    # Remove the previously deployed templates
    # TODO: fix
    print_status "INFO Removing nginx configuration templates"
    templates=$(find /var/lib/nginx/templates/*.template -maxdepth 1 -print0 | xargs -0 -n1 basename)
    templates=$(echo "${templates}" | sed -e "s|^|/etc/nginx/templates/|")
    snippets=$(find /var/lib/nginx/snippets/*.conf -maxdepth 1 -print0 | xargs -0 -n1 basename)
    snippets=$(echo "${snippets}" | sed -e "s|^|/etc/nginx/templates/snippets/|")
    templates=$(printf "%s\n%s" "${templates}" "${snippets}")
    echo "${templates}"| while read -r file
    do
        rm "${file}"
    done

    # Stop the main ghost process gracefully
    if [ "${pid}" -ne 0 ]; then
        kill -SIGTERM "${pid}"
        wait "${pid}"
        err=0 # indicate clean exit
    fi

    # Exit the script
    trap '' EXIT INT TERM
    exit "${err}" 
}

#======================================================================================================================
# Process SIGTERM, SIGINT, and SIGQUIT signals and invoke cleanup.
#======================================================================================================================
sig_cleanup() {
    trap '' EXIT # some shells will call EXIT after the INT handler
    false # sets $?
    cleanup
}

#======================================================================================================================
# Entrypoint for the script. It downloads the default Casper theme if applicable and deploys the provided nginx 
# templates. The deployed templates are removed when the Docker container is stopped. To this end, an event handler is
# attached to the INT, QUIT, and TERM signals. The ghost process runs in the background, while an endless loop listens
# for any signals. When a signal is received, the 'cleanup' function is invoked, which removes the templates and
# gracefully stops the ghost background process using its PID.
#======================================================================================================================
main() {
    # Initialize values for flags and variables
    [ -z "${THEMES}" ] && THEMES='false'
    THEMES=$(echo "${THEMES}" | tr -s '[:upper:]' '[:lower:]')

    # Download default theme if applicable
    execute_download_install_casper

    # Initialize content volume, including default theme (Casper)
    folders=$(echo "${CONTENT_FOLDERS}" | sed "s|/|${CONTENT_BASE_DIR}/|g")
    eval "mkdir -p ${folders}"
    ln -s "${INSTALL_DIR}"/current/content/themes/casper "${CONTENT_BASE_DIR}"/themes/casper

    # Trigger cleanup when receiving stop signal
    trap cleanup EXIT
    trap 'kill ${!}; sig_cleanup' INT QUIT TERM

    # Wait for dependencies and then run Ghost in background; store PID for future use
    wait && exec /usr/local/bin/docker-entrypoint.sh "$@" & pid="$!"

    # Listen for any signals indefinitely
    while true
    do
        tail -f /dev/null & wait ${!}
    done    
}

# TODO: temp
# main "$@"
echo "Testing..."