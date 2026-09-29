#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BIN_DIR="${SCRIPT_DIR}/binaries"
mkdir -p "${BIN_DIR}"

KUBE_VERSION="v1.37.0"
CONTAINERD_VERSION="2.4.0"
RUNC_VERSION="v1.5.1"
CRICTL_VERSION="v1.37.0"

echo "================================================================================"
echo " Fetching Kubernetes Worker Node Binaries and Runtimes into ${BIN_DIR}"
echo "================================================================================"


echo "--> [2/5] Fetching kube-proxy (${KUBE_VERSION})..."
if [ ! -f binaries/kube-proxy ]; then
  curl -fsSL -o "${BIN_DIR}/kube-proxy" "https://dl.k8s.io/${KUBE_VERSION}/bin/linux/amd64/kube-proxy"
  chmod +x "${BIN_DIR}/kube-proxy"
fi

# 2. Container Runtime (containerd & runc)
echo "--> [3/5] Fetching containerd (${CONTAINERD_VERSION}) & runc (${RUNC_VERSION})..."
if [ ! -f binaries/containerd.tar.gz ]; then
  curl -fsSL -o "${BIN_DIR}/containerd.tar.gz" \
    "https://github.com/containerd/containerd/releases/download/v${CONTAINERD_VERSION}/containerd-${CONTAINERD_VERSION}-linux-amd64.tar.gz"
fi

if [ ! -f binaries/runc.amd64 ]; then
  curl -fsSL -o "${BIN_DIR}/runc.amd64" \
    "https://github.com/opencontainers/runc/releases/download/${RUNC_VERSION}/runc.amd64"
fi

# 3. CRI CLI Tool (crictl)
echo "--> [4/5] Fetching crictl (${CRICTL_VERSION})..."
if [ ! -f binaries/crictl.tar.gz ]; then
  curl -fsSL -o "${BIN_DIR}/crictl.tar.gz" \
    "https://github.com/kubernetes-sigs/cri-tools/releases/download/${CRICTL_VERSION}/crictl-${CRICTL_VERSION}-linux-amd64.tar.gz"
fi

echo ""
echo "Done! All worker binaries cached in ${BIN_DIR} for the local HTTP server."
