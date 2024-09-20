data "aws_caller_identity" "current" {}
data "aws_region" "current" {}

#######################################################
######################### DMS #########################

data "aws_iam_policy_document" "dms_assume_role" {
  statement {
    actions = ["sts:AssumeRole"]

    principals {
      identifiers = ["dms.amazonaws.com"]
      type        = "Service"
    }
  }
}

resource "aws_iam_role" "dms_role" {
  name               = "dms-s3-access-role"
  assume_role_policy = data.aws_iam_policy_document.dms_assume_role.json
}

resource "aws_iam_policy" "dms_policy" {
  name        = "dms-s3-access-Policy"
  description = "Allow DMS to put objects in S3 bucket"
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action = [
        "s3:PutObject",
        "s3:ListBucket"
      ]
      Effect = "Allow"
      Resource = [
        aws_s3_bucket.dms_bucket.arn,
        "${aws_s3_bucket.dms_bucket.arn}/*"
      ]
    }]
  })
}

resource "aws_iam_role_policy_attachment" "dms_role_policy_attach" {
  role       = aws_iam_role.dms_role.name
  policy_arn = aws_iam_policy.dms_policy.arn
}

resource "aws_s3_bucket" "dms_bucket" {
  bucket        = "dms-${data.aws_caller_identity.current.account_id}"
  force_destroy = true
}


resource "aws_dms_replication_instance" "dms_instance" {
  replication_instance_id    = "dms-replication-instance"
  replication_instance_class = "dms.t2.micro"
  engine_version             = "3.5.2"
  multi_az                   = false
  availability_zone          = "us-east-1a"
  allocated_storage          = 5
  apply_immediately          = true
  publicly_accessible        = true
  auto_minor_version_upgrade = false
  tags = {
    Name = "test"
  }
}

#######################################################
###################### EC2 MySql ######################

resource "aws_security_group" "ec2_sg" {
  name        = "ec2-mysql-sg"
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
    cidr_blocks = ["0.0.0.0/0"] # Permite acesso ao MySQL
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "aws_instance" "ec2_mysql" {
  ami             = var.ami
  instance_type   = var.instance_type
  key_name        = var.key_name
  security_groups = [aws_security_group.ec2_sg.name]
  subnet_id       = var.subnet_ids

  user_data = <<-EOF
              #!/bin/bash
              sudo apt update -y
              sudo apt install mysql-server -y
              sudo systemctl start mysql
              sudo systemctl enable mysql
              sudo systemctl status mysql

              # Cria usuário e banco para o DMS
              sudo mysql -e "create user '${var.username_ec2}'@'%' identified by '${var.password_ec2}';"
              sudo mysql -e "grant all on *.* to '${var.username_ec2}'@'%';"
              sudo mysql -e "FLUSH PRIVILEGES;"
              sudo mysql -e "create database ${var.db_name_ec2};"
              EOF

  tags = {
    Name = "ec2-mysql"
  }
}




#######################################################
###################### RDS MySql ######################

resource "aws_db_subnet_group" "mysql_subnet_group" {
  name       = "mysql-subnet-group"
  subnet_ids = [var.subnet_ids, "subnet-09485a295a6a6d9c4"] # Substitua pelos IDs de subnets corretos

  tags = var.common_tags
}

resource "aws_security_group" "mysql_sg" {
  name        = "dms-mysql-sg"
  description = "Allow MySQL access"
  vpc_id      = var.vpc_id
  ingress {
    description = "MySQL inbound"
    from_port   = 3306
    to_port     = 3306
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"] # Ajuste conforme necessário
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
  tags = var.common_tags
}

resource "aws_db_instance" "mysql" {
  allocated_storage      = 20
  identifier             = "mysql-instance"
  engine                 = "mysql"
  engine_version         = var.engine_version
  instance_class         = var.instance_class
  db_name                = var.db_name_rds
  username               = var.username_rds
  password               = var.password_rds
  db_subnet_group_name   = aws_db_subnet_group.mysql_subnet_group.name
  vpc_security_group_ids = [aws_security_group.mysql_sg.id]
  skip_final_snapshot    = true
  publicly_accessible    = true
  multi_az               = false
  network_type           = "IPV4"
  availability_zone          = "us-east-1a"

  tags = var.common_tags
}


#######################################################
#################### DMS Endpoint #####################

resource "aws_dms_endpoint" "mysql_source" {
  endpoint_id   = "ec2-mysql-source-endpoint"
  endpoint_type = "source"
  engine_name   = "mysql"
  username      = var.username_ec2
  password      = var.password_ec2
  server_name   = aws_instance.ec2_mysql.public_ip
  port          = var.port_ec2
  database_name = var.db_name_ec2
  ssl_mode      = "none"
}

resource "aws_dms_endpoint" "mysql_target" {
  endpoint_id   = "rds-mysql-target-endpoint"
  endpoint_type = "target"
  engine_name   = "mysql"
  username      = aws_db_instance.mysql.username
  password      = aws_db_instance.mysql.password
  server_name   = aws_db_instance.mysql.endpoint
  port          = aws_db_instance.mysql.port
  database_name = aws_db_instance.mysql.db_name
  ssl_mode      = "none"
}



resource "aws_dms_replication_task" "dms_task" {
  replication_task_id      = "mysql-to-s3"
  migration_type           = "cdc" # CDC for streaming
  source_endpoint_arn      = aws_dms_endpoint.mysql_source.endpoint_arn
  target_endpoint_arn      = aws_dms_endpoint.mysql_target.endpoint_arn
  replication_instance_arn = aws_dms_replication_instance.dms_instance.replication_instance_arn
  table_mappings = jsonencode({
    "rules" : [
      {
        "rule-type" : "selection",
        "rule-id" : "1",
        "rule-name" : "1",
        "object-locator" : {
          "schema-name" : "your_schema_name",
          "table-name" : "table1"
        },
        "rule-action" : "include"
      },
      {
        "rule-type" : "selection",
        "rule-id" : "2",
        "rule-name" : "2",
        "object-locator" : {
          "schema-name" : "your_schema_name",
          "table-name" : "table2"
        },
        "rule-action" : "include"
      },
      # Continue for other tables
    ]
  })
}







#######################################################
################ DMS Data Colletor ####################
## Criar a IAM Role para o Fleet Advisor Collector
/*
resource "aws_iam_role" "fleet_advisor_role" {
  name = "FleetAdvisorCollectorRole"

  assume_role_policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Effect = "Allow",
        Principal = {
          Service = [
                    "dms-fleet-advisor.amazonaws.com",
                    "dms.amazonaws.com"
                  ]
        },
        Action = "sts:AssumeRole",
        Condition = {
          ArnLike = {
            "aws:SourceArn" = "arn:aws:dms:*:${data.aws_caller_identity.current.account_id}:*"
          }
        }
      }
    ]
  })
}

resource "aws_iam_policy" "fleet_advisor_policy" {
  name        = "FleetAdvisorCollectorPolicy"
  description = "Policy to allow DMS Fleet Advisor collector to upload data to S3."

  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Effect = "Allow",
        Action = [
          "s3:GetObject*",
          "s3:GetBucket*",
          "s3:GetBucketLocation",
          "s3:List*",
          "s3:DeleteObject*",
          "s3:PutObject*"
        ],
        Resource = "*"
      },
      {
        Effect = "Allow",
        Action = [
          "dms:CreateFleetAdvisorCollector",
          "dms:DescribeFleetAdvisorCollectors",
          "dms:DeleteFleetAdvisorCollector",
          "dms:ModifyFleetAdvisorCollectorStatuses",
          "dms:UploadFileMetadataList"
        ],
        Resource = "*"
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "attach_fleet_advisor_policy" {
  role       = aws_iam_role.fleet_advisor_role.name
  policy_arn = aws_iam_policy.fleet_advisor_policy.arn
}

# Criar o S3 Bucket para armazenar os dados coletados
resource "aws_s3_bucket" "fleet_advisor_bucket" {
  bucket = "migration-dms-data-colletor-${data.aws_caller_identity.current.account_id}"
  force_destroy = true
  tags = {
    Name        = "FleetAdvisorDataBucket"
    Environment = "prod"
  }
}


# Usuário IAM para o Fleet Advisor Collector
resource "aws_iam_user" "fleet_advisor_collector_user" {
  name = "FleetAdvisorCollectorUser-${var.region}"
}

# Política para o usuário IAM do Fleet Advisor Collector
resource "aws_iam_user_policy" "fleet_advisor_collector_policy" {
  name   = "FleetAdvisorCollectorUser-${var.region}-Policy"
  user   = aws_iam_user.fleet_advisor_collector_user.name

  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Effect = "Allow",
        Action = [
          "dms:DescribeFleetAdvisorCollectors",
          "dms:ModifyFleetAdvisorCollectorStatuses",
          "dms:UploadFileMetadataList",
          "s3:GetObject*",
          "s3:GetBucket*",
          "s3:GetBucketLocation",
          "s3:List*",
          "s3:DeleteObject*",
          "s3:PutObject*"
        ],
        Resource = "*"
      }
    ]
  })
}

# Service-Linked Role para o DMS Fleet Advisor
resource "aws_iam_service_linked_role" "fleet_advisor_slr" {
  aws_service_name = "dms-fleet-advisor.amazonaws.com"
  description      = "SLR for Fleet Advisor"
}
*/


# aws dms create-fleet-advisor-collector --collector-name "MyFleetAdvisorCollector" --s3-bucket-name "migration-dms-data-colletor-381491840841" --service-access-role-arn "arn:aws:iam::381491840841:role/FleetAdvisorCollectorRole"
