#!/usr/bin/env bash
set -euo pipefail

# Create a TLS certificate (dev-safe)
openssl req -x509 -nodes -days 365 \
  -newkey rsa:2048 \
  -keyout tls.key \
  -out tls.crt \
  -subj "/CN=localhost"

# Store it as a Kubernetes secret
kubectl create secret tls ingress-cert \
  --key tls.key \
  --cert tls.crt \
  -n istio-system
