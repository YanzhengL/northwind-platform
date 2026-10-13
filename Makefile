# Northwind Platform - one entry point for every routine action.
# Stub targets print what they will do; replace them as each milestone lands.
SHELL := /bin/bash
ENV ?= dev
TF_DIR := terraform/envs/$(ENV)

.PHONY: help bootstrap up down plan apply drill-1 drill-2 drill-3 drill-4 drill-5 diagram lint test tools-update

help: ## Show targets
	@grep -E '^[a-zA-Z0-9_-]+:.*?## ' $(MAKEFILE_LIST) | awk 'BEGIN {FS = ":.*?## "}; {printf "  %-14s %s\n", $$1, $$2}'

bootstrap: ## One-off: state bucket + GitHub OIDC roles (Week 1)
	@echo "TODO Week 1: terraform -chdir=terraform/bootstrap init && apply"

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
