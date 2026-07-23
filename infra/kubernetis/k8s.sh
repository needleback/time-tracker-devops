#!/bin/bash
set -e

K8S_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"


echo
echo "-- Создаю кластер"
kind create cluster --config "${K8S_DIR}/01-kind-config.yaml" --name diplom


echo
echo "-- Устанавливаю namespace"
kubectl apply -f "${K8S_DIR}/02-namespace.yaml"


echo
echo "-- Создаю секрет ghcr-secret для kubectl"
set -a
. "${K8S_DIR}/k8s.env"
set +a
kubectl create secret docker-registry ghcr-secret \
  --namespace diplom \
  --docker-server=ghcr.io \
  --docker-username=${GHCR_USERNAME} \
  --docker-password=${GHCR_PASSWORD}


echo
echo "-- Подготавливаю kube config для maven-агента Jenkins"
cp ~/.kube/config ~/.kube/config-jenkins
yq -i '
  (.clusters[] | select(.name == "kind-diplom") | .cluster.server) =
    "https://diplom-control-plane:6443" |
  (.clusters[] | select(.name == "kind-cluster-diplom") | .cluster.server) =
    "https://cluster-diplom-control-plane:6443"
' ~/.kube/config-jenkins


echo
echo "-- Добавляю logging fluent-bit"
helm repo add fluent https://fluent.github.io/helm-charts
helm repo update
helm install fluent-bit fluent/fluent-bit \
  -n logging \
  -f "${K8S_DIR}/fluent-bit.yaml"
