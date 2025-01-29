# Centralizar o arquivo de controle de estado do terraform
terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "5.70.0"
    }
  }
  backend "s3" {
    bucket = "cacaushow-terraform-state"
    key    = "state/aws/sdlf/streams/terraform.tfstate"
    region = "us-east-1"
  }
}