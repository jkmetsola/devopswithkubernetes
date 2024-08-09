
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
    wget --progress=dot:giga -O /bin/hadolint https://github.com/hadolint/hadolint/releases/download/v2.12.0/hadolint-Linux-x86_64 && \
    chmod +x /bin/hadolint && \
    wget --progress=dot:giga https://github.com/rhysd/actionlint/releases/download/v1.6.27/actionlint_1.6.27_linux_amd64.tar.gz && \
    mkdir actionlint_folder && \
    tar -xf actionlint_1.6.27_linux_amd64.tar.gz -C actionlint_folder && \
    mv actionlint_folder/actionlint /usr/local/bin/ && \
    rm -rf actionlint_folder && \
    chmod +x /usr/local/bin/actionlint

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

ENV DEVUSER=devroot

RUN apt-get update && \
    xargs -a "$PACKAGES_DEVENV_FILENAME" apt-get install --no-install-recommends -y && \
    apt-get clean && \
    rm -rf /var/lib/apt/lists/* && \
    if ! getent group "$HOST_GID" > /dev/null; then groupadd -g "$HOST_GID" user_host; fi && \
    useradd -s /bin/bash -mlou "$HOST_UID" -g "$HOST_GID" "$DEVUSER" && \
    echo "$DEVUSER ALL=(ALL) NOPASSWD: ALL" >> /etc/sudoers && \
    if ! getent group "$HOST_DOCKER_GID" > /dev/null; then groupadd -g "$HOST_DOCKER_GID" docker_host; fi && \
    usermod -aG "$(getent group $HOST_DOCKER_GID | cut -d: -f1)" "$DEVUSER"

USER "$DEVUSER"

ENTRYPOINT [ "/bin/bash", "-c" ]