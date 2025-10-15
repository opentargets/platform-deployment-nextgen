# Output to expose the internal DNS name and IP of the ClickHouse node.

output "internal_name" {
  description = "The internal DNS name of the ClickHouse node."
  value       = google_dns_record_set.internal.name
}

output "internal_ip" {
  description = "The internal IP address of the ClickHouse node."
  value       = google_compute_instance.node.network_interface.0.network_ip
}
