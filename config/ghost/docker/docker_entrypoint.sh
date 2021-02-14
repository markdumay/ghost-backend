#!/bin/sh

#======================================================================================================================
# Title         : docker_entrypoint.sh
# Description   : Runs Ghost using nginx as proxy
# Author        : Mark Dumay
# Date          : February 14th, 2020
# Version       : 1.2.0
# Usage         : ENTRYPOINT ["docker_entrypoint.sh"]
# Repository    : https://github.com/markdumay/ghost-backend.git
#======================================================================================================================

#======================================================================================================================
# Constants
#======================================================================================================================
readonly RED='\e[31m' # Red color
readonly NC='\e[m'    # No color / reset
readonly BOLD='\e[1m' # Bold font
readonly NODE_CMD="node 'current/index.js'"
readonly TEMPLATE_SOURCE_DIR='/var/lib/nginx/templates'
readonly SNIPPETS_SOURCE_DIR='/var/lib/nginx/snippets'
readonly TEMPLATE_TARGET_DIR='/etc/nginx/templates'
readonly SNIPPETS_TARGET_DIR='/etc/nginx/templates/snippets'
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

#=======================================================================================================================
# Displays error message on console and terminates with non-zero error.
#=======================================================================================================================
# Arguments:
#   $1 - Error message to display.
# Outputs:
#   Writes error message to stderr, non-zero exit code.
#=======================================================================================================================
terminate() {
    printf "[$(date -u '+%Y-%m-%d %T')] ${RED}${BOLD}%s${NC}\n" "ERROR: $1"
    exit 1
}


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
# Validates if a specified fully qualified domain name or subdomain adheres to the expected format.
#======================================================================================================================
# Arguments:
#   $1 - Domain to be verified. International names need to be converted to punycode ('xn--*') first.
# Returns:
#   Returns 0 if domain is supported, non-zero otherwise.
#======================================================================================================================
is_valid_domain() {
    domain_regex='^((?=[a-z0-9-]{1,63}\.)(xn--)?[a-z0-9]+(-[a-z0-9]+)*\.)+[a-z]{2,63}$'
    match=$(echo "$1" | grep -Pi "${domain_regex}")
    ([ -z "${match}" ] && return 1) || return 0
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
    templates="${DOMAINS_BLOG}".conf.template
    snippets=$(find "${SNIPPETS_SOURCE_DIR}"/*.conf -maxdepth 1 -print0 | xargs -0 -n1 basename)
    snippets=$(echo "${snippets}" | sed -e "s|^|${TEMPLATE_SNIPPETS_DIR}/|")
    templates=$(printf "%s\n%s" "${templates}" "${snippets}")
    echo "${templates}"| while read -r file
    do
        rm "${file}"
        print_status "INFO Removed deployed template: ${file}"
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
# Entrypoint for the script. It deploys the provided nginx templates. The deployed templates are removed when the
# Docker container is stopped. To this end, an event handler is attached to the INT, QUIT, and TERM signals. The ghost 
# process runs in the background, while an infinite loop listens for any signals. When a signal is received, the 
# 'cleanup' function is invoked, which removes the templates and gracefully stops the ghost background process using
# its PID.
#======================================================================================================================
main() {
    # Validate env variables
    [ -z "${DOMAINS_BLOG}" ] && terminate "Please specify 'DOMAINS_BLOG' environment variable"
    [ -z "${CACHING}" ] && terminate "Please specify 'CACHING' environment variable"
    is_valid_domain "${DOMAINS_BLOG}" || terminate "Invalid domain: ${DOMAINS_BLOG}"
    [ "${CACHING}" != 'cached' ] && [ "${CACHING}" != 'uncached' ] && terminate "Invalid caching value: ${CACHING}"

    # Copy nginx templates and snippets
    # TODO: test
    print_status "INFO Deploying nginx configuration templates (${CACHING})"
    mkdir -p "${SNIPPETS_TARGET_DIR}"
    cp "${TEMPLATE_SOURCE_DIR}/ghost-${CACHING}".conf.template "${TEMPLATE_TARGET_DIR}/${DOMAINS_BLOG}".conf.template
    cp "${SNIPPETS_SOURCE_DIR}"/*.conf "${SNIPPETS_TARGET_DIR}"/

    # Display deployed files
    # TODO: test
    templates="${TEMPLATE_TARGET_DIR}/${DOMAINS_BLOG}".conf.template
    snippets=$(find "${SNIPPETS_TARGET_DIR}"/*.conf -maxdepth 1 -print0 | xargs -0 -n1 basename)
    snippets=$(echo "${snippets}" | sed -e "s|^|${SNIPPETS_TARGET_DIR}/|")
    files=$(printf "%s\n%s" "${templates}" "${snippets}")
    echo "${files}" | while read -r file
    do
        print_status "INFO Deployed template: ${file}"
    done

    # Initialize content volume, including default theme (Casper)
    print_status "INFO Initializing content folder"
    folders=$(echo "${CONTENT_FOLDERS}" | sed "s|/|${CONTENT_BASE_DIR}/|g")
    eval "mkdir -p ${folders}"
    print_status "INFO Installing default theme (Casper)"
    rm -rf "${CONTENT_BASE_DIR}"/themes/casper
    cp -r "${INSTALL_DIR}"/current/content/themes/casper "${CONTENT_BASE_DIR}"/themes/casper

    # Trigger cleanup when receiving stop signal
    trap cleanup EXIT
    trap 'kill ${!}; sig_cleanup' INT QUIT TERM

    # Wait for dependencies and then run Ghost in background; store PID for future use
    wait && eval "${NODE_CMD}" & pid="$!"

    # Listen for any signals indefinitely
    while true
    do
        tail -f /dev/null & wait ${!}
    done    
}

main "$@"