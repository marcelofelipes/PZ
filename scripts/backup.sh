#!/bin/bash
# Faz backup dos saves/config do servidor em /backups.
set -euo pipefail

TS="$(date +%Y%m%d_%H%M%S)"
FILE="/backups/pz_${SERVER_NAME}_${TS}.tar.gz"

if [ -n "${RCON_PASSWORD:-}" ]; then
    rcon-cli -c /home/steam/server/rcon.yaml save > /dev/null 2>&1 || true
    sleep 5
fi

tar -czf "${FILE}" -C "${DATA_DIR}" Saves Server db 2>/dev/null || tar -czf "${FILE}" -C "${DATA_DIR}" .
echo "[backup] Criado ${FILE}"

if [ "${DELETE_OLD_BACKUPS}" = "true" ]; then
    find /backups -name "pz_*.tar.gz" -mtime +"${OLD_BACKUP_DAYS}" -delete
    echo "[backup] Removidos backups com mais de ${OLD_BACKUP_DAYS} dias"
fi
