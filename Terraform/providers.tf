## providers.tf

terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.70.0"
    }
    local = {
      source  = "hashicorp/local"
      version = "~> 2.9"
    }
  }

  # S3 Remote Backend for State Storage
  backend "s3" {
    bucket         = "barq-task-terraform-state-2026"
    key            = "terraform/state/terraform.tfstate"
    region         = "eu-central-1"
    encrypt        = true
  }
}

provider "aws" {
  region = var.aws_region

  default_tags {
    tags = {
      Project   = var.project_name
      ManagedBy = "terraform"
    }
  }
}