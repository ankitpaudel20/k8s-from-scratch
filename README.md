# Kubernetes from Scratch

This repository follows the philosophy of Kelsey Hightower's [Kubernetes the Hard Way](https://github.com/kelseyhightower/kubernetes-the-hard-way), but adapts it to run entirely on a local machine using **Incus KVM virtual machines** and automated **cloud-init** configurations.

By walking through this guide, you build a fully functional, production-structured Kubernetes cluster from raw Linux primitives without using automated installers (like `kubeadm` or `minikube`) or cloud-provider services.

---

## Course Roadmap

* **[Part 1: Control Plane, PKI & Cluster Bootstrap](part_1/README.md)**
  * Incus bridge networking (`k8sbr0`) and IP allocation planning.
  * Building the complete PKI infrastructure with CFSSL and understanding mandatory `CN`/`O` RBAC mappings.
  * Bootstrapping a 3-node HA etcd cluster with mTLS peer/server communication.
  * Setting up `kube-apiserver`, `kube-controller-manager`, and `kube-scheduler`.
  * Provisioning worker nodes (`containerd`, `runc`, `kubelet`, `kube-proxy`).

* **[Part 2: Production CNI, Gateway API & Bare-Metal LoadBalancers](part_2/README.md)**
  * Checkpointing state and pre-baking custom Incus VM images for fast boots.
  * Deep dive into production CNIs: Cilium (eBPF) vs. Calico.
  * Solving the bare-metal `type: LoadBalancer` `<pending>` problem using Layer 2 VIP allocation (MetalLB / Cilium L2).
  * Deploying the modern Kubernetes Gateway API (`GatewayClass`, `Gateway`, `HTTPRoute`).
  * Setting up an Envoy/Cilium Gateway controller on the local bridge.
  * Packaging a Go test application and implementing end-to-end HTTP traffic routing and health probes.

---

## Who is this for?

* Developers and DevOps / Platform Engineers who want to understand Kubernetes internals: Linux namespaces, cgroups v2, Raft consensus, mTLS trust boundaries, and CNI/CSI specifications.
* Anyone preparing for **CKA**, **CKAD**, or **CKS** certifications who wants hands-on diagnostic experience.

---

## Prerequisites

* **Hardware**: At least 16 GB of RAM on your host system (we will be running 5–6 hardware-isolated KVM virtual machines concurrently).
* **Operating System**: Linux with KVM virtualization enabled.
* **Incus**:
  * [Incus](https://linuxcontainers.org/incus/) manages containers and KVM virtual machines with a clean CLI interface.
  * Consult the official [Incus Installation Guide](https://linuxcontainers.org/incus/docs/main/tutorial/first_steps/).
  * **Btrfs Storage Note**: If your host filesystem is Btrfs, avoid using loop-backed image pools (`default.img`), as etcd `fdatasync()` calls cause severe write amplification. Create an Incus storage pool pointing directly to a host subvolume (`source=/var/lib/incus-btrfs`) with `nodatacow` enabled.
* **Local Tools**: `curl`, `tar`, `openssl`, `cfssl`, `cfssljson`, `etcdctl`, and `kubectl`.

---

## Repository Structure

```
.
├── part_1/
│   ├── README.md               # Guide for Part 1: PKI, Control Plane, Workers
│   ├── cloudinit/              # Cloud-init scripts (etcd, control-plane, workers)
│   ├── pki/                    # CFSSL specs, gencert.sh, del-cert.sh, PKI readme
│   ├── vm-profiles/            # Incus VM hardware profiles
│   ├── test_workload/          # Basic NGINX pod and NodePort service
│   └── binaries/               # Download cache for K8s binaries & runtime
├── part_2/
│   ├── README.md               # Guide for Part 2: CNIs, Gateway API, LoadBalancers
│   └── vmprofiles_and_images/  # Pre-baked Incus images & VM profile guides
└── test-application/           # Custom Go HTTP server with probes & Helm chart
    ├── main.go
    ├── Dockerfile
    └── chart/                  # Helm chart for test-application
```
