# tc3-infra-k8s

Infraestrutura Kubernetes do Tech Challenge Fase 3 (FIAP SOAT) — sistema de gestão de oficina mecânica.

Provisiona, via Terraform, a rede e o cluster onde a aplicação NestJS roda. É a **base** dos demais repositórios: `tc3-infra-db` e `tc3-auth-lambda` leem os outputs daqui pelo state remoto.

## O que este repositório cria

| Recurso | Detalhe |
|---|---|
| VPC | 2 AZs, subnets públicas e privadas, NAT único |
| Cluster EKS | Kubernetes 1.31, endpoint público, addons de base |
| Managed node group | 2× `t3.small` (2–4 nós) |
| metrics-server | Requisito do HPA da aplicação |
| AWS Load Balancer Controller | Traduz Ingress em ALB; alvo do VPC Link do API Gateway |

## Tecnologias

Terraform ≥ 1.10 · AWS provider 5.x · módulos `terraform-aws-modules/vpc` e `/eks` · Helm provider · GitHub Actions

## Ordem de execução

```
bootstrap/  →  tc3-infra-k8s  →  tc3-infra-db  →  tc3-auth-lambda
```

### 1. Bootstrap (uma vez por conta)

Cria o bucket de state, o budget de proteção de custo e o OIDC do GitHub Actions. Usa state local — por isso mora num diretório separado.

```bash
cd bootstrap
cp terraform.tfvars.example terraform.tfvars   # editar
terraform init
terraform apply
```

Anote os outputs: `state_bucket` e `github_actions_role_arn`.

### 2. Cluster

```bash
cp terraform.tfvars.example terraform.tfvars
terraform init -backend-config="bucket=SEU_BUCKET"
terraform apply

aws eks update-kubeconfig --region us-east-1 --name tc3-oficina-homolog
kubectl get nodes
```

## CI/CD

`.github/workflows/terraform.yml`

- **Pull request** → `fmt`, `validate` e `plan`, com o plano comentado no PR
- **Push em `develop`** → apply no ambiente de homologação
- **Push em `main`** → apply no ambiente de produção

Secrets necessários no repositório:

| Secret | Origem |
|---|---|
| `AWS_ROLE_ARN` | output `github_actions_role_arn` do bootstrap |
| `TF_STATE_BUCKET` | output `state_bucket` do bootstrap |

`main` é protegida: merge apenas via Pull Request com CI verde.

## Custo

O control plane do EKS e os nós são cobrados por hora enquanto existirem. Fora das janelas de trabalho:

```bash
terraform destroy
```

O `terraform apply` reconstrói o ambiente inteiro em ~20 minutos — que é, ele próprio, a demonstração de infraestrutura como código funcionando.

## Arquitetura

```
                       ┌──────────────────────────────────────┐
   Internet ──────────▶│ VPC 10.0.0.0/16 · 2 AZs              │
                       │                                      │
                       │  subnets públicas ── ALB ── NAT      │
                       │         │                            │
                       │         ▼                            │
                       │  subnets privadas                    │
                       │   ├── nós EKS (t3.small × 2)         │
                       │   │    └── pods da API + HPA 2–10    │
                       │   └── (RDS, criado em tc3-infra-db)  │
                       └──────────────────────────────────────┘
```

## Outputs consumidos por outros repositórios

`vpc_id` · `private_subnet_ids` · `public_subnet_ids` · `cluster_name` · `cluster_endpoint` · `cluster_oidc_provider_arn` · `node_security_group_id`
