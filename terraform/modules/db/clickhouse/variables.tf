# VARIABLES COMING FROM THE MAIN MODULE
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

variable "network" {
  description = "The name of the main VPC network for the deployment"
  type        = string
}

variable "base_labels" {
  description = "The base labels coming from the root module"
  type        = map(string)
}


# CLICKHOUSE VARIABLES
variable "machine_type" {
  description = "The machine type to use for the ClickHouse node"
  type        = string
}

variable "clickhouse_version" {
  description = "The ClickHouse version to deploy"
  type        = string
}

variable "snapshot_platform_blue" {
  description = "The name of the ClickHouse snapshot to use in the platform blue node"
  type        = string
}

variable "snapshot_platform_green" {
  description = "The name of the ClickHouse snapshot to use in the platform green node"
  type        = string
}

variable "snapshot_ppp_blue" {
  description = "The name of the ClickHouse snapshot to use in the ppp blue node"
  type        = string
}

variable "snapshot_ppp_green" {
  description = "The name of the ClickHouse snapshot to use in the ppp green node"
  type        = string
}

variable "dns_zone" {
  description = "The name of the managed DNS zone to expose ClickHouse"
  type        = string
}

variable "labels" {
  description = "The specific labels for the ClickHouse module"
  type        = map(string)
}
