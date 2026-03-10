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
cluster_kubernetes_version = "latest"
cluster_disk_type          = "hyperdisk-balanced"
cluster_disk_iops          = 3000
cluster_disk_throughput    = 140
cluster_labels             = {}

# APPS VARIABLES
apps_min_node_count = 1
apps_max_node_count = 3
apps_machine_type   = "c4d-standard-4"
apps_disk_size_gb   = 64
apps_labels         = {}

# CLICKHOUSE VARIABLES
clickhouse_machine_type    = "c4d-standard-4"
clickhouse_replicas        = 1
clickhouse_shards          = 1
clickhouse_labels          = {}
clickhouse_data_project_id = "open-targets-prod"

# OPENSEARCH VARIABLES
opensearch_machine_type = "c4d-standard-4"
opensearch_shards       = 1
opensearch_labels       = {}

# CLICKHOUSE VARIABLES (old)
old_clickhouse_machine_type = "n1-standard-4"
old_clickhouse_disk_size_gb = 75

# OPENSEARCH VARIABLES (old)
old_opensearch_machine_type = "n1-standard-4"
old_opensearch_disk_size_gb = 350
