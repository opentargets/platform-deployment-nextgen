resource "google_compute_subnetwork" "opensearch" {
  name          = "${var.global_prefix}-opensearch"
  description   = "The OpenSearch subnetwork"
  project       = var.project_id
  ip_cidr_range = "10.0.3.0/24"
  region        = var.region
  network       = var.network
}

resource "google_compute_firewall" "allow_cluster" {
  name          = "${var.global_prefix}-opensearch-from-cluster"
  description   = "The firewall rule to allow the cluster to access OpenSearch nodes"
  project       = var.project_id
  network       = var.network
  source_ranges = ["10.0.1.0/24"]
  target_tags   = ["opensearch"]
  priority      = 1000

  allow {
    protocol = "tcp"
    ports    = ["9200", "9600"]
  }
}

resource "google_compute_firewall" "allow_healthcheck" {
  name          = "${var.global_prefix}-opensearch-healthcheck"
  description   = "The firewall rule to allow GCP health checks to OpenSearch nodes"
  project       = var.project_id
  network       = var.network
  source_ranges = ["35.191.0.0/16", "130.211.0.0/22"]
  target_tags   = ["opensearch"]
  priority      = 1000

  allow {
    protocol = "tcp"
    ports    = ["9200"]
  }
}
