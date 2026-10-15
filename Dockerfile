FROM golang:1.27.1-alpine AS rcon-cli_builder

ARG RCON_VERSION="0.10.3"
ARG RCON_TGZ_SHA1SUM=33ee8077e66bea6ee097db4d9c923b5ed390d583

WORKDIR /build

# install rcon
SHELL ["/bin/ash", "-o", "pipefail", "-c"]

ENV CGO_ENABLED=0
RUN wget -q https://github.com/gorcon/rcon-cli/archive/refs/tags/v${RCON_VERSION}.tar.gz -O rcon.tar.gz \
    && echo "${RCON_TGZ_SHA1SUM}" rcon.tar.gz | sha1sum -c - \
    && tar -xzvf rcon.tar.gz \
    && rm rcon.tar.gz \
    && mv rcon-cli-${RCON_VERSION}/* ./ \
    && rm -rf rcon-cli-${RCON_VERSION} \
    && go build -v ./cmd/gorcon

FROM cm2network/steamcmd:root-trixie AS base-amd64
# Ignoring --platform=arm64 as this is required for the multi-arch build to continue to work on amd64 hosts
# hadolint ignore=DL3029
FROM --platform=arm64 sonroyaalmerol/steamcmd-arm64:root-trixie-2026-06-07 AS base-arm64
ARG TARGETARCH
# hadolint ignore=DL3006
FROM base-${TARGETARCH}
ARG TARGETARCH

LABEL name="pz-server-docker" \
      description="Project Zomboid dedicated server (amd64/arm64)"

# SUPERCRONIC: https://github.com/aptible/supercronic/releases
ARG SUPERCRONIC_SHA1SUM_ARM64="639ab81a72771990790df7ee87d9acfe88e5fa83"
ARG SUPERCRONIC_SHA1SUM_AMD64="5bcefed628e32adc08e32634db2d10e9230dbca0"
ARG SUPERCRONIC_VERSION="0.2.46"

# update and install dependencies
# hadolint ignore=DL3008
RUN apt-get update && apt-get install -y --no-install-recommends \
    procps \
    wget \
    gettext-base \
    jq \
    netcat-traditional \
    unzip \
    ca-certificates \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/*

SHELL ["/bin/bash", "-o", "pipefail", "-c"]

# install rcon
COPY --from=rcon-cli_builder /build/gorcon /usr/bin/rcon-cli

# install supercronic
# hadolint ignore=DL4001
RUN case "${TARGETARCH}" in \
        "amd64") SUPERCRONIC_SHA1SUM=${SUPERCRONIC_SHA1SUM_AMD64} ;; \
        "arm64") SUPERCRONIC_SHA1SUM=${SUPERCRONIC_SHA1SUM_ARM64} ;; \
    esac \
    && wget --progress=dot:giga "https://github.com/aptible/supercronic/releases/download/v${SUPERCRONIC_VERSION}/supercronic-linux-${TARGETARCH}" -O supercronic \
    && echo "${SUPERCRONIC_SHA1SUM}" supercronic | sha1sum -c - \
    && chmod +x supercronic \
    && mv supercronic /usr/local/bin/supercronic

# hadolint ignore=DL3044
ENV HOME=/home/steam \
    PUID=1000 \
    PGID=1000 \
    TZ=UTC \
    SERVER_DIR=/pz \
    DATA_DIR=/home/steam/Zomboid \
    STEAM_APP_ID=380870 \
    STEAM_BRANCH=public \
    UPDATE_ON_BOOT=true \
    SERVER_NAME=servertest \
    SERVER_PASSWORD= \
    ADMIN_USERNAME=admin \
    ADMIN_PASSWORD=changeme \
    PUBLIC=false \
    PUBLIC_NAME="Project Zomboid Server" \
    PUBLIC_DESCRIPTION= \
    MAX_PLAYERS=16 \
    PORT=16261 \
    UDP_PORT=16262 \
    RCON_PORT=27015 \
    RCON_PASSWORD= \
    MEMORY=4g \
    MOD_IDS= \
    WORKSHOP_IDS= \
    BACKUP_ENABLED=true \
    BACKUP_CRON_EXPRESSION="0 */6 * * *" \
    DELETE_OLD_BACKUPS=true \
    OLD_BACKUP_DAYS=7 \
    AUTO_UPDATE_ENABLED=false \
    AUTO_UPDATE_CRON_EXPRESSION="0 * * * *"

# Sane Box64 config defaults (arm64 only)
# hadolint ignore=DL3044
ENV BOX64_DYNAREC_STRONGMEM=1 \
    BOX64_DYNAREC_BIGBLOCK=1 \
    BOX64_DYNAREC_SAFEFLAGS=1 \
    BOX64_DYNAREC_FASTROUND=1 \
    BOX64_DYNAREC_FASTNAN=1 \
    BOX64_DYNAREC_X87DOUBLE=0

COPY ./scripts /home/steam/server/

RUN sed -i 's/\r$//' /home/steam/server/*.sh && \
    chmod +x /home/steam/server/*.sh && \
    ln -sf /home/steam/server/backup.sh /usr/local/bin/backup && \
    ln -sf /home/steam/server/update.sh /usr/local/bin/update && \
    mkdir -p /pz /home/steam/Zomboid /backups && \
    touch /home/steam/server/crontab /home/steam/server/rcon.yaml && \
    chown -R steam:steam /home/steam /pz /backups

WORKDIR /home/steam/server

VOLUME ["/pz", "/home/steam/Zomboid", "/backups"]

HEALTHCHECK --start-period=10m \
    CMD pgrep -f ProjectZomboid64 > /dev/null || exit 1

EXPOSE 16261/udp 16262/udp 27015/tcp
ENTRYPOINT ["/home/steam/server/init.sh"]
