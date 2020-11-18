FROM mariadb:10.5

# TODO: remove nano when no longer needed

# Add logrotate and self-updated restic
RUN set -ex && \
	apt-get update && \
    apt-get install -y --no-install-recommends ca-certificates logrotate nano restic && \
    restic self-update && \
	rm -rf /var/lib/apt/lists/*;

# Add scripts
COPY docker/docker-entrypoint-override.sh cron/mysqldump-local.sh cron/restic-remote.sh /usr/local/bin/

# Add logrotate configurations
COPY logrotate/mysqldumplog logrotate/resticlog /etc/logrotate.d/

# Set ownership and privileges
RUN chmod +x /usr/local/bin/docker-entrypoint-override.sh && \
    chmod +x /usr/local/bin/mysqldump-local.sh && \
    chmod +x /usr/local/bin/restic-remote.sh && \
    chmod 644 /etc/logrotate.d/resticlog && \
    chown mysql:mysql /etc/logrotate.d/resticlog && \
    chmod 644 /etc/logrotate.d/mysqldumplog && \
    chown mysql:mysql /etc/logrotate.d/mysqldumplog && \
    mkdir -p /var/mariadb/backup && \
    chown mysql:mysql /var/mariadb/backup;

# Run as unprivileged user
USER mysql

# Add additional, custom entrypoint script
ENTRYPOINT ["docker-entrypoint-override.sh", "docker-entrypoint.sh"]