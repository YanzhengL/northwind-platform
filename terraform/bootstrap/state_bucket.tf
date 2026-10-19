locals {
  state_bucket_name = "nw-${var.bucket_suffix}-tfstate"
}

resource "aws_s3_bucket" "tfstate" {
  #checkov:skip=CKV_AWS_145:SSE-S3 chosen over KMS, see README "SSE-S3 instead of KMS"
  #checkov:skip=CKV_AWS_144:Single-region by SCP (eu-west-2); versioning + prevent_destroy cover recovery
  #checkov:skip=CKV_AWS_18:Access logs need a second bucket; CloudTrail covers management events
  #checkov:skip=CKV2_AWS_62:No consumer for bucket events
  bucket = local.state_bucket_name

  # Losing this bucket means losing all Terraform state. Removing this block
  # is a deliberate, reviewable act.
  lifecycle {
    prevent_destroy = true
  }
}

# Every write keeps the previous version, so a bad apply or a corrupt state
# file can be rolled back.
resource "aws_s3_bucket_versioning" "tfstate" {
  bucket = aws_s3_bucket.tfstate.id

  versioning_configuration {
    status = "Enabled"
  }
}

# SSE-S3 (AES256). See README.md "Decision: SSE-S3 instead of KMS".
resource "aws_s3_bucket_server_side_encryption_configuration" "tfstate" {
  bucket = aws_s3_bucket.tfstate.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

resource "aws_s3_bucket_public_access_block" "tfstate" {
  bucket = aws_s3_bucket.tfstate.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# Disable ACLs entirely; access is controlled by IAM and the bucket policy only.
resource "aws_s3_bucket_ownership_controls" "tfstate" {
  bucket = aws_s3_bucket.tfstate.id

  rule {
    object_ownership = "BucketOwnerEnforced"
  }
}

# Keep storage from growing forever: old state versions expire, but the
# newest few are always kept regardless of age.
resource "aws_s3_bucket_lifecycle_configuration" "tfstate" {
  bucket = aws_s3_bucket.tfstate.id

  rule {
    id     = "expire-old-state-versions"
    status = "Enabled"

    filter {}

    noncurrent_version_expiration {
      noncurrent_days           = var.state_noncurrent_version_days
      newer_noncurrent_versions = 10
    }

    abort_incomplete_multipart_upload {
      days_after_initiation = 7
    }
  }

  depends_on = [aws_s3_bucket_versioning.tfstate]
}

# TLS-only: deny any request made over plain HTTP, and any TLS older than 1.2.
data "aws_iam_policy_document" "tfstate_tls_only" {
  statement {
    sid     = "DenyInsecureTransport"
    effect  = "Deny"
    actions = ["s3:*"]

    principals {
      type        = "*"
      identifiers = ["*"]
    }

    resources = [
      aws_s3_bucket.tfstate.arn,
      "${aws_s3_bucket.tfstate.arn}/*",
    ]

    condition {
      test     = "Bool"
      variable = "aws:SecureTransport"
      values   = ["false"]
    }
  }

  statement {
    sid     = "DenyOutdatedTLS"
    effect  = "Deny"
    actions = ["s3:*"]

    principals {
      type        = "*"
      identifiers = ["*"]
    }

    resources = [
      aws_s3_bucket.tfstate.arn,
      "${aws_s3_bucket.tfstate.arn}/*",
    ]

    condition {
      test     = "NumericLessThan"
      variable = "s3:TlsVersion"
      values   = ["1.2"]
    }
  }
}

resource "aws_s3_bucket_policy" "tfstate" {
  bucket = aws_s3_bucket.tfstate.id
  policy = data.aws_iam_policy_document.tfstate_tls_only.json

  # Public access block must exist first, otherwise S3 can reject the policy.
  depends_on = [aws_s3_bucket_public_access_block.tfstate]
}
