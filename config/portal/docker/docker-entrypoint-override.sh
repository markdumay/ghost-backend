#!/bin/sh

#======================================================================================================================
# Title         : docker-entrypoint-override.sh
# Description   : Configures Nginx reverse proxy with caching enabled/disabled
# Author        : Mark Dumay
# Date          : June 23th, 2020
# Version       : 1.0.0
# Usage         : ENTRYPOINT ["docker-entrypoint-override.sh"]
# Repository    : https://github.com/markdumay/ghost-backend.git
#======================================================================================================================

#======================================================================================================================
# Constants
#======================================================================================================================

CONF_DIR='/var/lib/nginx-conf'


#======================================================================================================================
# Helper Functions
#======================================================================================================================

# Prints current progress to the console
print_status () {
    echo "[$(date -u '+%Y-%m-%d %T')] $1"
}

# Display error message and terminate with non-zero error
terminate() {
    print_status "ERROR: $1"
    echo
    exit 1
}


#======================================================================================================================
# Workflow Functions
#======================================================================================================================

# Configure Nginx server with HTTPS configuration
execute_configure_server() {
    if [ "$CACHING" = 'true' ] ; then
        print_status "INFO Enabling caching"
        mv "$CONF_DIR"/http.conf.erb "$CONF_DIR"/"$DOMAINS_BLOG".conf.erb
        mv "$CONF_DIR"/https-cached.ssl.conf.erb "$CONF_DIR"/"$DOMAINS_BLOG".ssl.conf.erb
        rm "$CONF_DIR"/https-uncached.ssl.conf.erb
    else
        print_status "INFO Disabling caching"
        mv "$CONF_DIR"/http.conf.erb "$CONF_DIR"/"$DOMAINS_BLOG".conf.erb
        mv "$CONF_DIR"/https-uncached.ssl.conf.erb "$CONF_DIR"/"$DOMAINS_BLOG".ssl.conf.erb
        rm "$CONF_DIR"/https-cached.ssl.conf.erb
    fi
}


#======================================================================================================================
# Main Script
#======================================================================================================================

# Validate $DOMAINS_BLOG is set
if [ -z "$DOMAINS_BLOG" ]; then terminate "Please specify 'DOMAINS_BLOG' environment variable"; fi

# Set default values for flags and variables
if [ -z "$CACHING" ]; then CACHING='false'; fi

# Convert selected environment variables to lower case
CACHING=$(echo "$CACHING" | tr -s '[:upper:]' '[:lower:]')

# Execute workflows
execute_configure_server

# Call parent's entry script
/init