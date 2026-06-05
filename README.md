# Infrastructure — StatusBoard

Инфраструктура проекта StatusBoard на базе Yandex Cloud, управляемая через Terraform.

## Стек

- Cloud: Yandex Cloud
- IaC: Terraform (S3 backend)
- Kubernetes: Managed Kubernetes (зональный мастер, прерываемые ноды)
- База данных: Managed PostgreSQL 16
- Registry: Yandex Container Registry
- CI/CD: GitHub Actions (auto apply при коммите в main)

## Структура

    terraform/
    ├── backend/    — сервисный аккаунт + S3 bucket для state
    └── main/       — VPC, K8s, PostgreSQL, Registry
    start.sh        — поднять всё
    stop.sh         — снести всё

## Требования

- Terraform >= 1.5.0
- yc CLI с настроенным профилем
- kubectl, helm, jq

## Первый запуск

Bootstrap делается один раз. Создаёт S3 bucket для хранения Terraform state и сервисный аккаунт. Bucket нельзя удалять.

**Шаг 1.** Заполни terraform/backend/terraform.tfvars:

    cp terraform/backend/terraform.tfvars.example terraform/backend/terraform.tfvars

- cloud_id — ID облака: yc config list
- folder_id — ID каталога: yc config list
- token — IAM токен: yc iam create-token

**Шаг 2.** Запусти bootstrap:

    cd terraform/backend
    terraform init
    terraform apply

**Шаг 3.** Сохрани ключи из outputs:

    terraform output access_key
    terraform output secret_key

**Шаг 4.** Заполни terraform/main/terraform.tfvars:

    cp terraform/main/terraform.tfvars.example terraform/main/terraform.tfvars

- cloud_id, folder_id, token — те же что в bootstrap
- db_password — пароль для PostgreSQL, минимум 16 символов

**Шаг 5.** Вставь ключи из Шага 3 в terraform/main/backend.tf

**Шаг 6.** Создай .env:

    cp .env.example .env

Заполни GITHUB_TOKEN — Personal Access Token с правом repo.

## Ежедневная работа

    ./start.sh   — поднять инфраструктуру
    ./stop.sh    — снести инфраструктуру

## Terraform CI/CD

Коммит в main затрагивающий terraform/main/ запускает terraform plan и terraform apply автоматически.

Секреты репозитория:

- YC_SA_KEY — JSON ключ сервисного аккаунта в base64
- YC_CLOUD_ID — ID облака
- YC_FOLDER_ID — ID каталога
- AWS_ACCESS_KEY_ID — из bootstrap outputs
- AWS_SECRET_ACCESS_KEY — из bootstrap outputs
- DB_PASSWORD — пароль базы данных

## Что создаётся в Yandex Cloud

- VPC с тремя подсетями в зонах ru-central1-a, b, d
- Managed Kubernetes, зональный мастер, 3 прерываемые worker ноды (2 CPU, 4GB RAM)
- Managed PostgreSQL 16, s2.micro, 10GB
- Yandex Container Registry
- Сервисный аккаунт для K8s
