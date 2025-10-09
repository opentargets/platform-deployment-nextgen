output "opensearch_ip" {
  description = "The internal IP address of the OpenSearch instance"
  value       = google_compute_instance.opensearch_node.network_interface[0].network_ip
}

output "clickhouse_ip" {
  description = "The internal IP address of the ClickHouse instance"
  value       = google_compute_instance.clickhouse_node.network_interface[0].network_ip
}

output "clickhouse_hmac_access_id" {
  description = "The ClickHouse HMAC access ID"
  value       = google_storage_hmac_key.clickhouse.access_id
  sensitive   = true
}

output "clickhouse_hmac_secret" {
  description = "The ClickHouse HMAC secret"
  value       = google_storage_hmac_key.clickhouse.secret
  sensitive   = true
}
