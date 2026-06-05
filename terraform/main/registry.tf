resource "yandex_container_registry" "main" {
  name      = "statusboard-registry"
  folder_id = var.folder_id

  lifecycle {
    prevent_destroy = true
  }
}
