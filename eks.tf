module "eks" {
  source  = "terraform-aws-modules/eks/aws"
  version = "~> 20.31"

  cluster_name    = local.cluster_name
  cluster_version = var.kubernetes_version

  # Endpoint público para o CI e a máquina do time alcançarem o cluster sem VPN.
  cluster_endpoint_public_access = true

  # Dá acesso admin a quem rodou o apply, evitando ficar trancado do lado de fora.
  enable_cluster_creator_admin_permissions = true

  cluster_addons = {
    coredns                = {}
    kube-proxy             = {}
    vpc-cni                = {}
    eks-pod-identity-agent = {}
  }

  vpc_id     = module.vpc.vpc_id
  subnet_ids = module.vpc.private_subnets

  eks_managed_node_groups = {
    default = {
      instance_types = [var.node_instance_type]
      capacity_type  = "ON_DEMAND"

      min_size     = var.node_min_size
      max_size     = var.node_max_size
      desired_size = var.node_desired_size
    }
  }
}

# Permite que os pods da aplicação alcancem o Postgres. O security group do RDS
# (repositório tc3-infra-db) referencia este como origem autorizada.
output "node_security_group_id" {
  description = "Security group dos nós — origem do tráfego dos pods."
  value       = module.eks.node_security_group_id
}
