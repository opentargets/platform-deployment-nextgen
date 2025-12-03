# CLUSTER OUTPUTS
output "cluster_aiapi_service_account_emails" {
  description = "The emails for the cluster ai api service accounts"
  value       = module.cluster.aiapi_service_account_emails
}

output "observability_config" {
  description = "Configuration values for observability deployment"
  value = {
    cluster_name                       = module.cluster.name
    cluster_node_service_account_email = module.cluster.node_service_account_email
    gcp_project_id                     = var.project_id
    gcp_zone                           = var.zone
    cluster_full_name                  = "gke_${var.project_id}_${var.zone}_${var.global_prefix}"
    loki_bucket_chunks                 = "${var.global_prefix}-loki-gcp-chunks"
    loki_bucket_ruler                  = "${var.global_prefix}-loki-gcp-ruler"
  }
}

# CLICKHOUSE OUTPUTS
output "db_clickhouse_internal_name" {
  description = "The internal DNS name of the ClickHouse node."
  value       = module.clickhouse.internal_name
}

output "db_clickhouse_internal_ip" {
  description = "The internal IP address of the ClickHouse node."
  value       = module.clickhouse.internal_ip
}

# OPENSEARCH OUTPUTS
output "db_opensearch_internal_name" {
  description = "The internal DNS name of the OpenSearch node."
  value       = module.opensearch.internal_name
}

output "db_opensearch_internal_ip" {
  description = "The internal IP address of the OpenSearch node."
  value       = module.opensearch.internal_ip
}
