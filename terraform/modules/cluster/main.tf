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
      name         = "${var.global_prefix}-production"
      machine_type = var.machine_type_production
      disk_type    = var.disk_type_production
      labels = {
        pool = "production"
      }
      autoscaling = {
        min_node_count = var.min_node_count
        max_node_count = var.max_node_count
      }
      boot_disk = {
        provisioned_iops       = var.disk_iops_production
        provisioned_throughput = var.disk_tput_production
      }
    }
    staging = {
      name         = "${var.global_prefix}-staging"
      machine_type = var.machine_type_staging
      disk_type    = var.disk_type_staging
      labels = {
        pool = "staging"
      }
      autoscaling = {
        min_node_count = 0
        max_node_count = var.max_node_count
      }
    }
  }
}

resource "google_container_node_pool" "pools" {
  for_each = local.node_pools

  name               = each.value.name
  project            = var.project_id
  location           = var.zone
  cluster            = google_container_cluster.cluster.name
  initial_node_count = 1

  autoscaling {
    min_node_count = each.value.autoscaling.min_node_count
    max_node_count = each.value.autoscaling.max_node_count
  }


  node_config {
    machine_type    = each.value.machine_type
    disk_size_gb    = var.disk_size_gb
    disk_type       = each.value.disk_type
    image_type      = "COS_CONTAINERD"
    service_account = google_service_account.node.email
    labels          = merge(var.base_labels, var.labels, each.value.labels)
    tags            = ["cluster", "node"]
    oauth_scopes    = ["https://www.googleapis.com/auth/cloud-platform"]

    boot_disk {
      provisioned_iops       = strcontains(each.value.disk_type, "hyperdisk-") ? each.value.boot_disk.provisioned_iops : null
      provisioned_throughput = strcontains(each.value.disk_type, "hyperdisk-") ? each.value.boot_disk.provisioned_throughput : null
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
