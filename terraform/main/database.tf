resource "yandex_mdb_postgresql_cluster" "main" {
  name        = "statusboard-db"
  environment = "PRODUCTION"
  network_id  = yandex_vpc_network.main.id

  config {
    version = "16"
    resources {
      resource_preset_id = "s2.micro"
      disk_type_id       = "network-hdd"
      disk_size          = 10
    }
  }

  host {
    zone      = "ru-central1-a"
    subnet_id = yandex_vpc_subnet.subnets["a"].id
  }
}

resource "yandex_mdb_postgresql_user" "app" {
  cluster_id = yandex_mdb_postgresql_cluster.main.id
  name       = "app"
  password   = var.db_password
}

resource "yandex_mdb_postgresql_database" "app" {
  cluster_id = yandex_mdb_postgresql_cluster.main.id
  name       = "statusboard"
  owner      = yandex_mdb_postgresql_user.app.name
  depends_on = [yandex_mdb_postgresql_user.app]
}
