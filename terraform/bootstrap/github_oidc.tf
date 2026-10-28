locals {
  github_oidc_host = "token.actions.githubusercontent.com"
  github_repo_path = "${var.github_owner}/${var.github_repo}"

  # Exact sub claims (no wildcards). GitHub's default formats:
  #   pull_request:   repo:OWNER/REPO:pull_request
  #   branch push:    repo:OWNER/REPO:ref:refs/heads/BRANCH
  #   environment:    repo:OWNER/REPO:environment:NAME
  # Note: when a job declares `environment:`, GitHub sends the environment
  # form of sub, NOT the ref form - so both are listed for the apply role.
  plan_subjects = [
    "repo:${local.github_repo_path}:pull_request",
  ]

  apply_subjects = compact([
    "repo:${local.github_repo_path}:ref:refs/heads/${var.github_apply_branch}",
    var.github_apply_environment == null ? "" : "repo:${local.github_repo_path}:environment:${var.github_apply_environment}",
  ])
}

# One per AWS account. AWS validates GitHub's certificate against its own
# trusted CA library, so no thumbprint is needed.
resource "aws_iam_openid_connect_provider" "github" {
  url            = "https://${local.github_oidc_host}"
  client_id_list = ["sts.amazonaws.com"]
}

# ---------- Trust policies ----------

data "aws_iam_policy_document" "plan_trust" {
  statement {
    sid     = "GitHubPullRequests"
    effect  = "Allow"
    actions = ["sts:AssumeRoleWithWebIdentity"]

    principals {
      type        = "Federated"
      identifiers = [aws_iam_openid_connect_provider.github.arn]
    }

    condition {
      test     = "StringEquals"
      variable = "${local.github_oidc_host}:aud"
      values   = ["sts.amazonaws.com"]
    }

    condition {
      test     = "StringEquals"
      variable = "${local.github_oidc_host}:sub"
      values   = local.plan_subjects
    }
  }
}

data "aws_iam_policy_document" "apply_trust" {
  statement {
    sid     = "GitHubMainOrEnvironment"
    effect  = "Allow"
    actions = ["sts:AssumeRoleWithWebIdentity"]

    principals {
      type        = "Federated"
      identifiers = [aws_iam_openid_connect_provider.github.arn]
    }

    condition {
      test     = "StringEquals"
      variable = "${local.github_oidc_host}:aud"
      values   = ["sts.amazonaws.com"]
    }

    condition {
      test     = "StringEquals"
      variable = "${local.github_oidc_host}:sub"
      values   = local.apply_subjects
    }
  }
}

# ---------- nw-gha-plan (read-only) ----------

resource "aws_iam_role" "gha_plan" {
  name                 = "nw-gha-plan"
  description          = "GitHub Actions: terraform plan on pull requests in ${local.github_repo_path}. Read-only."
  assume_role_policy   = data.aws_iam_policy_document.plan_trust.json
  max_session_duration = 3600
}

resource "aws_iam_role_policy_attachment" "gha_plan_readonly" {
  role       = aws_iam_role.gha_plan.name
  policy_arn = "arn:aws:iam::aws:policy/ReadOnlyAccess"
}

# ReadOnlyAccess already allows reading state. The one write plan needs is the
# S3 lock file (<key>.tflock) that use_lockfile creates and removes. This is
# scoped to *.tflock objects only, so plan can never modify state itself.
data "aws_iam_policy_document" "gha_plan_state_lock" {
  statement {
    sid    = "ManageStateLockFilesOnly"
    effect = "Allow"
    actions = [
      "s3:PutObject",
      "s3:DeleteObject",
    ]
    resources = ["${aws_s3_bucket.tfstate.arn}/*.tflock"]
  }
}

resource "aws_iam_role_policy" "gha_plan_state_lock" {
  name   = "terraform-state-lock"
  role   = aws_iam_role.gha_plan.id
  policy = data.aws_iam_policy_document.gha_plan_state_lock.json
}

# ---------- nw-gha-apply ----------

resource "aws_iam_role" "gha_apply" {
  name                 = "nw-gha-apply"
  description          = "GitHub Actions: terraform apply from ${var.github_apply_branch} or the ${coalesce(var.github_apply_environment, "(none)")} environment in ${local.github_repo_path}."
  assume_role_policy   = data.aws_iam_policy_document.apply_trust.json
  max_session_duration = 3600
}

# Broad on purpose for now: apply has to create whatever later stacks define.
# Tighten to a scoped policy once the set of managed services is known (#3).
resource "aws_iam_role_policy_attachment" "gha_apply_admin" {
  #checkov:skip=CKV_AWS_274:Apply role creates all later stacks; trust limited to main/production (ADR 0012). Scope down in #3
  role       = aws_iam_role.gha_apply.name
  policy_arn = "arn:aws:iam::aws:policy/AdministratorAccess"
}
