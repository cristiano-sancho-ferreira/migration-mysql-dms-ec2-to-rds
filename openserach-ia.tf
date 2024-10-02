resource "aws_opensearch_domain" "opensearch_domain" {
  domain_name           = "dms-opensearch-domain"
  engine_version        = "OpenSearch_1.3"

  # Configuração do cluster com 1 instância para Tier Gratuito
  cluster_config {
    instance_type            = "t3.small.search"  # Instância elegível para o tier gratuito
    instance_count           = 1  # Apenas 1 instância para ficar dentro do free tier
    dedicated_master_enabled = false  # Não usar nó mestre dedicado
    zone_awareness_enabled   = false  # Sem alta disponibilidade no tier gratuito
  }

  # Opções de armazenamento EBS
  ebs_options {
    ebs_enabled = true
    volume_size = 10  # Limite do tier gratuito (até 10 GB de armazenamento)
    volume_type = "gp3"
  }

  # Configuração VPC
  vpc_options {
    subnet_ids         = [var.subnet_ids]  # Subnets da VPC
    security_group_ids = [aws_security_group.opensearch_sg.id]  # Grupos de segurança
  }

  # Criptografia em repouso e em trânsito
  encrypt_at_rest {
    enabled = true
  }

  node_to_node_encryption {
    enabled = true
  }

  domain_endpoint_options {
    enforce_https       = true
    tls_security_policy = "Policy-Min-TLS-1-2-2019-07"
  }

  # Políticas de Acesso via IAM Role
  access_policies = <<CONFIG
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": {
        "AWS": "*" 
      },
      "Action": "es:*",
      "Resource": "arn:aws:es:${data.aws_region.current.name}:${data.aws_caller_identity.current.account_id}:domain/dms-opensearch-domain/*"
    }
  ]
}
CONFIG

  tags = {
    Name = "my-opensearch-domain"
    Env  = "production"
  }
}

# Grupo de Segurança para OpenSearch
resource "aws_security_group" "opensearch_sg" {
  name        = "opensearch-sg-hgfgfd"
  description = "Security Group for OpenSearch"

  ingress {
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]  # Acesso restrito via HTTPS
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}