#!/usr/bin/env bash
# Creates a local kind cluster, installs Argo CD, and registers the app.
set -euo pipefail
cd "$(dirname "$0")/.."
source scripts/env.sh

kind create cluster --name argocd-demo --config scripts/kind-config.yaml

kubectl create namespace argocd --dry-run=client -o yaml | kubectl apply -f -
kubectl apply -n argocd --server-side -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml
kubectl -n argocd rollout status deploy/argocd-server --timeout=300s

kubectl apply -f argocd/application.yaml

echo
echo "Argo CD admin password:"
kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath='{.data.password}' | base64 -d; echo
echo
echo "Argo CD UI:  kubectl -n argocd port-forward svc/argocd-server 8443:443  ->  https://localhost:8443 (user: admin)"
echo "Chat UI:     http://localhost:8080"
echo "LLM API:     curl http://localhost:8080/api/tags"
echo
echo "First start downloads the model (~400MB). Watch: kubectl -n llm get pods -o wide -w"
