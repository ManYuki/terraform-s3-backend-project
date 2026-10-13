# AWS Networking & Terraform Remote State Architecture

![Terraform](https://img.shields.io/badge/Terraform-%235835CC.svg?style=for-the-badge&logo=terraform&logoColor=white)
![AWS](https://img.shields.io/badge/AWS-%23FF9900.svg?style=for-the-badge&logo=amazon-aws&logoColor=white)
![HCL](https://img.shields.io/badge/Configuration-HCL-blue.svg?style=for-the-badge)
![Security](https://img.shields.io/badge/Security-IAM%20%7C%20Least%20Privilege-green.svg?style=for-the-badge)

## Overview
This Infrastructure as Code (IaC) repository provisions an Amazon Virtual Private Cloud (VPC) and a hardened Amazon S3 remote state storage architecture using HashiCorp Terraform. Designed for scalable cloud operations, it establishes isolated network routing topologies and resolves the remote backend bootstrap lifecycle while enforcing strict least-privilege identity access management, TLS-only transit encryption, and versioned state persistence.

## Why This Matters 
* **Elimination of State Drift and Concurrency Race Conditions:** Centralizing the Terraform state lifecycle within a version-controlled Amazon S3 backend guarantees a unified source of truth across engineering teams, mitigating configuration drift and preventing catastrophic state overwrites through native S3 object versioning.
* **Hardened Security Posture and Compliance Adherence:** The state storage architecture enforces defense-in-depth compliance benchmarks out of the box, utilizing AES-256 encryption at rest, complete S3 public access block enforcement, mandatory TLS in-transit encryption (`aws:SecureTransport`), and tight IAM boundary scoping.
* **Modular Repeatability Across Multi-Account Topologies:** Decoupling network primitives into reusable child modules allows engineering organizations to deploy isolated environments (such as Dev, Staging, and Production) deterministically through variable parametrization without modifying upstream infrastructure definitions.
* **Reduced Blast Radius and Granular Network Segmentation:** Partitioning workloads across public and private subnets throughout multiple Availability Zones ensures critical backend services remain shielded from public internet ingress, establishing an enterprise foundation for cloud-native applications.

---

## Table of Contents
- [Architecture & Design Principles](#architecture--design-principles)
- [Repository Structure](#repository-structure)
- [Prerequisites & Workstation Configuration](#prerequisites--workstation-configuration)
- [Step-by-Step Implementation Guide](#step-by-step-implementation-guide)
  - [Step 0: Version Control Safety Rails & AWS Authentication](#step-0-version-control-safety-rails--aws-authentication)
  - [Step 1: Modular Networking Tier (VPC Module)](#step-1-modular-networking-tier-vpc-module)
  - [Step 2: Hardened State Storage (S3 Module)](#step-2-hardened-state-storage-s3-module)
  - [Step 3: Access Control & IAM Security Policies](#step-3-access-control--iam-security-policies)
  - [Step 4: Root Module Integration & Variable Parameterization](#step-4-root-module-integration--variable-parameterization)
  - [Step 5: Provisioning Initial Infrastructure via Locked Plan](#step-5-provisioning-initial-infrastructure-via-locked-plan)
  - [Step 6: Remote State Backend Migration](#step-6-remote-state-backend-migration)
  - [Step 7: Testing Multi-Environment Separation (Dev vs. Prod)](#step-7-testing-multi-environment-separation-dev-vs-prod)
- [Inputs & Outputs Reference](#inputs--outputs-reference)
- [State Management & Infrastructure Verification](#state-management--infrastructure-verification)

---

## Architecture & Design Principles

```text
                               AWS Cloud Region: eu-west-2 (London)
┌───────────────────────────────────────────────────────────────────────────────────────────────────────┐
│                                                                                                       │
│   ┌───────────────────────────────────────────────────────────────────────────────────────────────┐   │
│   │                                       Amazon S3 Backend                                       │   │
│   │                              (<your-unique-tf-state-dev-bucket>)                              │   │
│   │  - SSE-S3 AES-256 Encryption at Rest           - Public Access Block (4 Rules Active)         │   │
│   │  - Object Versioning Enabled (Rollback Ready)  - Bucket Policy Enforcing TLS (HTTPS Only)     │   │
│   │  - Key Prefix: dev/terraform.tfstate                                                          │   │
│   └───────────────────────────────────────────────────────────────────────────────────────────────┘   │
│                                                                                                       │
│   ┌───────────────────────────────────────────────────────────────────────────────────────────────┐   │
│   │                                       VPC: 10.0.0.0/16                                        │   │
│   │                                                                                               │   │
│   │   Internet Gateway (dev-igw) ◄── Attached to Public Route Table (0.0.0.0/0)                  │   │
│   │                                                                                               │   │
│   │   Availability Zone: eu-west-2a                  Availability Zone: eu-west-2b               │   │
│   │   ┌──────────────────────────────────┐           ┌──────────────────────────────────┐         │   │
│   │   │ Public Subnet 1: 10.0.1.0/24     │           │ Public Subnet 2: 10.0.2.0/24     │         │   │
│   │   │ - Auto-assigns Public IPv4       │           │ - Auto-assigns Public IPv4       │         │   │
│   │   └──────────────────────────────────┘           └──────────────────────────────────┘         │   │
│   │                                                                                               │   │
│   │   ┌──────────────────────────────────┐           ┌──────────────────────────────────┐         │   │
│   │   │ Private Subnet 1: 10.0.10.0/24   │           │ Private Subnet 2: 10.0.20.0/24   │         │   │
│   │   │ - Isolated from Direct Ingress   │           │ - Isolated from Direct Ingress   │         │   │
│   │   └──────────────────────────────────┘           └──────────────────────────────────┘         │   │
│   └───────────────────────────────────────────────────────────────────────────────────────────────┘   │
└───────────────────────────────────────────────────────────────────────────────────────────────────────┘

Modularity & DRY (Don't Repeat Yourself): Resources are partitioned into self-contained modules (modules/vpc and modules/s3), separating reusable infrastructure patterns from top-level root module orchestration.

    Immutability & State Integrity: Remote state is secured with object versioning to allow instant state restoration in the event of human error or concurrency conflict.

    Defense-in-Depth Access Controls: The S3 bucket rejects unencrypted transport via an explicit Deny bucket policy while simultaneously exposing a tailored, least-privilege IAM policy.

    Environment Isolation: Abstracting parameters into environment definition files (dev.tfvars, prod.tfvars) enables consistent infrastructure reusability across staging tiers.

Repository Structure
Plaintext

.
├── .gitignore                      # Prevents state files, caches, and live secrets from tracking
├── README.md                       # Comprehensive operational & architectural documentation
├── dev.tfvars.example              # Development variable configuration template
├── prod.tfvars.example             # Production variable configuration template
├── terraform.tfvars.example        # General reference input variable template
├── main.tf                         # Root entrypoint instantiating child modules
├── outputs.tf                      # Root outputs returning critical infrastructure IDs
├── provider.tf                     # Provider definitions, versions, and backend configuration
├── variables.tf                    # Root input variable schema declarations
├── screenshots/                    # Architectural proofs and AWS Console verification logs
└── modules/
    ├── s3/                         # S3 Remote State Storage Module
    │   ├── iam.tf                  # TLS enforcement bucket policy & least-privilege IAM policy
    │   ├── main.tf                 # S3 bucket resource, versioning, encryption, and public block
    │   ├── outputs.tf              # Exposed S3 ARNs, IDs, and IAM Policy ARNs
    │   └── variables.tf            # Configurable inputs for state bucket creation
    └── vpc/                        # Networking Tier Module
        ├── main.tf                 # AWS VPC, IGW, subnets, route tables, and route associations
        ├── outputs.tf              # Exposed network attributes (VPC ID, Subnet IDs, IGW ID)
        └── variables.tf            # CIDR ranges, AZ mappings, and environment tag s


Prerequisites & Workstation Configuration

Before executing the commands in this guide, verify that your local environment satisfies the following dependencies:

    Terraform CLI: v1.5.0 or higher installed.

    AWS CLI: v2.x installed and accessible in your system path.

    AWS IAM Permissions: An IAM user with programmatic access keys (Access Key ID and Secret Access Key) possessing administrative permissions to manage VPC, EC2, IAM, and S3 resources.

Step-by-Step Implementation Guide
Step 0: Version Control Safety Rails & AWS Authentication
1. Repository Initialization & .gitignore Configuration

Terraform creates local state caches (.terraform/), binary provider downloads, and state files (*.tfstate) containing plain-text infrastructure metadata. To prevent credential leaks and state drift conflicts, declare strict ignore patterns before running any code.
Bash

mkdir -p terraform-s3-backend-project
cd terraform-s3-backend-project
touch .gitignore

Populate .gitignore with standard Terraform exclusions:
Code snippet

# Local .terraform directories and plugin mirrors
**/.terraform/*

# Terraform runtime state files (local state must never be tracked in VCS)
*.tfstate
*.tfstate.*

# Crash logs
crash.log
crash.*.log

# Live variables files containing environment secrets or unique identifiers
*.tfvars
*.tfvars.json

# Override files
override.tf
override.tf.json
*_override.tf
*_override.tf.json

# Local CLI configuration
.terraformrc
terraform.rc

# Saved execution plans
tfplan*

    Reason: Ensures infrastructure code is safely separated from live environment variables (.tfvars), local cache dependencies, and state snapshots.

2. AWS CLI Authentication & Clock Alignment

Terraform utilizes the AWS CLI configuration located in ~/.aws/credentials to authenticate API calls.

Configure the AWS CLI:
Bash

aws configure

    AWS Access Key ID: Enter your 20-character Access Key ID (AKIA...)

    AWS Secret Access Key: Enter your 40-character Secret Access Key

    Default region name: eu-west-2 (London)

    Default output format: json

Verify authentication and identity via AWS Security Token Service (STS):
Bash

aws sts get-caller-identity

    Reason: Validates that the access key signature is accepted by AWS APIs and that your machine is operating against the correct AWS Account ID without clock-skew signature issues (SignatureDoesNotMatch).

Step 1: Modular Networking Tier (VPC Module)

The network tier establishes isolated boundaries for compute and database workloads across two Availability Zones (eu-west-2a and eu-west-2b).
1. Create the Module Files
Bash

mkdir -p modules/vpc
touch modules/vpc/variables.tf modules/vpc/main.tf modules/vpc/outputs.tf

2. Declare Variables (modules/vpc/variables.tf)
Terraform

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
  default     = ["eu-west-2a", "eu-west-2b"]
}

variable "environment" {
  description = "Deployment environment name (e.g., dev, prod)"
  type        = string
  default     = "dev"
}

3. Define Resources (modules/vpc/main.tf)
Terraform

# 1. Base VPC
resource "aws_vpc" "this" {
  cidr_block           = var.vpc_cidr
  enable_dns_hostnames = true
  enable_dns_support   = true

  tags = {
    Name        = "${var.environment}-vpc"
    Environment = var.environment
  }
}

# 2. Internet Gateway for Public Egress/Ingress
resource "aws_internet_gateway" "this" {
  vpc_id = aws_vpc.this.id

  tags = {
    Name        = "${var.environment}-igw"
    Environment = var.environment
  }
}

# 3. Public Subnet Allocation
resource "aws_subnet" "public" {
  count                   = length(var.public_subnet_cidrs)
  vpc_id                  = aws_vpc.this.id
  cidr_block              = var.public_subnet_cidrs[count.index]
  availability_zone       = var.availability_zones[count.index]
  map_public_ip_on_launch = true

  tags = {
    Name        = "${var.environment}-public-subnet-${count.index + 1}"
    Environment = var.environment
  }
}

# 4. Private Subnet Allocation
resource "aws_subnet" "private" {
  count             = length(var.private_subnet_cidrs)
  vpc_id            = aws_vpc.this.id
  cidr_block        = var.private_subnet_cidrs[count.index]
  availability_zone = var.availability_zones[count.index]

  tags = {
    Name        = "${var.environment}-private-subnet-${count.index + 1}"
    Environment = var.environment
  }
}

# 5. Public Route Table with Default Route to IGW
resource "aws_route_table" "public" {
  vpc_id = aws_vpc.this.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.this.id
  }

  tags = {
    Name        = "${var.environment}-public-rt"
    Environment = var.environment
  }
}

# 6. Public Route Table Association
resource "aws_route_table_association" "public" {
  count          = length(var.public_subnet_cidrs)
  subnet_id      = aws_subnet.public[count.index].id
  route_table_id = aws_route_table.public.id
}

# 7. Isolated Private Route Table
resource "aws_route_table" "private" {
  vpc_id = aws_vpc.this.id

  tags = {
    Name        = "${var.environment}-private-rt"
    Environment = var.environment
  }
}

# 8. Private Route Table Association
resource "aws_route_table_association" "private" {
  count          = length(var.private_subnet_cidrs)
  subnet_id      = aws_subnet.private[count.index].id
  route_table_id = aws_route_table.private.id
}

4. Define Outputs (modules/vpc/outputs.tf)
Terraform

output "vpc_id" {
  description = "The ID of the VPC"
  value       = aws_vpc.this.id
}

output "public_subnet_ids" {
  description = "List of IDs of the public subnets"
  value       = aws_subnet.public[*].id
}

output "private_subnet_ids" {
  description = "List of IDs of the private subnets"
  value       = aws_subnet.private[*].id
}

output "internet_gateway_id" {
  description = "The ID of the Internet Gateway"
  value       = aws_internet_gateway.this.id
}

    Reason: Parameterizing subnet generation via count and list indexing allows dynamic horizontal scaling across Availability Zones. Public subnets automatically route outbound traffic to the Internet Gateway, while private subnets lack default 0.0.0.0/0 egress, enforcing network isolation.

Step 2: Hardened State Storage (S3 Module)

The remote state storage module creates an S3 bucket configured specifically to satisfy cloud security compliance benchmarks for state persistence.
1. Create the Module Files
Bash

mkdir -p modules/s3
touch modules/s3/variables.tf modules/s3/main.tf modules/s3/outputs.tf

2. Declare Variables (modules/s3/variables.tf)
Terraform

variable "bucket_name" {
  description = "Globally unique name of the S3 bucket"
  type        = string
}

variable "environment" {
  description = "Deployment environment name (e.g., dev, prod)"
  type        = string
  default     = "dev"
}

variable "force_destroy" {
  description = "Allows deletion of all objects upon destroy for clean dev cleanup"
  type        = bool
  default     = false
}

3. Define Resources (modules/s3/main.tf)
Terraform

# 1. Base S3 Bucket Resource
resource "aws_s3_bucket" "this" {
  bucket        = var.bucket_name
  force_destroy = var.force_destroy

  tags = {
    Name        = var.bucket_name
    Environment = var.environment
  }
}

# 2. Bucket Versioning (Preserves State Snapshots)
resource "aws_s3_bucket_versioning" "this" {
  bucket = aws_s3_bucket.this.id

  versioning_configuration {
    status = "Enabled"
  }
}

# 3. Default Server-Side Encryption (SSE-S3 AES-256)
resource "aws_s3_bucket_server_side_encryption_configuration" "this" {
  bucket = aws_s3_bucket.this.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

# 4. Public Access Block (Total Ingress Denial)
resource "aws_s3_bucket_public_access_block" "this" {
  bucket = aws_s3_bucket.this.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

4. Define Initial Outputs (modules/s3/outputs.tf)
Terraform

output "bucket_id" {
  description = "The name/ID of the S3 bucket"
  value       = aws_s3_bucket.this.id
}

output "bucket_arn" {
  description = "The Amazon Resource Name (ARN) of the bucket"
  value       = aws_s3_bucket.this.arn
}

output "bucket_domain_name" {
  description = "The domain name of the bucket"
  value       = aws_s3_bucket.this.bucket_domain_name
}

    Reason: Object versioning allows rolling back state files if corruption occurs during an interrupted apply. Server-side AES-256 protects stored resource secrets at rest, and the public access block prevents accidental exposure across all four S3 evaluation vectors.

Step 3: Access Control & IAM Security Policies

To secure state storage, access policies must protect state operations at both the storage resource boundary and the identity boundary.
1. Define Policies (modules/s3/iam.tf)
Bash

touch modules/s3/iam.tf

Populate modules/s3/iam.tf:
Terraform

# 1. Bucket Policy: Enforce Encrypted HTTPS/TLS Transport Only
data "aws_iam_policy_document" "enforce_tls" {
  statement {
    sid       = "EnforceTLSRequestsOnly"
    effect    = "Deny"
    actions   = ["s3:*"]
    resources = [
      aws_s3_bucket.this.arn,
      "${aws_s3_bucket.this.arn}/*"
    ]

    principals {
      type        = "*"
      identifiers = ["*"]
    }

    condition {
      test     = "Bool"
      variable = "aws:SecureTransport"
      values   = ["false"]
    }
  }
}

resource "aws_s3_bucket_policy" "this" {
  bucket = aws_s3_bucket.this.id
  policy = data.aws_iam_policy_document.enforce_tls.json

  depends_on = [aws_s3_bucket_public_access_block.this]
}

# 2. Identity-Based IAM Policy: Least Privilege for Terraform Operators
data "aws_iam_policy_document" "terraform_state_access" {
  statement {
    sid    = "ListBucketForStateOperations"
    effect = "Allow"
    actions = [
      "s3:ListBucket",
      "s3:GetBucketLocation"
    ]
    resources = [aws_s3_bucket.this.arn]
  }

  statement {
    sid    = "ReadWriteStateObjects"
    effect = "Allow"
    actions = [
      "s3:GetObject",
      "s3:PutObject",
      "s3:DeleteObject"
    ]
    resources = ["${aws_s3_bucket.this.arn}/*"]
  }
}

resource "aws_iam_policy" "terraform_state_access" {
  name        = "${var.bucket_name}-state-access-policy"
  description = "IAM policy granting minimum necessary permissions to manage Terraform state in ${var.bucket_name}"
  policy      = data.aws_iam_policy_document.terraform_state_access.json

  tags = {
    Environment = var.environment
  }
}

2. Update modules/s3/outputs.tf

Append the policy ARN to modules/s3/outputs.tf:
Terraform

output "iam_policy_arn" {
  description = "The ARN of the IAM policy granting state management access"
  value       = aws_iam_policy.terraform_state_access.arn
}

    Reason: The resource bucket policy enforces in-transit encryption by rejecting insecure HTTP requests. The standalone identity policy implements the Principle of Least Privilege, granting only the four S3 API actions required by Terraform to manage state objects.

Step 4: Root Module Integration & Variable Parameterization

The root module connects the child modules, accepts external parameter configurations, and exposes the required deployment outputs.
1. Create Root Configurations
Bash

touch provider.tf variables.tf main.tf outputs.tf terraform.tfvars.example

2. Configure provider.tf (Initial Local State Phase)
Terraform

terraform {
  required_version = ">= 1.5.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }

  # NOTE: The backend "s3" block is declared in Step 6
  # after the physical S3 bucket is provisioned in AWS.
}

provider "aws" {
  region = var.aws_region
}

3. Configure variables.tf
Terraform

variable "aws_region" {
  description = "AWS region for provisioning resources"
  type        = string
  default     = "eu-west-2"
}

variable "environment" {
  description = "Target deployment environment"
  type        = string
  default     = "dev"
}

variable "vpc_cidr" {
  description = "CIDR block for the root VPC"
  type        = string
  default     = "10.0.0.0/16"
}

variable "public_subnet_cidrs" {
  description = "CIDRs for public subnets"
  type        = list(string)
  default     = ["10.0.1.0/24", "10.0.2.0/24"]
}

variable "private_subnet_cidrs" {
  description = "CIDRs for private subnets"
  type        = list(string)
  default     = ["10.0.10.0/24", "10.0.20.0/24"]
}

variable "availability_zones" {
  description = "Availability zones for subnet allocation"
  type        = list(string)
  default     = ["eu-west-2a", "eu-west-2b"]
}

variable "state_bucket_name" {
  description = "Globally unique name for the Terraform state S3 bucket"
  type        = string
}

4. Configure main.tf
Terraform

module "s3_backend" {
  source = "./modules/s3"

  bucket_name   = var.state_bucket_name
  environment   = var.environment
  force_destroy = true
}

module "vpc" {
  source = "./modules/vpc"

  vpc_cidr             = var.vpc_cidr
  public_subnet_cidrs  = var.public_subnet_cidrs
  private_subnet_cidrs = var.private_subnet_cidrs
  availability_zones   = var.availability_zones
  environment          = var.environment
}

5. Configure outputs.tf
Terraform

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

6. Configure Local Parameters & Tracking Templates

Create the live local parameter file (choose a globally unique bucket name):
Bash

cat <<EOF> terraform.tfvars
aws_region           = "eu-west-2"
environment          = "dev"
vpc_cidr             = "10.0.0.0/16"
public_subnet_cidrs  = ["10.0.1.0/24", "10.0.2.0/24"]
private_subnet_cidrs = ["10.0.10.0/24", "10.0.20.0/24"]
availability_zones   = ["eu-west-2a", "eu-west-2b"]
state_bucket_name    = "tf-state-remote-backend-dev-unique01"
EOF

Copy this layout to a reference template:
Bash

cat <<EOF> terraform.tfvars.example
aws_region           = "eu-west-2"
environment          = "dev"
vpc_cidr             = "10.0.0.0/16"
public_subnet_cidrs  = ["10.0.1.0/24", "10.0.2.0/24"]
private_subnet_cidrs = ["10.0.10.0/24", "10.0.20.0/24"]
availability_zones   = ["eu-west-2a", "eu-west-2b"]
state_bucket_name    = "your-unique-tf-state-bucket-name"
EOF

Step 5: Provisioning Initial Infrastructure via Locked Plan

Because the remote backend bucket cannot exist before it is provisioned, bootstrap the infrastructure using local state.
1. Initialize Working Directory
Bash

terraform init

    Reason: Downloads the required provider plugins (hashicorp/aws) and indexes local child modules.

2. Generate and Lock the Execution Plan
Bash

terraform plan -out=tfplan

    Reason: Captures an exact snapshot of the execution graph and planned changes. Outputting to a binary file (-out=tfplan) prevents race conditions and configuration drift between plan review and execution.

3. Apply the Locked Plan
Bash

terraform apply tfplan

    Reason: Executes the planned changes without prompting for manual confirmation. Terraform provisions the VPC, Internet Gateway, Subnets, Route Tables, and the S3 State Bucket (18 resources in total).

Step 6: Remote State Backend Migration

With the physical S3 bucket now created in eu-west-2, local state can be migrated to the remote backend.
1. Configure the Backend Block (provider.tf)

Edit provider.tf to uncomment/add the backend "s3" block (using your chosen bucket name):
Terraform

terraform {
  required_version = ">= 1.5.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }

  backend "s3" {
    bucket  = "tf-state-remote-backend-dev-unique01"
    key     = "dev/terraform.tfstate"
    region  = "eu-west-2"
    encrypt = true
  }
}

provider "aws" {
  region = var.aws_region
}

    Reason: Informs Terraform that the single source of truth for infrastructure state is now located in Amazon S3 rather than the local file system.

2. Run Backend Migration
Bash

terraform init -migrate-state

When prompted:
Plaintext

Do you want to copy existing state to the new backend?
  Enter a value: yes

    Reason: The -migrate-state flag instructs Terraform to read the local terraform.tfstate file, securely transfer the infrastructure records to dev/terraform.tfstate in the S3 bucket, and update local metadata to prevent duplicate applies.

Step 7: Testing Multi-Environment Separation (Dev vs. Prod)

To verify that the modular configurations can be deployed across multiple environments without code duplication, validate them against separate environment definitions.
1. Create Dedicated Environment Definitions

Create dev.tfvars:
Terraform

aws_region           = "eu-west-2"
environment          = "dev"
vpc_cidr             = "10.0.0.0/16"
public_subnet_cidrs  = ["10.0.1.0/24", "10.0.2.0/24"]
private_subnet_cidrs = ["10.0.10.0/24", "10.0.20.0/24"]
availability_zones   = ["eu-west-2a", "eu-west-2b"]
state_bucket_name    = "tf-state-remote-backend-dev-unique01"

Create prod.tfvars:
Terraform

aws_region           = "eu-west-2"
environment          = "prod"
vpc_cidr             = "10.50.0.0/16"
public_subnet_cidrs  = ["10.50.1.0/24", "10.50.2.0/24"]
private_subnet_cidrs = ["10.50.10.0/24", "10.50.20.0/24"]
availability_zones   = ["eu-west-2a", "eu-west-2b"]
state_bucket_name    = "tf-state-remote-backend-prod-unique01"

Create templates for version tracking:
Bash

cp dev.tfvars dev.tfvars.example
cp prod.tfvars prod.tfvars.example

2. Test Production Execution Preview

Execute an isolated plan against the production variable definitions:
Bash

terraform plan -var-file=prod.tfvars

3. Analyzing Plan Mechanics

The generated plan displays:
Plaintext

Plan: 17 to add, 1 to change, 17 to destroy.

    Explanation: Because our active Terraform backend context is locked to the dev state file (dev/terraform.tfstate), passing prod.tfvars signals that the existing infrastructure should be refactored to match production values (CIDR 10.50.0.0/16, tags prod-vpc, bucket tf-state-remote-backend-prod-unique01).

    This proves that the underlying modules are decoupled from environment-specific configurations.

    Operational Note: In multi-environment setups, separate environments should run in distinct state paths (e.g., using Terraform workspaces or distinct backend key paths like prod/terraform.tfstate) to manage their lifecycles independently.

Inputs & Outputs Reference
Root Input Variables
Variable	Description	Type	Default Value	Required
aws_region	AWS region targeted for infrastructure deployment	string	"eu-west-2"	No
environment	Infrastructure stage prefix/tag identifier	string	"dev"	No
vpc_cidr	Primary IPv4 address range for the VPC	string	"10.0.0.0/16"	No
public_subnet_cidrs	Subnet CIDR allocations for internet-accessible workloads	list(string)	["10.0.1.0/24", "10.0.2.0/24"]	No
private_subnet_cidrs	Subnet CIDR allocations for isolated backend workloads	list(string)	["10.0.10.0/24", "10.0.20.0/24"]	No
availability_zones	Target AWS Availability Zones for subnet placement	list(string)	["eu-west-2a", "eu-west-2b"]	No
state_bucket_name	Name of the state S3 bucket (globally unique)	string	N/A	Yes
Root Outputs
Output Name	Description	Exported Attribute
vpc_id	Identifier of the provisioned AWS Virtual Private Cloud	module.vpc.vpc_id
public_subnet_ids	List of IDs associated with the public subnets	module.vpc.public_subnet_ids
private_subnet_ids	List of IDs associated with the private subnets	module.vpc.private_subnet_ids
state_bucket_name	Resolved globally unique name of the S3 state storage bucket	module.s3_backend.bucket_id
state_bucket_arn	Amazon Resource Name (ARN) identifying the state bucket	module.s3_backend.bucket_arn
state_iam_policy_arn	ARN of the least-privilege IAM policy created for state access	module.s3_backend.iam_policy_arn
State Management & Infrastructure Verification

Architecture validation records:

    State Management Migration:

        Terminal records documenting terraform init -migrate-state execution with approval confirmation (yes) and the message: Successfully configured the backend "s3"!.

        AWS S3 Console confirmation displaying the dev/terraform.tfstate object stored inside the state bucket.

    Networking Infrastructure (VPC Module):

        AWS VPC Console view in eu-west-2 showing dev-vpc (10.0.0.0/16) alongside its associated subnets, route tables, and Internet Gateway mapping in the Resource Map tab.   

    Storage Security Controls (S3 Module):

        S3 Console Properties view verifying that Bucket Versioning is Enabled and Default encryption is set to SSE-S3 (AES-256).

        S3 Console Permissions view displaying Block all public access set to On and the TLS enforcement policy attached.
