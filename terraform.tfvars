# --------------------------------------------------------------------
# FREE TRIAL EXTREME (1 NODE ONLY)
# --------------------------------------------------------------------

project_id = "testing-472102" # <--- REPLACE THIS with your actual Project ID
region     = "us-central1"

# FIX FOR TIMEOUT ERROR:
# We must allow 0.0.0.0/0 so Infrastructure Manager (Cloud Build) can connect.
control_plane_cidrs = [
  {
    cidr_block   = "0.0.0.0/0"
    display_name = "Allow-All-For-Deploy"
  }
]

node_pools = {
  "combined-pool" = {
    machine_type   = "e2-standard-4"
    node_locations = ["us-central1-a"]
    min_count      = 1
    max_count      = 1
    disk_type      = "pd-standard"    # HDD to save SSD Quota
    disk_size_gb   = 100
    labels         = {}
    taints         = []
    gpu_type       = null
    gpu_count      = 0
  }
}
