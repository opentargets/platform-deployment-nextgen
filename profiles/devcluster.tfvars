global_prefix = "devcluster"
project_id    = "open-targets-eu-dev"
region        = "europe-west1"
zone          = "europe-west1-b"
base_labels = {
  "team"        = "open-targets",
  "subteam"     = "backend",
  "product"     = "platform",
  "tool"        = "nextgen",
  "environment" = "development",
  "created_by"  = "terraform",
}

# CLUSTER VARIABLES
cluster_min_node_count          = 1
cluster_max_node_count          = 3
cluster_machine_type_production = "n1-standard-4"
cluster_machine_type_staging    = "n1-standard-4"
cluster_disk_size_gb            = 64
cluster_kubernetes_version      = "latest"
cluster_labels                  = {}

# CLICKHOUSE VARIABLES
clickhouse_machine_type            = "n1-standard-4"
clickhouse_version                 = "25.8.2.29"
clickhouse_snapshot_platform_blue  = "platform-2506-ch"
clickhouse_snapshot_platform_green = "platform-2509-ch"
clickhouse_snapshot_ppp_blue       = "ppp-2506-ch"
clickhouse_snapshot_ppp_green      = "ppp-2506-ch"
clickhouse_labels                  = { "app" = "clickhouse" }

# OPENSEARCH VARIABLES
opensearch_machine_type            = "n1-standard-4"
opensearch_version                 = "3.1.0"
opensearch_snapshot_platform_blue  = "platform-2506-os"
opensearch_snapshot_platform_green = "platform-2509-os"
opensearch_snapshot_ppp_blue       = "ppp-2506-os"
opensearch_snapshot_ppp_green      = "ppp-2506-os"
opensearch_labels                  = { "app" = "opensearch" }
