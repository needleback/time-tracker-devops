#!/bin/bash
set -e

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

echo
echo "- Устанавливаю необходимый софт: yq"
YQ_BIN="/usr/local/bin/yq"
YQ_REPO="https://github.com/mikefarah/yq/releases/latest/download/yq_linux_amd64"
if [ ! -f ${YQ_BIN} ]; then
  sudo wget -O ${YQ_BIN} ${YQ_REPO}
  sudo chmod +x ${YQ_BIN}
fi


echo
echo "- Разворачиваю Kubernetes"
"${ROOT_DIR}/kubernetis/k8s.sh"


echo
echo "- Разворачиваю инфраструктуру"
docker compose \
  -f "$ROOT_DIR/docker-compose.yaml" \
  up -d
