# 1. Instantiate the S3 Remote Backend Module
module "s3_backend" {
  source = "./modules/s3"

  bucket_name   = var.state_bucket_name
  environment   = var.environment
  force_destroy = true # Set to true in dev for clean teardown testing
}

# 2. Instantiate the VPC Module
module "vpc" {
  source = "./modules/vpc"

  vpc_cidr             = var.vpc_cidr
  public_subnet_cidrs  = var.public_subnet_cidrs
  private_subnet_cidrs = var.private_subnet_cidrs
  availability_zones   = var.availability_zones
  environment          = var.environment
}
