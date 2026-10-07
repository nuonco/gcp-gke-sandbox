# Karpenter (https://github.com/cloudpilot-ai/karpenter-provider-gcp). The `main` pool runs the
# controller and is its bootstrap template; workload capacity comes from the `default` NodePool.

locals {
  karpenter = {
    enabled         = var.enable_karpenter
    namespace       = "karpenter-system"
    service_account = "karpenter"
    repository      = "https://cloudpilot-ai.github.io/karpenter-provider-gcp"
    version         = var.karpenter_version
    gsa_account_id  = "karpenter-${substr(var.nuon_id, 0, 19)}"
    role_id         = "karpenter_${var.nuon_id}"
  }

  # Mirrors deploy/iam/karpenter-controller-role.yaml at the pinned chart version.
  karpenter_controller_permissions = [
    "compute.instances.create",
    "compute.instances.delete",
    "compute.instances.get",
    "compute.instances.list",
    "compute.instances.setLabels",
    "compute.instances.setMetadata",
    "compute.instances.setServiceAccount",
    "compute.instances.setTags",
    "compute.disks.create",
    "compute.disks.setLabels",
    "compute.images.get",
    "compute.images.list",
    "compute.instanceGroupManagers.get",
    "compute.machineTypes.get",
    "compute.machineTypes.list",
    "compute.networks.get",
    "compute.projects.get",
    "compute.instanceTemplates.get",
    "compute.instanceTemplates.list",
    "compute.regions.get",
    "compute.subnetworks.get",
    "compute.subnetworks.use",
    "compute.subnetworks.useExternalIp",
    "compute.zones.list",
    "compute.zoneOperations.get",
    "container.clusters.get",
    "container.clusters.list",
    "container.clusters.update",
  ]

  karpenter_default_nodeclass_spec = {
    imageSelectorTerms = [
      {
        family  = "ContainerOptimizedOS"
        channel = "cluster"
      },
    ]
    disks = [
      {
        sizeGiB = 100
        boot    = true
      },
    ]
    serviceAccount = var.gke_node_pool_sa_email
    shieldedInstanceConfig = {
      enableSecureBoot          = var.node_secure_boot
      enableIntegrityMonitoring = true
    }
    labels = local.default_labels
  }

  karpenter_default_nodepool_spec = {
    limits = {
      cpu    = 100
      memory = "200Gi"
    }
    template = {
      spec = {
        expireAfter = "732h"
        nodeClassRef = {
          group = "karpenter.k8s.gcp"
          kind  = "GCENodeClass"
          name  = "default"
        }
        requirements = [
          {
            key      = "karpenter.sh/capacity-type"
            operator = "In"
            values   = ["on-demand"]
          },
          {
            key      = "karpenter.k8s.gcp/instance-family"
            operator = "In"
            values   = ["n2", "n2d", "e2"]
          },
          {
            key      = "kubernetes.io/arch"
            operator = "In"
            values   = ["amd64"]
          },
        ]
      }
    }
    disruption = {
      consolidationPolicy = "WhenEmptyOrUnderutilized"
      consolidateAfter    = "1m"
    }
  }
}

resource "google_service_account" "karpenter" {
  count = local.karpenter.enabled ? 1 : 0

  project      = var.project_id
  account_id   = local.karpenter.gsa_account_id
  display_name = "Karpenter controller for ${local.cluster_name}"
}

resource "google_project_iam_custom_role" "karpenter" {
  count = local.karpenter.enabled ? 1 : 0

  project     = var.project_id
  role_id     = local.karpenter.role_id
  title       = "Karpenter controller (${var.nuon_id})"
  permissions = local.karpenter_controller_permissions
}

resource "google_project_iam_member" "karpenter" {
  count = local.karpenter.enabled ? 1 : 0

  project = var.project_id
  role    = google_project_iam_custom_role.karpenter[0].id
  member  = "serviceAccount:${google_service_account.karpenter[0].email}"
}

# Karpenter attaches the node pool service account to the instances it creates.
resource "google_service_account_iam_member" "karpenter_node_sa_user" {
  count = local.karpenter.enabled ? 1 : 0

  service_account_id = "projects/${var.project_id}/serviceAccounts/${var.gke_node_pool_sa_email}"
  role               = "roles/iam.serviceAccountUser"
  member             = "serviceAccount:${google_service_account.karpenter[0].email}"
}

resource "google_service_account_iam_member" "karpenter_workload_identity" {
  count = local.karpenter.enabled ? 1 : 0

  service_account_id = google_service_account.karpenter[0].name
  role               = "roles/iam.workloadIdentityUser"
  member             = "serviceAccount:${var.project_id}.svc.id.goog[${local.karpenter.namespace}/${local.karpenter.service_account}]"
}

resource "helm_release" "karpenter_crd" {
  count = local.karpenter.enabled ? 1 : 0

  namespace        = local.karpenter.namespace
  create_namespace = true

  name       = "karpenter-crd"
  chart      = "karpenter-crd"
  repository = local.karpenter.repository
  version    = local.karpenter.version

  wait = true

  depends_on = [google_container_node_pool.main]
}

resource "helm_release" "karpenter" {
  count = local.karpenter.enabled ? 1 : 0

  namespace        = local.karpenter.namespace
  create_namespace = true

  name       = "karpenter"
  chart      = "karpenter"
  repository = local.karpenter.repository
  version    = local.karpenter.version

  wait = true

  values = concat(
    [yamlencode({
      controller = {
        replicaCount = var.karpenter_replica_count
        affinity = {
          nodeAffinity = {
            requiredDuringSchedulingIgnoredDuringExecution = {
              nodeSelectorTerms = [{
                matchExpressions = [{
                  key      = "cloud.google.com/gke-nodepool"
                  operator = "In"
                  values   = [google_container_node_pool.main.name]
                }]
              }]
            }
          }
        }
        settings = {
          projectID                     = var.project_id
          clusterLocation               = var.region
          clusterName                   = google_container_cluster.autopilot.name
          defaultNodePoolTemplateName   = google_container_node_pool.main.name
          defaultNodepoolServiceAccount = var.gke_node_pool_sa_email
        }
      }
      credentials = {
        enabled = false
      }
      serviceAccount = {
        name = local.karpenter.service_account
        annotations = {
          "iam.gke.io/gcp-service-account" = google_service_account.karpenter[0].email
        }
      }
    })],
    var.karpenter_extra_helm_values != null ? [yamlencode(var.karpenter_extra_helm_values)] : [],
  )

  depends_on = [
    helm_release.karpenter_crd,
    google_project_iam_member.karpenter,
    google_service_account_iam_member.karpenter_node_sa_user,
    google_service_account_iam_member.karpenter_workload_identity,
  ]
}

resource "kubectl_manifest" "karpenter_gcenodeclass_default" {
  count = local.karpenter.enabled ? 1 : 0

  wait = true

  yaml_body = yamlencode({
    apiVersion = "karpenter.k8s.gcp/v1alpha1"
    kind       = "GCENodeClass"
    metadata = {
      name = "default"
    }
    spec = [var.karpenter_default_nodeclass_spec, local.karpenter_default_nodeclass_spec][var.karpenter_default_nodeclass_spec != null ? 0 : 1]
  })

  depends_on = [helm_release.karpenter]
}

resource "kubectl_manifest" "karpenter_nodepool_default" {
  count = local.karpenter.enabled ? 1 : 0

  # Blocks destroy until Karpenter has deleted the instances it launched.
  wait = true

  yaml_body = yamlencode({
    apiVersion = "karpenter.sh/v1"
    kind       = "NodePool"
    metadata = {
      name = "default"
    }
    spec = [var.karpenter_default_nodepool_spec, local.karpenter_default_nodepool_spec][var.karpenter_default_nodepool_spec != null ? 0 : 1]
  })

  depends_on = [kubectl_manifest.karpenter_gcenodeclass_default]
}
