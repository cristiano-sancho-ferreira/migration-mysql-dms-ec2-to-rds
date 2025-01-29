#######################################################
###################### EC2 MySql ######################

resource "aws_security_group" "ec2_sg" {
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

resource "aws_instance" "ec2_mysql" {
  ami             = var.ami
  instance_type   = var.instance_type
  iam_instance_profile = aws_iam_instance_profile.ec2_instance_profile.name
  key_name        = var.key_name
  vpc_security_group_ids = [aws_security_group.ec2_sg.id]
  subnet_id       = var.subnet_ids

  user_data = <<-EOF
              #!/bin/bash
              sudo apt update -y
              sudo apt install mysql-server -y
              sudo systemctl start mysql
              sudo systemctl enable mysql
              sudo systemctl status mysql
              sudo snap install aws-cli --classic
              aws --version
              sudo aws s3 cp s3://sancho-terraform-state/mysqld.cnf /etc/mysql/mysql.conf.d/
              sudo systemctl restart mysql


              # Cria usuário e banco para o DMS
              sudo mysql -e "create user '${var.username_ec2}'@'%' identified by '${var.password_ec2}';"
              sudo mysql -e "grant all on *.* to '${var.username_ec2}'@'%';"
              sudo mysql -e "FLUSH PRIVILEGES;"
              sudo mysql -e "create database ${var.db_name_ec2};"
              EOF

  tags = {
    Name = "dms-mysql-ec2-ubuntu"
  }
}


resource "aws_iam_role" "ec2_role" {
  name = "ec2-s3-access-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action    = "sts:AssumeRole"
        Effect    = "Allow"
        Principal = {
          Service = "ec2.amazonaws.com"
        }
      }
    ]
  })
}

resource "aws_iam_policy" "s3_access_policy" {
  name        = "ec2-s3-access-policy"
  description = "Policy to allow EC2 access to S3"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action   = [
          "s3:ListBucket",
          "s3:GetObject",
          "s3:PutObject"
        ]
        Effect   = "Allow"
        Resource = "*"
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "attach_s3_policy" {
  role       = aws_iam_role.ec2_role.name
  policy_arn = aws_iam_policy.s3_access_policy.arn
}

resource "aws_iam_instance_profile" "ec2_instance_profile" {
  name = "ec2-s3-access-profile"
  role = aws_iam_role.ec2_role.name
}

