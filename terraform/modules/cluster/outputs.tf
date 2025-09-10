output "aiapi_service_account_emails" {
  description = "The emails for the cluster ai api service accounts"
  value       = [for sa in google_service_account.aiapi : sa.email]
}

# The id of the cluster, in the form projects/?/locations/?/clusters/?
# The private DNS zone needs it to allow the cluster to resolve names. The
# services inside the cluster use the private DNS zone to resolve the databases.
output "id" {
  description = "The id of the cluster"
  value       = google_container_cluster.cluster.id
}
