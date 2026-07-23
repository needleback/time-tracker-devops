#!/bin/bash
set -e

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

echo
echo "- Очищаю кластер"
kind delete cluster --name diplom
rm -f ~/.kube/config-jenkins


echo
echo "- удаляю контейнеры инфраструктуру"
docker compose \
  -f "$ROOT_DIR/docker-compose.yaml" \
  down
