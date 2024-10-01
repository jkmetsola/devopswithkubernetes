
# Stage 1: Main Build
ARG BASE_IMAGE
# hadolint ignore=DL3006
FROM $BASE_IMAGE AS main-build
SHELL ["/bin/bash", "-euo", "pipefail", "-c"]

WORKDIR /tmp
ARG IMAGEFILES_DIR
COPY $IMAGEFILES_DIR .

RUN pip install --no-cache-dir -r requirements.txt
ENTRYPOINT [ "/bin/bash", "-c" ]

# Stage 2: Dev tests build
FROM main-build AS dev-tests-build
SHELL ["/bin/bash", "-euo", "pipefail", "-c"]

ARG PACKAGES_DEVLINT_FILENAME

RUN apt-get update && \
    xargs -a "$PACKAGES_DEVLINT_FILENAME" apt-get install --no-install-recommends -y && \
    apt-get clean && \
    rm -rf /var/lib/apt/lists/* && \
    ./no-apt-packages-devlint.sh

RUN pip install --no-cache-dir -r requirements-pip-tools.txt && \
    pip install --no-cache-dir -r requirements-dev.txt
ENTRYPOINT [ "/bin/bash", "-c" ]

# Stage 3: Dev-env build: This stage is used as development environment.
FROM dev-tests-build AS dev-env-build
SHELL ["/bin/bash", "-euo", "pipefail", "-c"]

# Give your host machine's docker GID 'getent group docker | cut -d: -f3'
ARG HOST_DOCKER_GID
ARG HOST_UID
ARG HOST_GID
ARG PACKAGES_DEVENV_FILENAME
ARG REPOS_DEVENV_FILENAME
ARG DEVUSER
ARG CONFIGURE_DEVUSER_FILENAME

RUN ./${REPOS_DEVENV_FILENAME} && \
    apt-get update && \
    xargs -a "$PACKAGES_DEVENV_FILENAME" apt-get install --no-install-recommends -y && \
    apt-get clean && \
    rm -rf /var/lib/apt/lists/* && \
    ./no-apt-packages-devenv.sh && \
    ./${CONFIGURE_DEVUSER_FILENAME} "$DEVUSER" "$HOST_UID" "$HOST_GID" "$HOST_DOCKER_GID"

USER "$DEVUSER"

ENTRYPOINT [ "/bin/bash", "-c" ]
