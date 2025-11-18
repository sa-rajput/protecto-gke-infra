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

# 2. Client config for auth token
data "google_client_config" "default" {}

# REMOVED: data "google_container_cluster" "protecto_data"
# We must not use a data source for a cluster we are creating in the same apply.
# Instead, we reference the resource directly below.

# 3. Configure the Helm provider
provider "helm" {
  kubernetes {
    # Use the resource attributes directly.
    # This ensures Terraform waits for the cluster to be created.
    host                   = "https://${google_container_cluster.protecto.endpoint}"
    token                  = data.google_client_config.default.access_token
    cluster_ca_certificate = base64decode(google_container_cluster.protecto.master_auth[0].cluster_ca_certificate)
  }
}

# 4. Configure the Kubernetes provider
provider "kubernetes" {
  # Use the resource attributes directly.
  # This ensures Terraform waits for the cluster to be created.
  host                   = "https://${google_container_cluster.protecto.endpoint}"
  token                  = data.google_client_config.default.access_token
  cluster_ca_certificate = base64decode(google_container_cluster.protecto.master_auth[0].cluster_ca_certificate)
}
