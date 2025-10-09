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

variable "machine_type" {
  description = "The machine type to use for the OpenSearch node"
  type        = string
}

variable "opensearch_version" {
  description = "The OpenSearch version to deploy"
  type        = string
}

variable "clickhouse_version" {
  description = "The ClickHouse version to deploy"
  type        = string
}

variable "labels" {
  description = "The specific labels for the OpenSearch module"
  type        = map(string)
}
