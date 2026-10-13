# 1. Bucket Policy: Enforce HTTPS / TLS requests only
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

  # Ensure public access block is applied before attaching the bucket policy
  depends_on = [aws_s3_bucket_public_access_block.this]
}

# 2. IAM Policy: Least-privilege permissions for Terraform operators/roles
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
