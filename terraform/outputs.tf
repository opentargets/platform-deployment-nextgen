# CLUSTER OUTPUTS
output "observability_config" {
  description = "Configuration values for observability deployment"
  value = {
    cluster_name                       = google_container_cluster.cluster.name
    cluster_node_service_account_email = google_service_account.node.email
    gcp_project_id                     = var.project_id
    gcp_zone                           = var.zone
    cluster_full_name                  = "gke_${var.project_id}_${var.zone}_${var.global_prefix}"
    loki_bucket_chunks                 = "${var.global_prefix}-loki-gcp-chunks"
    loki_bucket_ruler                  = "${var.global_prefix}-loki-gcp-ruler"
  }
}
