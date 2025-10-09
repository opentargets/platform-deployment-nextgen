resource "google_compute_network" "testdb" {
  name                    = "${var.global_prefix}-main"
  description             = "The main VPC network for the ${var.global_prefix} deployment"
  project                 = var.project_id
  auto_create_subnetworks = false
}

resource "google_compute_subnetwork" "testdb" {
  name          = "${var.global_prefix}-subnet"
  description   = "The main subnetwork for the ${var.global_prefix} network"
  project       = var.project_id
  ip_cidr_range = "10.0.1.0/24"
  region        = var.region
  network       = google_compute_network.testdb.id
}

resource "google_compute_router" "testdb" {
  name        = "${var.global_prefix}-router"
  description = "The router for the ${var.global_prefix} network"
  project     = var.project_id
  region      = var.region
  network     = google_compute_network.testdb.self_link
}

resource "google_compute_router_nat" "testdb" {
  name                               = "${var.global_prefix}-router-nat"
  project                            = var.project_id
  router                             = google_compute_router.testdb.name
  region                             = var.region
  nat_ip_allocate_option             = "AUTO_ONLY"
  source_subnetwork_ip_ranges_to_nat = "ALL_SUBNETWORKS_ALL_IP_RANGES"
}

resource "google_compute_firewall" "allow_subnet_opensearchports" {
  name          = "${var.global_prefix}-opensearch-external"
  description   = "Allow external traffic and health checks to OpenSearch nodes"
  project       = var.project_id
  network       = google_compute_network.testdb.name
  source_ranges = ["10.0.0.0/8", "35.191.0.0/16", "130.211.0.0/22"]
  target_tags   = ["opensearch"]
  priority      = 1000

  allow {
    protocol = "tcp"
    ports    = ["9200", "9600"]
  }
}

resource "google_compute_firewall" "allow_subnet_clickhouseports" {
  name          = "${var.global_prefix}-clickhouse-external"
  description   = "Allow external traffic and health checks to ClickHouse nodes"
  project       = var.project_id
  network       = google_compute_network.testdb.name
  source_ranges = ["10.0.0.0/8", "35.191.0.0/16", "130.211.0.0/22"]
  target_tags   = ["clickhouse"]
  priority      = 1000

  allow {
    protocol = "tcp"
    ports    = ["8123", "9000"]
  }
}

resource "google_compute_firewall" "allow_ssh_from_iap" {
  name          = "${var.global_prefix}-ssh-from-iap"
  description   = "Allow SSH from IAP to all instances"
  project       = var.project_id
  network       = google_compute_network.testdb.name
  source_ranges = ["35.235.240.0/20"]
  target_tags   = [var.global_prefix]
  priority      = 1000

  allow {
    protocol = "tcp"
    ports    = ["22"]
  }
}
