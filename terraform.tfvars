# --------------------------------------------------------------------
# PRODUCTION VALUES
# This file provides the actual values for the variables defined in variables.tf
# --------------------------------------------------------------------

# 1. GCP Project Configuration
project_id = "testing-472102"  # <--- REPLACE THIS with your actual Project ID
region     = "us-central1"

# 2. Security / Jump Server Replacement
# CRITICAL: You must add your own IP address here.
# If you don't, you won't be able to connect to the cluster.
# Run 'curl ifconfig.me' to find your IP.
control_plane_cidrs = [
  {
    cidr_block   = "1.2.3.4/32"       # <--- REPLACE with your IP
    display_name = "My-Local-Machine"
  },
  {
    cidr_block   = "5.6.7.8/32"       # <--- REPLACE with Office VPN IP (if any)
    display_name = "Office-VPN"
  }
]

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
 
