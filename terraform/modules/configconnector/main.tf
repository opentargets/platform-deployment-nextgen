# Config Connector Operator setup.
# We use the operator to install Config Connector into the cluster.
resource "kubernetes_manifest" "config_connector_operator" {
  count    = length(local.config_connector_operator_manifests)
  manifest = local.config_connector_operator_manifests[count.index]

  depends_on = [
    var.cluster_id,
  ]
}

# Config Connector setup.
# We use it from inside the cluster to create DNS records and global IPs.
resource "kubernetes_manifest" "config_connector" {
  manifest = {
    apiVersion = "core.cnrm.cloud.google.com/v1beta1"
    kind       = "ConfigConnector"
    metadata = {
      name = "configconnector.core.cnrm.cloud.google.com"
    }
    spec = {
      mode                 = "cluster"
      googleServiceAccount = "${google_service_account.config_connector.email}"
      stateIntoSpec        = "Absent"
    }
  }

  depends_on = [
    kubernetes_manifest.config_connector_operator
  ]
}
