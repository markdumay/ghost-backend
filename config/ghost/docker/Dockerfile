# Copyright © 2021 Mark Dumay. All rights reserved.
# Use of this source code is governed by The MIT License (MIT) that can be found in the LICENSE file.
# Derived from https://github.com/docker-library/ghost. Copyright © 2014 Docker, Inc.

#======================================================================================================================
# Build arguments
#======================================================================================================================
ARG BUILD_UID=1001
ARG BUILD_GID=1001
ARG BUILD_USER='cms'
ARG BUILD_FLAGS=''
ARG BUILD_VERSION
ARG BUILD_TARGET='test'
ARG ALPINE_VERSION
ARG NODE_MAJOR_VERSION
ARG GHOST_VERSION
ARG GHOST_CLI_VERSION
ARG GHOST_PORT=2368

#======================================================================================================================
# Ghost builder image
#======================================================================================================================
FROM node:"${NODE_MAJOR_VERSION?version}"-alpine"${ALPINE_VERSION?version}" as builder

#Grab su-exec for easy step-down from root
RUN apk add --no-cache 'su-exec>=0.2'

ARG GHOST_VERSION
ARG GHOST_CLI_VERSION
ENV NODE_ENV production
ENV GHOST_INSTALL /var/lib/ghost
ENV GHOST_CONTENT /var/lib/ghost/content

# Install Ghost CLI
RUN set -eu; \
	npm install -g "ghost-cli@${GHOST_CLI_VERSION}"; \
	npm cache clean --force

# Install and configure Ghost using CLI
RUN set -eu; \
	mkdir -p "${GHOST_INSTALL}"; \
	chown node:node "${GHOST_INSTALL}"; \
	\
	su-exec node ghost install "${GHOST_VERSION}" --db sqlite3 --no-prompt --no-stack --no-setup --dir "${GHOST_INSTALL}"; \
	\
    # Tell Ghost to listen on all ips and not prompt for additional configuration
	cd "${GHOST_INSTALL}"; \
	su-exec node ghost config --ip 0.0.0.0 --port 2368 --no-prompt --db sqlite3 --url http://localhost:2368 --dbpath "${GHOST_CONTENT}/data/ghost.db"; \
	su-exec node ghost config paths.contentPath "${GHOST_CONTENT}"; \
	\
    # Make a config.json symlink for NODE_ENV=development (and sanity check that it's correct)
	su-exec node ln -s config.production.json "${GHOST_INSTALL}/config.development.json"; \
	readlink -f "${GHOST_INSTALL}/config.development.json"; \
	\
    # Need to save initial content for pre-seeding empty volumes
	mv "$GHOST_CONTENT" "${GHOST_INSTALL}/content.orig"; \
	mkdir -p "${GHOST_CONTENT}"; \
	chown node:node "${GHOST_CONTENT}"; \
	chmod 1777 "${GHOST_CONTENT}"; \
	\
    # Force install "sqlite3" manually since it's an optional dependency of "ghost"
    # (which means that if it fails to install, like on ARM/ppc64le/s390x, the failure will be silently ignored and thus turn into a runtime error instead)
    # See https://github.com/TryGhost/Ghost/pull/7677 for more details
	cd "${GHOST_INSTALL}/current"; \
    # Scrape the expected version of sqlite3 directly from Ghost itself
	sqlite3Version="$(node -p 'require("./package.json").optionalDependencies.sqlite3')"; \
	if ! su-exec node yarn add "sqlite3@$sqlite3Version" --force; then \
        # Must be some non-amd64 architecture pre-built binaries aren't published for, so let's install some build deps and do-it-all-over-again
		apk add --no-cache --virtual .build-deps g++ gcc libc-dev make python3 vips-dev; \
		\
		npm_config_python='python3' su-exec node yarn add "sqlite3@$sqlite3Version" --force --build-from-source; \
		\
		apk del --no-network .build-deps; \
	fi; \
	\
	su-exec node yarn cache clean; \
	su-exec node npm cache clean --force; \
	npm cache clean --force; \
	rm -rv /tmp/yarn* /tmp/v8*


#======================================================================================================================
# Main image
#======================================================================================================================

FROM node:"${NODE_MAJOR_VERSION?version}"-alpine"${ALPINE_VERSION?version}"

ENV GHOST_INSTALL /var/lib/ghost
ENV GHOST_CONTENT /var/lib/ghost/content
ENV NODE_ENV production

# Copy helper scripts and binaries
# TODO: compile wait from source
ARG WAIT_VERSION
COPY config/ghost/docker/docker_entrypoint.sh dbm/utils/harden_alpine.sh /usr/local/sbin/
ADD https://github.com/ufoscout/docker-compose-wait/releases/download/"${WAIT_VERSION?version}"/wait /usr/local/sbin/wait

# Copy the builder files
COPY --from=builder "${GHOST_INSTALL}" "${GHOST_INSTALL}"

# Harden the image and assign access rights for key files and folders
ARG BUILD_FLAGS
ARG BUILD_UID
ARG BUILD_GID
ARG BUILD_USER
RUN set -eu; \
    apk update -f; \
    apk --no-cache add -f shadow; \
    rm -rf /var/cache/apk/* /tmp; \
    chmod +x /usr/local/sbin/docker_entrypoint.sh; \
    chmod +x /usr/local/sbin/harden_alpine.sh; \
    chmod +x /usr/local/sbin/wait; \
    /usr/local/sbin/harden_alpine.sh harden \
        -n "${BUILD_USER}" \
        -u "${BUILD_UID}" \
        -g "${BUILD_GID}" \
        -d /tmp \
        # -v /var/lib/ghost/content \
        -v /etc/nginx/templates \
        -d "${GHOST_INSTALL}" \
        -f /usr/local/sbin/docker_entrypoint.sh \
        -U node \
        "${BUILD_FLAGS}";

# Run the container as non-root user
ARG BUILD_USER
ARG GHOST_VERSION
ENV GHOST_VERSION "${GHOST_VERSION}"
USER "${BUILD_USER}"

WORKDIR "${GHOST_INSTALL}"
VOLUME [ "${GHOST_CONTENT}" ]

# # Define the healthcheck (production only)
# # ARG BUILD_TARGET
# # HEALTHCHECK --interval=1m30s --timeout=10s --retries=3 --start-period=1m \
# #     CMD if [[ "${BUILD_TARGET}" == 'production' ]]; then certbot_issue.sh verify; else exit 0; fi

# Run entrypoint script
# ENTRYPOINT [ "docker_entrypoint.sh" ]

# Define default command and port
ARG GHOST_PORT
EXPOSE "${GHOST_PORT}"
CMD ["node", "current/index.js"]