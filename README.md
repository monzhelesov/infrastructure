# Infrastructure — StatusBoard

Инфраструктура проекта StatusBoard на базе Yandex Cloud, управляемая через Terraform.

## Стек

- Cloud: Yandex Cloud
- IaC: Terraform (S3 backend)
- Kubernetes: Managed Kubernetes (зональный мастер, прерываемые ноды)
- База данных: Managed PostgreSQL 16
- Registry: Yandex Container Registry
- CI/CD: GitHub Actions

## Структура

    terraform/
    ├── backend/    — сервисный аккаунт + S3 bucket для state
    └── main/       — VPC, K8s, PostgreSQL, Registry
    start.sh        — поднять всю инфраструктуру
    stop.sh         — снести инфраструктуру

## Требования

- Terraform >= 1.5.0
- yc CLI с настроенным профилем (yc init)
- kubectl
- helm
- jq

## Первый запуск с нуля

### Шаг 1 — Bootstrap (выполняется один раз)

Bootstrap создаёт S3 bucket для хранения Terraform state и сервисный аккаунт.
Эти ресурсы живут постоянно — никогда не удаляй их.

    cp terraform/backend/terraform.tfvars.example terraform/backend/terraform.tfvars

Заполни terraform/backend/terraform.tfvars:
- cloud_id   — ID облака. Узнать: yc config list
- folder_id  — ID каталога. Узнать: yc config list
- token      — IAM токен. Получить: yc iam create-token

    cd terraform/backend

    terraform init

    terraform apply

Сохрани значения из outputs — они нужны в следующих шагах:

    terraform output access_key
    terraform output secret_key
    terraform output service_account_id

### Шаг 2 — Настройка основной конфигурации

Заполни backend для хранения state:

    # Открой terraform/main/backend.tf и вставь ключи из Шага 1
    access_key = "значение из terraform output access_key"
    secret_key = "значение из terraform output secret_key"

Заполни переменные:

    cp terraform/main/terraform.tfvars.example terraform/main/terraform.tfvars

Что заполнять в terraform/main/terraform.tfvars:
- cloud_id    — ID облака (тот же что в bootstrap)
- folder_id   — ID каталога (тот же что в bootstrap)
- token       — IAM токен (yc iam create-token)
- db_password — пароль для PostgreSQL, минимум 16 символов

### Шаг 3 — Настройка GitHub секретов

Зайди в GitHub репозиторий с приложением → Settings → Secrets and variables → Actions.

Добавь следующие секреты:

YC_SA_KEY — JSON ключ сервисного аккаунта в base64.
Создай ключ и закодируй:

    yc iam key create --service-account-id <service_account_id из Шага 1> --output key.json
    cat key.json | base64 -w 0

YC_CLOUD_ID — ID облака (из yc config list)

YC_FOLDER_ID — ID каталога (из yc config list)

AWS_ACCESS_KEY_ID — access key из Шага 1 (terraform output access_key)

AWS_SECRET_ACCESS_KEY — secret key из Шага 1 (terraform output secret_key)

DB_PASSWORD — пароль базы данных (тот же что в terraform.tfvars)

### Шаг 4 — Настройка .env

    cp .env.example .env

Заполни .env:
- GITHUB_TOKEN — Personal Access Token с правом repo.
  Создать: GitHub → Settings → Developer settings → Personal access tokens → Generate new token (classic) → выбери repo
- GITHUB_REPO — путь к репо с приложением в формате username/statusboard-app

### Шаг 5 — Запуск

    ./start.sh

Скрипт выполняет:
1. Обновляет IAM токен
2. Запускает terraform apply
3. Получает kubeconfig
4. Создаёт сервисный аккаунт для GitHub Actions
5. Обновляет секреты KUBE_CONFIG и YC_REGISTRY_ID в GitHub
6. Применяет K8s манифесты
7. Устанавливает ingress-nginx и kube-prometheus stack
8. Выводит IP адрес приложения и Grafana

### Шаг 6 — После первого запуска

Если образов ещё не было в registry — запусти CI pipeline вручную:
GitHub репо с приложением → Actions → CI Pipeline → Run workflow

После сборки образов перезапусти поды:

    kubectl rollout restart deployment/api -n statusboard
    kubectl rollout restart deployment/frontend -n statusboard

## Ежедневная работа

IAM токен живёт 12 часов — скрипт обновляет его автоматически.

Поднять инфраструктуру:

    ./start.sh

Остановить (сохраняет registry и S3 bucket):

    ./stop.sh

## Terraform CI/CD

Любой коммит в main затрагивающий terraform/main/ автоматически запускает
terraform plan и terraform apply через GitHub Actions.

Секреты репозитория infrastructure:
- YC_SA_KEY          — JSON ключ сервисного аккаунта в base64
- YC_CLOUD_ID        — ID облака
- YC_FOLDER_ID       — ID каталога
- AWS_ACCESS_KEY_ID  — access key из bootstrap
- AWS_SECRET_ACCESS_KEY — secret key из bootstrap
- DB_PASSWORD        — пароль базы данных

## Что создаётся в Yandex Cloud

- VPC с тремя подсетями в зонах ru-central1-a, b, d
- Managed Kubernetes, зональный мастер, 3 прерываемые worker ноды (2 CPU, 4GB RAM)
- Managed PostgreSQL 16, s2.micro, 10GB
- Yandex Container Registry (не удаляется при stop — хранит образы между сессиями)
- Сервисный аккаунт для K8s

## Полное удаление

Если проект больше не нужен — удали всю инфраструктуру включая S3 bucket и registry:

    ./destroy-all.sh

Скрипт попросит подтверждение. После выполнения восстановление невозможно.
