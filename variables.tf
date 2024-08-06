variable "owner" {
  type = string
}

variable "eks_cluster_name" {
  type = string
}

variable "eks_cluster_region" {
  type = string
}

variable "karpenter_version" {
  type = string
  default = "0.36.1"
}

variable "karpenter_nodepool_instance_families" {
  type = list(string)
  default = [ "m5", "t4", "c5" ]
}