data "aws_caller_identity" "current" {}
data "aws_partition" "current" {}

locals {
  cloudtrail_bucket_name = "nw-${var.bucket_suffix}-cloudtrail"
  trail_name             = "nw-org-trail"
  # Built by hand because the bucket policy must name the trail before the trail exists.
  trail_arn = "arn:${data.aws_partition.current.partition}:cloudtrail:${var.region}:${data.aws_caller_identity.current.account_id}:trail/${local.trail_name}"
}

# ---------- Log bucket (management account for now, ADR 0020 / #4) ----------

resource "aws_s3_bucket" "cloudtrail" {
  #checkov:skip=CKV_AWS_145:SSE-S3 is enough for audit logs here, same reasoning as the state bucket
  #checkov:skip=CKV_AWS_144:Single-region by SCP (eu-west-2); versioning + prevent_destroy cover recovery
  #checkov:skip=CKV_AWS_18:Access logs on the access-log bucket would need a third bucket
  #checkov:skip=CKV2_AWS_62:No consumer for bucket events
  bucket = local.cloudtrail_bucket_name

  # The audit trail must outlive any mistake in this stack.
  lifecycle {
    prevent_destroy = true
  }
}

# Overwritten or deleted log files can be recovered from older versions.
resource "aws_s3_bucket_versioning" "cloudtrail" {
  bucket = aws_s3_bucket.cloudtrail.id

  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "cloudtrail" {
  bucket = aws_s3_bucket.cloudtrail.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

resource "aws_s3_bucket_public_access_block" "cloudtrail" {
  bucket = aws_s3_bucket.cloudtrail.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# Disable ACLs; CloudTrail works with BucketOwnerEnforced.
resource "aws_s3_bucket_ownership_controls" "cloudtrail" {
  bucket = aws_s3_bucket.cloudtrail.id

  rule {
    object_ownership = "BucketOwnerEnforced"
  }
}

# Logs grow every day; expiring them keeps storage cost at pennies.
resource "aws_s3_bucket_lifecycle_configuration" "cloudtrail" {
  bucket = aws_s3_bucket.cloudtrail.id

  rule {
    id     = "expire-old-logs"
    status = "Enabled"

    filter {}

    expiration {
      days = var.cloudtrail_log_retention_days
    }

    noncurrent_version_expiration {
      noncurrent_days = 30
    }

    abort_incomplete_multipart_upload {
      days_after_initiation = 7
    }
  }

  depends_on = [aws_s3_bucket_versioning.cloudtrail]
}

data "aws_iam_policy_document" "cloudtrail_bucket" {
  # CloudTrail checks the bucket ACL before its first write.
  statement {
    sid       = "AWSCloudTrailAclCheck"
    effect    = "Allow"
    actions   = ["s3:GetBucketAcl"]
    resources = [aws_s3_bucket.cloudtrail.arn]

    principals {
      type        = "Service"
      identifiers = ["cloudtrail.amazonaws.com"]
    }

    # Only this trail, so another account's trail can't use the bucket (confused deputy).
    condition {
      test     = "StringEquals"
      variable = "aws:SourceArn"
      values   = [local.trail_arn]
    }
  }

  # An org trail writes management-account logs under AWSLogs/<account-id>/
  # and member-account logs under AWSLogs/<org-id>/.
  statement {
    sid     = "AWSCloudTrailWrite"
    effect  = "Allow"
    actions = ["s3:PutObject"]
    resources = [
      "${aws_s3_bucket.cloudtrail.arn}/AWSLogs/${data.aws_caller_identity.current.account_id}/*",
      "${aws_s3_bucket.cloudtrail.arn}/AWSLogs/${aws_organizations_organization.this.id}/*",
    ]

    principals {
      type        = "Service"
      identifiers = ["cloudtrail.amazonaws.com"]
    }

    condition {
      test     = "StringEquals"
      variable = "aws:SourceArn"
      values   = [local.trail_arn]
    }
  }

  # TLS-only, same as the state bucket.
  statement {
    sid     = "DenyInsecureTransport"
    effect  = "Deny"
    actions = ["s3:*"]
    resources = [
      aws_s3_bucket.cloudtrail.arn,
      "${aws_s3_bucket.cloudtrail.arn}/*",
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

resource "aws_s3_bucket_policy" "cloudtrail" {
  bucket = aws_s3_bucket.cloudtrail.id
  policy = data.aws_iam_policy_document.cloudtrail_bucket.json

  # Public access block must exist first, otherwise S3 can reject the policy.
  depends_on = [aws_s3_bucket_public_access_block.cloudtrail]
}

# ---------- Organization trail ----------

resource "aws_cloudtrail" "org" {
  #checkov:skip=CKV_AWS_35:SSE-S3 on the bucket; a KMS key adds ~$1/month and a key policy for every reader
  #checkov:skip=CKV2_AWS_10:CloudWatch Logs delivery costs per GB; S3 + Athena is enough for this scale
  #checkov:skip=CKV_AWS_252:No SNS consumer for log delivery notifications
  name           = local.trail_name
  s3_bucket_name = aws_s3_bucket.cloudtrail.id

  # One trail logs every account in the org, including accounts created later.
  is_organization_trail = true
  # Multi-region even with the region lock: denied attempts in other regions are exactly what we want to see.
  is_multi_region_trail         = true
  include_global_service_events = true
  # Digest files prove log files weren't altered after delivery.
  enable_log_file_validation = true

  # Trusted access for CloudTrail and the bucket policy must exist before the first write.
  depends_on = [
    aws_organizations_organization.this,
    aws_s3_bucket_policy.cloudtrail,
  ]
}
