#!/bin/bash
#=======================================================================================================================
# Title         : docker-healthcheck.sh
# Description   : Validates the health of a local mariadb server.
# Copyright     : Copyright © 2021 Mark Dumay. All rights reserved.
# Date          : February 16th, 2021
# Version       : 0.1
# Usage         : docker-healthcheck.sh
# Repository    : https://github.com/markdumay/ghost-backend
# Comments      : This work is derived from the docker-library/healthcheck
#                 (https://github.com/docker-library/healthcheck/)
#                 Use of this source code is governed by The MIT License (MIT) that can be found in the LICENSE file.
#=======================================================================================================================

set -eo pipefail


#=======================================================================================================================
# Helper Functions
#=======================================================================================================================

#=======================================================================================================================
# Sources a variable from a file, such as Docker secrets. 
# Usage: file_env VAR [DEFAULT]
#    ie: file_env 'XYZ_DB_PASSWORD' 'example' (will allow for "$XYZ_DB_PASSWORD_FILE" to fill in the value of
#  "$XYZ_DB_PASSWORD" from a file, especially for Docker's secrets feature)
#=======================================================================================================================
# Arguments:
#   $1 - Variable name to source
#   $2 - Default value
# Outputs:
#   Exported variable.
#=======================================================================================================================
file_env() {
	local var="$1"
	local fileVar="${var}_FILE"
	local def="${2:-}"
	if [ "${!var:-}" ] && [ "${!fileVar:-}" ]; then
		mysql_error "Both $var and $fileVar are set (but are exclusive)"
	fi
	local val="$def"
	if [ "${!var:-}" ]; then
		val="${!var}"
	elif [ "${!fileVar:-}" ]; then
		val="$(< "${!fileVar}")"
	fi
	export "$var"="$val"
	unset "$fileVar"
}


#=======================================================================================================================
# Main Script
#=======================================================================================================================

#=======================================================================================================================
# Entrypoint for the script.
#=======================================================================================================================
main() {
	# Initialize values that might be stored in a file
	file_env 'MYSQL_ROOT_HOST' '%'
	file_env 'MYSQL_DATABASE'
	file_env 'MYSQL_USER'
	file_env 'MYSQL_PASSWORD'
	file_env 'MYSQL_ROOT_PASSWORD'

	# Init random root password if applicable
	if [ "$MYSQL_RANDOM_ROOT_PASSWORD" ] && [ -z "$MYSQL_USER" ] && [ -z "$MYSQL_PASSWORD" ]; then
		echo >&2 'healthcheck error: cannot determine random root password ' \
			'(and MYSQL_USER and MYSQL_PASSWORD were not set)'
		exit 0
	fi

	# Initialize healthcheck arguments
	# TODO: check if IP binding is required
	host=$(hostname -i || echo '127.0.0.1')
	user="${MYSQL_USER:-root}"
	export MYSQL_PWD="${MYSQL_PASSWORD:-$MYSQL_ROOT_PASSWORD}"
	args=(
		# force mysql to not use the local "mysqld.sock" (test "external" connectibility)
		-h"$host"
		-u"$user"
		--silent
	)

	if command -v mysqladmin &> /dev/null; then
		if mysqladmin "${args[@]}" ping > /dev/null; then
			exit 0
		fi
	else
		if select="$(echo 'SELECT 1' | mysql "${args[@]}")" && [ "$select" = '1' ]; then
			exit 0
		fi
	fi

	exit 1
}

main "$@"