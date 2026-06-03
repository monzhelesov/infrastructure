#!/bin/bash
set -e

echo "=== Обновляем токен ==="
TOKEN=$(yc iam create-token)
sed -i "s/token.*=.*/token = \"$TOKEN\"/" terraform/backend/terraform.tfvars
sed -i "s/token.*=.*/token = \"$TOKEN\"/" terraform/main/terraform.tfvars

echo "=== Получаем ключи S3 ==="
cd terraform/backend
export AWS_ACCESS_KEY_ID=$(terraform output -raw access_key)
export AWS_SECRET_ACCESS_KEY=$(terraform output -raw secret_key)
cd ../main

echo "=== Инициализируем и применяем ==="
terraform init -reconfigure
terraform apply -auto-approve

echo "=== Получаем outputs ==="
CLUSTER_ID=$(terraform output -raw cluster_id)
REGISTRY_ID=$(terraform output -raw registry_id)

echo "=== Обновляем registry_id в манифестах ==="
OLD_REGISTRY=$(grep -o 'cr\.yandex/[^/]*' ~/diploma/k8s-config/app/api/deployment.yaml | head -1 | cut -d'/' -f2 || echo "")
if [ -n "$OLD_REGISTRY" ] && [ "$OLD_REGISTRY" != "$REGISTRY_ID" ]; then
  sed -i "s|cr.yandex/$OLD_REGISTRY|cr.yandex/$REGISTRY_ID|g" ~/diploma/k8s-config/app/api/deployment.yaml
  sed -i "s|cr.yandex/$OLD_REGISTRY|cr.yandex/$REGISTRY_ID|g" ~/diploma/k8s-config/app/frontend/deployment.yaml
  sed -i "s|$OLD_REGISTRY|$REGISTRY_ID|g" ~/diploma/statusboard-app/.github/workflows/ci.yaml
  sed -i "s|$OLD_REGISTRY|$REGISTRY_ID|g" ~/diploma/statusboard-app/.github/workflows/cd.yaml
  echo "Registry ID обновлён: $REGISTRY_ID"
fi

echo "=== Получаем kubeconfig ==="
yc managed-kubernetes cluster get-credentials $CLUSTER_ID --external --force

echo "=== Применяем K8s манифесты ==="
kubectl apply -f ~/diploma/k8s-config/namespaces/
kubectl apply -f ~/diploma/k8s-config/app/api/
kubectl apply -f ~/diploma/k8s-config/app/frontend/

echo "=== Устанавливаем мониторинг ==="
helm repo add prometheus-community https://prometheus-community.github.io/helm-charts 2>/dev/null || true
helm repo update
helm upgrade --install monitoring prometheus-community/kube-prometheus-stack \
  --namespace monitoring \
  --set grafana.service.type=LoadBalancer \
  --set grafana.adminPassword=admin123 \
  --set prometheus.prometheusSpec.serviceMonitorSelectorNilUsesHelmValues=false

echo "=== Готово! ==="
kubectl get svc -n statusboard
kubectl get svc -n monitoring | grep grafana
