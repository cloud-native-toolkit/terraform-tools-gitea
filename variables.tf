variable "cluster_config_file" {
  type        = string
  description = "Cluster config file for Kubernetes cluster."
}

variable "cluster_type" {
  type        = string
  description = "The type of cluster (openshift or kubernetes)"
  default     = "openshift"
}

variable "olm_namespace" {
  type        = string
  description = "Namespace where olm is installed"
  default     = "openshift-marketplace"
}

variable "operator_namespace" {
  type        = string
  description = "Namespace where operators will be installed"
  default     = "openshift-operators"
}

variable "instance_namespace" {
  type        = string
  description = "Namespace where instance will be installed"
  default     = "tools"
}

variable "name" {
  type        = string
  description = "The name for the instance"
  default     = "gitea-tools"
}

variable "gitea_username" {
  type        = string
  description = "The username for the instance"
  default     = "toolkit"
}

variable "gitea_password" {
  type        = string
  description = "The password for the instance"
  default     = "toolkit"
}