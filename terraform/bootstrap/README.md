# terraform/bootstrap

One-time foundation for everything else in this repo:

- S3 bucket `nw-<suffix>-tfstate` for Terraform state (versioned, encrypted, private, TLS-only)
- GitHub Actions OIDC provider (`token.actions.githubusercontent.com`)
- `nw-gha-plan` role: read-only, assumable only by `pull_request` runs of this repo
- `nw-gha-apply` role: assumable only from `refs/heads/main` or the configured GitHub environment of this repo

This stack is applied **by a human** with SSO credentials (`AWS_PROFILE=admin`), not by CI.

## Backend: why `backend.tf` has no bucket name

This stack's own state lives in the bucket it creates, under `bootstrap/terraform.tfstate`.

`backend.tf` leaves out `bucket` on purpose (partial backend configuration):

- **Backend blocks can't use variables.** Terraform reads the backend during `init`, before variables are evaluated. So `bucket = "nw-${var.bucket_suffix}-tfstate"` is not allowed.
- **The bucket name contains the account ID.** That stays out of git.

Each environment supplies the name at `init` time:

| Where | How the bucket name is supplied |
|---|---|
| Laptop | `backend.s3.tfbackend` file (gitignored by `*.tfbackend`) |
| GitHub Actions | `-backend-config="bucket=${{ secrets.TF_STATE_BUCKET }}"` |

## Decision: SSE-S3 instead of KMS

State is encrypted with **SSE-S3 (AES256)**, not SSE-KMS.

- **Enough for the threat model.** State is already protected by IAM, the bucket policy, Block Public Access and TLS-only access. Encryption at rest is a baseline control here, not the main access boundary.
- **No key policy to manage.** With KMS, every role that reads state (`nw-gha-plan`, `nw-gha-apply`, admins) also needs `kms:Decrypt` / `kms:GenerateDataKey`. That is a second permission system to get right, and a misconfigured key policy can lock everyone out of state.
- **Cost.** A customer-managed KMS key is about $1/month plus request charges; SSE-S3 is free.

**Revisit if:** compliance requires customer-managed keys, key rotation control, or CloudTrail records of each decrypt; or state must be shared across accounts with separate key control. Switching later is a change to `aws_s3_bucket_server_side_encryption_configuration` plus KMS grants for the roles.

## Trust model

| Role | Allowed `sub` claims (exact match, no wildcards) |
|---|---|
| `nw-gha-plan` | `repo:<owner>/<repo>:pull_request` |
| `nw-gha-apply` | `repo:<owner>/<repo>:ref:refs/heads/main`, `repo:<owner>/<repo>:environment:production` |

`aud` must be `sts.amazonaws.com` for both. A job that sets `environment:` receives the environment form of `sub`, which is why the apply role lists both.

## Usage

Prerequisites: `aws sso login --profile admin` and `export AWS_PROFILE=admin`, run from this directory.

### Day-to-day (bootstrap already applied)

```bash
cp terraform.tfvars.example terraform.tfvars                   # fill in values
echo 'bucket = "nw-<suffix>-tfstate"' > backend.s3.tfbackend   # gitignored
terraform init -backend-config=backend.s3.tfbackend
terraform plan                                                 # expect: No changes
```

### First-ever run (state bucket does not exist yet)

The bucket that will hold the state is created by this stack, so the first apply has to use local state.

```bash
cp terraform.tfvars.example terraform.tfvars   # fill in values

# 1. Apply with local state. Move backend.tf aside so init doesn't look for a bucket that doesn't exist yet.
mv backend.tf backend.tf.off
terraform init
terraform apply

# 2. Record the bucket name while state is still local (terraform output fails once backend.tf is back).
echo "bucket = \"$(terraform output -raw state_bucket_name)\"" > backend.s3.tfbackend

# 3. Restore the backend and copy the state into S3 (answer "yes").
mv backend.tf.off backend.tf
terraform init -backend-config=backend.s3.tfbackend -migrate-state

# 4. Confirm, then delete the local copies. S3 is now the source of truth.
terraform plan                                 # expect: No changes
rm terraform.tfstate terraform.tfstate.backup
```
