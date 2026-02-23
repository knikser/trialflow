terraform {
  required_version = ">= 1.5"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }

  backend "s3" {
    bucket         = "trialflow-tfstate-prod"
    key            = "terraform.tfstate"
    region         = "us-east-1"
    dynamodb_table = "trialflow-tfstate-lock-prod"
    encrypt        = true
  }
}

provider "aws" {
  region = var.region

  default_tags {
    tags = {
      Project     = "trialflow"
      Environment = "prod"
      ManagedBy   = "terraform"
    }
  }
}
