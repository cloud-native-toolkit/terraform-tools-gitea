
locals {
  tmp_dir            = "${path.cwd}/.tmp"
  version_file       = "${local.tmp_dir}/gitea-cluster.version"
  cluster_version    = data.local_file.cluster_version.content
  version_re         = substr(local.cluster_version, 0, 1) == "4" ? regex("^4.([0-9]+)", local.cluster_version)[0] : ""
  openshift_gitops   = local.version_re == "6" || local.version_re == "7" || local.version_re == "8" || local.version_re == "9"
  password_file      = "${local.tmp_dir}/gitea-password.val"
  gitea_username     = var.gitea_username
  gitea_password     = var.gitea_password
  instance_namespace = var.instance_namespace 

  gitea_operator_values       = {
    global = {
      clusterType = var.cluster_type
      olmNamespace = var.olm_namespace
      operatorNamespace = var.operator_namespace
    }

    ocpCatalog = {
      source = "redhat-gpte-gitea"
      channel = "stable"
      name = "gitea-operator"
    }
  }
  gitea_operator_values_file = "${local.tmp_dir}/values-gitea-operator.yaml"


  gitea_instance_values = {
    global = {
      clusterType = var.cluster_type
    }
    giteaInstance = {
      name = "gitea-tools"
      namespace = "tools"
      giteaAdminUser = local.gitea_username
      giteaAdminPassword = local.gitea_password
      giteaAdminPasswordLength = "6"
      giteaAdminEmail = "admin@email.com"
    }
  }
  gitea_instance_values_file = "${local.tmp_dir}/values-gitea-instance.yaml"
}


resource null_resource cluster_version {
  provisioner "local-exec" {
    command = "${path.module}/scripts/get-cluster-version.sh ${local.version_file}"

    environment = {
      KUBECONFIG = var.cluster_config_file
    }
  }
}

data local_file cluster_version {
  depends_on = [null_resource.cluster_version]

  filename = local.version_file
}

resource null_resource print_version {
  provisioner "local-exec" {
    command = "echo 'Cluster version: ${local.version_re}'"
  }

  provisioner "local-exec" {
    command = "echo 'OpenShift GitOps: ${local.openshift_gitops}'"
  }
}

# resource null_resource delete_argocd_helm {
#   provisioner "local-exec" {
#     command = "kubectl delete job job-argocd -n ${local.app_namespace} || exit 0"

#     environment = {
#       KUBECONFIG = var.cluster_config_file
#     }
#   }

#   provisioner "local-exec" {
#     command = "kubectl delete job job-openshift-gitops-operator -n openshift-operators || exit 0"

#     environment = {
#       KUBECONFIG = var.cluster_config_file
#     }
#   }
# }

resource null_resource gitea_operator_helm {
  # depends_on = [null_resource.delete_argocd_helm]

  triggers = {
    namespace = var.operator_namespace
    name = "gitea_operator"
    # chart = "${path.module}/charts/gitea_operator"
    chart = "gitea-operator"
    repository = "https://charts.cloudnativetoolkit.dev"
    values_file_content = yamlencode(local.gitea_operator_values)
    kubeconfig = var.cluster_config_file
    tmp_dir = local.tmp_dir
  }

  provisioner "local-exec" {
    command = "${path.module}/scripts/deploy-helm.sh ${self.triggers.namespace} ${self.triggers.name} ${self.triggers.chart}"

    environment = {
      KUBECONFIG = self.triggers.kubeconfig
      VALUES_FILE_CONTENT = self.triggers.values_file_content
      TMP_DIR = self.triggers.tmp_dir
    }
  }

  provisioner "local-exec" {
    when = destroy

    command = "${path.module}/scripts/destroy-helm.sh ${self.triggers.namespace} ${self.triggers.name} ${self.triggers.chart}"

    environment = {
      KUBECONFIG = self.triggers.kubeconfig
      VALUES_FILE_CONTENT = self.triggers.values_file_content
      TMP_DIR = self.triggers.tmp_dir
    }
  }
}

resource null_resource get_gitea_password {
  depends_on = [null_resource.gitea_operator_helm]

  triggers = {
    always_run = timestamp()
  }

  provisioner "local-exec" {
    command = "${path.module}/scripts/get-gitea-password.sh ${local.instance_namespace} ${local.password_file} ${local.version_re}"

    environment = {
      KUBECONFIG = var.cluster_config_file
    }
  }
}

data local_file gitea_password {
  depends_on = [null_resource.get_gitea_password]

  filename = local.password_file
}

# resource "null_resource" "delete_argocd_config_helm" {
#   provisioner "local-exec" {
#     command = "kubectl api-resources | grep -q consolelink && kubectl delete consolelink -l grouping=garage-cloud-native-toolkit -l app=argocd || exit 0"

#     environment = {
#       KUBECONFIG = var.cluster_config_file
#     }
#   }

#   provisioner "local-exec" {
#     command = "kubectl delete -n ${var.app_namespace} secret sh.helm.release.v1.argocd-config.v1 || exit 0"

#     environment = {
#       KUBECONFIG = var.cluster_config_file
#     }
#   }
# }

resource null_resource gitea_instance_helm {
  # depends_on = [null_resource.delete_argocd_config_helm]
  depends_on = [null_resource.gitea_operator_helm]
  
  triggers = {
    namespace = local.instance_namespace
    name = var.name
    chart = "gitea-instance"
    repository = "https://charts.cloudnativetoolkit.dev"
    values_file_content = yamlencode(local.gitea_instance_values)
    kubeconfig = var.cluster_config_file
    tmp_dir = local.tmp_dir
  }

  provisioner "local-exec" {
    command = "${path.module}/scripts/deploy-helm.sh ${self.triggers.namespace} ${self.triggers.name} ${self.triggers.chart}"

    environment = {
      KUBECONFIG = self.triggers.kubeconfig
      REPO = self.triggers.repository
      VALUES_FILE_CONTENT = self.triggers.values_file_content
      TMP_DIR = self.triggers.tmp_dir
    }
  }

  provisioner "local-exec" {
    when = destroy

    command = "${path.module}/scripts/destroy-helm.sh ${self.triggers.namespace} ${self.triggers.name} ${self.triggers.chart}"

    environment = {
      KUBECONFIG = self.triggers.kubeconfig
      REPO = self.triggers.repository
      VALUES_FILE_CONTENT = self.triggers.values_file_content
      TMP_DIR = self.triggers.tmp_dir
    }
  }
}

