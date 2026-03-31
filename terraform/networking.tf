# The main network for the deployment.
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

resource "google_compute_subnetwork" "cluster" {
  name          = "${var.global_prefix}-cluster"
  ip_cidr_range = "10.0.1.0/24"
  region        = var.region
  network       = google_compute_network.main.self_link

  secondary_ip_range {
    range_name    = "pods"
    ip_cidr_range = "10.1.0.0/16"
  }

  secondary_ip_range {
    range_name    = "services"
    ip_cidr_range = "10.2.0.0/16"
  }

  private_ip_google_access = true
}


# The following prepares a security policy to restrict access to the PPP services
# in the cluster. The policy will be attached to the Ingress controller later.

# Import the PPP allowlist module.
module "ppp" {
  source = "git@github.com:opentargets/ppp-allowlist"
}

locals {
  # Chunk the CIDRs into groups of 10 (GCP's limit per rule)
  chunk_size = 10
  cidr_chunks = module.ppp.allowlist != [] ? [
    for i in range(0, length(module.ppp.allowlist), local.chunk_size) :
    slice(module.ppp.allowlist, i, min(i + local.chunk_size, length(module.ppp.allowlist)))
  ] : []
}

resource "google_compute_security_policy" "ppp" {
  name        = "${var.global_prefix}-ppp"
  description = "Allow access only from specified CIDRs, block all others"
  project     = var.project_id

  dynamic "rule" {
    for_each = local.cidr_chunks
    content {
      description = "Allow traffic from approved CIDRs - chunk ${rule.key + 1}"
      action      = "allow"
      priority    = 1000 + rule.key
      match {
        versioned_expr = "SRC_IPS_V1"
        config {
          src_ip_ranges = rule.value
        }
      }
    }
  }

  rule {
    description = "Redirect all other traffic to the unauthorised page"
    action      = "redirect"
    priority    = 2147483647
    match {
      versioned_expr = "SRC_IPS_V1"
      config {
        src_ip_ranges = ["*"]
      }
    }
    redirect_options {
      type   = "EXTERNAL_302"
      target = "https://platform.opentargets.org/unauthorised.html"
    }
  }
}
