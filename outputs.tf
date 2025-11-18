[Immersive content redacted for brevity.]
output "kubeconfig_command_hint" {
  description = "Command to get kubeconfig credentials for this cluster."
  value = "gcloud container clusters get-credentials ${google_container_cluster.protecto.name} --region ${var.region} --project ${var.project_id}"
}

output "next_manual_steps" {
  description = "Your infrastructure is ready. These are your next manual steps."
  value = <<EOT
-------------------------------------------------------------------
Terraform has completed ALL of Step 1 and Step 2.
The TiDB Operator and TiDB Cluster are being deployed.

Your next steps are (from your client's documentation):
1.  Run the 'kubeconfig_command_hint' output to connect kubectl.
2.  Verify the TiDB cluster is deploying:
    kubectl get pods -n tidb-cluster --watch
3.  Once the TiDB pods are running, proceed with all of Step 3
    (Protecto Application Deployment, python scripts, etc.).
-------------------------------------------------------------------
EOT
}
