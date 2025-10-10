resource "google_compute_subnetwork" "clickhouse" {
  name          = "${var.global_prefix}-clickhouse"
  description   = "The ClickHouse subnetwork"
  project       = var.project_id
  ip_cidr_range = "10.0.2.0/24"
  region        = var.region
  network       = var.network
}

resource "google_compute_firewall" "allow_cluster" {
  name          = "${var.global_prefix}-clickhouse-from-cluster"
  description   = "The firewall rule to allow the cluster to access ClickHouse nodes"
  project       = var.project_id
  network       = var.network
  source_ranges = ["10.0.1.0/24"]
  target_tags   = ["clickhouse"]
  priority      = 1000

  allow {
    protocol = "tcp"
    ports    = ["8123", "9000"]
  }
}

resource "google_compute_firewall" "allow_healthcheck" {
  name          = "${var.global_prefix}-clickhouse-healthcheck"
  description   = "The firewall rule to allow GCP health checks to ClickHouse nodes"
  project       = var.project_id
  network       = var.network
  source_ranges = ["35.191.0.0/16", "130.211.0.0/22"]
  target_tags   = ["clickhouse"]
  priority      = 1000

  allow {
    protocol = "tcp"
    ports    = ["8123"]
  }
}
