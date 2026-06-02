resource "yandex_iam_service_account" "k8s" {
  name      = "k8s-sa"
  folder_id = var.folder_id
}

resource "yandex_resourcemanager_folder_iam_member" "k8s_editor" {
  folder_id = var.folder_id
  role      = "editor"
  member    = "serviceAccount:${yandex_iam_service_account.k8s.id}"
}

resource "yandex_resourcemanager_folder_iam_member" "k8s_puller" {
  folder_id = var.folder_id
  role      = "container-registry.images.puller"
  member    = "serviceAccount:${yandex_iam_service_account.k8s.id}"
}

resource "yandex_kubernetes_cluster" "main" {
  name       = "statusboard-cluster"
  network_id = yandex_vpc_network.main.id

  master {
    zonal {
      zone      = yandex_vpc_subnet.subnets["a"].zone
      subnet_id = yandex_vpc_subnet.subnets["a"].id
    }

    public_ip = true
  }

  service_account_id      = yandex_iam_service_account.k8s.id
  node_service_account_id = yandex_iam_service_account.k8s.id

  release_channel = "STABLE"

  depends_on = [
    yandex_resourcemanager_folder_iam_member.k8s_editor,
    yandex_resourcemanager_folder_iam_member.k8s_puller
  ]
}

resource "yandex_kubernetes_node_group" "workers" {
  cluster_id = yandex_kubernetes_cluster.main.id
  name       = "worker-nodes"

  instance_template {
    platform_id = "standard-v2"

    resources {
      cores         = 2
      memory        = 4
      core_fraction = 20
    }

    scheduling_policy {
      preemptible = true
    }

    boot_disk {
      size = 30
      type = "network-hdd"
    }

    network_interface {
      nat        = true
      subnet_ids = [for s in yandex_vpc_subnet.subnets : s.id]
    }
  }

  scale_policy {
    fixed_scale {
      size = 3
    }
  }

  allocation_policy {
    location {
      zone = yandex_vpc_subnet.subnets["a"].zone
    }
    location {
      zone = yandex_vpc_subnet.subnets["b"].zone
    }
    location {
      zone = yandex_vpc_subnet.subnets["d"].zone
    }
  }
}
