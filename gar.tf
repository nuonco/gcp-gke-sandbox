resource "google_artifact_registry_repository" "main" {
  project       = var.project_id
  location      = var.region
  repository_id = local.cluster_name
  format        = "DOCKER"
  labels        = local.default_labels

  # Nuon mirrors the upstream ECR paths into this one repository, so ctl-api and
  # dashboard-ui are the packages mono/ctl-api and mono/dashboard-ui. Keep the 10
  # newest of each and delete the rest. Artifact Registry runs this itself. No
  # other package matches, so temporal, clickhouse and telemetry images stay.
  cleanup_policy_dry_run = false

  cleanup_policies {
    id     = "delete-old-control-plane-images"
    action = "DELETE"
    condition {
      tag_state             = "ANY"
      package_name_prefixes = ["mono/ctl-api", "mono/dashboard-ui"]
    }
  }

  cleanup_policies {
    id     = "keep-newest-control-plane-images"
    action = "KEEP"
    most_recent_versions {
      package_name_prefixes = ["mono/ctl-api", "mono/dashboard-ui"]
      keep_count            = 10
    }
  }

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
