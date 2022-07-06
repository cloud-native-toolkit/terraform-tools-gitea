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
  value       = data.external.gitea_route.result.password
  sensitive   = true
}

output "token" {
  description = "The api token of the Gitea admin user"
  value       = data.external.token.result.token
  sensitive   = true
}

output "host" {
  description = "The host name of the gitea server"
  value       = data.external.gitea_route.result.host
}

output "org" {
  description = "The host name of the gitea server"
  value       = local.gitea_username
}

output "ingress_host" {
  description = "The host name of the gitea server"
  value       = data.external.gitea_route.result.host
}

output "ingress_url" {
  description = "The url of the gitea server"
  value       = "https://${data.external.gitea_route.result.host}"
}
