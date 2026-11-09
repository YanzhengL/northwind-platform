#!/usr/bin/env bash
# Registers account IDs, the organization ID, account emails and SSO usernames as log masks.
# Shared by plan and apply so the two jobs can never mask different things (ADR 0032).
# Values come from live AWS, so a new member account is masked with no workflow change.
# Any failed lookup stops the job here, before Terraform has printed anything.
set -euo pipefail

store_id=$(aws sso-admin list-instances --query 'Instances[0].IdentityStoreId' --output text)

values=$(
  aws sts get-caller-identity --query Account --output text
  aws organizations describe-organization --query Organization.Id --output text
  aws organizations list-accounts --query 'Accounts[].[Id,Email]' --output text | tr '\t' '\n'
  aws identitystore list-users --identity-store-id "$store_id" \
    --query 'Users[].UserName' --output text | tr '\t' '\n'
)

while IFS= read -r value; do
  if [ -n "$value" ]; then
    echo "::add-mask::$value"
  fi
done <<< "$values"
