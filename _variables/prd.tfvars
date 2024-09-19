region            = "us-east-1"
organization_name = "beholder"
environment       = "prd"
common_tags = {
  "Name" = "Migration"
}
###################### RDS MySql ######################
engine_version = "8.0.35"
instance_class = "db.t4g.micro"
db_name_rds    = "retail"
username_rds   = "admin"
password_rds   = "calipso1234"
###################### EC2 MySql ######################
username_ec2  = "virtualadmin"
password_ec2  = "calipso1234"
port_ec2      = "3306"
db_name_ec2   = "retail"
key_name      = "key-pair-linux-sancho"
ami           = "ami-0a0e5d9c7acc336f1" # AMI do ubuntu
instance_type = "t2.micro"

vpc_id = "vpc-039ffaa0cf5d4c063"

