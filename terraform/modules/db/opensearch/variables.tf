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

# OPENSEARCH VARIABLES
variable "machine_type" {
  description = "The machine type to use for the OpenSearch node"
  type        = string
}

variable "disk_size_gb" {
  description = "The size of the OpenSearch data disk in GB"
  type        = number
}

variable "opensearch_version" {
  description = "The OpenSearch version to deploy"
  type        = string
}

variable "dns_zone_name" {
  description = "The name of the managed DNS zone to expose ClickHouse"
  type        = string
}

variable "labels" {
  description = "The specific labels for the OpenSearch module"
  type        = map(string)
}
