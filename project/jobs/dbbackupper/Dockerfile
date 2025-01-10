FROM debian:bookworm AS dbbackupper

SHELL [ "/bin/bash", "-euo", "pipefail", "-c" ]

RUN apt-get update && \
    apt-get install --no-install-recommends -y ca-certificates=20230311 && \
    apt-get install --no-install-recommends -y postgresql-common=248 && \
    /usr/share/postgresql-common/pgdg/apt.postgresql.org.sh -y && \
    apt-get update && \
    apt-get --no-install-recommends install -y \
    wget=1.21.3-1+b2 \
    fuse=2.9.9-6+b1 \
    postgresql-client-17=17.2-1.pgdg120+1 && \
    rm -rf /var/lib/apt/lists/* && \
    wget --progress=dot:giga \
    https://github.com/GoogleCloudPlatform/gcsfuse/releases/download/v2.6.0/gcsfuse_2.6.0_amd64.deb && \
    dpkg -i gcsfuse_2.6.0_amd64.deb && \
    rm gcsfuse_2.6.0_amd64.deb

CMD [ "{{index .databases.postgres.containerNames 0}}" ]
