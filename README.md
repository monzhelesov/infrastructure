# Infrastructure

Инфраструктура проекта StatusBoard на базе Yandex Cloud, управляемая через Terraform.

## Стек

- Cloud: Yandex Cloud
- IaC: Terraform (S3 backend)
- Kubernetes: Managed Kubernetes (зональный мастер)
- База данных: Managed PostgreSQL
- Registry: Yandex Container Registry
- CI/CD: GitHub Actions

## Структура

    terraform/
    backend/    - Сервисный аккаунт + S3 bucket
    main/       - Основная инфраструктура

## Быстрый старт

1. Создай .env по примеру .env.example
2. Заполни terraform/backend/terraform.tfvars
3. Bootstrap:

    cd terraform/backend
    terraform init
    terraform apply

4. Сохрани access_key и secret_key из outputs
5. Заполни terraform/main/terraform.tfvars и backend.tf

## Запуск и остановка

    ./start.sh   - поднять инфраструктуру
    ./stop.sh    - остановить и удалить

## GitHub Actions

При коммите в main затрагивающем terraform/main автоматически выполняется terraform plan и terraform apply.

## Секреты репозитория

- YC_SA_KEY - Ключ сервисного аккаунта в base64
- YC_CLOUD_ID - ID облака
- YC_FOLDER_ID - ID каталога
- AWS_ACCESS_KEY_ID - Access key для S3 backend
- AWS_SECRET_ACCESS_KEY - Secret key для S3 backend
- DB_PASSWORD - Пароль базы данных
