
locals {
  tmp_dir            = "${path.cwd}/.tmp"
  version_file       = "${local.tmp_dir}/gitea-cluster.version"
  cluster_version    = data.local_file.cluster_version.content
  version_re         = substr(local.cluster_version, 0, 1) == "4" ? regex("^4.([0-9]+)", local.cluster_version)[0] : ""
  openshift_gitops   = local.version_re == "6" || local.version_re == "7" || local.version_re == "8" || local.version_re == "9"
  password_file      = "${local.tmp_dir}/gitea-password.val"
  openshift          = var.cluster_type != "kubernetes"
  gitea_username     = var.gitea_username
  gitea_password     = var.gitea_password == "" ? random_password.password.result : var.gitea_password
  instance_namespace = var.instance_namespace
  instance_name      = var.instance_name
  git_protocol       = "https"
  git_name           = "Gitea"

  gitea_operator_values = {
    global = {
      clusterType       = var.cluster_type
      olmNamespace      = var.olm_namespace
      operatorNamespace = var.operator_namespace
    }

    ocpCatalog = {
      source  = "redhat-gpte-gitea"
      channel = "stable"
      name    = "gitea-operator"
    }
  }
  gitea_operator_values_file = "${local.tmp_dir}/values-gitea-operator.yaml"


  gitea_instance_values = {
    global = {
      clusterType = var.cluster_type
    }
    giteaInstance = {
      name               = local.instance_name
      namespace          = local.instance_namespace
      giteaAdminUser     = local.gitea_username
      giteaAdminPassword = "${local.gitea_password}"
    }
  }
  gitea_instance_values_file = "${local.tmp_dir}/values-gitea-instance.yaml"
}

resource "random_password" "password" {
  length           = 16
  special          = true
  override_special = "()$#-=_"
}


resource "null_resource" "cluster_version" {
  provisioner "local-exec" {
    command = "${path.module}/scripts/get-cluster-version.sh ${local.version_file}"

    environment = {
      KUBECONFIG = var.cluster_config_file
    }
  }
}

data "local_file" "cluster_version" {
  depends_on = [null_resource.cluster_version]

  filename = local.version_file
}

resource "null_resource" "print_version" {
  provisioner "local-exec" {
    command = "echo 'Cluster version: ${local.version_re}'"
  }

  provisioner "local-exec" {
    command = "echo 'OpenShift GitOps: ${local.openshift_gitops}'"
  }
}

resource "null_resource" "gitea_operator_helm" {

  triggers = {
    namespace           = var.operator_namespace
    name                = "gitea-operator"
    chart               = "gitea-operator"
    repository          = "https://charts.cloudnativetoolkit.dev"
    values_file_content = yamlencode(local.gitea_operator_values)
    kubeconfig          = var.cluster_config_file
    tmp_dir             = local.tmp_dir
    openshift           = local.openshift
  }

  provisioner "local-exec" {
    command = "${path.module}/scripts/deploy-helm.sh ${self.triggers.namespace} ${self.triggers.name} ${self.triggers.chart} ${self.triggers.openshift}"

    environment = {
      KUBECONFIG          = self.triggers.kubeconfig
      REPO                = self.triggers.repository
      VALUES_FILE_CONTENT = self.triggers.values_file_content
      TMP_DIR             = self.triggers.tmp_dir
    }
  }

  provisioner "local-exec" {
    when = destroy

    command = "${path.module}/scripts/destroy-helm.sh ${self.triggers.namespace} ${self.triggers.name} ${self.triggers.chart}"

    environment = {
      KUBECONFIG          = self.triggers.kubeconfig
      REPO                = self.triggers.repository
      VALUES_FILE_CONTENT = self.triggers.values_file_content
      TMP_DIR             = self.triggers.tmp_dir
    }
  }
}

resource "null_resource" "wait_gitea_operator_deployment" {
  depends_on = [null_resource.gitea_operator_helm]

  triggers = {
    namespace  = var.operator_namespace
    name       = "gitea-operator"
    kubeconfig = var.cluster_config_file
    tmp_dir    = local.tmp_dir
    openshift  = local.openshift
  }

  provisioner "local-exec" {
    command = "${path.module}/scripts/wait-for-deployments.sh ${self.triggers.namespace} ${self.triggers.name} ${self.triggers.openshift}"

    environment = {
      KUBECONFIG = self.triggers.kubeconfig
      TMP_DIR    = self.triggers.tmp_dir
    }
  }

}

resource "null_resource" "gitea_instance_helm" {
  depends_on = [null_resource.wait_gitea_operator_deployment]

  triggers = {
    namespace           = local.instance_namespace
    name                = local.instance_name
    chart               = "gitea-instance"
    repository          = "https://charts.cloudnativetoolkit.dev"
    values_file_content = yamlencode(local.gitea_instance_values)
    kubeconfig          = var.cluster_config_file
    tmp_dir             = local.tmp_dir
    openshift           = local.openshift
  }

  provisioner "local-exec" {
    command = "${path.module}/scripts/deploy-helm.sh ${self.triggers.namespace} ${self.triggers.name} ${self.triggers.chart} ${self.triggers.openshift}"

    environment = {
      KUBECONFIG          = self.triggers.kubeconfig
      REPO                = self.triggers.repository
      VALUES_FILE_CONTENT = self.triggers.values_file_content
      TMP_DIR             = self.triggers.tmp_dir
    }
  }

  provisioner "local-exec" {
    when = destroy

    command = "${path.module}/scripts/destroy-helm.sh ${self.triggers.namespace} ${self.triggers.name} ${self.triggers.chart}"

    environment = {
      KUBECONFIG          = self.triggers.kubeconfig
      REPO                = self.triggers.repository
      VALUES_FILE_CONTENT = self.triggers.values_file_content
      TMP_DIR             = self.triggers.tmp_dir
    }
  }
}

resource "null_resource" "wait_gitea_instance_deployment" {
  depends_on = [null_resource.gitea_instance_helm]

  triggers = {
    namespace  = local.instance_namespace
    name       = local.instance_name
    kubeconfig = var.cluster_config_file
    tmp_dir    = local.tmp_dir
    openshift  = local.openshift
  }

  provisioner "local-exec" {
    command = "${path.module}/scripts/wait-for-pods-routes.sh ${self.triggers.namespace} ${self.triggers.name} ${self.triggers.openshift}"

    environment = {
      KUBECONFIG = self.triggers.kubeconfig
      TMP_DIR    = self.triggers.tmp_dir
    }
  }
}

resource "null_resource" "gitea_consolelink_deployment" {
  depends_on = [null_resource.wait_gitea_instance_deployment]

  triggers = {
    namespace    = local.instance_namespace
    name         = local.instance_name
    kubeconfig   = var.cluster_config_file
    tmp_dir      = local.tmp_dir
    openshift    = local.openshift
    git_protocol = local.git_protocol
    git_name     = local.git_name
  }

  provisioner "local-exec" {
    command = "${path.module}/scripts/create-console-link.sh ${self.triggers.namespace} ${self.triggers.name} ${self.triggers.openshift}"

    environment = {
      KUBECONFIG   = self.triggers.kubeconfig
      TMP_DIR      = self.triggers.tmp_dir
      GIT_PROTOCOL = self.triggers.git_protocol
      GIT_NAME     = self.triggers.git_name
    }
  }
}
