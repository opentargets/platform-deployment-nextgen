# These service accounts are used by the ai-api to access the secret manager for
# the openai token. They are created here to avoid having to grant IAM roles to
# the config-connector service account.
locals {
  products    = ["platform", "ppp"]
  deployments = ["platform-blue", "ppp-blue", "platform-green", "ppp-green"]
}

resource "google_service_account" "aiapi" {
  for_each = toset(local.products)

  project      = var.project_id
  account_id   = "${var.global_prefix}-${each.value}-aiapi"
  display_name = "${var.global_prefix} cluster service account for the ${each.value} deployment ai api"
}

# These gives the aiapi service accounts read access to the secret manager.
resource "google_project_iam_member" "aiapi_roles" {
  for_each = toset(local.products)

  project = var.project_id
  role    = "roles/secretmanager.secretAccessor"
  member  = "serviceAccount:${google_service_account.aiapi[each.value].email}"
}

# Workload Identity bindings for the namespaces.
resource "google_service_account_iam_member" "aiapi_to_global_gsa_workload_identity_binding" {
  for_each = toset(local.deployments)

  service_account_id = google_service_account.aiapi[split("-", each.value)[0]].name
  role               = "roles/iam.workloadIdentityUser"
  member             = "serviceAccount:${var.project_id}.svc.id.goog[${var.global_prefix}-${split("-", each.value)[0]}/${var.global_prefix}-${each.value}-aiapi]"
}

# This service account is used by Config Connector. It needs permissions to create
# DNS records and global IPs. If we ever use it for more things, roles must be
# added here.
resource "google_service_account" "config_connector" {
  project      = var.project_id
  account_id   = "${var.global_prefix}-config-connector"
  display_name = "${var.global_prefix} config connector service account"
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

# This service account is used by the GKE nodes.
resource "google_service_account" "node" {
  project      = var.project_id
  account_id   = "${var.global_prefix}-node"
  display_name = "${var.global_prefix} gke node service account"
}

resource "google_project_iam_member" "node" {
  for_each = toset([
    "roles/logging.logWriter",
    "roles/monitoring.metricWriter",
    "roles/monitoring.viewer",
    "roles/stackdriver.resourceMetadata.writer",
    "roles/artifactregistry.reader",
    "roles/container.defaultNodeServiceAccount",
  ])

  project = var.project_id
  role    = each.value
  member  = "serviceAccount:${google_service_account.node.email}"
}

# Also, give the node service account access to read images from eu-dev
resource "google_project_iam_member" "node_cross_project_registry" {
  project = "open-targets-eu-dev"
  role    = "roles/artifactregistry.reader"
  member  = "serviceAccount:${google_service_account.node.email}"
}
