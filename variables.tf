variable "aws_region" {
  type    = string
  default = "us-east-1"
}

variable "project_name" {
  type    = string
  default = "tc3-oficina"
}

variable "environment" {
  description = "Ambiente lógico: homolog ou prod."
  type        = string
  default     = "homolog"
}

variable "vpc_cidr" {
  type    = string
  default = "10.0.0.0/16"
}

variable "kubernetes_version" {
  description = <<-EOT
    Manter numa versão em standard support. Versões em extended support custam
    US$ 0,60 por hora de cluster em vez de US$ 0,10 — seis vezes mais, cobrado
    em silêncio. A 1.31 saiu do standard support em 26/11/2025. A 1.35 fica em standard
    support ate marco de 2027, com folga sobre o prazo do projeto.
  EOT
  type        = string
  default     = "1.35"
}

variable "node_instance_type" {
  description = <<-EOT
    Tipo dos nós. t3.small (2 vCPU / 2 GiB) atende o HPA de 2–10 réplicas da
    aplicação; subir para t3.medium se os pods de sistema apertarem.
  EOT
  type        = string
  default     = "t3.small"
}

variable "node_desired_size" {
  type    = number
  default = 2
}

variable "node_min_size" {
  type    = number
  default = 2
}

variable "node_max_size" {
  type    = number
  default = 4
}

variable "ci_role_name" {
  description = "Role que o GitHub Actions assume por OIDC, criada no bootstrap."
  type        = string
  default     = "tc3-github-actions"
}

variable "admin_user_name" {
  description = "Usuário IAM que administra o cluster a partir da máquina local."
  type        = string
  default     = "tc3-admin"
}

variable "cluster_admin_users" {
  description = <<-EOT
    Usuários IAM do time que precisam operar o cluster com kubectl. Admin na
    conta AWS não basta — o EKS tem autorização própria.
  EOT
  type        = list(string)
  default = [
    "mauricio.mathias",
    "miguel.moraes",
    "lucas.valadao",
    "rodrigo.souza",
  ]
}
