# --------------------------------------------------------------------
# FREE TRIAL EXTREME (1 NODE ONLY)
# --------------------------------------------------------------------

project_id = "testing-472102" # <--- Don't forget to set this!
region     = "us-central1"

control_plane_cidrs = [
  {
    cidr_block   = "1.2.3.4/32"     # <--- Set your IP!
    display_name = "My-Local-Machine"
  }
]

node_pools = {
  "combined-pool" = {
    machine_type   = "e2-standard-4"
    node_locations = ["us-central1-a"]
    min_count      = 1
    max_count      = 1
    disk_type      = "pd-standard"   # Must be pd-standard
    disk_size_gb   = 100
    labels         = {}
    taints         = []
    gpu_type       = null
    gpu_count      = 0
  }
}
