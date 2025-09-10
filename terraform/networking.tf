# The main network which contains both the cluster and the databases.
resource "google_compute_network" "main" {
  name                    = "${var.global_prefix}-main"
  auto_create_subnetworks = false
}

# Router and NAT to allow outbound internet access for instances without external
# IPs. This is required because the nodes must pull opensearch and clickhouse images.
resource "google_compute_router" "main" {
  name    = "${var.global_prefix}-router"
  region  = var.region
  network = google_compute_network.main.self_link
}

resource "google_compute_router_nat" "main" {
  name                               = "${var.global_prefix}-router-nat"
  router                             = google_compute_router.main.name
  region                             = var.region
  nat_ip_allocate_option             = "AUTO_ONLY"
  source_subnetwork_ip_ranges_to_nat = "ALL_SUBNETWORKS_ALL_IP_RANGES"
}

# Firewall rule to allow SSH from IAP to all instances.
resource "google_compute_firewall" "main_ssh_from_iap" {
  name          = "${var.global_prefix}-ssh-from-iap"
  description   = "Allow SSH from IAP to all instances"
  project       = var.project_id
  network       = google_compute_network.main.name
  source_ranges = ["35.235.240.0/20"]
  target_tags   = [var.global_prefix]
  priority      = 1000

  allow {
    protocol = "tcp"
    ports    = ["22"]
  }
}

# Private DNS zone for internal service discovery within the VPC and GKE cluster.
# This is used by the cluster to resolve the database instances.
resource "google_dns_managed_zone" "internal" {
  name        = "${var.global_prefix}-internal"
  description = "Private DNS zone for ${var.global_prefix} services"
  project     = var.project_id
  dns_name    = "${var.global_prefix}.internal."
  visibility  = "private"

  private_visibility_config {
    networks {
      network_url = google_compute_network.main.id
    }
    gke_clusters {
      gke_cluster_name = module.cluster.id
    }
  }
}
