
# --------------------------------------------------------------------
# FREE TRIAL SURVIVAL MODE
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
  }
]

# 3. Node Pools Configuration (Free Trial Optimized)
# Total Resources: ~8 vCPU, ~160GB Disk (Fits in Free Tier)
node_pools = {
  # 1. Admin Node
  "admin" = {
    machine_type   = "e2-standard-2"  # 2 vCPU, 8GB RAM
    node_locations = ["us-central1-a"]
    min_count      = 1
    max_count      = 1
    disk_type      = "pd-standard"    # HDD (Standard) to save quota
    disk_size_gb   = 40
    labels         = {}
    taints         = []
    gpu_type       = null
    gpu_count      = 0
  },

  # 2. TiDB Node
  "tidb" = {
    machine_type   = "e2-standard-2"
    node_locations = ["us-central1-a"]
    min_count      = 1
    max_count      = 1
    disk_type      = "pd-standard"
    disk_size_gb   = 40
    labels         = { dedicated = "tidb" }
    taints         = [{ key = "dedicated", value = "tidb", effect = "NO_SCHEDULE" }]
    gpu_type       = null
    gpu_count      = 0
  },

  # 3. PD Node
  "pd" = {
    machine_type   = "e2-standard-2"
    node_locations = ["us-central1-a"]
    min_count      = 1
    max_count      = 1
    disk_type      = "pd-standard"
    disk_size_gb   = 40
    labels         = { dedicated = "pd" }
    taints         = [{ key = "dedicated", value = "pd", effect = "NO_SCHEDULE" }]
    gpu_type       = null
    gpu_count      = 0
  },

  # 4. TiKV Node
  "tikv" = {
    machine_type   = "e2-standard-2"
    node_locations = ["us-central1-a"]
    min_count      = 1
    max_count      = 1
    disk_type      = "pd-standard"
    disk_size_gb   = 40
    labels         = { dedicated = "tikv" }
    taints         = [{ key = "dedicated", value = "tikv", effect = "NO_SCHEDULE" }]
    gpu_type       = null
    gpu_count      = 0
  },

  # 5. Big Node - DISABLED for Free Trial
  "bignode" = {
    machine_type   = "e2-standard-2"
    node_locations = ["us-central1-a"]
    min_count      = 0
    max_count      = 0
    disk_type      = "pd-standard"
    disk_size_gb   = 40
    labels         = {}
    taints         = []
    gpu_type       = null
    gpu_count      = 0
  },

  # 6. GPU Node - DISABLED for Free Trial
  "gpunode" = {
    machine_type   = "a2-highgpu-1g"
    node_locations = ["us-central1-a"]
    min_count      = 0
    max_count      = 0
    disk_type      = "pd-standard"
    disk_size_gb   = 40
    labels         = {}
    taints         = []
    gpu_type       = null
    gpu_count      = 0
  }
}
