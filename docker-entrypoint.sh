#!/bin/sh

# Set default values for flags and variables
CASPER_VERSION=3.0.12
if [ -z "$THEMES" ]; then THEMES='false'; fi

# Convert selected environment variables to lower case
THEMES=$(echo "$THEMES" | tr -s '[:upper:]' '[:lower:]')

#  Create log directory
mkdir -p "$GHOST_CONTENT"/logs/ && chown node:node "$GHOST_CONTENT"/logs/

# Pull default casper theme if requested
# TODO: identify latest casper version
if [ "$THEMES" == 'true' ] ; then
    echo "Downloading default theme (Casper v$CASPER_VERSION)"
    mkdir -p "$GHOST_CONTENT"/themes/casper/ && chown node:node "$GHOST_CONTENT"/themes/casper/
    curl -sSL "https://github.com/TryGhost/Casper/archive/$CASPER_VERSION.tar.gz" \
        | tar -C "$GHOST_CONTENT/themes/casper/" -xz --strip 1
else
    echo "Skipping downloading of default theme, set THEMES=true to override"
fi

# Call parent's entry script in current script context
. /usr/local/bin/docker-entrypoint.sh