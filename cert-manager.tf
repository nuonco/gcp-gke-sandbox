# -----------------------------------------------------------------------------
# cert-manager
#
# Required by:
#   - ingress component: Certificate *.env.<domain>
#   - tunnel component:  Certificate *.tunnel.<domain>
#   - Linkerd:           identity issuer certificate rotation
# -----------------------------------------------------------------------------

resource "helm_release" "cert_manager" {
  count            = var.enable_cert_manager ? 1 : 0
  name             = "cert-manager"
  repository       = "https://charts.jetstack.io"
  chart            = "cert-manager"
  version          = "v1.17.2"
  namespace        = "cert-manager"
  create_namespace = true
  wait             = true
  wait_for_jobs    = true

  values = [yamlencode({
    crds = { enabled = true }
    # GKE: cainjector can take several minutes to inject the CA bundle into
    # the webhook configuration. The startupapicheck job retries until the
    # webhook is actually ready — with wait_for_jobs=true, Terraform blocks
    # here until it succeeds, so subsequent cert-manager resources are safe.
    startupapicheck = {
      timeout      = "5m"
      backoffLimit = 20
    }
  })]

  depends_on = [google_container_cluster.main, google_container_node_pool.main]
}

# Self-signed bootstrap issuer — used only to issue the public-issuer CA cert.
resource "kubectl_manifest" "cluster_issuer_bootstrap" {
  count     = var.enable_cert_manager ? 1 : 0
  yaml_body = yamlencode({
    apiVersion = "cert-manager.io/v1"
    kind       = "ClusterIssuer"
    metadata   = { name = "selfsigned-bootstrap" }
    spec       = { selfSigned = {} }
  })

  depends_on = [helm_release.cert_manager]
}

# CA cert for public-issuer — self-signed, in-cluster only.
resource "kubectl_manifest" "public_issuer_ca_cert" {
  count     = var.enable_cert_manager ? 1 : 0
  yaml_body = yamlencode({
    apiVersion = "cert-manager.io/v1"
    kind       = "Certificate"
    metadata = {
      name      = "public-issuer-ca"
      namespace = "cert-manager"
    }
    spec = {
      isCA       = true
      commonName = "public-issuer"
      secretName = "public-issuer-ca-tls"
      issuerRef = {
        name = "selfsigned-bootstrap"
        kind = "ClusterIssuer"
      }
      privateKey = { algorithm = "ECDSA", size = 256 }
    }
  })

  depends_on = [kubectl_manifest.cluster_issuer_bootstrap]
}

# public-issuer ClusterIssuer — used by ingress/tunnel Certificate resources.
# Issues self-signed certs (smoke test); swap for ACME/DNS01 in production.
resource "kubectl_manifest" "cluster_issuer_public" {
  count     = var.enable_cert_manager ? 1 : 0
  yaml_body = yamlencode({
    apiVersion = "cert-manager.io/v1"
    kind       = "ClusterIssuer"
    metadata   = { name = "public-issuer" }
    spec = {
      ca = { secretName = "public-issuer-ca-tls" }
    }
  })

  depends_on = [kubectl_manifest.public_issuer_ca_cert]
}
