# GKE auto-provisions l7-default-backend (deployment) and
# default-http-backend (service) with NEG enabled. No additional
# resources needed — the ingress controller uses these by default.
#
# If you see a 404 NEG error on first Ingress creation, it's a
# transient sync issue that resolves once the NEG endpoints propagate.
