# -----------------------------------------------------------------------------
# Additional Workload Identity bindings (GKE equivalent of IRSA)
# -----------------------------------------------------------------------------

resource "kubernetes_service_account_v1" "workload_identity" {
  for_each = {
    for wi in var.additional_workload_identities : wi.name => wi
  }

  metadata {
    name      = each.value.service_account
    namespace = each.value.namespace
    annotations = {
      "iam.gke.io/gcp-service-account" = each.value.gcp_sa_email
    }
    labels = local.default_labels
  }

  depends_on = [google_container_cluster.main, google_container_node_pool.main]
}

resource "google_service_account_iam_member" "workload_identity" {
  for_each = {
    for wi in var.additional_workload_identities : wi.name => wi
  }

  service_account_id = "projects/${var.project_id}/serviceAccounts/${each.value.gcp_sa_email}"
  role               = "roles/iam.workloadIdentityUser"
  member             = "serviceAccount:${var.project_id}.svc.id.goog[${each.value.namespace}/${each.value.service_account}]"

  depends_on = [kubernetes_service_account_v1.workload_identity]
}
