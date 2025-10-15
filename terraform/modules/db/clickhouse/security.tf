resource "google_service_account" "clickhouse" {
  project      = var.project_id
  account_id   = "${var.global_prefix}-clickhouse"
  display_name = "${var.global_prefix} clickhouse node service account"
  description  = "The service account for ClickHouse nodes in the ${var.global_prefix} environment, with logging, monitoring and GCS access for backup retrieval."
}

resource "google_project_iam_member" "clickhouse" {
  for_each = toset([
    "roles/logging.logWriter",
    "roles/monitoring.metricWriter",
    "roles/storage.objectUser",
  ])

  project = var.project_id
  role    = each.value
  member  = "serviceAccount:${google_service_account.clickhouse.email}"
}

# Used to access GCS buckets when loading data into ClickHouse by using backups.
resource "google_storage_hmac_key" "clickhouse" {
  service_account_email = google_service_account.clickhouse.email
  project               = var.project_id
}
