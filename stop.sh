#!/bin/bash
set -e

echo "=== Получаем ключи S3 ==="
cd terraform/backend
export AWS_ACCESS_KEY_ID=$(terraform output -raw access_key)
export AWS_SECRET_ACCESS_KEY=$(terraform output -raw secret_key)
cd ../main

echo "=== Уничтожаем инфраструктуру (кроме registry) ==="
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
  -auto-approve

echo "=== Готово! ==="
