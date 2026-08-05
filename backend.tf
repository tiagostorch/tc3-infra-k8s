terraform {
  # O nome do bucket sai do bootstrap e entra via -backend-config, para não
  # fixar no código um valor que muda por conta:
  #   terraform init -backend-config="bucket=SEU_BUCKET"
  backend "s3" {
    key          = "infra-k8s/terraform.tfstate"
    region       = "us-east-1"
    encrypt      = true
    use_lockfile = true
  }
}
