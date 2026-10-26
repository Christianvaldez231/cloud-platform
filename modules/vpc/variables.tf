variable "vpc_cidr" {
  type        = string
  description = "IP range for the VPC, in CIDR notation"
}

variable "name" {
  type        = string
  description = "Prefix for resource names, like dev or prod"
}

variable "azs" {
  type        = list(string)
  description = "Availability zones to use"
}

variable "public_subnet_cidrs" {
  type        = list(string)
  description = "Ip ranges for the pubic subnets, one per AZ"
}

variable "private_subnet_cidrs" {
  type        = list(string)
  description = "Ip ranges for the private subnets, one per AZ"
}

variable "enable_nat_gateway" {
  type        = bool
  default     = false
  description = "Create a NAT gateway so private subnets can reach the internet. Costs money while running."
}

variable "subnet_ids" {
  type = list(string)
  description = "Subnets for the cluster's network connections (the private subnets)"
}