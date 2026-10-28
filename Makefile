# Northwind Platform - one entry point for every routine action.
# Stub targets print what they will do; replace them as each milestone lands.
SHELL := /bin/bash
ENV ?= dev
TF_DIR := terraform/envs/$(ENV)

.PHONY: help bootstrap bootstrap-plan bootstrap-check up down plan apply drill-1 drill-2 drill-3 drill-4 drill-5 diagram lint test tools-update

help: ## Show targets
	@grep -E '^[a-zA-Z0-9_-]+:.*?## ' $(MAKEFILE_LIST) | awk 'BEGIN {FS = ":.*?## "}; {printf "  %-14s %s\n", $$1, $$2}'

BOOTSTRAP_DIR := terraform/bootstrap
BOOTSTRAP_PROFILE ?= admin

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

plan: ## terraform plan for ENV (default dev)
	terraform -chdir=$(TF_DIR) init -input=false && terraform -chdir=$(TF_DIR) plan

up: ## Create network + cluster for ENV and bootstrap Argo CD (Week 2-3)
	@echo "TODO Week 2: terraform apply $(TF_DIR), then install Argo CD app-of-apps"

down: ## Destroy network + cluster for ENV, then verify nothing billable is left (Week 2)
	@echo "TODO Week 2: terraform destroy $(TF_DIR) && python tools/teardown_verifier.py --env $(ENV)"

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

test: ## Run Python tests for apps and tools
	pytest -q apps tools

tools-update: ## Update pre-commit hook versions
	pre-commit autoupdate
