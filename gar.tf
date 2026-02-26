resource "google_artifact_registry_repository" "main" {
  project       = var.project_id
  location      = var.region
  repository_id = local.cluster_name
  format        = "DOCKER"
  labels        = local.default_labels
}
