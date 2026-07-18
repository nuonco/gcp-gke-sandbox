# Maintenance Kubernetes RBAC, mirroring the AWS EKS sandboxes: the
# maintenance identity gets no cluster-admin IAM grant; its k8s access comes
# solely from this ClusterRole (defaults: admin minus secret reads), bound to
# the maintenance service account. GKE evaluates IAM and RBAC as a union, so
# pair this with roles/container.clusterViewer only.
locals {
  maintenance_default_rules = yamldecode(file("${path.module}/values/k8s/maintenance_role.yaml")).rules
}

resource "kubectl_manifest" "maintenance_role" {
  count = var.maintenance_sa_email != "" ? 1 : 0

  yaml_body = yamlencode({
    apiVersion = "rbac.authorization.k8s.io/v1"
    kind       = "ClusterRole"
    metadata = {
      name = "maintenance"
      labels = length(var.maintenance_cluster_role_rules_override) > 0 ? {
        "nuon.co/source" = "customer-defined"
      } : { "nuon.co/source" = "sandbox-defaults" }
    }
    rules = length(var.maintenance_cluster_role_rules_override) > 0 ? var.maintenance_cluster_role_rules_override : tolist(local.maintenance_default_rules)
  })

  depends_on = [google_container_node_pool.main]
}

resource "kubectl_manifest" "maintenance_role_binding" {
  count = var.maintenance_sa_email != "" ? 1 : 0

  yaml_body = yamlencode({
    apiVersion = "rbac.authorization.k8s.io/v1"
    kind       = "ClusterRoleBinding"
    metadata = {
      name = "maintenance"
    }
    subjects = [{
      kind     = "User"
      name     = var.maintenance_sa_email
      apiGroup = "rbac.authorization.k8s.io"
    }]
    roleRef = {
      kind     = "ClusterRole"
      name     = "maintenance"
      apiGroup = "rbac.authorization.k8s.io"
    }
  })

  depends_on = [kubectl_manifest.maintenance_role]
}
