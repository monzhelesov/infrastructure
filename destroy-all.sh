#!/bin/bash
set -e

echo "=== ВНИМАНИЕ: полное удаление всей инфраструктуры ==="
echo "После этого восстановление невозможно."
read -p "Введи YES для подтверждения: " confirm
if [ "$confirm" != "YES" ]; then
  echo "Отменено."
  exit 0
fi

echo "=== Получаем ключи S3 пока стейт жив ==="
cd terraform/backend
export AWS_ACCESS_KEY_ID=$(terraform output -raw access_key 2>/dev/null || echo "")
export AWS_SECRET_ACCESS_KEY=$(terraform output -raw secret_key 2>/dev/null || echo "")
BUCKET=$(terraform output -raw bucket_name 2>/dev/null || echo "statusboard-tf-state-rm")
SA_TERRAFORM=$(terraform output -raw service_account_id 2>/dev/null || echo "")

echo "=== Удаляем образы из registry ==="
REGISTRY_ID=$(yc container registry list --format json | jq -r '.[0].id' 2>/dev/null || echo "")
if [ -n "$REGISTRY_ID" ] && [ "$REGISTRY_ID" != "null" ]; then
  IMAGE_IDS=$(yc container image list --registry-id $REGISTRY_ID --format json | jq -r '.[].id' 2>/dev/null || echo "")
  if [ -n "$IMAGE_IDS" ]; then
    echo "$IMAGE_IDS" | xargs -I {} yc container image delete --id {} 2>/dev/null || true
    echo "Образы удалены"
  fi
  yc container registry delete $REGISTRY_ID 2>/dev/null || true
  echo "Registry удалён"
fi

echo "=== Удаляем основную инфраструктуру ==="
cd ../main
terraform destroy \
  -target=yandex_kubernetes_node_group.workers \
  -target=yandex_kubernetes_cluster.main \
  -target=yandex_mdb_postgresql_database.app \
  -target=yandex_mdb_postgresql_user.app \
  -target=yandex_mdb_postgresql_cluster.main \
  -target=yandex_resourcemanager_folder_iam_member.k8s_editor \
  -target=yandex_resourcemanager_folder_iam_member.k8s_puller \
  -target=yandex_resourcemanager_folder_iam_member.k8s_vpc_admin \
  -target=yandex_iam_service_account.k8s \
  -target=yandex_vpc_subnet.subnets \
  -target=yandex_vpc_network.main \
  -auto-approve 2>/dev/null || true

echo "=== Очищаем S3 bucket ==="
OBJECTS=$(yc storage s3api list-objects --bucket $BUCKET --format json 2>/dev/null | jq -r '.contents[].key' || echo "")
if [ -n "$OBJECTS" ]; then
  echo "$OBJECTS" | while read key; do
    yc storage s3api delete-object --bucket $BUCKET --key "$key" 2>/dev/null || true
    echo "Удалён объект: $key"
  done
fi

echo "=== Удаляем bootstrap инфраструктуру ==="
cd ../backend
terraform destroy -auto-approve 2>/dev/null || true

echo "=== Удаляем оставшиеся сервисные аккаунты ==="
for SA in terraform-sa k8s-sa github-actions-sa; do
  SA_ID=$(yc iam service-account get $SA --format json 2>/dev/null | jq -r '.id' || echo "")
  if [ -n "$SA_ID" ] && [ "$SA_ID" != "null" ]; then
    yc iam service-account delete $SA_ID 2>/dev/null || true
    echo "Удалён SA: $SA"
  fi
done

echo ""
echo "=== Всё удалено ==="
