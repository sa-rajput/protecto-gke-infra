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

# 3. Configure the Helm provider
# This uses the cluster endpoint directly to ensure dependency
provider "helm" {
  kubernetes {
    host                   = "https://${google_container_cluster.protecto.endpoint}"
    token                  = data.google_client_config.default.access_token
    cluster_ca_certificate = base64decode(google_container_cluster.protecto.master_auth[0].cluster_ca_certificate)
  }
}

# 4. Kubernetes Provider
# We define this to allow 'kubernetes_namespace' resources to work.
provider "kubernetes" {
  host                   = "https://${google_container_cluster.protecto.endpoint}"
  token                  = data.google_client_config.default.access_token
  cluster_ca_certificate = base64decode(google_container_cluster.protecto.master_auth[0].cluster_ca_certificate)
}
