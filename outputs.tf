output "vpc_id" {
  description = "The ID of the provisioned VPC"
  value       = module.vpc.vpc_id
}

output "public_subnet_ids" {
  description = "Public subnet IDs"
  value       = module.vpc.public_subnet_ids
}

output "private_subnet_ids" {
  description = "Private subnet IDs"
  value       = module.vpc.private_subnet_ids
}

output "state_bucket_name" {
  description = "The name of the state S3 bucket"
  value       = module.s3_backend.bucket_id
}

output "state_bucket_arn" {
  description = "The ARN of the state S3 bucket"
  value       = module.s3_backend.bucket_arn
}

output "state_iam_policy_arn" {
  description = "The ARN of the IAM policy granting state access"
  value       = module.s3_backend.iam_policy_arn
}
