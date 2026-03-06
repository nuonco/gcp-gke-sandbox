# -----------------------------------------------------------------------------
# GKE IAM bindings for operational service accounts
#
# Provision / deprovision / break-glass get container.admin (full cluster
# control). Maintenance gets container.clusterViewer (auth-only; actual
# permissions are governed by the K8s RBAC ClusterRole).
# -----------------------------------------------------------------------------

# --- Provision ----------------------------------------------------------------

resource "google_project_iam_member" "provision_container_admin" {
  project = var.project_id
  role    = "roles/container.admin"
  member  = "serviceAccount:${var.provision_sa_email}"
}

# --- Maintenance --------------------------------------------------------------

resource "google_project_iam_member" "maintenance_cluster_viewer" {
  project = var.project_id
  role    = "roles/container.clusterViewer"
  member  = "serviceAccount:${var.maintenance_sa_email}"
}

# --- Deprovision --------------------------------------------------------------

resource "google_project_iam_member" "deprovision_container_admin" {
  project = var.project_id
  role    = "roles/container.admin"
  member  = "serviceAccount:${var.deprovision_sa_email}"
}

# --- Break-glass (conditional) ------------------------------------------------

resource "google_project_iam_member" "break_glass_container_admin" {
  count   = local.has_break_glass ? 1 : 0
  project = var.project_id
  role    = "roles/container.admin"
  member  = "serviceAccount:${var.break_glass_sa_email}"
}

# --- Additional service account access ----------------------------------------

resource "google_project_iam_member" "additional_sa" {
  for_each = {
    for pair in flatten([
      for name, entry in var.additional_service_account_access : [
        for role in entry.gke_iam_roles : {
          key      = "${name}-${role}"
          sa_email = entry.sa_email
          role     = role
        }
      ]
    ]) : pair.key => pair
  }

  project = var.project_id
  role    = each.value.role
  member  = "serviceAccount:${each.value.sa_email}"
}
