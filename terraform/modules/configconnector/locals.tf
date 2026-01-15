locals {
  config_connector_operator_components_str = split("---", file("${path.module}/configconnector-operator.yaml"))
  config_connector_operator_manifests = [
    for component_str in local.config_connector_operator_components_str : yamldecode(component_str)
  ]
}
