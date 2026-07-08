# -----------------------------------------------------------------------------
# GKE Standard Cluster
#
# Using Standard (not Autopilot) because Autopilot blocks NET_ADMIN, which
# Linkerd's proxy init container requires to set up iptables interception.
# Standard gives full node control; autoscaling handles capacity automatically.
# -----------------------------------------------------------------------------

resource "google_container_cluster" "autopilot" {
  depends_on = [google_project_service.container]

  project  = var.project_id
  name     = local.cluster_name
  location = var.region

  # Standard mode — remove the default node pool immediately and manage
  # node pools explicitly so we can tune machine type and autoscaling.
  remove_default_node_pool = true
  initial_node_count       = 1

  deletion_protection = var.deletion_protection

  network    = local.network
  subnetwork = local.subnetwork

  ip_allocation_policy {
    cluster_secondary_range_name  = local.create_vpc ? "pods" : null
    services_secondary_range_name = local.create_vpc ? "services" : null
  }

  release_channel {
    channel = var.release_channel
  }

  # Release-channel clusters force node auto-upgrade on, so this window is the
  # only control over when GKE rotates nodes (quorum-sensitive workloads like
  # clickhouse-keeper included).
  dynamic "maintenance_policy" {
    for_each = var.maintenance_recurring_window == null ? [] : [var.maintenance_recurring_window]
    content {
      recurring_window {
        start_time = maintenance_policy.value.start_time
        end_time   = maintenance_policy.value.end_time
        recurrence = maintenance_policy.value.recurrence
      }
    }
  }

  # Private cluster — nodes have no public IPs; Cloud NAT handles egress.
  private_cluster_config {
    enable_private_nodes    = true
    enable_private_endpoint = !var.cluster_endpoint_public_access
    master_ipv4_cidr_block  = "172.16.0.0/28"
  }

  dynamic "master_authorized_networks_config" {
    for_each = length(var.master_authorized_networks) > 0 ? [1] : []
    content {
      dynamic "cidr_blocks" {
        for_each = var.master_authorized_networks
        content {
          cidr_block   = cidr_blocks.value.cidr_block
          display_name = cidr_blocks.value.display_name
        }
      }
    }
  }

  # Workload Identity — allows pods to assume GCP service accounts via
  # Kubernetes ServiceAccount annotations (GKE equivalent of IRSA).
  workload_identity_config {
    workload_pool = "${var.project_id}.svc.id.goog"
  }

  binary_authorization {
    evaluation_mode = "DISABLED"
  }

  gateway_api_config {
    channel = "CHANNEL_STANDARD"
  }

  resource_labels = local.default_labels
}

resource "google_container_node_pool" "main" {
  project  = var.project_id
  name     = "main"
  cluster  = google_container_cluster.autopilot.name
  location = var.region

  autoscaling {
    min_node_count  = var.node_min_count
    max_node_count  = var.node_max_count
    location_policy = "BALANCED"
  }

  management {
    auto_repair  = true
    auto_upgrade = true
  }

  node_config {
    machine_type    = var.node_machine_type
    service_account = var.gke_node_pool_sa_email

    # Required for Workload Identity
    workload_metadata_config {
      mode = "GKE_METADATA"
    }

    shielded_instance_config {
      enable_secure_boot          = var.node_secure_boot
      enable_integrity_monitoring = true
    }

    oauth_scopes = [
      "https://www.googleapis.com/auth/cloud-platform",
    ]

    labels = local.default_labels
  }
}
