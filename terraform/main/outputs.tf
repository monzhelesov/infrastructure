output "cluster_id" {
  value = yandex_kubernetes_cluster.main.id
}

output "cluster_external_ip" {
  value = yandex_kubernetes_cluster.main.master[0].external_v4_endpoint
}

output "registry_id" {
  value = yandex_container_registry.main.id
}

output "db_host" {
  value = yandex_mdb_postgresql_cluster.main.host[0].fqdn
}
