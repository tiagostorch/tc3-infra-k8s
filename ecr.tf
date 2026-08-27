# Registry das imagens da aplicação. Mora aqui, e não no repositório do app,
# porque é infraestrutura: o cluster puxa daqui por permissão de IAM, sem login.

resource "aws_ecr_repository" "app" {
  name                 = "${local.cluster_name}-api"
  image_tag_mutability = "MUTABLE"

  image_scanning_configuration {
    scan_on_push = true
  }
}

# Sem isso o registry cresce sem limite a cada build do CI.
resource "aws_ecr_lifecycle_policy" "app" {
  repository = aws_ecr_repository.app.name

  policy = jsonencode({
    rules = [{
      rulePriority = 1
      description  = "Mantem apenas as 10 imagens mais recentes"
      selection = {
        tagStatus   = "any"
        countType   = "imageCountMoreThan"
        countNumber = 10
      }
      action = { type = "expire" }
    }]
  })
}

output "ecr_repository_url" {
  description = "Destino do docker push no pipeline da aplicação."
  value       = aws_ecr_repository.app.repository_url
}
