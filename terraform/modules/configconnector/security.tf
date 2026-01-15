# This service account is used by Config Connector. It needs permissions to create
# DNS records and global IPs. If we ever use it for more things, roles must be
# added here.
resource "google_service_account" "config_connector" {
  project      = var.project_id
  account_id   = "${var.global_prefix}-config-connector"
  display_name = "${var.global_prefix} cluster config connector service account"
  description  = "Service account for config connector in the ${var.global_prefix} cluster, used to add dns records and global ip addresses."
}

resource "google_project_iam_member" "config_connector_roles" {
  for_each = toset([
    "roles/dns.admin",
    "roles/compute.publicIpAdmin",
  ])

  project = var.project_id
  role    = each.value
  member  = "serviceAccount:${google_service_account.config_connector.email}"
}

resource "google_service_account_iam_member" "config_connector_workload_identity" {
  service_account_id = google_service_account.config_connector.name
  role               = "roles/iam.workloadIdentityUser"
  member             = "serviceAccount:${var.project_id}.svc.id.goog[cnrm-system/cnrm-controller-manager]"
}
