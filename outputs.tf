output "namespace" {
  description = "The namespace where the ArgoCD instance has been provisioned"
  value       = local.instance_namespace
  depends_on  = [null_resource.argocd-config]
}

# output "service_account" {
#   description = "The name of the service account for the ArgoCD instance has been provisioned"
#   value       = local.service_account_name
#   depends_on  = [null_resource.argocd-config]
# }

output "username" {
  description = "The username of the Gitea admin user"
  value       = local.gitea_username
  depends_on  = [null_resource.gitea-config]
}

output "password" {
  description = "The password of the default Gitea admin user"
  # value       = data.local_file.gitea_password.content
  value       = local.gitea_password
  depends_on  = [null_resource.gitea-config]
  sensitive   = true
}
