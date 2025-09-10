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

# The two database modules deploy ClickHouse and OpenSearch outside of the cluster.
# This deploys two instances of each database, a and b. This is temporary until we
# have a unified instance for each database once we implement namespacing.
module "db_clickhouse" {
  source                  = "./modules/db/clickhouse"
  global_prefix           = var.global_prefix
  project_id              = var.project_id
  region                  = var.region
  zone                    = var.zone
  network                 = google_compute_network.main.name
  base_labels             = var.base_labels
  machine_type            = var.clickhouse_machine_type
  clickhouse_version      = var.clickhouse_version
  snapshot_platform_blue  = var.clickhouse_snapshot_platform_blue
  snapshot_platform_green = var.clickhouse_snapshot_platform_green
  snapshot_ppp_blue       = var.clickhouse_snapshot_ppp_blue
  snapshot_ppp_green      = var.clickhouse_snapshot_ppp_green
  dns_zone                = google_dns_managed_zone.internal.name
  labels                  = { "app" = "clickhouse" }
}

module "db_opensearch" {
  source                  = "./modules/db/opensearch"
  global_prefix           = var.global_prefix
  project_id              = var.project_id
  region                  = var.region
  zone                    = var.zone
  network                 = google_compute_network.main.name
  base_labels             = var.base_labels
  machine_type            = var.opensearch_machine_type
  opensearch_version      = var.opensearch_version
  snapshot_platform_blue  = var.opensearch_snapshot_platform_blue
  snapshot_platform_green = var.opensearch_snapshot_platform_green
  snapshot_ppp_blue       = var.opensearch_snapshot_ppp_blue
  snapshot_ppp_green      = var.opensearch_snapshot_ppp_green
  dns_zone                = google_dns_managed_zone.internal.name
  labels                  = { "app" = "opensearch" }
}
