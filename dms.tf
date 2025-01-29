data "aws_caller_identity" "current" {}
data "aws_region" "current" {}

#######################################################
######################### IAM dms_vpc_role #########################
data "aws_iam_policy_document" "dms_vpc_role" {
  statement {
    actions = ["sts:AssumeRole"]

    principals {
      identifiers = ["dms.amazonaws.com"]
      type        = "Service"
    }
  }
}

resource "aws_iam_role" "dms_vpc_role" {
  name               = "dms-vpc-role"
  assume_role_policy = data.aws_iam_policy_document.dms_assume_role.json
  
}

resource "aws_iam_role_policy_attachment" "dms_vpc_role_policy" {
  role       = aws_iam_role.dms_vpc_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonDMSVPCManagementRole"
}
######################### IAM dms_cloudwatch_logs_role #########################
data "aws_iam_policy_document" "dms_cloudwatch_logs_role" {
  statement {
    actions = ["sts:AssumeRole"]

    principals {
      identifiers = ["dms.amazonaws.com"]
      type        = "Service"
    }
  }
}

resource "aws_iam_role" "dms_cloudwatch_logs_role" {
  name               = "dms-cloudwatch-logs-role"
  assume_role_policy = data.aws_iam_policy_document.dms_assume_role.json
  
}

resource "aws_iam_role_policy_attachment" "dms_cloudwatch_logs_role_policy" {
  role       = aws_iam_role.dms_vpc_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonDMSCloudWatchLogsRole"  ## Problema
}


######################### IAM #########################
data "aws_iam_policy_document" "dms_assume_role" {
  statement {
    actions = ["sts:AssumeRole"]

    principals {
      identifiers = ["dms.amazonaws.com"]
      type        = "Service"
    }
  }
}

resource "aws_iam_role" "dms_s3_role" {
  name               = "dms-mysql-s3-role"
  assume_role_policy = data.aws_iam_policy_document.dms_assume_role.json
}

resource "aws_iam_policy" "dms_s3_policy" {
  name        = "dms-mysql-s3-policy"
  description = "Allow DMS to put objects in S3 bucket"
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action = [
          "s3:PutObject",
          "s3:ListBucket",
          "s3:GetObject",
          "s3:DeleteObject"
      ]
      Effect = "Allow"
      Resource = [
        aws_s3_bucket.dms_bucket.arn,
        "${aws_s3_bucket.dms_bucket.arn}/*"
      ]
    }]
  })
}

resource "aws_iam_role_policy_attachment" "dms_role_policy_dms_s3_attach" {
  role       = aws_iam_role.dms_s3_role.name
  policy_arn = aws_iam_policy.dms_s3_policy.arn
}

#######################################################
####################    S3        #####################

resource "aws_s3_bucket" "dms_bucket" {
  bucket        = "dms-mysql-${data.aws_caller_identity.current.account_id}"
  force_destroy = true
}

# Buscar dinamicamente as Route Tables associadas à sua VPC
data "aws_route_tables" "vpc_route_tables" {
  vpc_id = var.vpc_id  # A VPC que você quer associar
}

resource "aws_vpc_endpoint" "s3_endpoint" {
  vpc_id       = var.vpc_id  # ID da sua VPC
  service_name = "com.amazonaws.${var.region}.s3"

  vpc_endpoint_type = "Gateway"

  # Subnets onde o endpoint será criado, utilizando as tabelas de rotas buscadas dinamicamente
  route_table_ids = data.aws_route_tables.vpc_route_tables.ids

  tags = {
    Name = "s3-endpoint"
    Env  = "production"
  }
}



#######################################################
#################### DMS Instance #####################

resource "aws_dms_replication_instance" "dms_instance" {
  replication_instance_id    = "dms-mysql-replication-instance"
  replication_instance_class = "dms.t2.micro"
  engine_version             = "3.5.2"
  multi_az                   = false
  availability_zone          = "us-east-1d"
  allocated_storage          = 5
  apply_immediately          = true
  publicly_accessible        = false
  auto_minor_version_upgrade = false
  tags = {
    Name = "test"
  }
  #depends_on = [ aws_opensearch_domain.opensearch_domain ]
}


#######################################################
#################### DMS Endpoint #####################
# resource "aws_dms_endpoint" "mysql_source" {
#   endpoint_id   = "dms-mysql-source-ec2"
#   endpoint_type = "source"
#   engine_name   = "mysql"
#   username      = var.username_ec2
#   password      = var.password_ec2
#   server_name   = aws_instance.ec2_mysql.public_ip
#   port          = var.port_ec2
#   database_name = var.db_name_ec2
#   ssl_mode      = "none"

#   depends_on = [ 
#     aws_instance.ec2_mysql, 
#     aws_dms_replication_instance.dms_instance 
#     ]
# }


resource "aws_dms_s3_endpoint" "s3_target" {
  endpoint_id             = "cacaushow-dms-target-s3"
  endpoint_type           = "target"
  bucket_name             = aws_s3_bucket.dms_bucket.id
  service_access_role_arn = aws_iam_role.dms_s3_role.arn
  data_format             = "csv"
  csv_delimiter           = "|"  
  ssl_mode                = "none"

  depends_on = [ aws_s3_bucket.dms_bucket, aws_dms_replication_instance.dms_instance ]
}


#######################################################
############### DMS Replication Task ##################

# resource "aws_dms_replication_task" "dms_task_s3" {
#   replication_task_id       = "dms-mysql-replication-task_s3"
#   replication_instance_arn  = aws_dms_replication_instance.dms_instance.replication_instance_arn  
#   source_endpoint_arn       = aws_dms_endpoint.mysql_source.endpoint_arn
#   target_endpoint_arn       = aws_dms_s3_endpoint.s3_target.endpoint_arn
#   migration_type            = "full-load-and-cdc"     # full-load | cdc | full-load-and-cdc
#   table_mappings            = file("table_mappings.json")
#   replication_task_settings = file("replication_task_settings.json")
#   cdc_start_time            = "1993-05-21T05:50:00Z"
# }



