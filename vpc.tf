locals {
  cluster_name = "${var.project_name}-${var.environment}"
}

data "aws_availability_zones" "disponiveis" {
  state = "available"
}

module "vpc" {
  source  = "terraform-aws-modules/vpc/aws"
  version = "~> 5.0"

  name = "${local.cluster_name}-vpc"
  cidr = var.vpc_cidr

  azs             = slice(data.aws_availability_zones.disponiveis.names, 0, 2)
  private_subnets = [cidrsubnet(var.vpc_cidr, 8, 1), cidrsubnet(var.vpc_cidr, 8, 2)]
  public_subnets  = [cidrsubnet(var.vpc_cidr, 8, 101), cidrsubnet(var.vpc_cidr, 8, 102)]

  # Um NAT só, compartilhado entre as AZs: metade do custo de rede, e a perda de
  # redundância é aceitável fora de produção.
  enable_nat_gateway = true
  single_nat_gateway = true

  enable_dns_hostnames = true
  enable_dns_support   = true

  # O AWS Load Balancer Controller descobre as subnets por estas tags.
  public_subnet_tags = {
    "kubernetes.io/role/elb" = "1"
  }

  private_subnet_tags = {
    "kubernetes.io/role/internal-elb" = "1"
  }
}
