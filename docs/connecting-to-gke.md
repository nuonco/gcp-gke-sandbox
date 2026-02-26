# Connecting to a GKE Cluster

## Prerequisites

### 1. gcloud CLI

```bash
# macOS
brew install google-cloud-sdk

# verify
gcloud version
```

### 2. GKE auth plugin

```bash
gcloud components install gke-gcloud-auth-plugin --quiet

# verify
gke-gcloud-auth-plugin --version
```

### 3. kubectl

```bash
brew install kubectl
```

## Authenticate

```bash
gcloud auth login
gcloud auth application-default login --project=<PROJECT_ID>
```

## Connect to cluster

```bash
gcloud container clusters get-credentials <CLUSTER_NAME> \
  --region=<REGION> \
  --project=<PROJECT_ID>
```

Example with the test cluster:

```bash
gcloud container clusters get-credentials n-gke-test-01 \
  --region=us-central1 \
  --project=nuon-gcp-support
```

## Verify

```bash
kubectl cluster-info
kubectl get namespaces
kubectl get nodes
```

Note: GKE Autopilot clusters show no nodes until pods are scheduled.

## Troubleshooting

**`gke-gcloud-auth-plugin not found`**

```bash
gcloud components install gke-gcloud-auth-plugin --quiet
```

If installed via brew instead of gcloud installer:

```bash
export USE_GKE_GCLOUD_AUTH_PLUGIN=True
```

**`Unable to connect to the server`**

Check that `cluster_endpoint_public_access = true` in the terraform config, or that your IP is in `master_authorized_networks`.

**`Forbidden` errors**

Your Google account needs IAM permissions on the project. Ask for `roles/container.developer` or `roles/container.admin` on the GCP project.
