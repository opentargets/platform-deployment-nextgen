resource "google_service_account" "clickhouse" {
  project      = var.project_id
  account_id   = "${var.global_prefix}-clickhouse"
  display_name = "${var.global_prefix} clickhouse node service account"
  description  = "The service account for ClickHouse nodes in ${var.global_prefix}, used for logging and monitoring."
}

resource "google_project_iam_member" "clickhouse" {
  for_each = toset([
    "roles/logging.logWriter",
    "roles/monitoring.metricWriter",
  ])

  project = var.project_id
  role    = each.value
  member  = "serviceAccount:${google_service_account.clickhouse.email}"
}
