# -----------------------------------------------------------------------------
# Kyverno
#
# Policy engine for Kubernetes. Installs Kyverno and applies default security
# policies (restrict system group bindings, restrict secret read verbs).
# Vendor-supplied policies can be loaded from kyverno_policy_dir.
# -----------------------------------------------------------------------------

locals {
  kyverno = {
    value_file = "${path.module}/values/kyverno/values.yaml"
    default_policies = [
      "${path.module}/values/kyverno/policies/restrict-binding-system-groups.yaml",
      "${path.module}/values/kyverno/policies/restrict-secret-role-verbs.yaml",
    ]
  }
}

resource "helm_release" "kyverno" {
  count            = var.enable_kyverno ? 1 : 0
  name             = "kyverno"
  repository       = "https://kyverno.github.io/kyverno/"
  chart            = "kyverno"
  version          = "3.3.7"
  namespace        = "kyverno"
  create_namespace = true
  wait             = true

  values = [
    file(local.kyverno.value_file),
  ]

  depends_on = [google_container_cluster.main, google_container_node_pool.main]
}

resource "kubectl_manifest" "kyverno_default_policies" {
  for_each = var.enable_kyverno ? toset(local.kyverno.default_policies) : toset([])

  yaml_body = file(each.value)

  depends_on = [helm_release.kyverno]
}

resource "kubectl_manifest" "kyverno_vendor_policies" {
  for_each = var.enable_kyverno ? fileset(var.kyverno_policy_dir, "*.yaml") : toset([])

  yaml_body = file("${var.kyverno_policy_dir}/${each.key}")

  depends_on = [helm_release.kyverno]
}
