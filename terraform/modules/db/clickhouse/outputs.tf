# Outputs to expose the internal DNS names of the ClickHouse nodes. This is the
# only thing that interests us from this module.

output "platform_blue_internal_name" {
  description = "The internal DNS name of the ClickHouse platform blue node"
  value       = google_dns_record_set.internal["platform_blue"].name
}

output "platform_green_internal_name" {
  description = "The internal DNS name of the ClickHouse platform green node"
  value       = google_dns_record_set.internal["platform_green"].name
}

output "ppp_blue_internal_name" {
  description = "The internal DNS name of the ClickHouse ppp blue node"
  value       = google_dns_record_set.internal["ppp_blue"].name
}

output "ppp_green_internal_name" {
  description = "The internal DNS name of the ClickHouse ppp green node"
  value       = google_dns_record_set.internal["ppp_green"].name
}
