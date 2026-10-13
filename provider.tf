terraform {
  required_version = ">= 1.5.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }

  # NOTE: The backend "s3" block will be added here in Step 5
  # after the S3 bucket is provisioned.
}

provider "aws" {
  region = var.aws_region
}
