# VARIABLES COMING FROM THE MAIN MODULE
variable "global_prefix" {
  description = "The global prefix for all resources in an environment"
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

variable "network" {
  description = "The name of the main VPC network for the deployment"
  type        = string
}

variable "base_labels" {
  description = "The base labels coming from the root module"
  type        = map(string)
}

# CLICKHOUSE VARIABLES
variable "data_project_id" {
  description = "The GCP project id where the backups are stored. Used to create an HMAC key for ClickHouse to access GCS buckets."
  type        = string
}

variable "machine_type" {
  description = "The machine type to use for the ClickHouse node"
  type        = string
}

variable "disk_size_gb" {
  description = "The size of the ClickHouse data disk in GB"
  type        = number
}

variable "clickhouse_version" {
  description = "The ClickHouse version to deploy"
  type        = string
}

variable "dns_zone_name" {
  description = "The name of the managed DNS zone to expose ClickHouse"
  type        = string
}

variable "labels" {
  description = "The specific labels for the ClickHouse module"
  type        = map(string)
}

variable "node_exporter_image_name" {
  description = "Image used to create the node exporter container."
  default     = "quay.io/prometheus/node-exporter"
}

variable "node_exporter_image_version" {
  description = "Image version of the node exporter image."
  default     = "v1.9.1"
}
