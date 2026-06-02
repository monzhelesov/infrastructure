resource "yandex_vpc_network" "main" {
  name = "statusboard-network"
}

resource "yandex_vpc_subnet" "subnets" {
  for_each = {
    "a" = { zone = "ru-central1-a", cidr = "10.0.1.0/24" }
    "b" = { zone = "ru-central1-b", cidr = "10.0.2.0/24" }
    "d" = { zone = "ru-central1-d", cidr = "10.0.3.0/24" }
  }

  name           = "subnet-${each.key}"
  zone           = each.value.zone
  network_id     = yandex_vpc_network.main.id
  v4_cidr_blocks = [each.value.cidr]
}
