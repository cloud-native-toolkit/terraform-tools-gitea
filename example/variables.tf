
variable "ibmcloud_api_key" {
  type        = string
  description = "The api key for IBM Cloud access"
}

variable "namespace" {
  type        = string
  description = "Namespace for tools"
}

variable "cluster_name" {
  type        = string
  description = "The name of the cluster"
  default     = ""
}

variable "cluster_exists" {
  type        = string
  description = "Flag indicating if the cluster already exists (true or false)"
  default     = "true"
}

variable "name_prefix" {
  type        = string
  description = "Prefix name that should be used for the cluster and services. If not provided then resource_group_name will be used"
  default     = ""
}

variable "vpc_cluster" {
  type        = bool
  description = "Flag indicating that this is a vpc cluster"
  default     = false
}

variable "server_url" {
}

variable "ingress_subdomain" {
  default = ""
}

variable "login_token" {
  default = ""
}

variable "region" {
}

variable "resource_group_name" {
}