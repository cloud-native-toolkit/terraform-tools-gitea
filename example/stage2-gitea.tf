module "gitea" {
  source = "../"

  cluster_config_file = module.cluster.config_file_path
  instance_namespace  = module.dev_tools_namespace.name
}

resource "null_resource" "output_values" {
  provisioner "local-exec" {
    command = "echo -n '${module.gitea.namespace}' > .namespace"
  }
  provisioner "local-exec" {
    command = "echo -n '${module.gitea.ingress_host}' > .host"
  }
  provisioner "local-exec" {
    command = "echo -n '${module.gitea.ingress_url}' > .url"
  }
  provisioner "local-exec" {
    command = "echo -n '${module.gitea.username}' > .username"
  }
  provisioner "local-exec" {
    command = "echo -n '${module.gitea.password}' > .password"
  }
  provisioner "local-exec" {
    command = "echo -n '${module.gitea.token}' > .token"
  }
}
