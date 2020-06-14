#!/bin/sh

#======================================================================================================================
# Title         : docker-entrypoint-override.sh
# Description   : Initializes Ghost with default Casper theme
# Author        : Mark Dumay
# Date          : June 14th, 2020
# Version       : 1.0.0
# Usage         : ENTRYPOINT ["docker-entrypoint-override.sh"]
# Repository    : https://github.com/markdumay/ghost-backend.git
#======================================================================================================================

#======================================================================================================================
# Constants
#======================================================================================================================

GHOST_CONTENT="/var/lib/ghost/content"
REPOSITORY="TryGhost/Casper"
DOWNLOAD_GITHUB="https://github.com/$REPOSITORY/archive"
GITHUB_API="https://api.github.com/repos/$REPOSITORY/releases/latest"
INSTALL_DIR="$GHOST_CONTENT/themes/casper/"
DEFAULT_CASPER_VERSION="3.0.12"


#======================================================================================================================
# Helper Functions
#======================================================================================================================

# Prints current progress to the console
print_status () {
    echo "[$(date -u '+%Y-%m-%d %T')] $1"
}


#======================================================================================================================
# Workflow Functions
#======================================================================================================================

# Pull default casper theme if requested
execute_download_install_casper() {
    if [ "$THEMES" == 'true' ] ; then
        print_status "INFO Downloading default theme (Casper)"

        # Detect latest available stable restic version
        VERSION=$(curl -s "$GITHUB_API" | grep "tag_name" | egrep -o "[0-9]+.[0-9]+.[0-9]+")
        if [ -z "$VERSION" ] ; then
            print_status "WARNING Could not detect Casper versions available for download, setting default value"
            VERSION="$DEFAULT_CASPER_VERSION"
        fi

        # Download and extract latest Casper theme
        mkdir -p "$GHOST_CONTENT"/themes/casper/ && chown node:node "$GHOST_CONTENT"/themes/casper/
        curl -sSL "$DOWNLOAD_GITHUB/$VERSION.tar.gz" | tar -C "$INSTALL_DIR/" -xz --strip 1
        CHECK=$(cat "$INSTALL_DIR"/package.json 2> /dev/null | grep "\"version\"" | egrep -o "[0-9]+.[0-9]+.[0-9]+")
        
        if [ "$CHECK" == "$VERSION" ] ; then
            print_status "INFO Installed Casper theme: v$VERSION"
        else
            print_status "ERROR Could not install Casper theme: v$VERSION"
        fi
    else
        print_status "INFO Skipping downloading of default theme, set THEMES=true to override"
    fi
}


#======================================================================================================================
# Main Script
#======================================================================================================================

# Set default values for flags and variables
if [ -z "$THEMES" ]; then THEMES='false'; fi

# Convert selected environment variables to lower case
THEMES=$(echo "$THEMES" | tr -s '[:upper:]' '[:lower:]')

#  Create log directory
mkdir -p "$GHOST_CONTENT"/logs/ && chown node:node "$GHOST_CONTENT"/logs/

# Execute workflows
execute_download_install_casper

# Call parent's entry script in current script context
. /usr/local/bin/docker-entrypoint.sh