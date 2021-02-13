ARG UID=1001
FROM alpine:3.12.1

# Install restic package and assign access rights for key files and folders
ARG UID
RUN apk update -f && \
    apk --no-cache add -f restic grep && \
    rm -rf /var/cache/apk/* && \
    addgroup -g "${UID}" -S restic && adduser --uid "${UID}" -S restic -G restic;

# Run the container as non-root user restic
USER restic

# TODO: Expose the certificates folder as volume
# VOLUME [ "/etc/certbot" ]

# TODO
ENTRYPOINT [ "/bin/sh" ]