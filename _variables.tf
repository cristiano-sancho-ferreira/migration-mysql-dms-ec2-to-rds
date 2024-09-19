variable "region" {
  description = "The AWS region to deploy resources"
  type        = string
}

variable "common_tags" {
  description = "Common tags of the project"
  type        = map(string)
}


variable "organization_name" {
  description = "Name of the organization"
  type        = string
}

variable "environment" {
  description = "Environment name"
  type        = string
}


variable "application_name" {
  description = "Name of the application"
  type        = string
  default     = "sdlf"
}

variable "vpc_id" {
  description = "ID vpc"
}

variable "engine_version" {
  type = string
}

variable "instance_class" {
  type = string
}

variable "db_name_rds" {
  type = string
}

variable "username_rds" {
  type = string
}

variable "password_rds" {
  type = string
}

variable "username_ec2" {
  type = string
}

variable "password_ec2" {
  type = string
}

variable "port_ec2" {
  type = string
}

variable "db_name_ec2" {
  type = string
}

variable "key_name" {
  type = string
}

variable "ami" {
  type = string
}
variable "instance_type" {
  type = string
}

