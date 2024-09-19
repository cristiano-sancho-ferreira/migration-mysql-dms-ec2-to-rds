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

variable "mysql_username" {
  type        = string
}

variable "mysql_password" {
  type        = string
}

variable "dump_files" {
  type = list(string)
}