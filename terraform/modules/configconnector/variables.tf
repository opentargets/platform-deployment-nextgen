variable "project_id" {
  description = "The GCP project ID where the Config Connector will be deployed."
  type        = string
}

variable "global_prefix" {
  description = "A global prefix for resource names."
  type        = string
}

variable "cluster_id" {
  description = "The id of the GKE cluster where Config Connector will be installed."
  type        = string
}
