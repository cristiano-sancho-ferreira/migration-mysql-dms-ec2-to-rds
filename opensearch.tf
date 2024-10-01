# SETUP AWS ElasticSearch | Accessing the Kibana dashboard within a 
# VPC-enabled ElasticSearch domain
# https://www.youtube.com/watch?v=UeFtTCl1mSE

# AWS OpenSearch | Creating an OpenSearch domain within a VPC and accessing it using Proxy API 
# https://www.youtube.com/watch?v=LkLMfGFp-mY

# ##################### Amazon OpenSearch #####################

resource "aws_opensearch_domain" "opensearch_domain" {
  domain_name           = "dms-opensearch-domain"
  engine_version        = "OpenSearch_1.3"

  cluster_config {
    instance_type            = "t3.small.search"  # Nó de dados
    instance_count           = 1
    dedicated_master_enabled = false
    # dedicated_master_count   = 1 #var.dedicated_master_count
    # dedicated_master_type    = "t3.small.search" #var.dedicated_master_type
    # zone_awareness_enabled   = false 
    # #multi_az_with_standby_enabled = false
    # zone_awareness_config {
    #   availability_zone_count = 2
    # }
  } 

  vpc_options {
    subnet_ids         = [var.subnet_ids]
    security_group_ids = [aws_security_group.ec2_sg.id]
  }

  advanced_security_options {
    enabled                        = true
    # anonymous_auth_enabled         = false
    internal_user_database_enabled = true
    master_user_options {
      master_user_name   = "admin"
      master_user_password = "Calipso@2024"
    }
  }
  
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

  ebs_options {
    ebs_enabled = true
    volume_size = 10  
    volume_type = "gp3"
  } 

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
      "Resource": "arn:aws:es:${data.aws_region.current.name}:${data.aws_caller_identity.current.account_id}:domain/*"
    }
  ]
}
CONFIG

  tags = {
    Name = "my-opensearch-domain"
    Env = "production"
  }

}




# resource "aws_opensearch_domain" "opensearch_domain" {
#   # ... outras configurações

#   log_publishing_options {
#     cloudwatch_log_group_arn = aws_cloudwatch_log_group.opensearch_application_logs.arn
#     log_type                 = "INDEX_SLOW_LOGS"
#     enabled                  = true
#   }

#   log_publishing_options {
#     cloudwatch_log_group_arn = aws_cloudwatch_log_group.opensearch_search_logs.arn
#     log_type                 = "SEARCH_SLOW_LOGS"
#     enabled                  = true
#   }
# }

# resource "aws_cloudwatch_log_group" "opensearch_application_logs" {
#   name = "opensearch-application-logs"
#   retention_in_days = 14
# }

# resource "aws_cloudwatch_log_group" "opensearch_search_logs" {
#   name = "opensearch-search-logs"
#   retention_in_days = 14
# }











# resource "aws_dms_endpoint" "opensearch_target" {
#   endpoint_id               = "opensearch-destination-endpoint"
#   endpoint_type             = "target"
#   engine_name               = "elasticsearch"  # O DMS ainda utiliza esse nome para OpenSearch
#   username                  = "opensearch_user"
#   password                  = "opensearch_password"
#   server_name               = "vpc-opensearch-cluster.example.com"
#   port                      = 443
#   ssl_mode                  = "require"

#   elasticsearch_settings {
#     service_access_role_arn = aws_iam_role.dms_opensearch_role.arn
#   }
# }




resource "aws_security_group" "_sg" {
  name        = "dms-mysql-ec2-sg"
  description = "Allow MySQL access"

  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"] # Acesse via SSH de qualquer lugar
  }

  ingress {
    from_port   = 3306
    to_port     = 3306
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"] 
  }

  ingress {
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"] 
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}