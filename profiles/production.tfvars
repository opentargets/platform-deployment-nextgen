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
cluster_disk_type          = "hyperdisk-balanced"
cluster_disk_iops          = 6000
cluster_disk_throughput    = 280
cluster_labels             = {}

# APPS VARIABLES
apps_min_node_count = 1
apps_max_node_count = 5
apps_machine_type   = "c4d-standard-8"
apps_disk_size_gb   = 128
apps_labels         = {}

# CLICKHOUSE VARIABLES
clickhouse_machine_type   = "c4d-standard-4"
clickhouse_min_node_count = 1
clickhouse_max_node_count = 5
clickhouse_labels         = {}

# OPENSEARCH VARIABLES
opensearch_machine_type   = "n4-highmem-2"
opensearch_min_node_count = 1
opensearch_max_node_count = 5
opensearch_labels         = {}
