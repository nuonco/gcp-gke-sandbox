# gcp-gke-sandbox

GKE Standard sandbox for Nuon BYOC deployments. Equivalent to [aws-eks-karpenter-sandbox](https://github.com/nuonco/aws-eks-karpenter-sandbox).

Capacity comes from an autoscaled `main` node pool, or from [Karpenter](https://github.com/cloudpilot-ai/karpenter-provider-gcp) when `enable_karpenter = true`.

## Prerequisites

### Required GCP APIs

Enable these APIs on your GCP project before running:

```bash
gcloud services enable \
  compute.googleapis.com \
  container.googleapis.com \
  artifactregistry.googleapis.com \
  dns.googleapis.com \
  cloudresourcemanager.googleapis.com \
  --project=<PROJECT_ID>
```

### Required IAM Permissions

The service account or user running terraform needs:
- Kubernetes Engine Admin (`roles/container.admin`)
- Compute Network Admin (`roles/compute.networkAdmin`)
- Artifact Registry Admin (`roles/artifactregistry.admin`)
- DNS Administrator (`roles/dns.admin`)
- Service Account User (`roles/iam.serviceAccountUser`)

With `enable_karpenter = true` it also creates the Karpenter controller service account, a custom role and
their bindings, so it additionally needs Service Account Admin (`roles/iam.serviceAccountAdmin`), Role Administrator
(`roles/iam.roleAdmin`) and Project IAM Admin (`roles/resourcemanager.projectIamAdmin`), or `roles/owner`.

## Resources Created

- **GKE Standard Cluster** — Workload Identity, private nodes, configurable release channel, autoscaled `main` node pool
- **Karpenter** (optional) — controller on the `main` pool, plus a `default` GCENodeClass and NodePool
- **Artifact Registry** (Docker) — equivalent to ECR
- **Cloud DNS Zones** — public and internal (optional, controlled by `enable_nuon_dns`)
- **VPC + Subnet + Cloud NAT** — networking (optional, can use existing VPC)
- **Kubernetes Namespaces** — nuon_id namespace + additional

## Local Testing

```bash
gcloud auth application-default login --project=<PROJECT_ID>
terraform init
terraform plan -var-file=example.tfvars
terraform apply -var-file=example.tfvars
```

See [docs/connecting-to-gke.md](docs/connecting-to-gke.md) for connecting to the cluster after creation.

## Inputs

| Name | Description | Default | Required |
|------|-------------|---------|----------|
| `nuon_id` | Nuon install identifier | — | yes |
| `region` | GCP region | — | yes |
| `project_id` | GCP project ID | — | yes |
| `gcp_credentials_base64` | Base64-encoded service account JSON | `""` | no |
| `cluster_name` | GKE cluster name | `n-{nuon_id}` | no |
| `release_channel` | GKE release channel | `REGULAR` | no |
| `cluster_endpoint_public_access` | Public API endpoint | `true` | no |
| `network` | Existing VPC (empty = create new) | `""` | no |
| `subnetwork` | Existing subnet (empty = create new) | `""` | no |
| `enable_nuon_dns` | Enable Nuon DNS zones | `false` | no |
| `public_root_domain` | Public DNS domain | `""` | no |
| `internal_root_domain` | Internal DNS domain | `""` | no |
| `additional_namespaces` | Extra K8s namespaces | `[]` | no |
| `deletion_protection` | Cluster deletion protection | `false` | no |
| `labels` | Resource labels | `{}` | no |
| `tags` | Nuon resource tags | `{}` | no |
| `enable_karpenter` | Install Karpenter with a default GCENodeClass and NodePool | `false` | no |
| `karpenter_version` | karpenter-provider-gcp chart version | `0.7.0` | no |
| `karpenter_replica_count` | Karpenter controller replicas | `2` | no |
| `karpenter_default_nodeclass_spec` | Replaces the default GCENodeClass spec | `null` | no |
| `karpenter_default_nodepool_spec` | Replaces the default NodePool spec | `null` | no |
| `karpenter_extra_helm_values` | Extra karpenter chart values | `null` | no |

## Outputs

| Name | Description |
|------|-------------|
| `account` | project_id, region |
| `cluster` | name, endpoint, ca_cert, location |
| `gar` | repository_id, repository_url, registry_url |
| `vpc` | network, subnetwork |
| `nuon_dns` | enabled, public_domain, internal_domain |
| `namespaces` | list of created namespaces |
| `karpenter` | enabled, namespace, version, controller_gsa_email, default_nodepool_name, bootstrap_node_pool |
