nuon_id    = "gke-test-01"
region     = "us-central1"
project_id = "nuon-gcp-support"

public_root_domain   = ""
internal_root_domain = ""
enable_nuon_dns      = "false"

# Service accounts (from install stack)
provision_sa_email   = "provision-sa@my-project.iam.gserviceaccount.com"
maintenance_sa_email = "maintenance-sa@my-project.iam.gserviceaccount.com"
deprovision_sa_email = "deprovision-sa@my-project.iam.gserviceaccount.com"
# break_glass_sa_email = "break-glass-sa@my-project.iam.gserviceaccount.com"

tags = {
  "test" = "true"
}
