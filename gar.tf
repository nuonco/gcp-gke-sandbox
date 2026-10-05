resource "google_artifact_registry_repository" "main" {
  project       = var.project_id
  location      = var.region
  repository_id = local.cluster_name
  format        = "DOCKER"
  labels        = local.default_labels

  depends_on = [google_project_service.artifact_registry]

  # update_time is server-managed and changes whenever GCP touches the repo.
  # vulnerability_scanning_config also drifts when containerscanning is disabled,
  # which then bumps update_time on every reconcile.
  lifecycle {
    ignore_changes = [
      update_time,
      vulnerability_scanning_config,
    ]
  }
}
