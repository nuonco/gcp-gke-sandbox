# Config Connector — GKE addon that allows the Restate operator to create
# IAMPolicyMember CRs, which Config Connector reconciles into GCP IAM bindings.
# This is the GCP equivalent of ACK on AWS (see ack_eks.tf in aws-eks-karpenter-sandbox).

# GCP SA for Config Connector. Needs permission to manage IAM bindings on the
# restate SA so it can create per-environment workload identity bindings.
resource "google_service_account" "config_connector" {
  account_id   = "${substr(var.nuon_id, 0, 20)}-cnrm"
  display_name = "Config Connector for ${var.nuon_id}"
}

# Allow Config Connector to manage IAM bindings on the restate GCP SA.
resource "google_service_account_iam_member" "config_connector_sa_admin" {
  service_account_id = google_service_account.restate.name
  role               = "roles/iam.serviceAccountAdmin"
  member             = "serviceAccount:${google_service_account.config_connector.email}"
}

# Workload Identity binding so the Config Connector K8s SA can act as the GCP SA.
# The addon runs in the cnrm-system namespace with a SA named cnrm-controller-manager.
resource "google_service_account_iam_member" "config_connector_wi" {
  service_account_id = google_service_account.config_connector.name
  role               = "roles/iam.workloadIdentityUser"
  member             = "serviceAccount:${var.project_id}.svc.id.goog[cnrm-system/cnrm-controller-manager]"
  depends_on         = [google_container_cluster.autopilot]
}

# ConfigConnectorContext tells the addon which GCP SA to use for reconciling
# resources. Cluster-scoped mode (configconnector.core.cnrm.cloud.google.com)
# would also work, but namespaced mode is more flexible if we ever need
# per-namespace SA scoping.
resource "kubectl_manifest" "config_connector_context" {
  yaml_body = yamlencode({
    apiVersion = "core.cnrm.cloud.google.com/v1beta1"
    kind       = "ConfigConnectorContext"
    metadata = {
      name      = "configconnectorcontext.core.cnrm.cloud.google.com"
      namespace = "cnrm-system"
    }
    spec = {
      googleServiceAccount = google_service_account.config_connector.email
    }
  })

  depends_on = [
    google_container_cluster.autopilot,
    google_container_node_pool.main,
    google_service_account_iam_member.config_connector_wi,
  ]
}
