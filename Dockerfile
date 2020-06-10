FROM ghost:3-alpine

ENV GHOST_CONTENT /var/lib/ghost/content

# Add curl
RUN apk update -f \
    && apk --no-cache add -f \
    curl \
    && rm -rf /var/cache/apk/*

## Add a wait script to the image
USER root
ADD https://github.com/ufoscout/docker-compose-wait/releases/download/2.7.3/wait /wait
RUN chmod +x /wait

# Override entrypoint with custom script
COPY docker-entrypoint.sh /usr/local/bin/docker-entrypoint-override.sh
RUN chmod +x /usr/local/bin/docker-entrypoint-override.sh; \
    chown node:node /usr/local/bin/docker-entrypoint-override.sh;

USER node
ENTRYPOINT ["/usr/local/bin/docker-entrypoint-override.sh"]

## Add wait instruction to initialization command
# USER 1001:0
# USER node
CMD /wait && node current/index.js