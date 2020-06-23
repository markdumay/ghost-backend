FROM steveltn/https-portal:1

# Add scripts
COPY config/portal/docker/docker-entrypoint-override.sh \
    /usr/local/bin/

# Add configurations
COPY config/portal/nginx.conf.erb \
    config/portal/http.conf.erb \
    config/portal/https-cached.ssl.conf.erb \
    config/portal/https-uncached.ssl.conf.erb \
    /var/lib/nginx-conf/

# Set ownership and privileges
RUN chmod +x /usr/local/bin/docker-entrypoint-override.sh; \
    chmod 644 /var/lib/nginx-conf/nginx.conf.erb; \
    chown root:root /var/lib/nginx-conf/nginx.conf.erb; \
    chmod 644 /var/lib/nginx-conf/http.conf.erb; \
    chown root:root /var/lib/nginx-conf/http.conf.erb; \
    chmod 644 /var/lib/nginx-conf/https-cached.ssl.conf.erb; \
    chown root:root /var/lib/nginx-conf/https-cached.ssl.conf.erb; \
    chmod 644 /var/lib/nginx-conf/https-uncached.ssl.conf.erb; \
    chown root:root /var/lib/nginx-conf/https-uncached.ssl.conf.erb;

# Add additional, custom entrypoint script
ENTRYPOINT ["docker-entrypoint-override.sh"]