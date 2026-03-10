global_prefix = "production"
project_id    = "open-targets-prod"
region        = "europe-west1"
zone          = "europe-west1-d"
base_labels = {
  "team"        = "open-targets",
  "subteam"     = "backend",
  "product"     = "platform",
  "tool"        = "nextgen",
  "environment" = "production",
  "created_by"  = "terraform",
}

# CLUSTER VARIABLES
cluster_kubernetes_version = "latest"
cluster_disk_iops          = 6000
cluster_disk_throughput    = 280
cluster_labels             = {}

# APPS VARIABLES
apps_min_node_count = 1
apps_max_node_count = 5
apps_machine_type   = "c4d-standard-8"
apps_disk_size_gb   = 128
apps_disk_type      = "hyperdisk-balanced"
apps_labels         = {}

# CLICKHOUSE VARIABLES
clickhouse_machine_type    = "c4d-standard-16"
clickhouse_replicas        = 1
clickhouse_shards          = 1
clickhouse_labels          = {}
clickhouse_data_project_id = "open-targets-prod"

# OPENSEARCH VARIABLES
opensearch_machine_type = "c4d-highmem-8"
opensearch_shards       = 1
opensearch_labels       = {}

# CLICKHOUSE VARIABLES (old)
old_clickhouse_machine_type = "n1-standard-16"
old_clickhouse_disk_size_gb = 500

# OPENSEARCH VARIABLES (old)
old_opensearch_machine_type = "n1-standard-16"
old_opensearch_disk_size_gb = 1000
