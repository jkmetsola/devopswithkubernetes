ARG BASE_IMAGE
### BUILD STAGES:

FROM stackrox/kube-linter:v0.6.8 AS kube-linter
FROM ghcr.io/sigstore/cosign/cosign:v2.4.1 AS cosign-bin

# hadolint ignore=DL3006
FROM $BASE_IMAGE AS sops-bin
WORKDIR /tmp
COPY --from=cosign-bin /ko-app/cosign /usr/local/bin/cosign
COPY imagefiles /tmp/imagefiles
RUN imagefiles/install-sops.sh


### MAIN STAGES:

# Stage 1: Main Build

# hadolint ignore=DL3006
FROM $BASE_IMAGE AS main-build
SHELL ["/bin/bash", "-euo", "pipefail", "-c"]

WORKDIR /tmp
COPY imagefiles /tmp/imagefiles

RUN pip install --no-cache-dir -r "imagefiles/requirements.txt"
ENTRYPOINT [ "/bin/bash", "-c" ]

# Stage 2: Dev tests build
FROM main-build AS dev-tests-build
SHELL ["/bin/bash", "-euo", "pipefail", "-c"]

ARG PACKAGES_DEVLINT_FILE

RUN apt-get update && \
    xargs -a "$PACKAGES_DEVLINT_FILE" apt-get install --no-install-recommends -y && \
    apt-get clean && \
    rm -rf /var/lib/apt/lists/* && \
    imagefiles/no-apt-packages-devlint.sh && \
    pip install --no-cache-dir -r imagefiles/requirements-pip-tools.txt && \
    pip install --no-cache-dir -r imagefiles/requirements-dev.txt

ENTRYPOINT [ "/bin/bash", "-c" ]

# Stage 3: Dev-env build: This stage is used as development environment.
FROM dev-tests-build AS dev-env-build
SHELL ["/bin/bash", "-euo", "pipefail", "-c"]

# Give your host machine's docker GID 'getent group docker | cut -d: -f3'
ARG HOST_DOCKER_GID
ARG HOST_UID
ARG HOST_GID
ARG REPOS_DEVENV_FILE
ARG PACKAGES_DEVENV_FILE
ARG DEVUSER
ARG CONFIGURE_DEVUSER_FILE
ARG ARGO_DOWNLOAD_URL

RUN ./${REPOS_DEVENV_FILE} && \
    apt-get update && \
    xargs -a "$PACKAGES_DEVENV_FILE" apt-get install --no-install-recommends -y && \
    apt-get clean && \
    rm -rf /var/lib/apt/lists/* && \
    imagefiles/no-apt-packages-devenv.sh "$ARGO_DOWNLOAD_URL" && \
    ./${CONFIGURE_DEVUSER_FILE} "$DEVUSER" "$HOST_UID" "$HOST_GID" "$HOST_DOCKER_GID"

COPY --from=sops-bin /usr/local/bin/sops /usr/local/bin/sops
COPY --from=kube-linter /kube-linter /usr/local/bin/kube-linter

USER "$DEVUSER"

ENTRYPOINT [ "/bin/bash", "-c" ]
