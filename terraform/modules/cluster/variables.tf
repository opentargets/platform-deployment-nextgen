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


# CLUSTER VARIABLES
variable "min_node_count" {
  description = "The minimum (and initial) number of nodes in the cluster"
  type        = number
}

variable "max_node_count" {
  description = "The maximum number of nodes in the cluster"
  type        = number
}

variable "machine_type_production" {
  description = "The machine type for GKE nodes in the production node pool"
  type        = string
}

variable "machine_type_staging" {
  description = "The machine type for GKE nodes in the staging node pool"
  type        = string
}

variable "disk_size_gb" {
  description = "The disk size in GB for each GKE node"
  type        = number
}

variable "kubernetes_version" {
  description = "The Kubernetes version for the GKE cluster"
  type        = string
}

variable "labels" {
  description = "The specific labels for the cluster module"
  type        = map(string)
}
