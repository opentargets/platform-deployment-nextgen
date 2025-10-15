locals {
  cloud_init = templatefile(
    "${path.module}/cloud-init.yaml",
    { OPENSEARCH_VERSION = var.opensearch_version },
  )
}

# Null resource that triggers instance recreation if we change cloud-init.yaml.
resource "null_resource" "cloud_init" {
  triggers = {
    cloud_init_hash = md5(local.cloud_init)
  }
}

resource "google_compute_disk" "data" {
  name        = "${var.global_prefix}-data-opensearch"
  description = "The data disk for the OpenSearch node in the ${var.global_prefix} environment."
  project     = var.project_id
  zone        = var.zone
  type        = "pd-ssd"
  size        = var.disk_size_gb
  labels      = merge(var.base_labels, var.labels)
}

resource "google_compute_instance" "node" {
  name         = "${var.global_prefix}-opensearch"
  description  = "The OpenSearch node for the ${var.global_prefix} environment."
  project      = var.project_id
  zone         = var.zone
  machine_type = var.machine_type
  tags         = [var.global_prefix, "opensearch"]
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
    subnetwork         = google_compute_subnetwork.opensearch.name
    subnetwork_project = var.project_id
  }

  service_account {
    email  = google_service_account.opensearch.email
    scopes = ["cloud-platform"]
  }

  metadata = {
    user-data = local.cloud_init
  }

  lifecycle {
    replace_triggered_by = [google_compute_disk.data, null_resource.cloud_init]

  }
}
