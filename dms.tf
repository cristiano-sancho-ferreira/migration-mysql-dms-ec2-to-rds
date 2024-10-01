data "aws_caller_identity" "current" {}
data "aws_region" "current" {}

#######################################################
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

#######################################################
#################### DMS Instance #####################

resource "aws_dms_replication_instance" "dms_instance" {
  replication_instance_id    = "dms-mysql-replication-instance"
  replication_instance_class = "dms.t2.micro"
  engine_version             = "3.5.2"
  multi_az                   = false
  availability_zone          = "us-east-1a"
  allocated_storage          = 5
  apply_immediately          = true
  publicly_accessible        = false
  auto_minor_version_upgrade = false
  tags = {
    Name = "test"
  }
}


#######################################################
#################### DMS Endpoint #####################

resource "aws_dms_s3_endpoint" "s3_target" {
  endpoint_id             = "dms-mysql-target-s3"
  endpoint_type           = "target"
  bucket_name             = aws_s3_bucket.dms_bucket.id
  service_access_role_arn = aws_iam_role.dms_s3_role.arn
  data_format             = "csv"
  csv_delimiter           = "|"  
  ssl_mode                = "none"
}


#######################################################
############### DMS Replication Task ##################

# resource "aws_dms_replication_task" "dms_task" {
#   replication_task_id       = "dms-mysql-replication-task"
#   replication_instance_arn  = aws_dms_replication_instance.dms_instance.replication_instance_arn  
#   source_endpoint_arn       = aws_dms_endpoint.mysql_source.endpoint_arn
#   target_endpoint_arn       = aws_dms_s3_endpoint.s3_target.endpoint_arn
#   #target_endpoint_arn       = aws_dms_endpoint.mysql_target.endpoint_arn
#   migration_type            = "full-load-and-cdc"     # full-load | cdc | full-load-and-cdc
#   table_mappings            = file("table_mappings.json")
#   replication_task_settings = file("replication_task_settings.json")
#   cdc_start_time            = "1993-05-21T05:50:00Z"
# }



