locals {
  cloud_init = templatefile(
    "${path.module}/assets/cloud-init.yaml",
    {
      # TODO: NOT REMAKE MACHINE ON XML CHANGES
      CLICKHOUSE_VERSION = var.clickhouse_version
      config-xml         = file("${path.module}/assets/config.xml")
      users-xml          = file("${path.module}/assets/users.xml")
    },

  )
}

# Null resource that triggers instance recreation if we change cloud-init.yaml.
resource "null_resource" "cloud_init" {
  triggers = {
    cloud_init_hash = md5(local.cloud_init)
  }
}

resource "google_compute_disk" "data" {
  name    = "${var.global_prefix}-data-ch"
  project = var.project_id
  zone    = var.zone
  type    = "pd-ssd"
  size    = var.disk_size_gb
  labels  = merge(var.base_labels, var.labels)
}

resource "google_compute_instance" "node" {
  name         = "${var.global_prefix}-ch"
  project      = var.project_id
  zone         = var.zone
  machine_type = var.machine_type
  tags         = [var.global_prefix, "clickhouse"]
  labels       = merge(var.base_labels, var.labels)

  boot_disk {
    initialize_params {
      image = "cos-cloud/cos-stable"
      size  = 16
      type  = "pd-ssd"
    }
  }

  attached_disk {
    source      = google_compute_disk.data.id
    device_name = "data"
  }

  network_interface {
    subnetwork         = google_compute_subnetwork.clickhouse.name
    subnetwork_project = var.project_id
  }

  service_account {
    email  = google_service_account.clickhouse.email
    scopes = ["cloud-platform"]
  }

  metadata = {
    user-data = local.cloud_init
  }

  lifecycle {
    replace_triggered_by = [google_compute_disk.data, null_resource.cloud_init]
  }
}
