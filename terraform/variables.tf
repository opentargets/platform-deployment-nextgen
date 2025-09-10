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
variable "cluster_min_node_count" {
  description = "The minimum (and initial) number of nodes in the cluster"
  type        = number
}

variable "cluster_max_node_count" {
  description = "The maximum number of nodes in the cluster"
  type        = number
}

variable "cluster_machine_type_production" {
  description = "The machine type for GKE nodes in the production node pool"
  type        = string
}

variable "cluster_machine_type_staging" {
  description = "The machine type for GKE nodes in the staging node pool"
  type        = string
}

variable "cluster_disk_size_gb" {
  description = "The disk size in GB for each GKE node"
  type        = number
}

variable "cluster_kubernetes_version" {
  description = "The Kubernetes version for the GKE cluster"
  type        = string
}

variable "cluster_labels" {
  description = "The specific labels for the GKE cluster"
  type        = map(string)
}


# CLICKHOUSE VARIABLES
variable "clickhouse_machine_type" {
  description = "The machine type to use for the ClickHouse node"
  type        = string
}

variable "clickhouse_version" {
  description = "The ClickHouse version to deploy"
  type        = string
}

variable "clickhouse_snapshot_platform_blue" {
  description = "The name of the ClickHouse snapshot to use in the platform blue node"
  type        = string
}

variable "clickhouse_snapshot_platform_green" {
  description = "The name of the ClickHouse snapshot to use in the platform green node"
  type        = string
}

variable "clickhouse_snapshot_ppp_blue" {
  description = "The name of the ClickHouse snapshot to use in the ppp blue node"
  type        = string
}

variable "clickhouse_snapshot_ppp_green" {
  description = "The name of the ClickHouse snapshot to use in the ppp green node"
  type        = string
}

variable "clickhouse_labels" {
  description = "The specific labels for the ClickHouse module"
  type        = map(string)
}


# OPENSEARCH VARIABLES
variable "opensearch_machine_type" {
  description = "The machine type to use for the OpenSearch node"
  type        = string
}

variable "opensearch_version" {
  description = "The OpenSearch version to deploy"
  type        = string
}

variable "opensearch_snapshot_platform_blue" {
  description = "The name of the OpenSearch snapshot to use in the platform blue node"
  type        = string
}

variable "opensearch_snapshot_platform_green" {
  description = "The name of the OpenSearch snapshot to use in the platform green node"
  type        = string
}

variable "opensearch_snapshot_ppp_blue" {
  description = "The name of the OpenSearch snapshot to use in the ppp blue node"
  type        = string
}

variable "opensearch_snapshot_ppp_green" {
  description = "The name of the OpenSearch snapshot to use in the ppp green node"
  type        = string
}

variable "opensearch_labels" {
  description = "The specific labels for the OpenSearch module"
  type        = map(string)
}
