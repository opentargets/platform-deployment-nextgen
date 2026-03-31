variable "global_prefix" {
  description = "The global prefix for all resources in a deployment"
  type        = string
}

variable "project_id" {
  description = "The GCP project id"
  type        = string
}

variable "region" {
  description = "The GCP region"
  type        = string
}

variable "zone" {
  description = "The GCP zone"
  type        = string
}

variable "base_labels" {
  description = "The base labels applied to every resource"
  type        = map(string)
}


# CLUSTER VARIABLES
variable "cluster_kubernetes_version" {
  description = "The Kubernetes version for the GKE cluster"
  type        = string
}

variable "cluster_disk_type" {
  description = "The disk type"
  type        = string
}

variable "cluster_disk_iops" {
  description = "The provisioned IOPS for hyperdisks"
  type        = number
}

variable "cluster_disk_throughput" {
  description = "The provisioned throughput for hyperdisks in MB/s "
  type        = number
}

variable "cluster_labels" {
  description = "The labels for the GKE cluster"
  type        = map(string)
}


# APPS VARIABLES
variable "apps_machine_type" {
  description = "The machine type for nodes in the apps node pool"
  type        = string
}

variable "apps_min_node_count" {
  description = "The minimum (and initial) number of nodes in the apps node pool"
  type        = number
}

variable "apps_max_node_count" {
  description = "The maximum number of nodes in the apps node pool"
  type        = number
}

variable "apps_disk_size_gb" {
  description = "The disk size in GB for each node in the apps node pool"
  type        = number
}

variable "apps_labels" {
  description = "The labels for the apps node pool"
  type        = map(string)
}


# CLICKHOUSE VARIABLES
variable "clickhouse_machine_type" {
  description = "The machine type to use for the ClickHouse nodes"
  type        = string
}


variable "clickhouse_min_node_count" {
  description = "The minimum (and initial) number of nodes in the ClickHouse node pool"
  type        = number
}

variable "clickhouse_max_node_count" {
  description = "The maximum number of nodes in the ClickHouse node pool"
}

variable "clickhouse_labels" {
  description = "The labels for the ClickHouse module"
  type        = map(string)
}

# OPENSEARCH VARIABLES
variable "opensearch_machine_type" {
  description = "The machine type to use for the OpenSearch nodes"
  type        = string
}

variable "opensearch_min_node_count" {
  description = "The minimum (and initial) number of nodes in the OpenSearch node pool"
  type        = number
}

variable "opensearch_max_node_count" {
  description = "The maximum number of nodes in the OpenSearch node pool"
  type        = number
}

variable "opensearch_labels" {
  description = "The labels for the OpenSearch module"
  type        = map(string)
}
