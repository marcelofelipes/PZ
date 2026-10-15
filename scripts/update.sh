#!/bin/bash
# Instala/atualiza o servidor dedicado do Project Zomboid via SteamCMD.
set -euo pipefail

BRANCH_ARGS=()
if [ "${STEAM_BRANCH}" != "public" ]; then
    BRANCH_ARGS=(-beta "${STEAM_BRANCH}")
fi

echo "[update] Instalando/atualizando app ${STEAM_APP_ID} (branch ${STEAM_BRANCH}) em ${SERVER_DIR}"
/home/steam/steamcmd/steamcmd.sh \
    +@sSteamCmdForcePlatformType linux \
    +force_install_dir "${SERVER_DIR}" \
    +login anonymous \
    +app_update "${STEAM_APP_ID}" "${BRANCH_ARGS[@]}" validate \
    +quit
