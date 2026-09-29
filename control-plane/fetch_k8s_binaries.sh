#!/bin/bash
mkdir -p binaries

KUBE_VERSION="v1.37.0"
ETCD_VERSION="v3.7.1"
HELM_VERSION="v4.3.0"

echo "--> Downloading Kubernetes binaries (${KUBE_VERSION})..."
if [ ! -f binaries/kubelet ]; then
    echo "--> Downloading kubelet (${KUBE_VERSION})..."
    curl -fsSL -o binaries/kubelet "https://dl.k8s.io/${KUBE_VERSION}/bin/linux/amd64/kubelet"
fi
if [ ! -f binaries/kube-apiserver ]; then
    echo "--> Downloading kube-apiserver (${KUBE_VERSION})..."
    curl -fsSL -o binaries/kube-apiserver "https://dl.k8s.io/${KUBE_VERSION}/bin/linux/amd64/kube-apiserver"
fi
if [ ! -f binaries/kube-controller-manager ]; then
    echo "--> Downloading kube-controller-manager (${KUBE_VERSION})..."
    curl -fsSL -o binaries/kube-controller-manager "https://dl.k8s.io/${KUBE_VERSION}/bin/linux/amd64/kube-controller-manager"
fi
if [ ! -f binaries/kube-scheduler ]; then
    echo "--> Downloading kube-scheduler (${KUBE_VERSION})..."
    curl -fsSL -o binaries/kube-scheduler "https://dl.k8s.io/${KUBE_VERSION}/bin/linux/amd64/kube-scheduler"
fi
if [ ! -f binaries/kubectl ]; then
    echo "--> Downloading kubectl (${KUBE_VERSION})..."
    curl -fsSL -o binaries/kubectl "https://dl.k8s.io/${KUBE_VERSION}/bin/linux/amd64/kubectl"
fi

if [ ! -f binaries/etcd.tar.gz ]; then
    echo "--> Downloading etcd binaries (${ETCD_VERSION})..."
    curl -fsSL -o binaries/etcd.tar.gz "https://github.com/etcd-io/etcd/releases/download/${ETCD_VERSION}/etcd-${ETCD_VERSION}-linux-amd64.tar.gz"
fi

if [ ! -f binaries/helm.tar.gz ]; then
    echo "--> Downloading helm (${HELM_VERSION})..."
    curl -fsSL -o binaries/helm.tar.gz "https://get.helm.sh/helm-${HELM_VERSION}-linux-amd64.tar.gz"
fi


echo "Done! All binaries cached in $(pwd)/binaries"
