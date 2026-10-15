#!/bin/bash
# Build + run do servidor Project Zomboid.
# Uso: ./run.sh [build|run|all|logs|stop]   (padrão: all)
set -euo pipefail
cd "$(dirname "$0")"

IMAGE="${IMAGE:-pz-server}"
CONTAINER="${CONTAINER:-pz-server}"
PLATFORM="${PLATFORM:-linux/arm64}"

# Carrega variáveis (senhas etc.) do .env
if [ ! -f .env ]; then
    echo "[run] .env não encontrado, criando a partir de .env.example — edite as senhas!"
    cp .env.example .env
fi
env_get() { grep -E "^$1=" .env | tail -n1 | cut -d= -f2- | tr -d '\r'; }
PORT="$(env_get PORT)"
UDP_PORT="$(env_get UDP_PORT)"
RCON_PORT="$(env_get RCON_PORT)"

build() {
    echo "[run] Build ${IMAGE} (${PLATFORM})"
    docker buildx build --platform "${PLATFORM}" -t "${IMAGE}" --load .
}

run() {
    if docker ps -a --format '{{.Names}}' | grep -qx "${CONTAINER}"; then
        echo "[run] Removendo container antigo ${CONTAINER}"
        docker stop -t 60 "${CONTAINER}" > /dev/null || true
        docker rm "${CONTAINER}" > /dev/null
    fi

    echo "[run] Iniciando ${CONTAINER}"
    docker run -d --name "${CONTAINER}" \
        --restart unless-stopped \
        --stop-timeout 60 \
        --env-file .env \
        -p "${PORT:-16261}:${PORT:-16261}/udp" \
        -p "${UDP_PORT:-16262}:${UDP_PORT:-16262}/udp" \
        -p "${RCON_PORT:-27015}:${RCON_PORT:-27015}/tcp" \
        -v steamcmd_login_volume:/home/steam/Steam \
        -v steamcmd_volume:/home/steam/steamcmd \
        -v pz_server:/pz \
        -v pz_data:/home/steam/Zomboid \
        -v "$(pwd)/backups:/backups" \
        "${IMAGE}"
}

case "${1:-all}" in
    build) build ;;
    run)   run ;;
    all)   build && run && docker logs -f "${CONTAINER}" ;;
    logs)  docker logs -f "${CONTAINER}" ;;
    stop)  docker stop -t 60 "${CONTAINER}" ;;
    *)     echo "Uso: $0 [build|run|all|logs|stop]"; exit 1 ;;
esac
