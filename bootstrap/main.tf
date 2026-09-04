# Fundação da conta AWS — roda UMA vez, com state local.
#
# Cria o que precisa existir antes de qualquer outro Terraform:
#   1. Bucket S3 para o state remoto dos demais repositórios
#   2. Budget com alertas (proteção dos créditos da conta)
#   3. GitHub OIDC provider + role de CI (deploy sem access key)
#
#   cd bootstrap && terraform init && terraform apply

terraform {
  required_version = ">= 1.10"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

provider "aws" {
  region = var.aws_region

  default_tags {
    tags = {
      Project   = "tech-challenge-fase3"
      ManagedBy = "terraform"
      Stack     = "bootstrap"
    }
  }
}

variable "aws_region" {
  type    = string
  default = "us-east-1"
}

variable "state_bucket_name" {
  description = "Nome do bucket de state — precisa ser único globalmente."
  type        = string
}

variable "budget_alert_emails" {
  description = "E-mails que recebem os alertas de custo."
  type        = list(string)
}

variable "budget_limit_usd" {
  description = "Teto mensal monitorado. Alertas disparam em 50%, 80% e na previsão de 100%."
  type        = string
  default     = "100"
}

variable "github_repositories" {
  description = <<-EOT
    Repositórios autorizados a assumir a role de CI. Cada entrada leva o
    "org/repo" e os IDs numéricos do dono e do repositório:

      gh api users/OWNER      --jq .id
      gh api repos/OWNER/REPO --jq .id

    O GitHub emite o subject do token OIDC com identificadores imutáveis —
    "repo:owner@ID/repo@ID:pull_request" — para que renomear um repositório não
    transfira a confiança para quem tomar o nome antigo. Sem os IDs, a role
    recusa a troca com "Not authorized to perform sts:AssumeRoleWithWebIdentity".

    O dono vem por repositório, e não num campo único da conta: o repo da
    aplicação é de outro integrante do time.
  EOT

  type = list(object({
    repo     = string
    owner_id = optional(string, "")
    repo_id  = optional(string, "")
  }))

  default = []
}

# ─── 1. State remoto ────────────────────────────────────────────────────────

resource "aws_s3_bucket" "tfstate" {
  bucket = var.state_bucket_name

  # O state descreve a infra inteira; apagar por engano é irrecuperável.
  lifecycle {
    prevent_destroy = true
  }
}

resource "aws_s3_bucket_versioning" "tfstate" {
  bucket = aws_s3_bucket.tfstate.id

  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "tfstate" {
  bucket = aws_s3_bucket.tfstate.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

resource "aws_s3_bucket_public_access_block" "tfstate" {
  bucket = aws_s3_bucket.tfstate.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# ─── 2. Budget ──────────────────────────────────────────────────────────────

resource "aws_budgets_budget" "mensal" {
  name         = "tc3-budget-mensal"
  budget_type  = "COST"
  limit_amount = var.budget_limit_usd
  limit_unit   = "USD"
  time_unit    = "MONTHLY"

  notification {
    comparison_operator        = "GREATER_THAN"
    threshold                  = 50
    threshold_type             = "PERCENTAGE"
    notification_type          = "ACTUAL"
    subscriber_email_addresses = var.budget_alert_emails
  }

  notification {
    comparison_operator        = "GREATER_THAN"
    threshold                  = 80
    threshold_type             = "PERCENTAGE"
    notification_type          = "ACTUAL"
    subscriber_email_addresses = var.budget_alert_emails
  }

  # Avisa antes de estourar, não depois.
  notification {
    comparison_operator        = "GREATER_THAN"
    threshold                  = 100
    threshold_type             = "PERCENTAGE"
    notification_type          = "FORECASTED"
    subscriber_email_addresses = var.budget_alert_emails
  }
}

# ─── 3. GitHub Actions via OIDC ─────────────────────────────────────────────

resource "aws_iam_openid_connect_provider" "github" {
  count = length(var.github_repositories) > 0 ? 1 : 0

  url             = "https://token.actions.githubusercontent.com"
  client_id_list  = ["sts.amazonaws.com"]
  thumbprint_list = ["6938fd4d98bab03faadb97b34396831e3780aea1"]
}

locals {
  # Forma legada: repo:owner/repo:*
  subjects_legado = [for r in var.github_repositories : "repo:${r.repo}:*"]

  # Forma imutável: repo:owner@ownerId/repo@repoId:*
  subjects_imutavel = [
    for r in var.github_repositories :
    format(
      "repo:%s@%s/%s@%s:*",
      split("/", r.repo)[0],
      r.owner_id,
      split("/", r.repo)[1],
      r.repo_id,
    )
    if r.owner_id != "" && r.repo_id != ""
  ]

  subjects_confiaveis = concat(local.subjects_legado, local.subjects_imutavel)
}

data "aws_iam_policy_document" "github_assume_role" {
  count = length(var.github_repositories) > 0 ? 1 : 0

  statement {
    effect  = "Allow"
    actions = ["sts:AssumeRoleWithWebIdentity"]

    principals {
      type        = "Federated"
      identifiers = [aws_iam_openid_connect_provider.github[0].arn]
    }

    condition {
      test     = "StringEquals"
      variable = "token.actions.githubusercontent.com:aud"
      values   = ["sts.amazonaws.com"]
    }

    # Aceita as duas formas do subject: a legada, sem IDs, e a imutável que o
    # GitHub emite hoje. Padrões explícitos em vez de curinga largo — um
    # "repo:tiagostorch*" também casaria com uma conta chamada tiagostorch-x.
    condition {
      test     = "StringLike"
      variable = "token.actions.githubusercontent.com:sub"
      values   = local.subjects_confiaveis
    }
  }
}

resource "aws_iam_role" "github_actions" {
  count = length(var.github_repositories) > 0 ? 1 : 0

  name               = "tc3-github-actions"
  assume_role_policy = data.aws_iam_policy_document.github_assume_role[0].json
}

# Projeto acadêmico de vida curta: admin mantém o foco na arquitetura, não em
# afinar permissão. Em produção, trocar por policies mínimas por stack.
resource "aws_iam_role_policy_attachment" "github_actions_admin" {
  count = length(var.github_repositories) > 0 ? 1 : 0

  role       = aws_iam_role.github_actions[0].name
  policy_arn = "arn:aws:iam::aws:policy/AdministratorAccess"
}

# ─── Outputs ────────────────────────────────────────────────────────────────

output "state_bucket" {
  description = "Preencher em backend.tf dos demais repositórios."
  value       = aws_s3_bucket.tfstate.id
}

output "github_actions_role_arn" {
  description = "Secret AWS_ROLE_ARN nos repositórios do GitHub."
  value       = try(aws_iam_role.github_actions[0].arn, null)
}
