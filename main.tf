
locals {
  tmp_dir            = "${path.cwd}/.tmp"
  version_file       = "${local.tmp_dir}/gitea-cluster.version"
  cluster_version    = data.external.cluster_config.result.clusterVersion
  version_re         = substr(local.cluster_version, 0, 1) == "4" ? regex("^4.([0-9]+)", local.cluster_version)[0] : ""
  openshift_gitops   = local.version_re == "6" || local.version_re == "7" || local.version_re == "8" || local.version_re == "9"
  password_file      = "${local.tmp_dir}/gitea-password.val"
  openshift          = var.cluster_type != "kubernetes"
  subscription_name  = "gitea-operator-${random_string.module_id.result}"
  gitea_username     = "gitea-admin"
  gitea_password     = var.password == "" ? random_password.password.result : var.password
  gitea_email        = "${local.gitea_username}@cloudnativetoolkit.dev"
  instance_namespace = var.instance_namespace
  base_instance_name = "gitea"
  instance_name      = "${var.instance_name}-${random_string.module_id.result}"
  git_protocol       = "https"
  git_name           = "Gitea"

  gitea_operator_values = {
    global = {
      clusterType       = var.cluster_type
      olmNamespace      = var.olm_namespace
      operatorNamespace = var.operator_namespace
    }

    gitea-operator = {
      ocpCatalog = {
        source  = "redhat-gpte-gitea"
        channel = "stable"
        name    = "gitea-operator"
      }
    }
  }
  gitea_operator_values_file = "${local.tmp_dir}/values-gitea-operator.yaml"


  gitea_instance_values = {
    global = {
      clusterType = var.cluster_type
    }
    gitea-instance = {
      giteaInstance = {
        name               = local.base_instance_name
        namespace          = local.instance_namespace
        giteaAdminUser     = local.gitea_username
        giteaAdminPassword = local.gitea_password
        giteaAdminEmail    = local.gitea_email
      }
    }
  }
  gitea_instance_values_file = "${local.tmp_dir}/values-gitea-instance.yaml"

  ca_cert               = var.ca_cert_file != null && var.ca_cert_file != "" ? base64encode(file(var.ca_cert_file)) : var.ca_cert
}

module setup_clis {
  source = "cloud-native-toolkit/clis/util"

  clis = ["helm", "jq", "oc", "kubectl"]
}

resource random_string module_id {
  length = 8
  upper = false
  special = false
}

resource random_password password {
  length           = 16
  special          = true
  override_special = "()$#-=_"
}

data external cluster_config {
  program = ["bash", "${path.module}/scripts/get-cluster-version.sh"]

  query = {
    bin_dir     = module.setup_clis.bin_dir
    kube_config = var.cluster_config_file
  }
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
    name                = local.subscription_name
    chart               = "${path.module}/chart/gitea-operator"
    values_file_content = yamlencode(local.gitea_operator_values)
    kubeconfig          = var.cluster_config_file
    tmp_dir             = local.tmp_dir
    bin_dir             = module.setup_clis.bin_dir
    openshift           = local.openshift
  }

  provisioner "local-exec" {
    command = "${path.module}/scripts/deploy-helm.sh ${self.triggers.namespace} ${self.triggers.name} ${self.triggers.chart} ${self.triggers.openshift} subscription"

    environment = {
      KUBECONFIG          = self.triggers.kubeconfig
      VALUES_FILE_CONTENT = self.triggers.values_file_content
      TMP_DIR             = self.triggers.tmp_dir
      BIN_DIR             = self.triggers.bin_dir
    }
  }

  provisioner "local-exec" {
    when = destroy

    command = "${path.module}/scripts/destroy-helm.sh ${self.triggers.namespace} ${self.triggers.name} ${self.triggers.chart} subscription"

    environment = {
      KUBECONFIG          = self.triggers.kubeconfig
      VALUES_FILE_CONTENT = self.triggers.values_file_content
      TMP_DIR             = self.triggers.tmp_dir
      BIN_DIR             = self.triggers.bin_dir
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
    bin_dir    = module.setup_clis.bin_dir
    openshift  = local.openshift
  }

  provisioner "local-exec" {
    command = "${path.module}/scripts/wait-for-deployments.sh ${self.triggers.namespace} ${self.triggers.name} ${self.triggers.openshift}"

    environment = {
      KUBECONFIG = self.triggers.kubeconfig
      TMP_DIR    = self.triggers.tmp_dir
      BIN_DIR    = self.triggers.bin_dir
    }
  }

}

resource "null_resource" "gitea_instance_helm" {
  depends_on = [null_resource.wait_gitea_operator_deployment]

  triggers = {
    namespace           = local.instance_namespace
    name                = local.instance_name
    chart               = "${path.module}/chart/gitea-instance"
    values_file_content = yamlencode(local.gitea_instance_values)
    kubeconfig          = var.cluster_config_file
    tmp_dir             = local.tmp_dir
    bin_dir             = module.setup_clis.bin_dir
    openshift           = local.openshift
    module_id           = random_string.module_id.result
  }

  provisioner "local-exec" {
    command = "${path.module}/scripts/deploy-helm.sh ${self.triggers.namespace} ${self.triggers.name} ${self.triggers.chart} ${self.triggers.openshift} gitea"

    environment = {
      KUBECONFIG          = self.triggers.kubeconfig
      VALUES_FILE_CONTENT = self.triggers.values_file_content
      TMP_DIR             = self.triggers.tmp_dir
      BIN_DIR             = self.triggers.bin_dir
      MODULE_ID           = self.triggers.module_id
    }
  }

  provisioner "local-exec" {
    when = destroy

    command = "${path.module}/scripts/destroy-helm.sh ${self.triggers.namespace} ${self.triggers.name} ${self.triggers.chart} gitea"

    environment = {
      KUBECONFIG          = self.triggers.kubeconfig
      VALUES_FILE_CONTENT = self.triggers.values_file_content
      TMP_DIR             = self.triggers.tmp_dir
      BIN_DIR             = self.triggers.bin_dir
      MODULE_ID           = self.triggers.module_id
    }
  }
}

resource "null_resource" "wait_gitea_instance_deployment" {
  depends_on = [null_resource.gitea_instance_helm]

  triggers = {
    namespace  = local.instance_namespace
    name       = local.base_instance_name
    kubeconfig = var.cluster_config_file
    tmp_dir    = local.tmp_dir
    bin_dir    = module.setup_clis.bin_dir
    openshift  = local.openshift
  }

  provisioner "local-exec" {
    command = "${path.module}/scripts/wait-for-pods-routes.sh ${self.triggers.namespace} ${self.triggers.name} ${self.triggers.openshift}"

    environment = {
      KUBECONFIG = self.triggers.kubeconfig
      TMP_DIR    = self.triggers.tmp_dir
      BIN_DIR    = self.triggers.bin_dir
    }
  }
}

data external gitea_route {
  depends_on = [null_resource.wait_gitea_instance_deployment]
  program = ["bash", "${path.module}/scripts/get-route-host.sh"]

  query = {
    bin_dir     = module.setup_clis.bin_dir
    kube_config = var.cluster_config_file
    namespace   = local.instance_namespace
    name        = local.base_instance_name
  }
}

resource random_string token_id {
  upper = false
  special = false

  length = 6
}

resource null_resource token {
  provisioner "local-exec" {
    command = "${path.module}/scripts/generate-token.sh '${var.instance_namespace}' 'gitea-token' 'token-${random_string.token_id.result}' '${data.external.gitea_route.result.host}'"

    environment = {
      KUBECONFIG = var.cluster_config_file
      TMP_DIR    = local.tmp_dir
      BIN_DIR    = module.setup_clis.bin_dir
      USERNAME   = local.gitea_username
      PASSWORD   = data.external.gitea_route.result.password
    }
  }
}

data external token {
  depends_on = [null_resource.token]
  program = ["bash", "${path.module}/scripts/get-token.sh"]

  query = {
    bin_dir = module.setup_clis.bin_dir
    kube_config = var.cluster_config_file
    namespace = var.instance_namespace
    name = "gitea-token"
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
    bin_dir      = module.setup_clis.bin_dir
  }

  provisioner "local-exec" {
    command = "${path.module}/scripts/create-console-link.sh ${self.triggers.namespace} ${self.triggers.name} ${self.triggers.openshift}"

    environment = {
      KUBECONFIG   = self.triggers.kubeconfig
      TMP_DIR      = self.triggers.tmp_dir
      GIT_PROTOCOL = self.triggers.git_protocol
      GIT_NAME     = self.triggers.git_name
      BIN_DIR      = self.triggers.bin_dir
    }
  }
}
