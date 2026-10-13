#!/usr/bin/env bash
# Installs tools that have no dev container feature. Runs once when the container is built.
set -euo pipefail

# Versions: bump deliberately and record the change in a PR.
ARGOCD_VERSION="latest"
K9S_VERSION="latest"

sudo apt-get update -y
sudo apt-get install -y --no-install-recommends graphviz make jq unzip

python -m pip install --upgrade pip
pip install --user -r requirements-dev.txt

# Trivy (image and IaC scanning)
curl -sfL https://raw.githubusercontent.com/aquasecurity/trivy/main/contrib/install.sh | sudo sh -s -- -b /usr/local/bin

# Argo CD CLI
curl -sSL -o /tmp/argocd "https://github.com/argoproj/argo-cd/releases/${ARGOCD_VERSION}/download/argocd-linux-amd64"
sudo install -m 0755 /tmp/argocd /usr/local/bin/argocd

# k9s (terminal UI for watching the cluster during drills)
curl -sSL "https://github.com/derailed/k9s/releases/${K9S_VERSION}/download/k9s_Linux_amd64.tar.gz" | sudo tar -xz -C /usr/local/bin k9s

# Git hooks
pre-commit install

echo
echo "Tool versions (copy into docs if you pin them):"
terraform version | head -1
aws --version
kubectl version --client 2>/dev/null | head -1
helm version --short
argocd version --client --short 2>/dev/null || true
trivy --version | head -1
python --version
