#!/bin/bash
# Roda como root: ajusta UID/GID, permissões e cai para o usuário steam.
set -euo pipefail

if [ "$(id -u)" -eq 0 ]; then
    if [ "$(id -g steam)" != "${PGID}" ]; then groupmod -o -g "${PGID}" steam; fi
    if [ "$(id -u steam)" != "${PUID}" ]; then usermod -o -u "${PUID}" steam; fi

    chown -R steam:steam "${SERVER_DIR}" "${DATA_DIR}" /backups /home/steam/server
    chown steam:steam /home/steam /home/steam/Steam /home/steam/steamcmd 2>/dev/null || true

    exec runuser -u steam -- /home/steam/server/start.sh
fi

exec /home/steam/server/start.sh
