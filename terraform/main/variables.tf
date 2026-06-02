variable "cloud_id" {
  type = string
}

variable "folder_id" {
  type = string
}

variable "zone" {
  type    = string
  default = "ru-central1-a"
}

variable "token" {
  type      = string
  sensitive = true
}

variable "db_password" {
  type      = string
  sensitive = true
}
