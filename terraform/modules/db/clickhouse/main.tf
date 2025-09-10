# ClickHouse disks and instances. This is repeated four times for products and
# colors. In the future, we will have only one, but it will be an instance group
# with multiple nodes, and a load balancer in front of it.
locals {
  instances = {
    platform_blue = {
      disk_name     = "${var.global_prefix}-data-ch-platform-blue"
      disk_snapshot = var.snapshot_platform_blue
      instance_name = "${var.global_prefix}-platform-blue-clickhouse"
      machine_type  = var.machine_type
      dns_name      = "platform-blue.clickhouse.${var.global_prefix}.internal."
      labels = {
        product = "platform"
        color   = "blue"
      }
    }
    platform_green = {
      disk_name     = "${var.global_prefix}-data-ch-platform-green"
      disk_snapshot = var.snapshot_platform_green
      instance_name = "${var.global_prefix}-platform-green-clickhouse"
      machine_type  = var.machine_type
      dns_name      = "platform-green.clickhouse.${var.global_prefix}.internal."
      labels = {
        product = "platform"
        color   = "green"
      }
    }
    ppp_blue = {
      disk_name     = "${var.global_prefix}-data-ch-ppp-blue"
      disk_snapshot = var.snapshot_ppp_blue
      instance_name = "${var.global_prefix}-ppp-blue-clickhouse"
      machine_type  = "n1-standard-2"
      dns_name      = "ppp-blue.clickhouse.${var.global_prefix}.internal."
      labels = {
        product = "ppp"
        color   = "blue"
      }
    }
    ppp_green = {
      disk_name     = "${var.global_prefix}-data-ch-ppp-green"
      disk_snapshot = var.snapshot_ppp_green
      instance_name = "${var.global_prefix}-ppp-green-clickhouse"
      machine_type  = "n1-standard-2"
      dns_name      = "ppp-green.clickhouse.${var.global_prefix}.internal."
      labels = {
        product = "ppp"
        color   = "green"
      }
    }
  }
}

resource "google_compute_disk" "clickhouse_data" {
  for_each = local.instances

  name     = each.value.disk_name
  project  = var.project_id
  zone     = var.zone
  type     = "pd-ssd"
  snapshot = "projects/open-targets-eu-dev/global/snapshots/${each.value.disk_snapshot}"
  labels   = merge(var.base_labels, var.labels, each.value.labels)
}

resource "google_compute_instance" "clickhouse_node" {
  for_each = local.instances

  name         = each.value.instance_name
  project      = var.project_id
  zone         = var.zone
  machine_type = each.value.machine_type
  tags         = [var.global_prefix, "clickhouse"]
  labels       = merge(var.base_labels, var.labels, each.value.labels)

  boot_disk {
    initialize_params {
      image = "cos-cloud/cos-stable"
      size  = 16
      type  = "pd-ssd"
    }
  }

  attached_disk {
    source      = google_compute_disk.clickhouse_data[each.key].id
    device_name = "data"
  }

  network_interface {
    subnetwork = google_compute_subnetwork.clickhouse.name
  }

  service_account {
    email  = google_service_account.clickhouse.email
    scopes = ["cloud-platform"]
  }

  metadata = {
    user-data = templatefile(
      "${path.module}/cloud-init.yaml",
      { CLICKHOUSE_VERSION = var.clickhouse_version },
    )
  }
}
