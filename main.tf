# ------------------------------------------------------------------------------
# SERVICE ACCOUNT FOR GKE NODES
# ------------------------------------------------------------------------------

resource "google_service_account" "gke_nodes" {
  project      = var.project_id
  account_id   = var.gke_node_service_account_name
  display_name = "GKE Node Service Account"
}

resource "google_project_iam_member" "gke_nodes_logging" {
  project = var.project_id
  role    = "roles/logging.logWriter"
  member  = "serviceAccount:${google_service_account.gke_nodes.email}"
}

resource "google_project_iam_member" "gke_nodes_monitoring" {
  project = var.project_id
  role    = "roles/monitoring.metricWriter"
  member  = "serviceAccount:${google_service_account.gke_nodes.email}"
}

resource "google_project_iam_member" "gke_nodes_viewer" {
  project = var.project_id
  role    = "roles/monitoring.viewer"
  member  = "serviceAccount:${google_service_account.gke_nodes.email}"
}

resource "google_project_iam_member" "gke_nodes_storage_viewer" {
  project = var.project_id
  role    = "roles/storage.objectViewer"
  member  = "serviceAccount:${google_service_account.gke_nodes.email}"
}

# ------------------------------------------------------------------------------
# VPC NETWORK & SUBNET
# ------------------------------------------------------------------------------

resource "google_compute_network" "main" {
  project                 = var.project_id
  name                    = var.network_name
  auto_create_subnetworks = false
  mtu                     = 1460
}

resource "google_compute_subnetwork" "main" {
  project                  = var.project_id
  name                     = var.subnet_name
  ip_cidr_range            = var.subnet_cidr
  region                   = var.region
  network                  = google_compute_network.main.id
  private_ip_google_access = true

  secondary_ip_range {
    range_name    = "pods-range"
    ip_cidr_range = var.pods_cidr_range
  }

  secondary_ip_range {
    range_name    = "services-range"
    ip_cidr_range = var.services_cidr_range
  }
}

# ------------------------------------------------------------------------------
# STEP 1 (Part 1): GKE CLUSTER
# ------------------------------------------------------------------------------

resource "google_container_cluster" "protecto" {
  project  = var.project_id
  name     = var.gke_cluster_name
  location = var.region

  network    = google_compute_network.main.id
  subnetwork = google_compute_subnetwork.main.id
  networking_mode = "VPC_NATIVE"
  datapath_provider = "ADVANCED_DATAPATH"

  ip_allocation_policy {
    cluster_secondary_range_name  = google_compute_subnetwork.main.secondary_ip_range[0].range_name
    services_secondary_range_name = google_compute_subnetwork.main.secondary_ip_range[1].range_name
  }

  # --- Security: Private Cluster Configuration ---
  private_cluster_config {
    enable_private_nodes    = true
    enable_private_endpoint = false
    master_ipv4_cidr_block  = var.master_ipv4_cidr_block
  }

  # --- Security: Master Authorized Networks ---
  master_authorized_networks_config {
    dynamic "cidr_blocks" {
      for_each = var.control_plane_cidrs
      content {
        cidr_block   = cidr_blocks.value.cidr_block
        display_name = cidr_blocks.value.display_name
      }
    }
  }

  # --- Security: Workload Identity & Service Account ---
  workload_identity_config {
    workload_pool = "${var.project_id}.svc.id.goog"
  }

  # Fix for Free Trial Quota: Force small HDD default pool
  node_config {
    service_account = google_service_account.gke_nodes.email
    oauth_scopes = [
      "https://www.googleapis.com/auth/cloud-platform"
    ]
    disk_type    = "pd-standard"
    disk_size_gb = 30
  }

  remove_default_node_pool = true
  initial_node_count       = 1

  logging_service    = "logging.googleapis.com/kubernetes"
  monitoring_service = "monitoring.googleapis.com/kubernetes"

  release_channel {
    channel = "REGULAR"
  }
}

# ------------------------------------------------------------------------------
# STEP 1 (Part 2): GKE NODE GROUPS
# ------------------------------------------------------------------------------

resource "google_container_node_pool" "pools" {
  for_each = var.node_pools

  project  = var.project_id
  name     = each.key
  location = var.region
  cluster  = google_container_cluster.protecto.id
  node_locations = each.value.node_locations
  initial_node_count = each.value.min_count

  autoscaling {
    min_node_count = each.value.min_count
    max_node_count = each.value.max_count
  }

  node_config {
    machine_type = each.value.machine_type
    disk_type    = each.value.disk_type
    disk_size_gb = each.value.disk_size_gb
    labels       = each.value.labels

    dynamic "taint" {
      for_each = each.value.taints
      content {
        key    = taint.value.key
        value  = taint.value.value
        effect = taint.value.effect
      }
    }

    service_account = google_service_account.gke_nodes.email
    oauth_scopes = [
      "https://www.googleapis.com/auth/cloud-platform"
    ]

    dynamic "guest_accelerator" {
      for_each = (each.value.gpu_type != null && each.value.gpu_count > 0) ? [1] : []
      content {
        type  = each.value.gpu_type
        count = each.value.gpu_count
      }
    }

    workload_metadata_config {
      mode = (each.value.gpu_type != null) ? "GKE_METADATA" : "GCE_METADATA"
    }
  }

  management {
    auto_repair  = true
    auto_upgrade = true
  }
}

# ------------------------------------------------------------------------------
# AUTOMATION OF CLIENT DEPLOYMENT - STEP 2 (TiDB Operator & Cluster)
# ------------------------------------------------------------------------------

# Create the TiDB Namespaces
resource "kubernetes_namespace" "tidb_admin" {
  metadata { name = "tidb-admin" }
  depends_on = [google_container_cluster.protecto]
}

resource "kubernetes_namespace" "tidb_cluster" {
  metadata { name = "tidb-cluster" }
  depends_on = [google_container_cluster.protecto]
}

# Install the TiDB Operator Helm chart
resource "helm_release" "tidb_operator" {
  name       = "tidb-operator"
  repository = "https://charts.pingcap.org/"
  chart      = "tidb-operator"
  namespace  = kubernetes_namespace.tidb_admin.metadata[0].name
  version    = "v1.6.0"
  depends_on = [google_container_node_pool.pools]
}

# ------------------------------------------------------------------------------
# DEPLOY TiDB CRDs AND CLUSTER YAML (Self-contained, No gcloud needed)
# ------------------------------------------------------------------------------

resource "null_resource" "apply_k8s_yamls" {
  triggers = {
    cluster_endpoint = google_container_cluster.protecto.endpoint
  }

  provisioner "local-exec" {
    # We pass Terraform variables into the shell command to avoid "gcloud not found"
    command = <<EOT
      set -e
      echo "--- Setting up kubectl environment ---"
      
      # 1. Download kubectl (Since it's missing in the runner image)
      curl -LO "https://dl.k8s.io/release/v1.29.0/bin/linux/amd64/kubectl"
      chmod +x ./kubectl

      # 2. Create Auth Config manually (No gcloud needed)
      echo "${base64decode(google_container_cluster.protecto.master_auth[0].cluster_ca_certificate)}" > ca.crt
      
      ./kubectl config set-cluster gke-cluster \
        --server=https://${google_container_cluster.protecto.endpoint} \
        --certificate-authority=ca.crt \
        --embed-certs=true

      ./kubectl config set-credentials deployer \
        --token="${data.google_client_config.default.access_token}"

      ./kubectl config set-context gke-deploy \
        --cluster=gke-cluster \
        --user=deployer

      ./kubectl config use-context gke-deploy

      # 3. Apply TiDB CRDs
      echo "--- Applying TiDB CRDs ---"
      ./kubectl create -f https://raw.githubusercontent.com/pingcap/tidb-operator/v1.5.2/manifests/crd.yaml || echo "CRDs might already exist"

      echo "Waiting for CRDs to establish..."
      sleep 15

      # 4. Apply the TiDB Cluster YAML
      echo "--- Applying TiDB Cluster YAML ---"
      ./kubectl apply -f ${path.module}/tidb-yamls/tidb-cluster.yaml -n tidb-cluster
      
      echo "--- Deployment Submitted Successfully ---"
    EOT
  }

  depends_on = [
    helm_release.tidb_operator
  ]
}
