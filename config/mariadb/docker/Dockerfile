FROM mariadb:10.3

# TODO: remove nano when no longer needed

# Add crontab, curl, and logrotate
RUN set -ex; \
	apt-get update; \
    apt-get install -y --no-install-recommends cron; \
    apt-get install -y --no-install-recommends curl; \
    apt-get install -y --no-install-recommends ca-certificates; \
    apt-get install -y --no-install-recommends logrotate; \
    apt-get install -y --no-install-recommends nano; \
	rm -rf /var/lib/apt/lists/*

# Add scripts
COPY config/mariadb/docker/docker-entrypoint-override.sh \
    config/mariadb/cron/mysqldump-local.sh \
    config/mariadb/cron/restic-remote.sh \
    /usr/local/bin/

# Add logrotate configurations
COPY config/mariadb/logrotate/mysqldumplog config/mariadb/logrotate/resticlog /etc/logrotate.d/

# Set ownership and privileges
RUN chmod +x /usr/local/bin/docker-entrypoint-override.sh; \
    chmod +x /usr/local/bin/mysqldump-local.sh; \
    chmod +x /usr/local/bin/restic-remote.sh; \
    chmod 644 /etc/logrotate.d/resticlog; \
    chown root:root /etc/logrotate.d/resticlog; \
    chmod 644 /etc/logrotate.d/mysqldumplog; \
    chown root:root /etc/logrotate.d/mysqldumplog; \
    mkdir -p /var/mariadb/backup/

# Add additional, custom entrypoint script
ENTRYPOINT ["docker-entrypoint-override.sh", "docker-entrypoint.sh"]