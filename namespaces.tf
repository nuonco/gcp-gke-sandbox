# create some default namespaces
#
# Uses kubectl_manifest (gavinbunney) rather than kubernetes_namespace_v1
# (hashicorp), mirroring the AWS EKS sandboxes. The hashicorp
# provider blocks on namespace deletion, polling until the namespace fully
# terminates (up to its 5m delete timeout). A namespace holding workloads with
# controller-managed finalizers (e.g. the Altinity ClickHouse CHI/CHK, whose
# operator is a BYOC component torn down in an earlier stage than the sandbox)
# can never finish terminating, so that delete hangs and the deprovision fails
# with "context deadline exceeded". The kubectl_manifest delete does not block
# on full termination, so teardown proceeds and the namespace is reaped along
# with the cluster — same behavior as AWS.
resource "kubectl_manifest" "main" {
  for_each = toset(local.namespaces)

  yaml_body = yamlencode({
    apiVersion = "v1"
    kind       = "Namespace"
    metadata = {
      name   = each.value
      labels = local.default_labels
    }
  })

  depends_on = [google_container_cluster.autopilot, google_container_node_pool.main]
}
