terraform {
  required_version = ">= 1.5"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }

  backend "s3" {
    bucket         = "trialflow-tfstate-staging"
    key            = "terraform.tfstate"
    region         = "us-east-1"
    dynamodb_table = "trialflow-tfstate-lock-staging"
    encrypt        = true
  }
}

provider "aws" {
  region = var.region

  default_tags {
    tags = {
      Project     = "trialflow"
      Environment = "staging"
      ManagedBy   = "terraform"
    }
  }
}
