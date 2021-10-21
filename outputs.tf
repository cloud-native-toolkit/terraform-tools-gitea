output "namespace" {
  description = "The namespace where the Gitea instance has been provisioned"
  value       = local.instance_namespace
}

output "username" {
  description = "The username of the Gitea admin user"
  value       = local.gitea_username
}

output "password" {
  description = "The password of the Gitea admin user"
  value       = local.gitea_password
  sensitive   = true
}
