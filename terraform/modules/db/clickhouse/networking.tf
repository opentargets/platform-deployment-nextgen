resource "google_compute_subnetwork" "clickhouse" {
  name          = "${var.global_prefix}-clickhouse"
  project       = var.project_id
  ip_cidr_range = "10.0.2.0/24"
  region        = var.region
  network       = var.network
}

resource "google_compute_firewall" "allow_subnet_clickhouseports" {
  name          = "${var.global_prefix}-clickhouse-external"
  description   = "Allow external traffic and health checks to ClickHouse nodes"
  project       = var.project_id
  network       = var.network
  source_ranges = ["10.0.0.0/9", "35.191.0.0/16", "130.211.0.0/22"]
  target_tags   = ["clickhouse"]
  priority      = 1000

  allow {
    protocol = "tcp"
    ports    = ["8123", "9000"]
  }
}

# We create DNS A records for each ClickHouse node, so we can access them by name.
# This is used by the cluster clickhouse services, for the APIs of each color to
# connect to.
resource "google_dns_record_set" "internal" {
  for_each = local.instances

  name         = each.value.dns_name
  type         = "A"
  ttl          = 300
  project      = var.project_id
  managed_zone = var.dns_zone

  rrdatas = [
    google_compute_instance.clickhouse_node[each.key].network_interface[0].network_ip,
  ]
}
