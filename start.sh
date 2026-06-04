#!/bin/bash
set -e

source "$(dirname "$0")/.env"
GITHUB_REPO="monzhelesov/statusboard-app"

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

echo "=== Создаём статический kubeconfig для GitHub Actions ==="
kubectl create serviceaccount github-actions -n kube-system --dry-run=client -o yaml | kubectl apply -f -
kubectl create clusterrolebinding github-actions --clusterrole=cluster-admin --serviceaccount=kube-system:github-actions --dry-run=client -o yaml | kubectl apply -f -
K8S_TOKEN=$(kubectl create token github-actions -n kube-system --duration=87600h)
SERVER=$(kubectl config view --raw --minify --flatten -o jsonpath='{.clusters[0].cluster.server}')
CA=$(kubectl config view --raw --minify --flatten -o jsonpath='{.clusters[0].cluster.certificate-authority-data}')

KUBECONFIG_B64=$(cat << KUBEEOF | base64 -w 0
apiVersion: v1
kind: Config
clusters:
- cluster:
    certificate-authority-data: ${CA}
    server: ${SERVER}
  name: statusboard
contexts:
- context:
    cluster: statusboard
    user: github-actions
  name: statusboard
current-context: statusboard
users:
- name: github-actions
  user:
    token: ${K8S_TOKEN}
KUBEEOF
)

echo "=== Обновляем KUBE_CONFIG в GitHub ==="
PUBLIC_KEY=$(curl -s -H "Authorization: token $GITHUB_TOKEN" \
  "https://api.github.com/repos/$GITHUB_REPO/actions/secrets/public-key")
KEY_ID=$(echo $PUBLIC_KEY | jq -r '.key_id')
curl -s -X PUT \
  -H "Authorization: token $GITHUB_TOKEN" \
  -H "Accept: application/vnd.github.v3+json" \
  "https://api.github.com/repos/$GITHUB_REPO/actions/secrets/KUBE_CONFIG" \
  -d "{\"encrypted_value\":\"$KUBECONFIG_B64\",\"key_id\":\"$KEY_ID\"}"

echo "=== Применяем K8s манифесты ==="
kubectl apply -f ~/diploma/k8s-config/namespaces/
kubectl apply -f ~/diploma/k8s-config/app/api/
kubectl apply -f ~/diploma/k8s-config/app/frontend/

echo "=== Устанавливаем мониторинг ==="
helm repo add prometheus-community https://prometheus-community.github.io/helm-charts 2>/dev/null || true
helm repo add ingress-nginx https://kubernetes.github.io/ingress-nginx 2>/dev/null || true
helm repo update

helm upgrade --install ingress-nginx ingress-nginx/ingress-nginx \
  --namespace ingress-nginx \
  --create-namespace \
  --set controller.service.type=LoadBalancer

helm upgrade --install monitoring prometheus-community/kube-prometheus-stack \
  --namespace monitoring \
  --set grafana.service.type=ClusterIP \
  --set grafana.adminPassword=admin123 \
  --set prometheus.prometheusSpec.serviceMonitorSelectorNilUsesHelmValues=false

echo "=== Ждём IP ingress контроллера ==="
echo "Ожидание до 5 минут..."
for i in $(seq 1 30); do
  IP=$(kubectl get svc ingress-nginx-controller -n ingress-nginx -o jsonpath='{.status.loadBalancer.ingress[0].ip}' 2>/dev/null || echo "")
  if [ -n "$IP" ]; then
    echo "Ingress IP: $IP"
    break
  fi
  sleep 10
done

echo "=== Применяем Ingress манифесты ==="
kubectl apply -f ~/diploma/k8s-config/ingress/

echo "=== Готово! ==="
echo "Приложение: http://$IP"
echo "Grafana: http://$IP/grafana"
