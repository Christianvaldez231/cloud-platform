terraform {
  required_version = ">=1.10"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0 "
    }
  }
}

provider "aws" {
  region  = "us-east-1"
  profile = "dev"

  default_tags {
    tags = {
      Enviroment = "dev"
      Project    = "cloud_platform"
      ManagedBy  = "terraform"
    }
  }
}

module "vpc" {
  source = "../../modules/vpc"

  name                 = "dev"
  vpc_cidr             = "10.0.0.0/16"
  azs                  = ["us-east-1a", "us-east-1b"]
  public_subnet_cidrs  = ["10.0.1.0/24", "10.0.2.0/24"]
  private_subnet_cidrs = ["10.0.11.0/24", "10.0.12.0/24"]
  enable_nat_gateway   = true
}

module "eks" {
  source = "../../modules/eks"

  name                     = "dev"
  kubernetes_version       = "1.35"
  kubernetes_instance_type = ["t3.medium"]
  desired_size             = "2"
  max_size                 = "2"
  min_size                 = "1"
  access_ip                = "73.57.212.229/32"
  subnet_ids               = module.vpc.private_subnet_ids
  depends_on               = [module.vpc]

}
