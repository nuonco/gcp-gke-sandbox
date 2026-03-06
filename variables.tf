# -----------------------------------------------------------
# Nuon-provided variables (from install stack / app config)
# -----------------------------------------------------------

variable "nuon_id" {
  description = "Nuon install identifier."
  type        = string
}

variable "region" {
  description = "GCP region for the GKE cluster."
  type        = string
}

variable "gcp_credentials_base64" {
  description = "GCP service account credentials JSON, base64 encoded."
  type        = string
  sensitive   = true
  default     = ""
}

variable "project_id" {
  description = "GCP project ID."
  type        = string
}

# -----------------------------------------------------------
# Cluster configuration
# -----------------------------------------------------------

variable "enable_cert_manager" {
  description = "Whether to install cert-manager and its cluster issuers."
  type        = bool
  default     = false
}

variable "enable_kyverno" {
  description = "Whether to install the Kyverno policy engine."
  type        = bool
  default     = false
}

variable "kyverno_policy_dir" {
  description = "Path to a directory with additional Kyverno policy manifests."
  type        = string
  default     = "./kyverno-policies"
}

variable "enable_linkerd" {
  description = "Whether to install the Linkerd service mesh."
  type        = bool
  default     = false
}

variable "cluster_name" {
  description = "Name for the GKE cluster. Defaults to n-{nuon_id}."
  type        = string
  default     = ""
}

variable "node_machine_type" {
  description = "Machine type for the default node pool."
  type        = string
  default     = "e2-standard-4"
}

variable "node_min_count" {
  description = "Minimum node count per zone for autoscaling."
  type        = number
  default     = 1
}

variable "node_max_count" {
  description = "Maximum node count per zone for autoscaling."
  type        = number
  default     = 10
}

variable "release_channel" {
  description = "GKE release channel. One of: RAPID, REGULAR, STABLE."
  type        = string
  default     = "REGULAR"
}

variable "deletion_protection" {
  description = "Whether to enable deletion protection on the cluster."
  type        = bool
  default     = false
}

variable "cluster_endpoint_public_access" {
  description = "Whether the GKE cluster API endpoint is publicly accessible."
  type        = bool
  default     = true
}

# -----------------------------------------------------------
# Networking (optional — empty = create new VPC)
# -----------------------------------------------------------

variable "network" {
  description = "Existing VPC network name or self_link. If empty, a new VPC is created."
  type        = string
  default     = ""
}

variable "subnetwork" {
  description = "Existing subnetwork name or self_link for GKE. If empty, a new subnet is created."
  type        = string
  default     = ""
}

variable "subnet_cidr" {
  description = "Primary CIDR for the GKE subnet (when creating a new VPC)."
  type        = string
  default     = "10.0.0.0/20"
}

variable "pods_cidr_range" {
  description = "Secondary CIDR range for pods."
  type        = string
  default     = "10.1.0.0/16"
}

variable "services_cidr_range" {
  description = "Secondary CIDR range for services."
  type        = string
  default     = "10.2.0.0/20"
}

# -----------------------------------------------------------
# DNS
# -----------------------------------------------------------

variable "enable_nuon_dns" {
  description = "Whether the cluster should use Nuon-provided DNS."
  type        = string
  default     = "false"
}

variable "public_root_domain" {
  description = "The public root domain."
  type        = string
  default     = ""
}

variable "internal_root_domain" {
  description = "The internal root domain."
  type        = string
  default     = ""
}

# -----------------------------------------------------------
# Namespaces
# -----------------------------------------------------------

variable "additional_namespaces" {
  description = "Extra namespaces to create. The nuon_id namespace is always created."
  type        = list(string)
  default     = []
}

# -----------------------------------------------------------
# Access control
# -----------------------------------------------------------

variable "master_authorized_networks" {
  description = "CIDR blocks authorized to access the GKE control plane."
  type = list(object({
    cidr_block   = string
    display_name = string
  }))
  default = []
}

# -----------------------------------------------------------
# Labels / tags
# -----------------------------------------------------------

variable "labels" {
  description = "Labels to apply to all resources."
  type        = map(string)
  default     = {}
}

variable "tags" {
  description = "Tags provided by Nuon for resource identification."
  type        = map(any)
  default     = {}
}
