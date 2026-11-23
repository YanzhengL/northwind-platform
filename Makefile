# Northwind Platform - one entry point for every routine action.
# Stub targets print what they will do; replace them as each milestone lands.
SHELL := /bin/bash
ENV ?= dev
TF_DIR := terraform/envs/$(ENV)

# Make ignores an unknown variable, so env=shared would silently run against the default ENV.
ifeq ($(origin env),command line)
$(error Use ENV=$(env), not env=$(env))
endif

.PHONY: help bootstrap bootstrap-plan bootstrap-check env-guard env-init up down teardown-check plan apply drill-1 drill-2 drill-3 drill-4 drill-5 diagram lint test tools-update

help: ## Show targets
	@grep -E '^[a-zA-Z0-9_-]+:.*?## ' $(MAKEFILE_LIST) | awk 'BEGIN {FS = ":.*?## "}; {printf "  %-14s %s\n", $$1, $$2}'

BOOTSTRAP_DIR := terraform/bootstrap
BOOTSTRAP_PROFILE ?= nw-management

# Bootstrap is applied by a human with SSO, never by CI, so pin the profile for these targets only.
bootstrap bootstrap-plan bootstrap-check: export AWS_PROFILE := $(BOOTSTRAP_PROFILE)

# Fail fast with a clear message instead of a cryptic Terraform/backend error.
bootstrap-check:
	@test -f $(BOOTSTRAP_DIR)/terraform.tfvars || { echo "Missing $(BOOTSTRAP_DIR)/terraform.tfvars - copy terraform.tfvars.example and fill it in."; exit 1; }
	@test -f $(BOOTSTRAP_DIR)/backend.s3.tfbackend || { echo "Missing $(BOOTSTRAP_DIR)/backend.s3.tfbackend - first-ever run? Follow 'First-ever run' in $(BOOTSTRAP_DIR)/README.md."; exit 1; }
	@aws sts get-caller-identity > /dev/null 2>&1 || { echo "No valid AWS session for profile '$(AWS_PROFILE)' - run: aws sso login --profile $(AWS_PROFILE)"; exit 1; }
	terraform -chdir=$(BOOTSTRAP_DIR) init -input=false -backend-config=backend.s3.tfbackend

bootstrap-plan: bootstrap-check ## Plan the bootstrap stack (expect: No changes)
	terraform -chdir=$(BOOTSTRAP_DIR) plan

# Apply prompts for "yes" after showing the plan - that prompt is the review gate.
bootstrap: bootstrap-check ## Apply state bucket + GitHub OIDC roles (after the first-ever run)
	terraform -chdir=$(BOOTSTRAP_DIR) apply

ENV_PROFILE ?= nw-$(ENV)
STATE_PROFILE ?= nw-management

# An allowlist, so a typo or ENV=shared (the DNS stack, ADR 0041) can never reach apply or destroy.
env-guard:
	@case "$(ENV)" in dev|prod) ;; *) echo "Refusing ENV=$(ENV): up, down and teardown-check only accept dev or prod (ADR 0041)."; exit 1 ;; esac

# State and resources use different profiles (ADR 0040), so both sessions are checked.
env-init:
	@for f in backend.s3.tfbackend terraform.tfvars; do test -f $(TF_DIR)/$$f || { echo "Missing $(TF_DIR)/$$f - see the comments in $(TF_DIR)/backend.tf and terraform.tfvars.example."; exit 1; }; done
	@for p in $(STATE_PROFILE) $(ENV_PROFILE); do aws sts get-caller-identity --profile $$p > /dev/null 2>&1 || { echo "No valid AWS session for profile '$$p' - run: aws sso login --profile $$p"; exit 1; }; done
	terraform -chdir=$(TF_DIR) init -input=false -backend-config=backend.s3.tfbackend

plan: env-init ## terraform plan for ENV (default dev)
	terraform -chdir=$(TF_DIR) plan

# No -auto-approve: the "yes" prompt after the plan is the review gate, as with bootstrap.
up: env-guard env-init ## Create network + cluster for ENV (Argo CD bootstrap comes in Week 3)
	terraform -chdir=$(TF_DIR) apply

down: env-guard env-init ## Destroy network + cluster for ENV, then check no NAT gateway or EIP is left
	terraform -chdir=$(TF_DIR) destroy
	@$(MAKE) --no-print-directory teardown-check

# Asks AWS, not the state file, because a leftover resource may no longer be in state.
# A failed AWS call exits non-zero, so it can't pass as "clean".
# Day 6 replaces this with tools/teardown_verifier.py.
teardown-check: env-guard ## Fail if a NAT gateway or Elastic IP tagged with ENV still exists
	@export AWS_PROFILE=$(ENV_PROFILE) AWS_REGION=eu-west-2; \
	nats=$$(aws ec2 describe-nat-gateways --filter Name=tag:env,Values=$(ENV) Name=state,Values=pending,available --query 'NatGateways[].NatGatewayId' --output text) || exit 1; \
	eips=$$(aws ec2 describe-addresses --filters Name=tag:env,Values=$(ENV) --query 'Addresses[].AllocationId' --output text) || exit 1; \
	if [ -n "$$nats$$eips" ]; then echo "Still running and billed in ENV=$(ENV): NAT gateways: $${nats:-none}; Elastic IPs: $${eips:-none}"; exit 1; fi; \
	echo "Clean: no NAT gateway or Elastic IP tagged env=$(ENV)."

drill-1: ## Incident drill: latency spike on orders-api (Week 5)
	@echo "TODO Week 5: enable /chaos/latency, see docs/runbooks/"

drill-2: ## Incident drill: bad deploy / crash loop (Week 6)
	@echo "TODO Week 6"

drill-3: ## Incident drill: node loss (Week 6)
	@echo "TODO Week 6"

drill-4: ## Incident drill: broken IAM permission (Week 6)
	@echo "TODO Week 6"

drill-5: ## Incident drill: SQS backlog (Week 6)
	@echo "TODO Week 6"

diagram: ## Regenerate architecture diagrams from code
	python docs/diagrams/architecture.py

lint: ## Run all pre-commit hooks on every file
	pre-commit run --all-files

test: ## Run Python tests for apps, tools and Checkov policies
	pytest -q apps tools tests

tools-update: ## Update pre-commit hook versions
	pre-commit autoupdate --freeze
