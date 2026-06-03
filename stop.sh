#!/bin/bash
set -e

echo "=== Получаем ключи S3 ==="
cd terraform/backend
export AWS_ACCESS_KEY_ID=$(terraform output -raw access_key)
export AWS_SECRET_ACCESS_KEY=$(terraform output -raw secret_key)
cd ../main

echo "=== Удаляем образы из registry ==="
REGISTRY_ID=$(terraform output -raw registry_id 2>/dev/null || echo "")
if [ -n "$REGISTRY_ID" ]; then
  IMAGE_IDS=$(yc container image list --registry-id $REGISTRY_ID --format json | jq -r '.[].id' 2>/dev/null || echo "")
  if [ -n "$IMAGE_IDS" ]; then
    echo "$IMAGE_IDS" | xargs -I {} yc container image delete --id {} 2>/dev/null || true
    echo "Образы удалены"
  fi
fi

echo "=== Уничтожаем инфраструктуру ==="
terraform destroy -auto-approve

echo "=== Готово! ==="
