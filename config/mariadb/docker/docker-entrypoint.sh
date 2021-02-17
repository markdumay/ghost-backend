#!/bin/bash
#=======================================================================================================================
# Title         : docker-entrypoint.sh
# Description   : Initializes and starts a mariadb server.
# Copyright     : Copyright (C) 1989, 1991 Free Software Foundation, Inc.
# Date          : February 16th, 2021
# Version       : 0.1
# Usage         : docker-entrypoint.sh
# Repository    : https://github.com/markdumay/ghost-backend
# Comments      : This work is derived from the docker-library/mariadb (https://github.com/docker-library/mariadb/)
#                 Use of this source code is governed by GPL-2.0 License that can be found in the LICENSE-GPLv2 file.
#=======================================================================================================================

set -eo pipefail
shopt -s nullglob


#=======================================================================================================================
# Constants
#=======================================================================================================================
readonly RW_DIRS='/var/tmp /var/run/mysqld /run/mysqld /docker-entrypoint-initdb.d'


#=======================================================================================================================
# Helper Functions
#=======================================================================================================================

#=======================================================================================================================
# Displays a log message on console.
#=======================================================================================================================
# Arguments:
#   $1  - Log type to display, e.g. Note, Warn, or ERROR.
#   $2+ - Log messages to display.
# Outputs:
#   Writes log message to stdout.
#=======================================================================================================================
mysql_log() {
	local type="$1"; shift
	printf '%s [%s] [Entrypoint]: %s\n' "$(date -u '+%Y-%m-%d %T') 0" "$type" "$*"
}

#=======================================================================================================================
# Displays an informative log message on console.
#=======================================================================================================================
# Arguments:
#   $1+ - Log messages to display.
# Outputs:
#   Writes log message to stdout.
#=======================================================================================================================
mysql_note() {
	mysql_log Note "$@"
}

#=======================================================================================================================
# Displays a warning on console.
#=======================================================================================================================
# Arguments:
#   $1+ - Warning messages to display.
# Outputs:
#   Writes warning to stdout.
#=======================================================================================================================
mysql_warn() {
	mysql_log Warn "$@" >&2
}

#=======================================================================================================================
# Displays error message on console and terminates with non-zero exit code.
#=======================================================================================================================
# Arguments:
#   $1+ - Error messages to display.
# Outputs:
#   Writes error message to stderr, non-zero exit code.
#=======================================================================================================================
mysql_error() {
	mysql_log ERROR "$@" >&2
	exit 1
}

#=======================================================================================================================
# Validates if the current shell user has R/W access to selected directories. The script terminates if a directory is
# not found, or if the permissions are incorrect.
#=======================================================================================================================
# Outputs:
#   Non-zero exit code in case of errors.
#=======================================================================================================================
validate_access() {
    mysql_note 'Validating access to key directories'

    # skip when R/W dirs are not specified
    if [ -n "${RW_DIRS}" ]; then
        # print directories that do not have R/W access
        dirs=$(eval "find ${RW_DIRS} -xdev -type d \
            -exec sh -c '(test -r \"\$1\" && test -w \"\$1\") || echo \"\$1\"' _ {} \; 2> /dev/null")
        result="$?"

        # capture result:
        # - non-zero result implies a directory cannot be found
        # - non-zero dirs captures directories that do not have R/W access
        [ "${result}" -ne 0 ] && mysql_error "Missing one or more directories: ${RW_DIRS}"
        [ -n "${dirs}" ] && mysql_error "Incorrect permissions: ${dirs}"
        mysql_note 'Permissions are correct'
    fi
}

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
# Checks to see if this file is being run or sourced from another script
#=======================================================================================================================
# Outputs:
#   Returns true if sourced.
#=======================================================================================================================
_is_sourced() {
	# https://unix.stackexchange.com/a/215279
	[ "${#FUNCNAME[@]}" -ge 2 ] \
		&& [ "${FUNCNAME[0]}" = '_is_sourced' ] \
		&& [ "${FUNCNAME[1]}" = 'source' ]
}

#=======================================================================================================================
# Processes init files. Supported file extensions are *.sh, *,sql, *.sql.gz, and *.sql.xz.
# usage: docker_process_init_files [file [file [...]]]
#    ie: docker_process_init_files /always-initdb.d/*
#=======================================================================================================================
# Outputs:
#   Processed init files.
#=======================================================================================================================
docker_process_init_files() {
	# mysql here for backwards compatibility "${mysql[@]}"
	# shellcheck disable=SC2034
	mysql=( docker_process_sql )

	echo
	local f
	for f; do
		case "$f" in
			*.sh)
				# https://github.com/docker-library/postgres/issues/450#issuecomment-393167936
				# https://github.com/docker-library/postgres/pull/452
				if [ -x "$f" ]; then
					mysql_note "$0: running $f"
					"$f"
				else
					mysql_note "$0: sourcing $f"
					# shellcheck source=/dev/null
					. "$f"
				fi
				;;
			*.sql)    mysql_note "$0: running $f"; docker_process_sql < "$f"; echo ;;
			*.sql.gz) mysql_note "$0: running $f"; gunzip -c "$f" | docker_process_sql; echo ;;
			*.sql.xz) mysql_note "$0: running $f"; xzcat "$f" | docker_process_sql; echo ;;
			*)        mysql_warn "$0: ignoring $f" ;;
		esac
		echo
	done
}

#=======================================================================================================================
# Checks the mariadb configuration.
#=======================================================================================================================
# Outputs:
#   Exits with a non-zero exit code in case of errors.
#=======================================================================================================================
mysql_check_config() {
	local toRun=( "$@" --verbose --help --log-bin-index="$(mktemp -u)" ) errors
	if ! errors="$("${toRun[@]}" 2>&1 >/dev/null)"; then
		mysql_error $'mysqld failed while attempting to check config\n\tcommand was: '"${toRun[*]}"$'\n\t'"$errors"
	fi
}

#=======================================================================================================================
# Fetches a value from the server config. Uses mysqld --verbose --help instead of my_print_defaults because the latter
# only show values present in config files, and not server defaults.
#=======================================================================================================================
# Outputs:
#   Fetched value.
#=======================================================================================================================
mysql_get_config() {
	local conf="$1"; shift
	"$@" --verbose --help --log-bin-index="$(mktemp -u)" 2>/dev/null \
		| awk -v conf="$conf" '$1 == conf && /^[^ \t]/ { sub(/^[^ \t]+[ \t]+/, ""); print; exit }'
	# match "datadir      /some/path with/spaces in/it here" but not "--xyz=abc\n     datadir (xyz)"
}

#=======================================================================================================================
# Executes a temporary startup of the MySQL server for init purposes.
#=======================================================================================================================
# Outputs:
#   Temporary server started, exits with a non-zero exit code in case of errors.
#=======================================================================================================================
docker_temp_server_start() {
	"$@" --skip-networking --socket="${SOCKET}" &
	mysql_note "Waiting for server startup"
	local i
	for i in {30..0}; do
		# only use the root password if the database has already been initializaed
		# so that it won't try to fill in a password file when it hasn't been set yet
		extraArgs=()
		if [ -z "$DATABASE_ALREADY_EXISTS" ]; then
			extraArgs+=( '--dont-use-mysql-root-password' )
		fi
		if docker_process_sql "${extraArgs[@]}" --database=mysql <<<'SELECT 1' &> /dev/null; then
			break
		fi
		sleep 1
	done
	if [ "$i" = 0 ]; then
		mysql_error "Unable to start server."
	fi
}

#=======================================================================================================================
# Stops the server daemon. When using a local socket file mysqladmin will block until the shutdown is complete.
#=======================================================================================================================
# Outputs:
#   Server stopped, exits with a non-zero exit code in case of errors.
#=======================================================================================================================
docker_temp_server_stop() {
	if ! mysqladmin --defaults-extra-file=<( _mysql_passfile ) shutdown -uroot --socket="${SOCKET}"; then
		mysql_error "Unable to shut down server."
	fi
}

#=======================================================================================================================
# Verifies that the minimally required password settings are set for new databases.
#=======================================================================================================================
# Outputs:
#   Exits with a non-zero exit code in case of errors.
#=======================================================================================================================
docker_verify_minimum_env() {
	if [ -z "$MYSQL_ROOT_PASSWORD" ] && [ -z "$MYSQL_ALLOW_EMPTY_PASSWORD" ] && \
		[ -z "$MYSQL_RANDOM_ROOT_PASSWORD" ]; then
		mysql_error $'Database is uninitialized and password option is not specified\n\tYou need to specify one of\
					MYSQL_ROOT_PASSWORD, MYSQL_ALLOW_EMPTY_PASSWORD and MYSQL_RANDOM_ROOT_PASSWORD'
	fi
}

#=======================================================================================================================
# Creates folders for the database. It also ensures permission for user mysql of run as root.
#=======================================================================================================================
# Outputs:
#   Created default folders.
#=======================================================================================================================
docker_create_db_directories() {
	local user; user="$(id -u)"

	# TODO other directories that are used by default? like /var/lib/mysql-files
	# see https://github.com/docker-library/mysql/issues/562
	mkdir -p "$DATADIR"

	if [ "$user" = "0" ]; then
		# this will cause less disk access than `chown -R`
		find "$DATADIR" \! -user mysql -exec chown mysql '{}' +
	fi
}

#=======================================================================================================================
# Initializes the database directory and files.
#=======================================================================================================================
# Outputs:
#   Initialized database files.
#=======================================================================================================================
docker_init_database_dir() {
	mysql_note "Initializing database files"
	installArgs=( --datadir="$DATADIR" --rpm --auth-root-authentication-method=normal )
	if { mysql_install_db --help || :; } | grep -q -- '--skip-test-db'; then
		# 10.3+
		installArgs+=( --skip-test-db )
	fi
	# "Other options are passed to mysqld." (so we pass all "mysqld" arguments directly here)
	mysql_install_db "${installArgs[@]}" "${@:2}"
	mysql_note "Database files initialized"
}

#=======================================================================================================================
# Loads various settings that are used elsewhere in the script. This should be called after mysql_check_config, bu
# before any other functions.
#=======================================================================================================================
# Outputs:
#   Initialized environment variables.
#=======================================================================================================================
docker_setup_env() {
	# Get config
	declare -g DATADIR SOCKET
	DATADIR="$(mysql_get_config 'datadir' "$@")"
	SOCKET="$(mysql_get_config 'socket' "$@")"

	# Initialize values that might be stored in a file
	file_env 'MYSQL_ROOT_HOST' '%'
	file_env 'MYSQL_DATABASE'
	file_env 'MYSQL_USER'
	file_env 'MYSQL_PASSWORD'
	file_env 'MYSQL_ROOT_PASSWORD'

	declare -g DATABASE_ALREADY_EXISTS
	if [ -d "$DATADIR/mysql" ]; then
		DATABASE_ALREADY_EXISTS='true'
	fi
}

#=======================================================================================================================
# Executes an sql script, passed via stdin.
# usage: docker_process_sql [--dont-use-mysql-root-password] [mysql-cli-args]
#    ie: docker_process_sql --database=mydb <<<'INSERT ...'
#    ie: docker_process_sql --dont-use-mysql-root-password --database=mydb <my-file.sql
#=======================================================================================================================
# Outputs:
#   Executed sql script.
#=======================================================================================================================
docker_process_sql() {
	passfileArgs=()
	if [ '--dont-use-mysql-root-password' = "$1" ]; then
		passfileArgs+=( "$1" )
		shift
	fi
	# args sent in can override this db, since they will be later in the command
	if [ -n "$MYSQL_DATABASE" ]; then
		set -- --database="$MYSQL_DATABASE" "$@"
	fi

	mysql --defaults-extra-file=<( _mysql_passfile "${passfileArgs[@]}") --protocol=socket -uroot -hlocalhost \
		--socket="${SOCKET}" "$@"
}

#=======================================================================================================================
# Initializes database with timezone info and root password, plus optional extra db/user.
#=======================================================================================================================
# Outputs:
#   Initialized database.
#=======================================================================================================================
docker_setup_db() {
	# Load timezone info into database
	if [ -z "$MYSQL_INITDB_SKIP_TZINFO" ]; then
		{
			# Aria in 10.4+ is slow due to "transactional" (crash safety)
			# https://jira.mariadb.org/browse/MDEV-23326
			# https://github.com/docker-library/mariadb/issues/262
			local tztables=( time_zone time_zone_leap_second time_zone_name time_zone_transition time_zone_transition_type )
			for table in "${tztables[@]}"; do
				echo "/*!100400 ALTER TABLE $table TRANSACTIONAL=0 */;"
			done

			# sed is for https://bugs.mysql.com/bug.php?id=20545
			mysql_tzinfo_to_sql /usr/share/zoneinfo \
				| sed 's/Local time zone must be set--see zic manual page/FCTY/'

			for table in "${tztables[@]}"; do
				echo "/*!100400 ALTER TABLE $table TRANSACTIONAL=1 */;"
			done
		} | docker_process_sql --dont-use-mysql-root-password --database=mysql
		# tell docker_process_sql to not use MYSQL_ROOT_PASSWORD since it is not set yet
	fi
	# Generate random root password
	if [ -n "$MYSQL_RANDOM_ROOT_PASSWORD" ]; then
		MYSQL_ROOT_PASSWORD="$(pwgen -1 32)"
		export MYSQL_ROOT_PASSWORD
		mysql_note "GENERATED ROOT PASSWORD: $MYSQL_ROOT_PASSWORD"
	fi
	# Sets root password and creates root users for non-localhost hosts
	local rootCreate=
	# default root to listen for connections from anywhere
	if [ -n "$MYSQL_ROOT_HOST" ] && [ "$MYSQL_ROOT_HOST" != 'localhost' ]; then
		# no, we don't care if read finds a terminating character in this heredoc
		# https://unix.stackexchange.com/questions/265149/why-is-set-o-errexit-breaking-this-read-heredoc-expression/265151#265151
		read -r -d '' rootCreate <<-EOSQL || true
			CREATE USER 'root'@'${MYSQL_ROOT_HOST}' IDENTIFIED BY '${MYSQL_ROOT_PASSWORD}' ;
			GRANT ALL ON *.* TO 'root'@'${MYSQL_ROOT_HOST}' WITH GRANT OPTION ;
		EOSQL
	fi

	# tell docker_process_sql to not use MYSQL_ROOT_PASSWORD since it is just now being set
	docker_process_sql --dont-use-mysql-root-password --database=mysql <<-EOSQL
		-- What's done in this file shouldn't be replicated
		--  or products like mysql-fabric won't work
		SET @@SESSION.SQL_LOG_BIN=0;

		DELETE FROM mysql.user WHERE user NOT IN ('mysql.sys', 'mariadb.sys', 'mysqlxsys', 'root') OR host NOT IN ('localhost') ;
		SET PASSWORD FOR 'root'@'localhost'=PASSWORD('${MYSQL_ROOT_PASSWORD}') ;
		-- 10.1: https://github.com/MariaDB/server/blob/d925aec1c10cebf6c34825a7de50afe4e630aff4/scripts/mysql_secure_installation.sh#L347-L365
		-- 10.5: https://github.com/MariaDB/server/blob/00c3a28820c67c37ebbca72691f4897b57f2eed5/scripts/mysql_secure_installation.sh#L351-L369
		DELETE FROM mysql.db WHERE Db='test' OR Db='test\_%' ;

		GRANT ALL ON *.* TO 'root'@'localhost' WITH GRANT OPTION ;
		FLUSH PRIVILEGES ;
		${rootCreate}
		DROP DATABASE IF EXISTS test ;
	EOSQL

	# Creates a custom database and user if specified
	if [ -n "$MYSQL_DATABASE" ]; then
		mysql_note "Creating database ${MYSQL_DATABASE}"
		docker_process_sql --database=mysql <<<"CREATE DATABASE IF NOT EXISTS \`$MYSQL_DATABASE\` ;"
	fi

	if [ -n "$MYSQL_USER" ] && [ -n "$MYSQL_PASSWORD" ]; then
		mysql_note "Creating user ${MYSQL_USER}"
		docker_process_sql --database=mysql <<<"CREATE USER '$MYSQL_USER'@'%' IDENTIFIED BY '$MYSQL_PASSWORD' ;"

		if [ -n "$MYSQL_DATABASE" ]; then
			mysql_note "Giving user ${MYSQL_USER} access to schema ${MYSQL_DATABASE}"
			docker_process_sql --database=mysql <<<"GRANT ALL ON \`${MYSQL_DATABASE//_/\\_}\`.* TO '$MYSQL_USER'@'%' ;"
		fi
	fi
}

#=======================================================================================================================
# Exports the password to the "file" the client uses. The client command will use process substitution to create a file
# on the fly.
# ie: --defaults-extra-file=<( _mysql_passfile )
#=======================================================================================================================
# Outputs:
#   Initialized file.
#=======================================================================================================================
_mysql_passfile() {
	if [ '--dont-use-mysql-root-password' != "$1" ] && [ -n "$MYSQL_ROOT_PASSWORD" ]; then
		cat <<-EOF
			[client]
			password="${MYSQL_ROOT_PASSWORD}"
		EOF
	fi
}

#=======================================================================================================================
# Check arguments for an option that would cause mysqld to stop
#=======================================================================================================================
# Outputs:
#   Return true if there is one
#=======================================================================================================================
_mysql_want_help() {
	local arg
	for arg; do
		case "$arg" in
			-'?'|--help|--print-defaults|-V|--version)
				return 0
				;;
		esac
	done
	return 1
}


#=======================================================================================================================
# Main Script
#=======================================================================================================================

#=======================================================================================================================
# Entrypoint for the script.
#=======================================================================================================================
_main() {
    # validate r/w access to key directories
    validate_access

	# if command starts with an option, prepend mysqld
	if [ "${1:0:1}" = '-' ]; then
		set -- mysqld "$@"
	fi

	# skip setup if they are not running mysqld or want an option that stops mysqld
	if [ "$1" = 'mysqld' ] && ! _mysql_want_help "$@"; then
		mysql_note "Entrypoint script for MySQL Server ${MARIADB_VERSION} started."

		mysql_check_config "$@"
		# Load various environment variables
		docker_setup_env "$@"
		docker_create_db_directories

		# If container is started as root user, restart as dedicated mysql user
		if [ "$(id -u)" = "0" ]; then
			mysql_note "Switching to dedicated user 'mysql'"
			exec su-exec mysql "${BASH_SOURCE[0]}" "$@"
		fi

		# there is no database, so it needs to be initialized
		if [ -z "$DATABASE_ALREADY_EXISTS" ]; then
			docker_verify_minimum_env

			# check dir permissions to reduce likelihood of half-initialized database
			ls /docker-entrypoint-initdb.d/ > /dev/null

			docker_init_database_dir "$@"

			mysql_note "Starting temporary server"
			docker_temp_server_start "$@"
			mysql_note "Temporary server started."

			docker_setup_db
			docker_process_init_files /docker-entrypoint-initdb.d/*

			mysql_note "Stopping temporary server"
			docker_temp_server_stop
			mysql_note "Temporary server stopped"

			echo
			mysql_note "MySQL init process done. Ready for start up."
			echo
		fi
	fi
	exec "$@"
}

# If we are sourced from elsewhere, do not perform any further actions
if ! _is_sourced; then
	_main "$@"
fi