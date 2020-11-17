#!/bin/sh
#======================================================================================================================
# Title         : cache-test.sh
# Description   : Compares average duration of a request to a cached and uncached web site
# Author        : Mark Dumay
# Date          : November 11th, 2020
# Version       : 0.1
# Usage         : ./cache-test.sh URL
# Repository    : 
# Comments      :
#======================================================================================================================

#======================================================================================================================
# Constants
#======================================================================================================================
readonly RED='\e[31m' # Red color
readonly NC='\e[m' # No color / reset
readonly BOLD='\e[1m' #Bold font
readonly ITERATIONS=10 # number of iterations to call the specified URL


#======================================================================================================================
# Helper Functions
#======================================================================================================================

#======================================================================================================================
# Display usage message.
#======================================================================================================================
# Outputs:
#   Writes message to stdout.
#======================================================================================================================
usage() { 
    echo "Usage: $0 URL" 
    echo
}

#======================================================================================================================
# Displays error message on console and log file, terminate with non-zero error.
#======================================================================================================================
# Arguments:
#   $1 - Error message to display.
# Outputs:
#   Writes error message to stderr, non-zero exit code.
#======================================================================================================================
terminate() {
    printf "${RED}${BOLD}%s${NC}\n" "ERROR: $1"
    exit 1
}

#======================================================================================================================
# Print current progress to the console.
#======================================================================================================================
# Arguments:
#   $1 - Progress message to display.
# Outputs:
#   Writes message to stdout in bold.
#======================================================================================================================
print_status() {
    printf "${BOLD}%s${NC}\n" "$1"
}

#======================================================================================================================
# Prints current progress to the console.
#======================================================================================================================
# Arguments:
#   $1 - Progress message to display.
# Outputs:
#   Writes message to stdout.
#======================================================================================================================
log() {
    echo "$1"
}


#======================================================================================================================
# Workflow Functions
#======================================================================================================================

#======================================================================================================================
# Times the average response time of a web site across ten requests.
#======================================================================================================================
# Arguments:
#   $1 - The url of the web site to test.
#   $2 - If 'true' call the web site 'no-cache' directive, otherwise use the default directives.
# Outputs:
#   Writes the average duration in milliseconds to stdout.
#======================================================================================================================
execute_call_url_loop() {
    i=1
    total=0
    while [ $i -le $ITERATIONS ]; do
        if [ "$2" = 'true' ]; then
            duration=$(curl -Lsw '%{time_total}' -o /dev/null -H "Cache-Control: no-cache" "$1")
        else
            duration=$(curl -Lsw '%{time_total}' -o /dev/null "$1")
        fi
        total=$(echo "${total} + ${duration}" | bc -l)
        i=$((i + 1))
    done
    avg=$(echo "(${total} / ${ITERATIONS}) * 1000" | bc -l)
    printf "%.*f\n" "0" "${avg}"
}


#======================================================================================================================
# Entrypoint for the script. 
#======================================================================================================================
main() {
    # Show header
    echo "Test script to compare average duration of a request to a cached and uncached web site"
    echo 

    # Validate URL is provided and can be found
    [ -z "$1" ] && usage && terminate "No URL provided"

    # Validate URL can be found
    if ! curl --output /dev/null --silent --head --fail "$1"; then
        terminate "URL does not exist: '$1'"
    fi

    # Measure average cached and uncached response times
    uncached_ms=$(execute_call_url_loop "$1" 'true')
    echo "Uncached average: ${uncached_ms} ms"
    cached_ms=$(execute_call_url_loop "$1" 'false')
    echo "Cached average: ${cached_ms} ms"
}

main "$@"