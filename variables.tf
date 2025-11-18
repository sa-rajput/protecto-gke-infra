variable "project_id" {
  description = "The GCP project ID to deploy resources into."
  type        = string
}

variable "region" {
  description = "The GCP region for the GKE cluster. Example: 'us-central1'."
  type        = string
}

variable "gke_cluster_name" {
  description = "Name for the GKE cluster."
  type        = string
  default     = "protecto-gke-prod"
}

variable "network_name" {
  description = "Name for the GKE VPC network."
  type        = string
  default     = "protecto-vpc"
}

variable "subnet_name" {
  description = "Name for the GKE subnetwork."
  type        = string
  default     = "gke-subnet"
}

variable "subnet_cidr" {
  description = "Primary CIDR range for the GKE subnetwork."
  type        = string
  default     = "10.10.0.0/20"
}

variable "pods_cidr_range" {
  description = "Secondary CIDR range for GKE Pods."
  type        = string
  default     = "10.20.0.0/16"
}

variable "services_cidr_range" {
  description = "Secondary CIDR range for GKE Services."
  type        = string
  default     = "10.30.0.0/20"
}

variable "master_ipv4_cidr_block" {
  description = "Internal CIDR range for the GKE control plane (must be /28)."
  type        = string
  default     = "172.16.0.0/28"
}

variable "control_plane_cidrs" {
  description = "List of CIDR blocks (e.g., your local IP, CI/CD IPs) authorized to access the GKE public API endpoint. This replaces the jump server."
  type = list(object({
    cidr_block   = string
    display_name = string
  }))
  validation {
    condition     = alltrue([for block in var.control_plane_cidrs : block.cidr_block != "0.0.0.0/0"])
    error_message = "Do not use '0.0.0.0/0' for production. Please restrict this to your specific IP addresses."
  }
}

variable "gke_node_service_account_name" {
  description = "Name for the dedicated GKE node service account."
  type        = string
  default     = "gke-node-sa"
}

variable "node_pools" {
  description = "A map of GKE node pools to create, including standard and GPU pools."
  type = map(object({
    # Standard Config
    machine_type   = string
    node_locations = list(string) # List of zones, e.g., ["us-central1-a"]
    min_count      = number       # Minimum nodes *per zone*
    max_count      = number       # Maximum nodes *per zone*
    disk_type      = string       # "pd-standard", "pd-balanced", or "pd-ssd"
    disk_size_gb   = number
    taints = optional(list(object({
      key    = string
      value  = string
      effect = string
    })), [])
    labels = optional(map(string), {})

    # GPU Config (Optional: set to null for standard pools)
    gpu_type  = optional(string, null)
    gpu_count = optional(number, null)
  }))
}
