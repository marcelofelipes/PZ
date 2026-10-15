#!/bin/bash
# Roda como steam: instala/atualiza, configura e inicia o servidor.
set -euo pipefail
cd /home/steam/server

export SERVER_PASSWORD="${SERVER_PASSWORD:-}"
export RCON_PASSWORD="${RCON_PASSWORD:-}"
if [ -z "${ADMIN_PASSWORD:-}" ]; then
    echo "[start] AVISO: ADMIN_PASSWORD não definido, usando 'changeme'"
    ADMIN_PASSWORD=changeme
fi

if [ "${UPDATE_ON_BOOT}" = "true" ] || [ ! -f "${SERVER_DIR}/start-server.sh" ]; then
    ./update.sh
fi

# --- Configuração do .ini (existe após o primeiro boot) ---
INI="${DATA_DIR}/Server/${SERVER_NAME}.ini"
set_ini() { sed -i "s|^$1=.*|$1=$2|" "${INI}"; }
if [ -f "${INI}" ]; then
    echo "[start] Aplicando configurações em ${INI}"
    set_ini DefaultPort "${PORT}"
    set_ini UDPPort "${UDP_PORT}"
    set_ini RCONPort "${RCON_PORT}"
    set_ini RCONPassword "${RCON_PASSWORD}"
    set_ini Password "${SERVER_PASSWORD}"
    set_ini MaxPlayers "${MAX_PLAYERS}"
    set_ini Public "${PUBLIC}"
    set_ini PublicName "${PUBLIC_NAME}"
    set_ini PublicDescription "${PUBLIC_DESCRIPTION}"
    [ -n "${MOD_IDS}" ] && set_ini Mods "${MOD_IDS}"
    [ -n "${WORKSHOP_IDS}" ] && set_ini WorkshopItems "${WORKSHOP_IDS}"
fi

# --- Memória da JVM ---
JSON="${SERVER_DIR}/ProjectZomboid64.json"
if [ -f "${JSON}" ]; then
    jq --arg m "-Xmx${MEMORY}" '.vmArgs |= (map(select(startswith("-Xmx") | not)) + [$m])' \
        "${JSON}" > /tmp/pz.json && cat /tmp/pz.json > "${JSON}"
fi

# --- rcon-cli ---
cat > rcon.yaml <<EOF
default:
  address: "127.0.0.1:${RCON_PORT}"
  password: "${RCON_PASSWORD}"
EOF

# --- Cron (backup / auto update) ---
: > crontab
[ "${BACKUP_ENABLED}" = "true" ] && echo "${BACKUP_CRON_EXPRESSION} /usr/local/bin/backup" >> crontab
[ "${AUTO_UPDATE_ENABLED}" = "true" ] && echo "${AUTO_UPDATE_CRON_EXPRESSION} /usr/local/bin/update" >> crontab
if [ -s crontab ]; then
    supercronic -quiet crontab &
fi

# --- Shutdown gracioso ---
shutdown() {
    echo "[start] Parando servidor..."
    if [ -n "${RCON_PASSWORD}" ]; then
        rcon-cli -c rcon.yaml save || true
        rcon-cli -c rcon.yaml quit || true
    else
        kill -TERM "${PZ_PID}" 2>/dev/null || true
    fi
    wait "${PZ_PID}" || true
    exit 0
}
trap shutdown SIGTERM SIGINT

ARGS=(-servername "${SERVER_NAME}" -adminusername "${ADMIN_USERNAME}" -adminpassword "${ADMIN_PASSWORD}" -cachedir="${DATA_DIR}")

cd "${SERVER_DIR}"
export LD_LIBRARY_PATH="${SERVER_DIR}/linux64:${SERVER_DIR}/natives:${SERVER_DIR}:${SERVER_DIR}/jre64/lib/amd64:${LD_LIBRARY_PATH:-}"
export PATH="${SERVER_DIR}/jre64/bin:${PATH}"

echo "[start] Iniciando Project Zomboid (${SERVER_NAME}) em $(uname -m)"
if [ "$(uname -m)" = "aarch64" ]; then
    box64 ./ProjectZomboid64 "${ARGS[@]}" &
else
    ./ProjectZomboid64 "${ARGS[@]}" &
fi
PZ_PID=$!
wait "${PZ_PID}"
