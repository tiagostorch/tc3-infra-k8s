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
  type    = string
  default = "1.31"
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
