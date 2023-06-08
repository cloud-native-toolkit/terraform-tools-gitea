variable "cluster_config_file" {
  type        = string
  description = "Cluster config file for Kubernetes cluster."
}

variable "cluster_type" {
  type        = string
  description = "The type of cluster (openshift or kubernetes)"
  default     = "ocp4"
}

variable "ingress_subdomain" {
  type        = string
  description = "The subdomain for ingresses created on the cluster"
  default     = ""
}

variable "tls_secret_name" {
  type        = string
  description = "The name of the secret containing the tls information"
  default     = ""
}

variable "instance_namespace" {
  type        = string
  description = "Namespace where instance will be installed"
  default     = "tools"
}

variable "instance_name" {
  type        = string
  description = "The name for the instance"
  default     = "gitea"
}

variable "username" {
  type        = string
  description = "The username for the instance"
  default     = "gitea-admin"
}

variable "password" {
  type        = string
  description = "The password for the instance"
  default     = ""
}

variable "ca_cert" {
  type        = string
  description = "The base64 encoded ca certificate"
  default     = ""
}

variable "ca_cert_file" {
  type        = string
  description = "The path to the file that contains the ca certificate"
  default     = ""
}
