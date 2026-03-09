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
variable "kubernetes_version" {
  description = "The Kubernetes version for the GKE cluster"
  type        = string
}

variable "labels" {
  description = "The labels for the GKE cluster"
  type        = map(string)
}

variable "disk_iops" {
  description = "The provisioned IOPS for hyperdisks"
  type        = number
}

variable "disk_throughput" {
  description = "The provisioned throughput for hyperdisks in MB/s "
  type        = number
}


# APPS VARIABLES
variable "apps_min_node_count" {
  description = "The minimum (and initial) number of nodes in the apps node pool"
  type        = number
}

variable "apps_max_node_count" {
  description = "The maximum number of nodes in the apps node pool"
  type        = number
}

variable "apps_machine_type" {
  description = "The machine type for nodes in the apps node pool"
  type        = string
}

variable "apps_disk_size_gb" {
  description = "The disk size in GB for each node in the apps node pool"
  type        = number
}

variable "apps_disk_type" {
  description = "The disk type for nodes in the apps node pool"
  type        = string
}

variable "apps_labels" {
  description = "The labels for the apps node pool"
  type        = map(string)
}
