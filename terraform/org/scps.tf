locals {
  cloudtrail_bucket_arn = "arn:${data.aws_partition.current.partition}:s3:::${local.cloudtrail_bucket_name}"
}

# ---------- Region lock (ADR 0022) ----------

data "aws_iam_policy_document" "region_lock" {
  statement {
    sid    = "DenyOutsideAllowedRegion"
    effect = "Deny"
    # NotAction: global services are served from us-east-1, so denying them would break IAM, billing and support.
    not_actions = var.region_lock_exempt_actions
    resources   = ["*"]

    condition {
      test     = "StringNotEquals"
      variable = "aws:RequestedRegion"
      values   = [var.region]
    }
  }
}

# ---------- Baseline guardrails (ADR 0021) ----------

# One policy for the remaining guardrails: a target can have at most 5 SCPs,
# and FullAWSAccess already uses one.
data "aws_iam_policy_document" "baseline" {
  statement {
    sid       = "DenyLeaveOrganization"
    effect    = "Deny"
    actions   = ["organizations:LeaveOrganization"]
    resources = ["*"]
  }

  # Even an admin in a member account can't stop, change or delete a trail. The org
  # trail is already read-only in members; this also covers member-level trails and
  # a future delegated-admin account (#4). Log files are protected by the bucket, not here.
  statement {
    sid    = "DenyCloudTrailTampering"
    effect = "Deny"
    actions = [
      "cloudtrail:StopLogging",
      "cloudtrail:DeleteTrail",
      "cloudtrail:UpdateTrail",
      "cloudtrail:PutEventSelectors",
    ]
    resources = ["*"]
  }

  # Defence in depth: still protects the log bucket if it moves to shared-services (#4).
  statement {
    sid    = "DenyLogBucketChanges"
    effect = "Deny"
    actions = [
      "s3:DeleteBucket",
      "s3:DeleteBucketPolicy",
      "s3:PutBucketPolicy",
      "s3:PutBucketVersioning",
      "s3:PutLifecycleConfiguration",
    ]
    resources = [local.cloudtrail_bucket_arn]
  }

  # Root can't be limited by IAM; day-to-day access is through Identity Center.
  statement {
    sid       = "DenyRootUser"
    effect    = "Deny"
    actions   = ["*"]
    resources = ["*"]

    condition {
      test     = "StringLike"
      variable = "aws:PrincipalArn"
      values   = ["arn:${data.aws_partition.current.partition}:iam::*:root"]
    }
  }
}

# ---------- Policies and attachments ----------

locals {
  scps = {
    "nw-region-lock" = {
      description = "Deny all actions outside ${var.region}, except global services (ADR 0022)."
      json        = data.aws_iam_policy_document.region_lock.minified_json
    }
    "nw-baseline-guardrails" = {
      description = "Deny leaving the org, CloudTrail tampering and root use (ADR 0021)."
      json        = data.aws_iam_policy_document.baseline.minified_json
    }
  }

  # Every (policy, OU) pair, so adding "Infrastructure" to scp_target_ous attaches both policies there.
  scp_attachments = {
    for pair in setproduct(keys(local.scps), var.scp_target_ous) :
    "${pair[0]}/${pair[1]}" => { policy = pair[0], ou = pair[1] }
  }
}

resource "aws_organizations_policy" "scp" {
  for_each = local.scps

  name        = each.key
  description = each.value.description
  type        = "SERVICE_CONTROL_POLICY"
  # Minified because SCPs are limited to 5,120 characters.
  content = each.value.json

  depends_on = [aws_organizations_organization.this]
}

resource "aws_organizations_policy_attachment" "scp" {
  for_each = local.scp_attachments

  policy_id = aws_organizations_policy.scp[each.value.policy].id
  target_id = aws_organizations_organizational_unit.this[each.value.ou].id
}
