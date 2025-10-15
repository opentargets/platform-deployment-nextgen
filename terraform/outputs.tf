# CLUSTER OUTPUTS
output "cluster_aiapi_service_account_emails" {
  description = "The emails for the cluster ai api service accounts"
  value       = module.cluster.aiapi_service_account_emails
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
