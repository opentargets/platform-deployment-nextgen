# OpenSearch disks and instances. This is repeated four times for products and
# colors. In the future, we will have only one, but it will be an instance group
# with multiple nodes, and a load balancer in front of it.
locals {
  instances = {
    platform_blue = {
      disk_name     = "${var.global_prefix}-data-os-platform-blue"
      disk_snapshot = var.snapshot_platform_blue
      instance_name = "${var.global_prefix}-platform-blue-opensearch"
      machine_type  = var.machine_type
      dns_name      = "platform-blue.opensearch.${var.global_prefix}.internal."
      labels = {
        product = "platform"
        color   = "blue"
      }
    }
    platform_green = {
      disk_name     = "${var.global_prefix}-data-os-platform-green"
      disk_snapshot = var.snapshot_platform_green
      instance_name = "${var.global_prefix}-platform-green-opensearch"
      machine_type  = var.machine_type
      dns_name      = "platform-green.opensearch.${var.global_prefix}.internal."
      labels = {
        product = "platform"
        color   = "green"
      }
    }
    ppp_blue = {
      disk_name     = "${var.global_prefix}-data-os-ppp-blue"
      disk_snapshot = var.snapshot_ppp_blue
      instance_name = "${var.global_prefix}-ppp-blue-opensearch"
      machine_type  = "n1-standard-2"
      dns_name      = "ppp-blue.opensearch.${var.global_prefix}.internal."
      labels = {
        product = "ppp"
        color   = "blue"
      }
    }
    ppp_green = {
      disk_name     = "${var.global_prefix}-data-os-ppp-green"
      disk_snapshot = var.snapshot_ppp_green
      instance_name = "${var.global_prefix}-ppp-green-opensearch"
      machine_type  = "n1-standard-2"
      dns_name      = "ppp-green.opensearch.${var.global_prefix}.internal."
      labels = {
        product = "ppp"
        color   = "green"
      }
    }
  }
}

resource "google_compute_disk" "opensearch_data" {
  for_each = local.instances

  name     = each.value.disk_name
  project  = var.project_id
  zone     = var.zone
  type     = "pd-ssd"
  snapshot = "projects/open-targets-eu-dev/global/snapshots/${each.value.disk_snapshot}"
  labels   = merge(var.base_labels, var.labels, each.value.labels)
}

resource "google_compute_instance" "opensearch_node" {
  for_each = local.instances

  name         = each.value.instance_name
  project      = var.project_id
  zone         = var.zone
  machine_type = each.value.machine_type
  tags         = [var.global_prefix, "opensearch"]
  labels       = merge(var.base_labels, var.labels, each.value.labels)

  boot_disk {
    initialize_params {
      image = "cos-cloud/cos-stable"
      size  = 16
      type  = "pd-ssd"
    }
  }

  attached_disk {
    source      = google_compute_disk.opensearch_data[each.key].id
    device_name = "data"
  }

  network_interface {
    subnetwork = google_compute_subnetwork.opensearch.name
  }

  service_account {
    email  = google_service_account.opensearch.email
    scopes = ["cloud-platform"]
  }

  metadata = {
    user-data = templatefile(
      "${path.module}/cloud-init.yaml",
      { OPENSEARCH_VERSION = var.opensearch_version },
    )
  }

  lifecycle {
    replace_triggered_by = [google_compute_disk.opensearch_data[each.key]]
  }
}
