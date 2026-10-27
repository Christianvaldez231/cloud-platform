variable "name" {
  type        = string
  description = "Prefix for resource names"
}

variable "subnet_ids" {
  type        = list(string)
  description = "Subnets for the cluster's network connections"
}