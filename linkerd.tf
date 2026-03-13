locals {
  linkerd_egress_network_name = var.enable_linkerd ? "all-egress" : ""
}

# -----------------------------------------------------------------------------
# Linkerd mTLS certificates
#
# Trust anchor: long-lived root CA (10 years), stored in state.
# Issuer cert:  shorter-lived intermediate CA (1 year), rotated by cert-manager.
# Both generated with the tls provider to avoid external tooling dependencies.
# -----------------------------------------------------------------------------

resource "tls_private_key" "linkerd_trust_anchor" {
  count       = var.enable_linkerd ? 1 : 0
  algorithm   = "ECDSA"
  ecdsa_curve = "P256"
}

resource "tls_self_signed_cert" "linkerd_trust_anchor" {
  count             = var.enable_linkerd ? 1 : 0
  private_key_pem   = tls_private_key.linkerd_trust_anchor[0].private_key_pem
  is_ca_certificate = true

  subject {
    common_name = "root.linkerd.cluster.local"
  }

  validity_period_hours = 87600 # 10 years
  allowed_uses          = ["cert_signing", "crl_signing"]
}

resource "tls_private_key" "linkerd_issuer" {
  count       = var.enable_linkerd ? 1 : 0
  algorithm   = "ECDSA"
  ecdsa_curve = "P256"
}

resource "tls_cert_request" "linkerd_issuer" {
  count           = var.enable_linkerd ? 1 : 0
  private_key_pem = tls_private_key.linkerd_issuer[0].private_key_pem

  subject {
    common_name = "identity.linkerd.cluster.local"
  }
}

resource "tls_locally_signed_cert" "linkerd_issuer" {
  count                 = var.enable_linkerd ? 1 : 0
  cert_request_pem      = tls_cert_request.linkerd_issuer[0].cert_request_pem
  ca_private_key_pem    = tls_private_key.linkerd_trust_anchor[0].private_key_pem
  ca_cert_pem           = tls_self_signed_cert.linkerd_trust_anchor[0].cert_pem
  is_ca_certificate     = true
  validity_period_hours = 8760 # 1 year
  allowed_uses          = ["cert_signing"]
}

# -----------------------------------------------------------------------------
# Linkerd
#
# GKE Standard: proxy init container uses NET_ADMIN to set up iptables
# interception; no CNI plugin needed.
#
# Using the edge channel (helm.linkerd.io/edge) — EgressNetwork was added in
# Linkerd 2.17 (edge-26.2.1) and is not available in the stable channel.
# Edge releases are published frequently and are well-tested.
# -----------------------------------------------------------------------------

resource "helm_release" "linkerd_crds" {
  count            = var.enable_linkerd ? 1 : 0
  name             = "linkerd-crds"
  repository       = "https://helm.linkerd.io/edge"
  chart            = "linkerd-crds"
  version          = "2026.2.1"
  namespace        = "linkerd"
  create_namespace = true
  wait             = true

  values = [yamlencode({
    installGatewayAPI = true
  })]

  depends_on = [google_container_cluster.main, google_container_node_pool.main]
}

resource "helm_release" "linkerd_control_plane" {
  count      = var.enable_linkerd ? 1 : 0
  name       = "linkerd-control-plane"
  repository = "https://helm.linkerd.io/edge"
  chart      = "linkerd-control-plane"
  version    = "2026.2.1"
  namespace  = "linkerd"
  wait       = true

  set = [
    {
      name  = "identityTrustAnchorsPEM"
      value = tls_self_signed_cert.linkerd_trust_anchor[0].cert_pem
    },
    {
      name  = "identity.issuer.tls.crtPEM"
      value = tls_locally_signed_cert.linkerd_issuer[0].cert_pem
    },
    {
      name  = "identity.issuer.tls.keyPEM"
      value = tls_private_key.linkerd_issuer[0].private_key_pem
    },
  ]

  depends_on = [helm_release.linkerd_crds]
}

# -----------------------------------------------------------------------------
# Linkerd egress
#
# EgressNetwork captures all non-RFC1918 outbound TLS so that TLSRoute rules
# in the tunnel component can intercept and route traffic to the proxy service
# instead of sending it directly to the internet.
# -----------------------------------------------------------------------------

resource "kubernetes_namespace_v1" "linkerd_egress" {
  count = var.enable_linkerd ? 1 : 0
  metadata {
    name = "linkerd-egress"
    annotations = {
      "linkerd.io/inject" = "enabled"
    }
  }

  depends_on = [helm_release.linkerd_control_plane]
}

resource "kubectl_manifest" "egress_network" {
  count     = var.enable_linkerd ? 1 : 0
  yaml_body = yamlencode({
    apiVersion = "policy.linkerd.io/v1alpha1"
    kind       = "EgressNetwork"
    metadata = {
      name      = local.linkerd_egress_network_name
      namespace = "linkerd-egress"
    }
    spec = {
      trafficPolicy = "Allow"
      networks = [
        {
          cidr = "0.0.0.0/0"
          except = [
            "10.0.0.0/8",
            "172.16.0.0/12",
            "192.168.0.0/16",
          ]
        }
      ]
    }
  })

  depends_on = [kubernetes_namespace_v1.linkerd_egress]
}
