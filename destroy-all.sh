#!/bin/bash
set -e

echo "=== ВНИМАНИЕ: полное удаление всей инфраструктуры включая S3 bucket и registry ==="
echo "После этого восстановление невозможно."
read -p "Введи YES для подтверждения: " confirm
if [ "$confirm" != "YES" ]; then
  echo "Отменено."
  exit 0
fi

echo "=== Получаем ключи S3 ==="
cd terraform/backend
export AWS_ACCESS_KEY_ID=$(terraform output -raw access_key)
export AWS_SECRET_ACCESS_KEY=$(terraform output -raw secret_key)

echo "=== Удаляем основную инфраструктуру ==="
cd ../main
terraform destroy -auto-approve 2>/dev/null || true

echo "=== Удаляем образы из registry ==="
REGISTRY_ID=$(yc container registry list --format json | jq -r '.[0].id')
if [ -n "$REGISTRY_ID" ]; then
  IMAGE_IDS=$(yc container image list --registry-id $REGISTRY_ID --format json | jq -r '.[].id' 2>/dev/null || echo "")
  if [ -n "$IMAGE_IDS" ]; then
    echo "$IMAGE_IDS" | xargs -I {} yc container image delete --id {} 2>/dev/null || true
  fi
fi

echo "=== Удаляем bootstrap инфраструктуру ==="
cd ../backend
terraform destroy -auto-approve

echo "=== Всё удалено ==="
