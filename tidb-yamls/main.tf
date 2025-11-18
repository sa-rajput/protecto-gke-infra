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
  # Add roles/artifactregistry.reader if using Artifact Registry
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
  private_ip_google_access = true # CRITICAL for private nodes to pull images

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
  location = var.region # Regional control plane for High Availability

  # --- Networking ---
  network    = google_compute_network.main.id
  subnetwork = google_compute_subnetwork.main.id
  networking_mode = "VPC_NATIVE"
  datapath_provider = "ADVANCED_DATAPATH" # Enables GKE Dataplane V2 (Cilium)

  ip_allocation_policy {
    cluster_secondary_range_name  = google_compute_subnetwork.main.secondary_ip_range[0].range_name
    services_secondary_range_name = google_compute_subnetwork.main.secondary_ip_range[1].range_name
  }

  # --- Security: Private Cluster Configuration ---
  private_cluster_config {
    enable_private_nodes    = true  # Nodes have no public IPs
    enable_private_endpoint = false # No internal master endpoint
    enable_public_endpoint  = true  # Master API is public, but...
    master_ipv4_cidr_block  = var.master_ipv4_cidr_block
  }

  # ...locked down by Master Authorized Networks.
  # This configuration replaces the need for a jump server.
  master_authorized_networks_config {
    # FIXED: Use dynamic block to create a cidr_block for each item.
    dynamic "cidr_block" {
      for_each = var.control_plane_cidrs
      content {
        cidr_block   = cidr_block.value.cidr_block
        display_name = cidr_block.value.display_name
      }
    }
  }

  # --- Security: Workload Identity & Service Account ---
  workload_identity_config {
    workload_pool = "${var.project_id}.svc.id.goog"
  }

  node_config {
    # This SA is used by the nodes themselves
    service_account = google_service_account.gke_nodes.email
    oauth_scopes = [
      "https://www.googleapis.com/auth/cloud-platform"
    ]
  }

  # --- Features & Management ---
  remove_default_node_pool = true
  initial_node_count       = 1 # Required, but we remove it immediately.

  logging_service    = "logging.googleapis.com/kubernetes"
  monitoring_service = "monitoring.googleapis.com/kubernetes"

  release_channel {
    channel = "REGULAR"
  }
}

# ------------------------------------------------------------------------------
# STEP 1 (Part 2): GKE NODE GROUPS
# This single resource creates all 6 node pools from your variable map.
# ------------------------------------------------------------------------------

resource "google_container_node_pool" "pools" {
  # Create one node pool for each item in the var.node_pools map
  for_each = var.node_pools

  project  = var.project_id
  name     = each.key # Uses map keys: "admin", "tidb", "gpunode", etc.
  location = var.region
  cluster  = google_container_cluster.protecto.id

  # Defines the zones this regional pool will span
  node_locations = each.value.node_locations

  # --- Autoscaling & Sizing ---
  initial_node_count = each.value.min_count

  autoscaling {
    min_node_count = each.value.min_count
    max_node_count = each.value.max_count
  }

  # --- VM Configuration ---
  node_config {
    machine_type = each.value.machine_type
    disk_type    = each.value.disk_type
    disk_size_gb = each.value.disk_size_gb
    labels       = each.value.labels

    # FIXED: Use dynamic block to create a taint for each item in the list.
    dynamic "taint" {
      for_each = each.value.taints
      content {
        key    = taint.value.key
        value  = taint.value.value
        effect = taint.value.effect
      }
    }

    # Use the dedicated service account
    service_account = google_service_account.gke_nodes.email
    oauth_scopes = [
      "https://www.googleapis.com/auth/cloud-platform"
    ]

    # --- Dynamic GPU Configuration ---
    # This block only adds a GPU if gpu_type is set in the .tfvars file
    dynamic "guest_accelerator" {
      for_each = (each.value.gpu_type != null && each.value.gpu_count > 0) ? [1] : []
      content {
        type  = each.value.gpu_type
        count = each.value.gpu_count
      }
    }

    # Required for GPUs to disable GKE Sandbox
    # This ternary checks if a GPU is present
    workload_metadata_config {
      mode = (each.value.gpu_type != null) ? "GKE_METADATA" : "GCE_METADATA"
    }
  }

  # --- Management ---
  management {
    auto_repair  = true
    auto_upgrade = true
  }
}

# ------------------------------------------------------------------------------
# AUTOMATION OF CLIENT DEPLOYMENT - STEP 2 (TiDB Operator & Cluster)
# (Contents formerly in k8s-tidb.tf)
# ------------------------------------------------------------------------------

# Create the TiDB Admin Namespace (from client docs)
resource "kubernetes_namespace" "tidb_admin" {
  metadata {
    name = "tidb-admin"
  }
}

# Create the TiDB Cluster Namespace (from client docs)
resource "kubernetes_namespace" "tidb_cluster" {
  metadata {
    name = "tidb-cluster"
  }
}

# Apply the TiDB CRD (from client docs)
# This replaces `kubectl create -f https://.../crd.yaml`
resource "kubernetes_manifest" "tidb_crd" {
  manifest = yamldecode(data.http.tidb_crd.response_body)

  # Wait for namespaces to be created first
  depends_on = [
    kubernetes_namespace.tidb_admin,
    kubernetes_namespace.tidb_cluster
  ]
}

# HTTP data source to fetch the CRD YAML
data "http" "tidb_crd" {
  url = "https://raw.githubusercontent.com/pingcap/tidb-operator/v1.5.2/manifests/crd.yaml"
}

# Add the Pingcap Helm repository (from client docs)
# This replaces `helm repo add pingcap ...`
resource "helm_repository" "pingcap" {
  name = "pingcap"
  url  = "https://charts.pingcap.org/"

  # Wait for CRD to be applied
  depends_on = [kubernetes_manifest.tidb_crd]
}

# Install the TiDB Operator Helm chart (from client docs)
# This replaces `helm install ... tidb-operator`
resource "helm_release" "tidb_operator" {
  name       = "tidb-operator"
  repository = helm_repository.pingcap.name
  chart      = "tidb-operator"
  namespace  = kubernetes_namespace.tidb_admin.metadata[0].name
  version    = "v1.6.0" # Version from client docs

  # This ensures the repo is added before Helm tries to install
  depends_on = [helm_repository.pingcap]
}

# ------------------------------------------------------------------------------
# Deploy the TiDB Cluster (from tidb-yamls/tidb-cluster.yaml)
# This replaces `kubectl apply -f tidb-yamls/tidb-cluster.yaml`
# ------------------------------------------------------------------------------
resource "kubernetes_manifest" "tidb_cluster" {
  # Read the YAML file from your local directory
  # Note: This requires you to have a `tidb-yamls/tidb-cluster.yaml` file
  # in the same directory you run `terraform apply` from.
  manifest = yamldecode(file("${path.module}/tidb-yamls/tidb-cluster.yaml"))

  # This is CRITICAL. It waits until the TiDB Operator is
  # fully installed and its CRDs are registered before
  # attempting to create a TiDBCluster custom resource.
  depends_on = [
    helm_release.tidb_operator
  ]
}
