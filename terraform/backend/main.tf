terraform {
  required_providers {
    yandex = {
      source  = "yandex-cloud/yandex"
      version = "~> 0.130"
    }
  }
  required_version = ">= 1.5.0"
}

provider "yandex" {
  token     = var.token
  cloud_id  = var.cloud_id
  folder_id = var.folder_id
  zone      = var.zone
}

resource "yandex_iam_service_account" "terraform" {
  name      = "terraform-sa"
  folder_id = var.folder_id
}

resource "yandex_resourcemanager_folder_iam_member" "terraform_editor" {
  folder_id = var.folder_id
  role      = "editor"
  member    = "serviceAccount:${yandex_iam_service_account.terraform.id}"
}

resource "yandex_resourcemanager_folder_iam_member" "terraform_k8s" {
  folder_id = var.folder_id
  role      = "k8s.admin"
  member    = "serviceAccount:${yandex_iam_service_account.terraform.id}"
}

resource "yandex_resourcemanager_folder_iam_member" "terraform_storage" {
  folder_id = var.folder_id
  role      = "storage.admin"
  member    = "serviceAccount:${yandex_iam_service_account.terraform.id}"
}

resource "yandex_iam_service_account_static_access_key" "terraform_key" {
  service_account_id = yandex_iam_service_account.terraform.id
}

resource "yandex_storage_bucket" "terraform_state" {
  bucket     = "statusboard-tf-state-rm"
  access_key = yandex_iam_service_account_static_access_key.terraform_key.access_key
  secret_key = yandex_iam_service_account_static_access_key.terraform_key.secret_key

  versioning {
    enabled = true
  }
}
