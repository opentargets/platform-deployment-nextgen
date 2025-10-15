resource "google_service_account" "opensearch" {
  project      = var.project_id
  account_id   = "${var.global_prefix}-opensearch"
  display_name = "${var.global_prefix} opensearch node service account"
  description  = "The service account for OpenSearch nodes in ${var.global_prefix}, used for logging and monitoring."
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
