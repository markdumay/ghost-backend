#!/bin/sh

DOWNLOAD_GITHUB=https://github.com/TryGhost/Casper
GITHUB_RELEASES=/TryGhost/Casper/releases/tag
DEFAULT_CASPER_VERSION=3.0.12

# Set default values for flags and variables
if [ -z "$THEMES" ]; then THEMES='false'; fi

# Convert selected environment variables to lower case
THEMES=$(echo "$THEMES" | tr -s '[:upper:]' '[:lower:]')

#  Create log directory
mkdir -p "$GHOST_CONTENT"/logs/ && chown node:node "$GHOST_CONTENT"/logs/

# Pull default casper theme if requested
if [ "$THEMES" == 'true' ] ; then
    echo "Downloading default theme (Casper)"
    
    # Identify latest release of Casper, revert to default value if not found
    CASPER_TAGS=$(curl -s "$DOWNLOAD_GITHUB/tags" | egrep "a href=\"$GITHUB_RELEASES/[0-9]+.[0-9]+.[0-9]+\"")
    LATEST_CASPER_VERSION=$(echo "$CASPER_TAGS" | head -1 | cut -c 46- | sed "s/\">//g")
    if [ ! -z "$LATEST_CASPER_VERSION" ] ; then
        TARGET_CASPER_VERSION="$LATEST_CASPER_VERSION"
    else
        echo "Could not identify latest Casper version, reverting to default value"
        TARGET_CASPER_VERSION="$DEFAULT_CASPER_VERSION"
    fi

    # Download and extract latest Casper theme
    echo "Targeted Casper theme: v$TARGET_CASPER_VERSION"
    mkdir -p "$GHOST_CONTENT"/themes/casper/ && chown node:node "$GHOST_CONTENT"/themes/casper/
    curl -sSL "https://github.com/TryGhost/Casper/archive/$TARGET_CASPER_VERSION.tar.gz" \
        | tar -C "$GHOST_CONTENT/themes/casper/" -xz --strip 1
else
    echo "Skipping downloading of default theme, set THEMES=true to override"
fi

# Call parent's entry script in current script context
. /usr/local/bin/docker-entrypoint.sh