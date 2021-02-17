# Copyright © 2021 Mark Dumay. All rights reserved.
# Use of this source code is governed by The MIT License (MIT) that can be found in the LICENSE file.

#======================================================================================================================
# Build arguments
#======================================================================================================================
ARG BUILD_UID=1001
ARG BUILD_GID=1001
ARG BUILD_USER='mariadb'
ARG BUILD_FLAGS=''
ARG BUILD_VERSION
ARG BUILD_TARGET='test'
ARG MARIADB_VERSION
ARG MARIADB_ALPINE_VERSION


#======================================================================================================================
# Main image
#======================================================================================================================
FROM alpine:"${MARIADB_ALPINE_VERSION?version}"

ARG BUILD_VERSION
ENV BUILD_VERSION "${BUILD_VERSION}"

# Add mariadb, dependencies, and key packages needed by docker-entrypoint.sh
ARG MARIADB_VERSION
RUN set -eu; \
    apk update -f; \
    apk --no-cache add -f \
        bash \
        grep \
        su-exec \
        "mysql>=${MARIADB_VERSION}" \
        "mysql-client>=${MARIADB_VERSION}" \
        pwgen \
        shadow \
		tzdata \
		xz-utils; \
    apk -e info mysql mysql-client > /dev/null || \
        (echo "ERROR: mariadb package v${MARIADB_VERSION} not available" && exit 1); \
    rm -rf /var/cache/apk/*;

# Copy helper scripts and init scripts
COPY dbm/utils/harden_alpine.sh config/mariadb/docker/*.sh  /usr/local/sbin/
COPY config/mariadb/init/*.sh /docker-entrypoint-initdb.d/

# Harden the image and assign access rights for key files and folders
ARG BUILD_UID
ARG BUILD_GID
ARG BUILD_USER
ARG BUILD_FLAGS
ARG BUILD_TARGET
RUN set -eu; \
    rm -rf /var/lib/mysql /var/tmp /run/mysqld; \
    chmod +x /usr/local/sbin/harden_alpine.sh; \
    chmod +x /usr/local/sbin/docker-entrypoint.sh; \
    chmod +x /usr/local/sbin/docker-healthcheck.sh; \
    chmod +x /docker-entrypoint-initdb.d/*.sh; \
    mkdir -p /etc/mysql/conf.d; \
    /usr/local/sbin/harden_alpine.sh harden \
        -n "${BUILD_USER}" \
        -u "${BUILD_UID}" \
        -g "${BUILD_GID}" \
        -v /var/lib/mysql \
        -d /run/mysqld \
        -d /var/run/mysqld \
        -d /docker-entrypoint-initdb.d \
        -d /var/tmp \
        -U mysql \
        -k su-exec \
        -k bash \
        "${BUILD_FLAGS}";

# Initialize mariadb configuration
RUN	set -eu; \
    # comment out a few problematic configuration values
	find /etc/mysql/ -name '*.cnf' -print0 \
		| xargs -0 grep -lZE '^(bind-address|log|user\s)' \
		| xargs -rt -0 sed -Ei 's/^(bind-address|log|user\s)/#&/'; \
    # do not reverse lookup hostnames, they are usually another container
	printf '[mysqld]\nskip-host-cache\nskip-name-resolve\nskip-networking=0' > /etc/mysql/conf.d/docker.cnf

# Run the container as non-root user
USER "${BUILD_USER}"

# Define mountable directories
VOLUME [ "/var/lib/mysql" ]

# Define the healthcheck (production only)
ARG BUILD_TARGET
HEALTHCHECK --interval=1m30s --timeout=10s --retries=3 --start-period=1m \
    CMD if [ "${BUILD_TARGET}" = 'production' ]; then docker-healthcheck.sh; else exit 0; fi

# Start custom script
ENTRYPOINT ["docker-entrypoint.sh"]

# Expose default port
EXPOSE 3306

# Start mariadb daemon by default
CMD ["mysqld"]