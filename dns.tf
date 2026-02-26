resource "google_dns_managed_zone" "public" {
  count = local.enable_nuon_dns && var.public_root_domain != "" ? 1 : 0

  project     = var.project_id
  name        = "${local.cluster_name}-public"
  dns_name    = "${var.public_root_domain}."
  description = "Public DNS zone for ${local.cluster_name}"
  labels      = local.default_labels
}

resource "google_dns_managed_zone" "internal" {
  count = var.internal_root_domain != "" ? 1 : 0

  project     = var.project_id
  name        = "${local.cluster_name}-internal"
  dns_name    = "${var.internal_root_domain}."
  visibility  = "private"

  private_visibility_config {
    networks {
      network_url = local.network_self_link
    }
  }

  labels = local.default_labels
}
