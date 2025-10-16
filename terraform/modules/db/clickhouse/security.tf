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

# In the development environment, we create need to create a service account for accessing the GCS bucket
# that holds the backups. This is because the bucket is in the production project and ClickHouse uses the
# S3 endpoint to access it, which requires an HMAC key. The HMAC key is tied to a service account, and it
# must be a service account in the same project as the bucket.
resource "google_service_account" "clickhouse_data" {
  count        = var.global_prefix == "production" ? 0 : 1
  project      = var.data_project_id
  account_id   = "${var.global_prefix}-clickhouse-data"
  display_name = "${var.global_prefix} clickhouse data access service account"
  description  = "The service account for ClickHouse nodes in the ${var.global_prefix} environment, with access to GCS buckets in project ${var.data_project_id} for backup retrieval."
}

resource "google_project_iam_member" "clickhouse_data" {
  count   = var.global_prefix == "production" ? 0 : 1
  project = var.data_project_id
  role    = "roles/storage.objectViewer"
  condition {
    description = "Allow access only to the open-targets-data-backends bucket"
    expression  = "resource.name.startsWith('projects/_/buckets/open-targets-data-backends')"
    title       = "Limit to open-targets-data-backends bucket"
  }
  member = "serviceAccount:${google_service_account.clickhouse_data[0].email}"
}

resource "google_project_iam_member" "clickhouse_allow_impersonate_clickhouse_data" {
  count   = var.global_prefix == "production" ? 0 : 1
  project = var.project_id
  role    = "roles/iam.serviceAccountUser"
  member  = "serviceAccount:${google_service_account.clickhouse.email}"
  condition {
    description = "Allow the ClickHouse service account to impersonate the ClickHouse data access service account"
    expression  = "resource.name == 'projects/${var.data_project_id}/serviceAccounts/${google_service_account.clickhouse_data[0].email}'"
    title       = "Allow impersonation of ClickHouse data access service account"
  }
  depends_on = [google_service_account.clickhouse, google_service_account.clickhouse_data]
}

# Used to access GCS buckets when loading data into ClickHouse by using backups.
resource "google_storage_hmac_key" "clickhouse" {
  service_account_email = var.global_prefix == "production" ? google_service_account.clickhouse.email : google_service_account.clickhouse_data[0].email
  project               = var.data_project_id
}
