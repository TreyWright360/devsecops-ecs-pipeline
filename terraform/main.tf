terraform {
  required_version = ">= 1.7.0"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.50.0"
    }
  }
}

provider "aws" {
  region = var.aws_region

  default_tags {
    tags = {
      Environment = var.environment
      Service     = "overflow-ledger-service"
      ManagedBy   = "Terraform"
      Compliance  = "SOC2-TypeII"
    }
  }
}

variable "aws_region" {
  type    = string
  default = "us-east-1"
}

variable "environment" {
  type    = string
  default = "production"
}

variable "github_repository" {
  description = "Format: owner/repo-name (e.g., your-username/devsecops-ecs-pipeline)"
  type        = string
  default     = "trey-wright/devsecops-ecs-pipeline"
}
