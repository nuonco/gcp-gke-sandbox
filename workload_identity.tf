resource "google_service_account" "restate" {
  account_id   = "${substr(var.nuon_id, 0, 20)}-rst"
  display_name = "Restate pods for ${var.nuon_id}"
}

resource "google_service_account_iam_member" "restate_wi" {
  service_account_id = google_service_account.restate.name
  role               = "roles/iam.workloadIdentityUser"
  member             = "principalSet://iam.googleapis.com/projects/${data.google_project.current.number}/locations/global/workloadIdentityPools/${var.project_id}.svc.id.goog/*"

  condition {
    title      = "restate-sa-only"
    expression = "request.auth.claims.google.subject.endsWith(':restate')"
  }

  depends_on = [google_container_cluster.autopilot]
}

resource "google_service_account" "secrets_accessor" {
  account_id   = "${substr(var.nuon_id, 0, 20)}-sec"
  display_name = "Secret accessor for ${var.nuon_id}"
}

resource "google_secret_manager_secret" "region_token" {
  project   = var.project_id
  secret_id = "restatecloudregiontoken-${var.nuon_id}"

  replication {
    auto {}
  }
}

resource "google_secret_manager_secret_iam_member" "secrets_accessor" {
  project   = var.project_id
  secret_id = google_secret_manager_secret.region_token.secret_id
  role      = "roles/secretmanager.secretAccessor"
  member    = "serviceAccount:${google_service_account.secrets_accessor.email}"
}

resource "google_service_account_iam_member" "secrets_accessor_wi_ingress" {
  service_account_id = google_service_account.secrets_accessor.name
  role               = "roles/iam.workloadIdentityUser"
  member             = "serviceAccount:${var.project_id}.svc.id.goog[restate-cloud-ingress/default]"
  depends_on         = [google_container_cluster.autopilot]
}

resource "google_service_account_iam_member" "secrets_accessor_wi_tunnel" {
  service_account_id = google_service_account.secrets_accessor.name
  role               = "roles/iam.workloadIdentityUser"
  member             = "serviceAccount:${var.project_id}.svc.id.goog[restate-cloud-tunnel/default]"
  depends_on         = [google_container_cluster.autopilot]
}
