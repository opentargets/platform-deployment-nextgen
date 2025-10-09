resource "google_compute_subnetwork" "opensearch" {
  name          = "${var.global_prefix}-opensearch"
  project       = var.project_id
  ip_cidr_range = "10.0.3.0/24"
  region        = var.region
  network       = var.network
}

resource "google_compute_firewall" "allow_subnet_opensearchports" {
  name          = "${var.global_prefix}-opensearch-external"
  description   = "Allow external traffic and health checks to OpenSearch nodes"
  project       = var.project_id
  network       = var.network
  source_ranges = ["10.0.0.0/9", "35.191.0.0/16", "130.211.0.0/22"]
  target_tags   = ["opensearch"]
  priority      = 1000

  allow {
    protocol = "tcp"
    ports    = ["9200", "9600"]
  }
}

# We create DNS A records for each OpenSearch node, so we can access them by name.
# This is used by the cluster opensearch services, for the APIs of each color to
# connect to.
resource "google_dns_record_set" "internal" {
  for_each = local.instances

  name         = each.value.dns_name
  type         = "A"
  ttl          = 300
  project      = var.project_id
  managed_zone = var.dns_zone

  rrdatas = [
    google_compute_instance.opensearch_node[each.key].network_interface[0].network_ip,
  ]
}
