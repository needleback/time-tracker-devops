#!/bin/bash
set -e

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"


echo
echo "- Разворачиваю Kubernetes"
"${ROOT_DIR}/kubernetis/k8s.sh"


echo
echo "- Разворачиваю инфраструктуру"
docker compose \
  -f "$ROOT_DIR/docker-compose.yaml" \
  up -d
