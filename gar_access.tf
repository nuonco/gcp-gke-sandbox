# -----------------------------------------------------------------------------
# GAR access for service accounts
#
# Grants Artifact Registry admin on the sandbox repository to the
# provision, maintenance, deprovision, and (optionally) break-glass
# service accounts. Equivalent to ecr_access.tf in the EKS sandbox.
# -----------------------------------------------------------------------------

resource "google_artifact_registry_repository_iam_member" "provision" {
  project    = var.project_id
  location   = var.region
  repository = google_artifact_registry_repository.main.repository_id
  role       = "roles/artifactregistry.admin"
  member     = "serviceAccount:${var.provision_sa_email}"
}

resource "google_artifact_registry_repository_iam_member" "maintenance" {
  project    = var.project_id
  location   = var.region
  repository = google_artifact_registry_repository.main.repository_id
  role       = "roles/artifactregistry.admin"
  member     = "serviceAccount:${var.maintenance_sa_email}"
}

resource "google_artifact_registry_repository_iam_member" "deprovision" {
  project    = var.project_id
  location   = var.region
  repository = google_artifact_registry_repository.main.repository_id
  role       = "roles/artifactregistry.admin"
  member     = "serviceAccount:${var.deprovision_sa_email}"
}

resource "google_artifact_registry_repository_iam_member" "break_glass" {
  count      = var.break_glass_sa_email != "" ? 1 : 0
  project    = var.project_id
  location   = var.region
  repository = google_artifact_registry_repository.main.repository_id
  role       = "roles/artifactregistry.admin"
  member     = "serviceAccount:${var.break_glass_sa_email}"
}
