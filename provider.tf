terraform {
  required_version = ">= 1.4.0"

  required_providers {
    google = {
      source  = "hashicorp/google"
      version = "~> 5.0"
    }
    helm = {
      source  = "hashicorp/helm"
      version = "~> 2.10"
    }
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = "~> 2.20"
    }
    http = {
      source  = "hashicorp/http"
      version = "~> 3.0"
    }
  }
}

# 1. Configure the Google Cloud provider
provider "google" {
  project = var.project_id
  region  = var.region
}

# 2. Get cluster data to configure the Kubernetes & Helm providers
# This allows Terraform to connect to the GKE cluster it just created.

data "google_client_config" "default" {}

data "google_container_cluster" "protecto_data" {
  # This dynamically gets the cluster info created in main.tf
  # We use a "data" source to avoid a circular dependency
  project  = var.project_id
  name     = google_container_cluster.protecto.name
  location = var.region

  # This explicit dependency ensures the cluster is
  # fully created *before* these providers try to connect.
  depends_on = [
    google_container_cluster.protecto
  ]
}

# 3. Configure the Helm provider (FIXED SYNTAX)
# The "kubernetes" block is removed, and attributes are top-level.
provider "helm" {
  host                   = "https://${data.google_container_cluster.protecto_data.endpoint}"
  token                  = data.google_client_config.default.access_token
  cluster_ca_certificate = base64decode(data.google_container_cluster.protecto_data.master_auth[0].cluster_ca_certificate)
}

# 4. Configure the Kubernetes provider (FIXED SYNTAX)
# The "kubernetes" block is removed, and attributes are top-level.
provider "kubernetes" {
  host                   = "https://${data.google_container_cluster.protecto_data.endpoint}"
  token                  = data.google_client_config.default.access_token
  cluster_ca_certificate = base64decode(data.google_container_cluster.protecto_data.master_auth[0].cluster_ca_certificate)
}
