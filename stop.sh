#!/bin/bash
set -e

echo "=== Получаем ключи S3 ==="
cd terraform/backend
export AWS_ACCESS_KEY_ID=$(terraform output -raw access_key)
export AWS_SECRET_ACCESS_KEY=$(terraform output -raw secret_key)
cd ../main

echo "=== Уничтожаем инфраструктуру ==="
terraform destroy -auto-approve

echo "=== Готово! ==="
