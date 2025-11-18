# --------------------------------------------------------------------
# FREE TRIAL EXTREME (1 NODE ONLY)
# --------------------------------------------------------------------

# 1. GCP Project Configuration
project_id = "testing-472102"  # <--- REPLACE THIS
region     = "us-central1"

# 2. Security
control_plane_cidrs = [
  {
    cidr_block   = "1.2.3.4/32"       # <--- REPLACE with your IP
    display_name = "My-Local-Machine"
  }
]

# 3. Node Pools Configuration (1 Node Total)
# Resources: 4 vCPU, 16GB RAM, 100GB HDD
node_pools = {
  "combined-pool" = {
    machine_type   = "e2-standard-4"  # 4 vCPU, 16GB RAM (Good for running everything on 1 node)
    node_locations = ["us-central1-a"]
    min_count      = 1
    max_count      = 1
    disk_type      = "pd-standard"    # HDD (Critical to avoid SSD Quota error)
    disk_size_gb   = 100              # Fits easily in Free Trial quota
    labels         = {}               # No specific labels, generic node
    taints         = []               # No taints so all pods can schedule
    gpu_type       = null
    gpu_count      = 0
  }
}
