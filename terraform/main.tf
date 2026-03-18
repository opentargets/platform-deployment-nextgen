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
  source                     = "./modules/cluster"
  global_prefix              = var.global_prefix
  project_id                 = var.project_id
  region                     = var.region
  zone                       = var.zone
  network                    = google_compute_network.main.name
  base_labels                = var.base_labels
  kubernetes_version         = var.cluster_kubernetes_version
  disk_type                  = var.cluster_disk_type
  disk_iops                  = var.cluster_disk_iops
  disk_throughput            = var.cluster_disk_throughput
  labels                     = var.cluster_labels
  apps_machine_type          = var.apps_machine_type
  apps_min_node_count        = var.apps_min_node_count
  apps_max_node_count        = var.apps_max_node_count
  apps_disk_size_gb          = var.apps_disk_size_gb
  apps_labels                = var.apps_labels
  clickhouse_machine_type    = var.clickhouse_machine_type
  clickhouse_min_node_count  = var.clickhouse_min_node_count
  clickhouse_max_node_count  = var.clickhouse_max_node_count
  clickhouse_data_project_id = var.clickhouse_data_project_id
  clickhouse_labels          = var.clickhouse_labels
  opensearch_machine_type    = var.opensearch_machine_type
  opensearch_min_node_count  = var.opensearch_min_node_count
  opensearch_max_node_count  = var.opensearch_max_node_count
  opensearch_labels          = var.opensearch_labels
}

# After dbs are put in the cluster, we can remove all this and bring the cluster module
# here into the root, as there won't be any other modules apart from it.
module "clickhouse" {
  source             = "./modules/db/clickhouse"
  global_prefix      = var.global_prefix
  project_id         = var.project_id
  data_project_id    = var.clickhouse_data_project_id
  region             = var.region
  zone               = var.zone
  network            = google_compute_network.main.name
  base_labels        = var.base_labels
  machine_type       = var.old_clickhouse_machine_type
  disk_size_gb       = var.old_clickhouse_disk_size_gb
  clickhouse_version = "25.8.2.29"
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
  machine_type       = var.old_opensearch_machine_type
  disk_size_gb       = var.old_opensearch_disk_size_gb
  opensearch_version = "3.1.0"
  dns_zone_name      = google_dns_managed_zone.internal.name
  labels             = { "app" = "opensearch" }
}
