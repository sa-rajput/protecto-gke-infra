# --------------------------------------------------------------------
# TESTING VALUES EXAMPLE
# Rename this file to 'terraform.tfvars' for testing/dev use.
# --------------------------------------------------------------------
project_id = "testing-472102"
region     = "us-central1"

gke_cluster_name = "protecto-test-gke"

# For testing, you can use your local IP.
control_plane_cidrs = [
  {
    cidr_block   = "1.2.3.4/32"
    display_name = "My-Home-IP"
  }
]

node_pools = {
  "default-pool" = {
    machine_type   = "e2-medium"
    node_locations = ["us-central1-a"] # Single-zone for cost
    min_count      = 0 # Scale to zero
    max_count      = 1
    disk_type      = "pd-standard"
    disk_size_gb   = 50
  }
}

# 3. Node Pool Configuration (As per your Client's Requirements)
node_pools = {
  "admin" = {
    machine_type   = "e2-standard-2" # 2vCPU, 4GB RAM
    node_locations = ["us-central1-a"]
    min_count      = 1
    max_count      = 1
    disk_type      = "pd-balanced"
    disk_size_gb   = 50
    labels         = {}
    taints         = []
    gpu_type       = null
    gpu_count      = 0
  },
  "tidb" = {
    machine_type   = "e2-standard-4" # 4vCPU, 8GB RAM
    node_locations = ["us-central1-a"]
    min_count      = 1
    max_count      = 1
    disk_type      = "pd-balanced"
    disk_size_gb   = 100
    labels = {
      dedicated = "tidb"
    }
    taints = [
      { key = "dedicated", value = "tidb", effect = "NO_SCHEDULE" }
    ]
    gpu_type       = null
    gpu_count      = 0
  }
 }
 
