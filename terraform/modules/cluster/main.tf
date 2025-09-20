data "google_client_config" "default" {}

provider "kubernetes" {
  host                   = "https://${google_container_cluster.cluster.endpoint}"
  token                  = data.google_client_config.default.access_token
  cluster_ca_certificate = base64decode(google_container_cluster.cluster.master_auth[0].cluster_ca_certificate)
}

resource "google_container_cluster" "cluster" {
  name                     = var.global_prefix
  project                  = var.project_id
  location                 = var.zone
  network                  = var.network
  subnetwork               = google_compute_subnetwork.cluster.name
  remove_default_node_pool = true
  initial_node_count       = var.min_node_count

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
      recurrence = "FREQ=DAILY"
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
}

locals {
  node_pools = {
    production = {
      name         = "${var.global_prefix}-production"
      machine_type = var.machine_type_production
      labels = {
        pool = "production"
      }
    }
    staging = {
      name         = "${var.global_prefix}-staging"
      machine_type = var.machine_type_staging
      labels = {
        pool = "staging"
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
  initial_node_count = var.min_node_count

  autoscaling {
    min_node_count = var.min_node_count
    max_node_count = var.max_node_count
  }

  node_config {
    machine_type    = each.value.machine_type
    disk_size_gb    = var.disk_size_gb
    disk_type       = "pd-ssd"
    image_type      = "COS_CONTAINERD"
    service_account = google_service_account.node.email
    labels          = merge(var.base_labels, var.labels, each.value.labels)
    tags            = ["cluster", "node"]
    oauth_scopes    = ["https://www.googleapis.com/auth/cloud-platform"]

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
    google_container_cluster.cluster,
    google_container_node_pool.pools,
    google_service_account.config_connector,
    google_project_iam_member.config_connector_roles,
    google_service_account_iam_member.config_connector_workload_identity,
  ]
}
