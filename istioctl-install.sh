#!/usr/bin/env bash
set -euo pipefail

ISTIO_VERSION="1.28.1"
TMP_DIR="$(mktemp -d)"

echo "▶ Using temp dir: $TMP_DIR"

(
  cd "$TMP_DIR"

  curl -sL https://istio.io/downloadIstio | \
    ISTIO_VERSION="$ISTIO_VERSION" sh
)

# Install istioctl
sudo mv "$TMP_DIR/istio-$ISTIO_VERSION/bin/istioctl" /usr/local/bin/istioctl

echo "✔ istioctl installed"

# Verify
istioctl version --remote=false

# Precheck
istioctl x precheck

# Install Istio (minimal)
istioctl install --set profile=default --set values.revision=default -y

# Cleanup
rm -rf "$TMP_DIR"

echo "✔ Cleanup complete"
echo "✔ No files left in working directory"
