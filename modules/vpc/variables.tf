variable "vpc_cidr" {
  description = "The CIDR block for the VPC"
  type        = string
  default     = "10.0.0.0/16"
}

variable "public_subnet_cidrs" {
  description = "List of CIDR blocks for public subnets"
  type        = list(string)
  default     = ["10.0.1.0/24", "10.0.2.0/24"]
}

variable "private_subnet_cidrs" {
  description = "List of CIDR blocks for private subnets"
  type        = list(string)
  default     = ["10.0.10.0/24", "10.0.20.0/24"]
}

variable "availability_zones" {
  description = "List of Availability Zones to deploy subnets across"
  type        = list(string)
  default     = ["us-east-1a", "us-east-1b"]
}

variable "environment" {
  description = "Deployment environment name (e.g., dev, prod)"
  type        = string
  default     = "dev"
}
