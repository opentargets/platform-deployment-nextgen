resource "google_compute_subnetwork" "cluster" {
  name          = "${var.global_prefix}-cluster"
  ip_cidr_range = "10.0.1.0/24"
  region        = var.region
  network       = var.network

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

module "ppp" {
  source = "git@github.com:opentargets/ppp-allowlist"
}

# This prepares a security policy to restrict access to the PPP services in the
# cluster. The policy will be attached to the Ingress controller later.
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
