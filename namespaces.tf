resource "kubernetes_namespace_v1" "main" {
  for_each = toset(local.namespaces)

  metadata {
    name   = each.value
    labels = local.default_labels
  }

  depends_on = [google_container_cluster.main, google_container_node_pool.main]
}
