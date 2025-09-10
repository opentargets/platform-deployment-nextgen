# CLUSTER OUTPUTS
output "cluster_aiapi_service_account_emails" {
  description = "The emails for the cluster ai api service accounts"
  value       = module.cluster.aiapi_service_account_emails
}

# CLICKHOUSE OUTPUTS
output "db_clickhouse_platform_blue_internal_name" {
  description = "The internal DNS name of the ClickHouse platform blue node"
  value       = module.db_clickhouse.platform_blue_internal_name
}

output "db_clickhouse_platform_green_internal_name" {
  description = "The internal DNS name of the ClickHouse platform green node"
  value       = module.db_clickhouse.platform_green_internal_name
}

output "db_clickhouse_ppp_blue_internal_name" {
  description = "The internal DNS name of the ClickHouse ppp blue node"
  value       = module.db_clickhouse.ppp_blue_internal_name
}

output "db_clickhouse_ppp_green_internal_name" {
  description = "The internal DNS name of the ClickHouse ppp green node"
  value       = module.db_clickhouse.ppp_green_internal_name
}

# OPENSEARCH OUTPUTS
output "db_opensearch_platform_blue_internal_name" {
  description = "The internal DNS name of the OpenSearch platform blue node"
  value       = module.db_opensearch.platform_blue_internal_name
}

output "db_opensearch_platform_green_internal_name" {
  description = "The internal DNS name of the OpenSearch platform green node"
  value       = module.db_opensearch.platform_green_internal_name
}

output "db_opensearch_ppp_blue_internal_name" {
  description = "The internal DNS name of the OpenSearch ppp blue node"
  value       = module.db_opensearch.ppp_blue_internal_name
}

output "db_opensearch_ppp_green_internal_name" {
  description = "The internal DNS name of the OpenSearch ppp green node"
  value       = module.db_opensearch.ppp_green_internal_name
}
