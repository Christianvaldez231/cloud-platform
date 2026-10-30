variable "name" {
  type        = string
  description = "Prefix for resource names"
}

variable "subnet_ids" {
  type        = list(string)
  description = "Subnets for the cluster's network connections"
}

variable "kubernetes_version" {
  type        = string
  description = "The kubernetes version being used"
}

variable "kubernetes_instance_type" {
  type        = list(string)
  description = "The instance type eks runs"
}

variable "desired_size" {
  type = string
}

variable "max_size" {
  type = string
}

variable "min_size" {
  type = string
}

variable "access_ip" {
  type        = string
  description = "Only ip that is allowed to manage kubernetes"
}