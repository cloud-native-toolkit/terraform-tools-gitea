module "gitea" {
  source = "./module"

  cluster_config_file = module.dev_cluster.config_file_path
  olm_namespace       = module.dev_software_olm.olm_namespace
  operator_namespace  = module.dev_software_olm.target_namespace
  instance_namespace  = module.dev_tools_namespace.name
}

resource "null_resource" "output_values" {
  provisioner "local-exec" {
    command = "echo -n '${module.dev_software_olm.target_namespace}' > .namespace"
  }
  provisioner "local-exec" {
    command = "echo -n '${module.gitea.namespace}' > .argo-namespace"
  }
  provisioner "local-exec" {
    command = "echo -n '${module.gitea.ingress_host}' > .argo-host"
  }
  provisioner "local-exec" {
    command = "echo -n '${module.gitea.ingress_url}' > .argo-url"
  }
  provisioner "local-exec" {
    command = "echo -n '${module.gitea.username}' > .argo-username"
  }
  provisioner "local-exec" {
    command = "echo -n '${module.gitea.password}' > .argo-password"
  }
}
