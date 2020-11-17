# Init base image and build arguments
ARG UID=1001
FROM ghost:latest

# Add curl package (incl dependencies) and initialize unprivileged user
ARG UID
RUN apt-get update && \
    apt-get install -y --no-install-recommends ca-certificates curl && \
	rm -rf /var/lib/apt/lists/* && \
    groupadd --gid "${UID}" ghost && useradd -g ghost --uid "${UID}" ghost;

# Add helper scripts
ADD https://github.com/ufoscout/docker-compose-wait/releases/download/2.7.3/wait /usr/local/bin/wait
COPY docker-entrypoint-override.sh /usr/local/bin/

# Refine access rights:
#  - creation of /etc/nginx/templates in the image propagates ghost:ghost ownership to the shared volume
#  - ensure the UID build argument is similar to the owner of the shared volume
RUN chmod +x /usr/local/bin/docker-entrypoint-override.sh && \
    chmod +x /usr/local/bin/wait && \
    mkdir -p /etc/nginx/templates && \ 
    mkdir -p /var/lib/ghost/content/logs && \
    chown ghost:ghost /etc/nginx/templates && \
    chown ghost:ghost /var/lib/ghost/content/logs;

# Run as unprivileged user
USER ghost

# Add custom entrypoint script
ENTRYPOINT ["docker-entrypoint-override.sh"]

# Add default initialization command
CMD ["node", "current/index.js"]