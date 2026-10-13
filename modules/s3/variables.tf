variable "bucket_name" {
  description = "The name of the S3 bucket (must be globally unique across AWS)"
  type        = string
}

variable "environment" {
  description = "Deployment environment name (e.g., dev, prod)"
  type        = string
  default     = "dev"
}

variable "force_destroy" {
  description = "Whether to delete all objects from the bucket when destroying (useful for dev/testing)"
  type        = bool
  default     = false
}
