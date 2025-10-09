terraform {
  required_version = ">= 1.0"
  required_providers {
    google = {
      source  = "hashicorp/google"
      version = "~> 7.0"
    }
  }
  backend "gcs" {
    bucket = "open-targets-ops"
    prefix = "terraform/testdb"
  }
}

resource "google_compute_disk" "opensearch_data" {
  name    = "${var.global_prefix}-data-os"
  project = var.project_id
  zone    = var.zone
  type    = "pd-ssd"
  size    = 500
  labels  = var.labels
}

resource "google_compute_disk" "clickhouse_data" {
  name    = "${var.global_prefix}-data-ch"
  project = var.project_id
  zone    = var.zone
  type    = "pd-ssd"
  size    = 200
  labels  = var.labels
}

locals {
  opensearch_startup_script = templatefile(
    "${path.module}/cloud-init-opensearch.yaml",
    { OPENSEARCH_VERSION = var.opensearch_version },
  )
}

resource "null_resource" "opensearch_startup_script" {
  triggers = {
    cloud_init_hash = md5(local.opensearch_startup_script)
  }
}

resource "google_compute_instance" "opensearch_node" {
  name         = "${var.global_prefix}-os"
  project      = var.project_id
  zone         = var.zone
  machine_type = var.machine_type
  tags         = [var.global_prefix, "opensearch"]
  labels       = var.labels

  boot_disk {
    initialize_params {
      image = "cos-cloud/cos-stable"
      size  = 32
      type  = "pd-ssd"
    }
  }

  attached_disk {
    source      = google_compute_disk.opensearch_data.id
    device_name = "data"
  }

  network_interface {
    subnetwork         = google_compute_subnetwork.testdb.self_link
    subnetwork_project = var.project_id
  }

  service_account {
    email  = google_service_account.opensearch.email
    scopes = ["cloud-platform"]
  }

  metadata = {
    user-data = local.opensearch_startup_script
  }

  lifecycle {
    replace_triggered_by = [google_compute_disk.opensearch_data, null_resource.opensearch_startup_script]

  }
}

locals {
  clickhouse_startup_script = templatefile(
    "${path.module}/cloud-init-clickhouse.yaml",
    { CLICKHOUSE_VERSION = var.clickhouse_version },
  )
}

resource "null_resource" "clickhouse_startup_script" {
  triggers = {
    cloud_init_hash = md5(local.clickhouse_startup_script)
  }
}

resource "google_compute_instance" "clickhouse_node" {
  name         = "${var.global_prefix}-ch"
  project      = var.project_id
  zone         = var.zone
  machine_type = var.machine_type
  tags         = [var.global_prefix, "clickhouse"]
  labels       = var.labels

  boot_disk {
    initialize_params {
      image = "cos-cloud/cos-stable"
      size  = 32
      type  = "pd-ssd"
    }
  }

  attached_disk {
    source      = google_compute_disk.clickhouse_data.id
    device_name = "data"
  }

  network_interface {
    subnetwork         = google_compute_subnetwork.testdb.name
    subnetwork_project = var.project_id
  }

  service_account {
    email  = google_service_account.clickhouse.email
    scopes = ["cloud-platform"]
  }

  metadata = {
    user-data = local.clickhouse_startup_script
  }

  lifecycle {
    replace_triggered_by = [google_compute_disk.clickhouse_data, null_resource.clickhouse_startup_script]
  }
}
