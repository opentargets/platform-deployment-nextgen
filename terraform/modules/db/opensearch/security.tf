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

# Grant the service account access to the GCS bucket used for storing OpenSearch snapshots.
resource "google_storage_bucket_iam_member" "opensearch_data_access" {
  bucket = "open-targets-data-backends"
  role   = "roles/storage.objectUser"
  member = "serviceAccount:${google_service_account.opensearch.email}"
}
