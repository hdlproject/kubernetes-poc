#!/usr/bin/env bash
set -euo pipefail

# Create a TLS certificate (dev-safe)
openssl req -x509 -nodes -days 365 \
  -newkey rsa:2048 \
  -keyout tls.key \
  -out tls.crt \
  -subj "/CN=localhost"

# Store it as a Kubernetes secret
kubectl delete secret ingress-cert -n istio-system --ignore-not-found=true
kubectl create secret tls ingress-cert \
  --key tls.key \
  --cert tls.crt \
  -n istio-system
kubectl create secret tls ingress-cert \
  --key tls.key \
  --cert tls.crt \
  -n default
kubectl label secret ingress-cert -n istio-system istio.io/tls-cert=true --overwrite

# Restart necessary deployment
kubectl rollout restart deployment/istio-ingressgateway -n istio-system
