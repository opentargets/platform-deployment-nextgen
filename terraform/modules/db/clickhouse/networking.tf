resource "google_compute_subnetwork" "clickhouse" {
  name = "${var.global_prefix}-clickhouse"
  # description   = "The ClickHouse subnetwork for the ${var.global_prefix} environment."
  project       = var.project_id
  ip_cidr_range = "10.0.2.0/24"
  region        = var.region
  network       = var.network
}

resource "google_compute_firewall" "allow_cluster" {
  name          = "${var.global_prefix}-clickhouse-from-cluster"
  description   = "The firewall rule to allow the cluster's pod range to access ClickHouse nodes in the ${var.global_prefix} environment."
  project       = var.project_id
  network       = var.network
  source_ranges = ["10.1.0.0/16"]
  target_tags   = ["clickhouse"]
  priority      = 1000

  allow {
    protocol = "tcp"
    ports    = ["8123", "9000"]
  }
}

resource "google_compute_firewall" "allow_healthcheck" {
  name          = "${var.global_prefix}-clickhouse-healthcheck"
  description   = "The firewall rule to allow GCP health checks to ClickHouse nodes in the ${var.global_prefix} environment."
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

resource "google_dns_record_set" "internal" {
  name         = "clickhouse.${var.global_prefix}.internal."
  project      = var.project_id
  managed_zone = var.dns_zone_name
  type         = "A"
  ttl          = 300

  rrdatas = [
    google_compute_instance.node.network_interface.0.network_ip,
  ]
}
