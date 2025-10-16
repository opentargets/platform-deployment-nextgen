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
  }
}

provider "google" {
  project = var.project_id
  region  = var.region
}

module "cluster" {
  source                  = "./modules/cluster"
  global_prefix           = var.global_prefix
  project_id              = var.project_id
  region                  = var.region
  zone                    = var.zone
  network                 = google_compute_network.main.name
  base_labels             = var.base_labels
  min_node_count          = var.cluster_min_node_count
  max_node_count          = var.cluster_max_node_count
  machine_type_production = var.cluster_machine_type_production
  machine_type_staging    = var.cluster_machine_type_staging
  disk_size_gb            = var.cluster_disk_size_gb
  kubernetes_version      = var.cluster_kubernetes_version
  labels                  = var.cluster_labels
}

module "clickhouse" {
  source             = "./modules/db/clickhouse"
  global_prefix      = var.global_prefix
  project_id         = var.project_id
  data_project_id    = var.clickhouse_data_project_id
  region             = var.region
  zone               = var.zone
  network            = google_compute_network.main.name
  base_labels        = var.base_labels
  machine_type       = var.clickhouse_machine_type
  disk_size_gb       = var.clickhouse_disk_size_gb
  clickhouse_version = var.clickhouse_version
  dns_zone_name      = google_dns_managed_zone.internal.name
  labels             = { "app" = "clickhouse" }
}

module "opensearch" {
  source             = "./modules/db/opensearch"
  global_prefix      = var.global_prefix
  project_id         = var.project_id
  region             = var.region
  zone               = var.zone
  network            = google_compute_network.main.name
  base_labels        = var.base_labels
  machine_type       = var.opensearch_machine_type
  disk_size_gb       = var.opensearch_disk_size_gb
  opensearch_version = var.opensearch_version
  dns_zone_name      = google_dns_managed_zone.internal.name
  labels             = { "app" = "opensearch" }
}
