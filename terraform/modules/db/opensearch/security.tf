# Basic security for ClickHouse: service account with logging and monitoring roles.

resource "google_service_account" "opensearch" {
  project      = var.project_id
  account_id   = "${var.global_prefix}-opensearch"
  display_name = "Service account for OpenSearch nodes"
}

resource "google_project_iam_member" "opensearch" {
  for_each = toset([
    "roles/logging.logWriter",
    "roles/monitoring.metricWriter",
  ])

  project = var.project_id
  role    = each.value
  member  = "serviceAccount:${google_service_account.opensearch.email}"
}
