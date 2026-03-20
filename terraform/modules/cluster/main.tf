resource "google_container_cluster" "cluster" {
  name                     = var.global_prefix
  project                  = var.project_id
  location                 = var.zone
  network                  = var.network
  subnetwork               = google_compute_subnetwork.cluster.name
  remove_default_node_pool = true
  initial_node_count       = 1

  ip_allocation_policy {
    cluster_secondary_range_name  = "pods"
    services_secondary_range_name = "services"
  }

  secret_manager_config {
    enabled = true
  }

  private_cluster_config {
    enable_private_nodes    = true
    enable_private_endpoint = false
    master_ipv4_cidr_block  = "172.16.0.0/28"
  }

  network_policy {
    enabled = true
  }

  workload_identity_config {
    workload_pool = "${var.project_id}.svc.id.goog"
  }

  binary_authorization {
    evaluation_mode = "PROJECT_SINGLETON_POLICY_ENFORCE"
  }

  maintenance_policy {
    recurring_window {
      start_time = "2025-09-06T02:00:00Z"
      end_time   = "2025-09-06T06:00:00Z"
      recurrence = "FREQ=WEEKLY;BYDAY=MO,WE,FR"
    }
  }

  release_channel {
    channel = "REGULAR"
  }

  addons_config {
    network_policy_config {
      disabled = false
    }

    config_connector_config {
      enabled = true
    }
  }

  resource_labels = merge(var.base_labels, var.labels)

  lifecycle {
    ignore_changes = [
      initial_node_count, # We don't care about changes to this after creation.
    ]
  }
}

locals {
  node_pools = {
    production = {
      name   = "${var.global_prefix}-production"
      labels = { pool = "production" }
    }
    staging = {
      name        = "${var.global_prefix}-staging"
      labels      = { pool = "staging" }
      autoscaling = { min_node_count = 0 } # allow scale to 0 when staging is off
    }
  }
}

# MAIN NODE POOLS
resource "google_container_node_pool" "pools" {
  for_each = local.node_pools

  name               = each.value.name
  project            = var.project_id
  location           = var.zone
  cluster            = google_container_cluster.cluster.name
  initial_node_count = 1

  autoscaling {
    min_node_count = try(each.value.autoscaling.min_node_count, var.apps_min_node_count)
    max_node_count = var.apps_max_node_count
  }


  node_config {
    machine_type    = var.apps_machine_type
    disk_type       = var.disk_type
    disk_size_gb    = var.apps_disk_size_gb
    image_type      = "COS_CONTAINERD"
    service_account = google_service_account.node.email
    labels          = merge(var.base_labels, var.labels, each.value.labels)
    tags            = ["cluster", "node"]
    oauth_scopes    = ["https://www.googleapis.com/auth/cloud-platform"]

    boot_disk {
      provisioned_iops       = strcontains(var.disk_type, "hyperdisk-") ? var.disk_iops : null
      provisioned_throughput = strcontains(var.disk_type, "hyperdisk-") ? var.disk_throughput : null
    }

    shielded_instance_config {
      enable_secure_boot          = true
      enable_integrity_monitoring = true
    }

    workload_metadata_config {
      mode = "GKE_METADATA"
    }

    metadata = {
      disable-legacy-endpoints = "true"
    }
  }

  upgrade_settings {
    strategy        = "SURGE"
    max_surge       = 1
    max_unavailable = 0
  }

  lifecycle {
    ignore_changes = [
      initial_node_count, # We don't care about changes to this after creation.
    ]
  }
}

# CLICKHOUSE NODE POOL
resource "google_container_node_pool" "databases_clickhouse" {
  name               = "${var.global_prefix}-clickhouse"
  project            = var.project_id
  location           = var.zone
  cluster            = google_container_cluster.cluster.name
  initial_node_count = 1

  autoscaling {
    min_node_count = var.clickhouse_min_node_count
    max_node_count = var.clickhouse_max_node_count * 2 # Because it holds staging and prod dbs.
  }

  node_config {
    machine_type    = var.clickhouse_machine_type
    disk_type       = var.disk_type
    disk_size_gb    = 30 # This is the boot disk. Data is on a PV.
    image_type      = "COS_CONTAINERD"
    service_account = google_service_account.node.email
    labels          = merge(var.base_labels, var.labels, { pool = "clickhouse" })
    tags            = ["cluster", "node", "clickhouse"]
    oauth_scopes    = ["https://www.googleapis.com/auth/cloud-platform"]

    boot_disk {
      provisioned_iops       = strcontains(var.disk_type, "hyperdisk-") ? var.disk_iops : null
      provisioned_throughput = strcontains(var.disk_type, "hyperdisk-") ? var.disk_throughput : null
    }

    taint {
      key    = "workload"
      value  = "clickhouse"
      effect = "NO_SCHEDULE"
    }

    shielded_instance_config {
      enable_secure_boot          = true
      enable_integrity_monitoring = true
    }

    workload_metadata_config {
      mode = "GKE_METADATA"
    }

    metadata = {
      disable-legacy-endpoints = "true"
    }
  }

  upgrade_settings {
    strategy        = "SURGE"
    max_surge       = 1
    max_unavailable = 0
  }

  lifecycle {
    ignore_changes = [
      initial_node_count,
    ]
  }
}

# Config Connector setup.
# The GKE addon auto-creates a ConfigConnector CR in namespaced mode.
# We use kubectl apply to reconfigure it to cluster mode.
# See:
# https://docs.cloud.google.com/config-connector/docs/how-to/install-upgrade-uninstall
resource "null_resource" "config_connector" {
  triggers = {
    cluster_id            = google_container_cluster.cluster.id
    service_account_email = google_service_account.config_connector.email
  }

  provisioner "local-exec" {
    command = <<-EOT
      gcloud container clusters get-credentials ${google_container_cluster.cluster.name} \
        --zone ${var.zone} \
        --project ${var.project_id} && \
      kubectl apply -f - <<EOF
      apiVersion: core.cnrm.cloud.google.com/v1beta1
      kind: ConfigConnector
      metadata:
        name: configconnector.core.cnrm.cloud.google.com
      spec:
        mode: cluster
        googleServiceAccount: "${google_service_account.config_connector.email}"
        stateIntoSpec: Absent
      EOF
    EOT
  }

  depends_on = [
    google_container_cluster.cluster,
    google_container_node_pool.pools,
    google_service_account.config_connector,
    google_project_iam_member.config_connector_roles,
    google_service_account_iam_member.config_connector_workload_identity,
  ]
}

# OPENSEARCH NODE POOL
resource "google_container_node_pool" "pools_opensearch" {
  name               = "${var.global_prefix}-opensearch"
  project            = var.project_id
  location           = var.zone
  cluster            = google_container_cluster.cluster.name
  initial_node_count = 1

  autoscaling {
    min_node_count = var.opensearch_min_node_count
    max_node_count = var.opensearch_max_node_count * 2 # Because it holds staging and prod dbs.
  }

  node_config {
    machine_type    = var.opensearch_machine_type
    disk_type       = var.disk_type
    disk_size_gb    = 30 # This is the boot disk. Data is on a PV.
    image_type      = "COS_CONTAINERD"
    service_account = google_service_account.node.email
    labels          = merge(var.base_labels, var.labels, { pool = "opensearch" })
    tags            = ["cluster", "node", "opensearch"]
    oauth_scopes    = ["https://www.googleapis.com/auth/cloud-platform"]

    boot_disk {
      provisioned_iops       = strcontains(var.disk_type, "hyperdisk-") ? var.disk_iops : null
      provisioned_throughput = strcontains(var.disk_type, "hyperdisk-") ? var.disk_throughput : null
    }

    taint {
      key    = "workload"
      value  = "opensearch"
      effect = "NO_SCHEDULE"
    }

    shielded_instance_config {
      enable_secure_boot          = true
      enable_integrity_monitoring = true
    }

    workload_metadata_config {
      mode = "GKE_METADATA"
    }

    linux_node_config {
      sysctls = {
        "vm.max_map_count" = "262144"
      }
    }

    metadata = {
      disable-legacy-endpoints = "true"
    }
  }

  upgrade_settings {
    strategy        = "SURGE"
    max_surge       = 1
    max_unavailable = 0
  }

  lifecycle {
    ignore_changes = [
      initial_node_count,
    ]
  }
}
