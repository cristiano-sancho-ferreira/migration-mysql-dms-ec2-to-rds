region            = "us-east-1"
organization_name = "cacaushow"
environment       = "prd"
common_tags = {
  "Name" = "Migration"
}
###################### RDS MySql ######################
engine_version = "8.0.35"
instance_class = "db.t3.micro"
db_name_rds    = "retail"
username_rds   = "admin"
password_rds   = "calipso2024"
###################### EC2 MySql ######################
username_ec2  = "virtualadmin"
password_ec2  = "calipso"
port_ec2      = "3306"
db_name_ec2   = "retail"
key_name      = "dms-mysql-key"
ami           = "ami-0866a3c8686eaeeba" # AMI do ubuntu
instance_type = "t2.micro"


vpc_id        = "vpc-0512e5889e2a04da7"
subnet_ids    = "subnet-08b756f575d8975b9"  

