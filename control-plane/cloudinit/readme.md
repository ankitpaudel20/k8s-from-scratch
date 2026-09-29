# Cloud-Init Bootstrapping

Automates the provisioning of Incus KVM virtual machines for the etcd cluster, Kubernetes control plane, and worker nodes.

- Binaries and certificates are pulled dynamically from the host HTTP server at `http://10.240.0.1:8080`.
- Node identity and IP addresses are derived dynamically at boot via `uname -n` and interface inspection.

---

## File Overview

- **`user-data-etcd.yaml`**: Bootstraps an isolated etcd member node (`etcd-0`, `etcd-1`, or `etcd-2`).
  - Fetches `root-ca.pem` and node-specific server/peer certs, sets up data dir `/var/lib/etcd` (`0700`), and starts `etcd.service` clustered across all 3 nodes on ports 2379 and 2380.
- **`user-data-control-plane.yaml`**: Bootstraps a Kubernetes control plane node (`cp-0`, `cp-1`).
  - Loads kernel modules (`overlay`, `br_netfilter`), sets sysctls, writes systemd units and kubeconfigs for `controller-manager`, `scheduler`, and `admin`, starts the control plane services, and automatically bootstraps Calico via Helm on `cp-0`.
- **`user-data-worker-nodes.yaml`**: Bootstraps a Kubernetes worker node (`worker-0`, `worker-1`).
  - Installs and configures `containerd` (systemd cgroups) and `runc`, generates `kubelet.kubeconfig` and `kube-proxy.kubeconfig`, detects upstream DNS to prevent CoreDNS loops, and starts `containerd`, `kubelet`, and `kube-proxy`.

---

## Key Implementation Details

- **Single-Run Calico Bootstrap**: Calico is a cluster-wide addon and is installed **only once** from `cp-0` (`if [ "$NODE_INDEX" -eq 0 ]`). Workers boot with empty `/etc/cni/net.d/` and wait for the Calico DaemonSet to self-install and flip them to `Ready`.
- **CoreDNS Loop Prevention**: Ubuntu uses `systemd-resolved` with a local stub at `127.0.0.53`. The cloud-init checks for `/run/systemd/resolve/resolv.conf` so Kubelet passes the real upstream DNS to CoreDNS instead of the loopback stub.
- **POSIX `/bin/sh` Syntax**: Cloud-init runs `runcmd` via `/bin/sh` (`dash` on Ubuntu). Always use single brackets `[ "$VAR" -eq 0 ]` and ensure `EOF` delimiters have zero leading whitespace.
