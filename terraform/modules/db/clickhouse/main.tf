locals {
  cloud_init = templatefile(
    "${path.module}/assets/cloud-init.yaml",
    {
      CLICKHOUSE_VERSION = var.clickhouse_version
      config-xml         = base64encode(file("${path.module}/assets/config.xml"))
      users-xml          = base64encode(file("${path.module}/assets/users.xml"))
      s3-config = base64encode(templatefile(
        "${path.module}/assets/s3.xml",
        {
          ACCESS_KEY_ID     = google_storage_hmac_key.clickhouse.access_id
          SECRET_ACCESS_KEY = google_storage_hmac_key.clickhouse.secret
        },
      )),
      node_exporter_container_image = "${var.node_exporter_image_name}:${var.node_exporter_image_version}"
    },
  )
  cloud_init_template_hash = md5(file("${path.module}/assets/cloud-init.yaml"))
}

# Null resource that triggers instance recreation if we change cloud-init.yaml.
# But not if we change config.xml or users.xml, we can just restart ClickHouse.
resource "null_resource" "cloud_init" {
  triggers = {
    cloud_init_hash = local.cloud_init_template_hash
  }
}

resource "google_compute_disk" "data" {
  name        = "${var.global_prefix}-data-clickhouse"
  description = "The data disk for the ClickHouse node in the ${var.global_prefix} environment."
  project     = var.project_id
  zone        = var.zone
  type        = "pd-ssd"
  size        = var.disk_size_gb
  labels      = merge(var.base_labels, var.labels)
}

resource "google_compute_instance" "node" {
  name         = "${var.global_prefix}-clickhouse"
  description  = "The ClickHouse node for the ${var.global_prefix} environment."
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
