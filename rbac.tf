# -----------------------------------------------------------------------------
# Kubernetes RBAC for operational service accounts
# -----------------------------------------------------------------------------

# --- Provision: cluster-admin -------------------------------------------------

resource "kubernetes_cluster_role_binding_v1" "provision" {
  metadata {
    name   = "provision"
    labels = local.default_labels
  }

  role_ref {
    api_group = "rbac.authorization.k8s.io"
    kind      = "ClusterRole"
    name      = "cluster-admin"
  }

  subject {
    api_group = "rbac.authorization.k8s.io"
    kind      = "User"
    name      = var.provision_sa_email
  }

  depends_on = [google_container_cluster.main, google_container_node_pool.main]
}

# --- Deprovision: cluster-admin -----------------------------------------------

resource "kubernetes_cluster_role_binding_v1" "deprovision" {
  metadata {
    name   = "deprovision"
    labels = local.default_labels
  }

  role_ref {
    api_group = "rbac.authorization.k8s.io"
    kind      = "ClusterRole"
    name      = "cluster-admin"
  }

  subject {
    api_group = "rbac.authorization.k8s.io"
    kind      = "User"
    name      = var.deprovision_sa_email
  }

  depends_on = [google_container_cluster.main, google_container_node_pool.main]
}

# --- Break-glass: cluster-admin (conditional) ---------------------------------

resource "kubernetes_cluster_role_binding_v1" "break_glass" {
  count = local.has_break_glass ? 1 : 0

  metadata {
    name   = "break-glass"
    labels = local.default_labels
  }

  role_ref {
    api_group = "rbac.authorization.k8s.io"
    kind      = "ClusterRole"
    name      = "cluster-admin"
  }

  subject {
    api_group = "rbac.authorization.k8s.io"
    kind      = "User"
    name      = var.break_glass_sa_email
  }

  depends_on = [google_container_cluster.main, google_container_node_pool.main]
}

# --- Maintenance: custom ClusterRole (admin minus secrets read) ---------------

locals {
  maintenance_labels = length(var.maintenance_cluster_role_rules_override) > 0 ? {
    "nuon.co/source" = "customer-defined"
  } : {
    "nuon.co/source" = "sandbox-defaults"
  }
  maintenance_default_rules = yamldecode(file("${path.module}/values/k8s/maintenance_role.yaml")).rules
}

resource "kubectl_manifest" "maintenance_cluster_role" {
  yaml_body = yamlencode({
    apiVersion = "rbac.authorization.k8s.io/v1"
    kind       = "ClusterRole"
    metadata = {
      name   = "maintenance"
      labels = local.maintenance_labels
    }
    rules = length(var.maintenance_cluster_role_rules_override) > 0 ? var.maintenance_cluster_role_rules_override : tolist(local.maintenance_default_rules)
  })

  depends_on = [google_container_cluster.main, google_container_node_pool.main]
}

resource "kubernetes_cluster_role_binding_v1" "maintenance" {
  metadata {
    name   = "maintenance"
    labels = local.default_labels
  }

  role_ref {
    api_group = "rbac.authorization.k8s.io"
    kind      = "ClusterRole"
    name      = "maintenance"
  }

  subject {
    api_group = "rbac.authorization.k8s.io"
    kind      = "User"
    name      = var.maintenance_sa_email
  }

  depends_on = [kubectl_manifest.maintenance_cluster_role]
}

# --- Additional service account RBAC ------------------------------------------

resource "kubernetes_cluster_role_binding_v1" "additional_sa" {
  for_each = var.additional_service_account_access

  metadata {
    name   = each.key
    labels = local.default_labels
  }

  role_ref {
    api_group = "rbac.authorization.k8s.io"
    kind      = "ClusterRole"
    name      = each.value.cluster_role
  }

  subject {
    api_group = "rbac.authorization.k8s.io"
    kind      = "User"
    name      = each.value.sa_email
  }

  depends_on = [google_container_cluster.main, google_container_node_pool.main]
}
