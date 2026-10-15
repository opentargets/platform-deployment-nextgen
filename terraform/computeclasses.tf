# DATA STORE COMPUTE CLASSES
# A node pool has one machine type, so a zonal stockout of that type stops it scaling.
# Each data store therefore gets extra node pools, one per fallback machine type, which
# start empty, plus a GKE ComputeClass that tells the autoscaler which pool to try first.
#
# - Priority order: the main pool (main.tf), then each fallback pool in the order listed in
#   `*_fallback_machine_types`. Fallbacks should match the main pool's shape and must
#   attach hyperdisk-balanced volumes (the data PVCs and boot disks).
# - Every pool is a Terraform pool with the same settings, so the class auto-creates
#   nothing, and has nothing to fall back to beyond the list (DoNotScaleUp).
# - No active migration: moving a replica back to a preferred machine type means evicting
#   it and re-attaching its disk.
# Pods opt in with `gcp.computeClasses: true` in their Helm profile.
locals {
  data_stores = {
    clickhouse = {
      main_pool = google_container_node_pool.databases_clickhouse.name
      fallbacks = var.clickhouse_fallback_machine_types
      max_nodes = var.clickhouse_max_node_count * 2 # Holds staging and prod dbs.
      sysctls   = {}
    }
    opensearch = {
      main_pool = google_container_node_pool.pools_opensearch.name
      fallbacks = var.opensearch_fallback_machine_types
      max_nodes = var.opensearch_max_node_count * 2 # Holds staging and prod dbs.
      sysctls   = { "vm.max_map_count" = "262144" }
    }
  }

  data_store_fallback_pools = merge([
    for store, cfg in local.data_stores : {
      for machine_type in cfg.fallbacks : "${store}-${machine_type}" => {
        store        = store
        machine_type = machine_type
        max_nodes    = cfg.max_nodes
        sysctls      = cfg.sysctls
      }
    }
  ]...)
}

resource "google_container_node_pool" "data_store_fallbacks" {
  for_each = local.data_store_fallback_pools

  name               = "${var.global_prefix}-${each.key}"
  project            = var.project_id
  location           = var.zone
  cluster            = google_container_cluster.cluster.name
  initial_node_count = 0

  autoscaling {
    min_node_count = 0
    max_node_count = each.value.max_nodes
  }

  node_config {
    machine_type    = each.value.machine_type
    disk_type       = var.cluster_disk_type
    disk_size_gb    = 30 # This is the boot disk. Data is on a PV.
    image_type      = "COS_CONTAINERD"
    service_account = google_service_account.node.email
    labels          = merge(var.base_labels, var.cluster_labels, { pool = each.value.store, "cloud.google.com/compute-class" = each.value.store })
    tags            = ["cluster", "node", each.value.store]
    oauth_scopes    = ["https://www.googleapis.com/auth/cloud-platform"]

    boot_disk {
      provisioned_iops       = strcontains(var.cluster_disk_type, "hyperdisk-") ? var.cluster_disk_iops : null
      provisioned_throughput = strcontains(var.cluster_disk_type, "hyperdisk-") ? var.cluster_disk_throughput : null
    }

    taint {
      key    = "workload"
      value  = each.value.store
      effect = "NO_SCHEDULE"
    }

    taint {
      key    = "cloud.google.com/compute-class"
      value  = each.value.store
      effect = "NO_SCHEDULE"
    }

    shielded_instance_config {
      enable_secure_boot          = true
      enable_integrity_monitoring = true
    }

    workload_metadata_config {
      mode = "GKE_METADATA"
    }

    dynamic "linux_node_config" {
      for_each = length(each.value.sysctls) > 0 ? [each.value.sysctls] : []
      content {
        sysctls = linux_node_config.value
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

locals {
  compute_classes = {
    for store, cfg in local.data_stores : store => {
      apiVersion = "cloud.google.com/v1"
      kind       = "ComputeClass"
      metadata   = { name = store }
      spec = {
        priorities = concat(
          [{ nodepools = [cfg.main_pool] }],
          [for machine_type in cfg.fallbacks : { nodepools = [google_container_node_pool.data_store_fallbacks["${store}-${machine_type}"].name] }]
        )
        activeMigration      = { optimizeRulePriority = false }
        whenUnsatisfiable    = "DoNotScaleUp"
        nodePoolAutoCreation = { enabled = false }
      }
    }
  }
}

resource "null_resource" "compute_classes" {
  for_each = local.compute_classes

  triggers = {
    cluster_id = google_container_cluster.cluster.id
    manifest   = yamlencode(each.value)
  }

  # The heredoc's indent is stripped before interpolation, so the YAML stays at column 0.
  provisioner "local-exec" {
    command = <<-EOT
      gcloud container clusters get-credentials ${google_container_cluster.cluster.name} \
        --zone ${var.zone} \
        --project ${var.project_id} && \
      kubectl apply -f - <<EOF
      ${yamlencode(each.value)}
      EOF
    EOT
  }
}
