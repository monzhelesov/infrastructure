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
  token                    = var.token != "" ? var.token : null
  service_account_key_file = var.service_account_key_file != "" ? var.service_account_key_file : null
  cloud_id                 = var.cloud_id
  folder_id                = var.folder_id
  zone                     = var.zone
}
