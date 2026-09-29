# PKI and Certificates

- Uses **cfssl** for all CA signing and certificate generation.
- To generate all certificates with the proper extensions and flags: run [`./gencert.sh`](gencert.sh)
- To clean up generated certificates and CSRs: run [`./del-cert.sh`](del-cert.sh)

---

## Configuration & Root CA

- **`ca-config.json`**: Defines CFSSL signing profiles (`server`, `client`, `peer`) specifying validity periods and Extended Key Usage (EKU) flags.
- **`root-ca/`**: Contains the root Certificate Authority specification used to bootstrap and self-sign the root CA.

---

## Control Plane Certificates

- **`apiserver/`**: Certificates used by the `kube-apiserver`.
  - **`apiserver-kube.json`**: Used to indetify itself when connecting itself to downward clients and other k8s components.
  - **`apiserver-etcd.json`**: uset to connect to the etcd cluster (port 2379).
  - **`apiserver-kubelet-client.json`**: Client certificate with `O: system:masters` used by `kube-apiserver` to authenticate to worker Kubelet HTTPS endpoints (port 10250) for `exec`, `logs`, and `port-forward`.
- **`controller-manager/`**: Client credentials for the Kubernetes Controller Manager, to connect to the API server.
- **`scheduler/`**: Client credentials for the Kubernetes Scheduler to the apiserver.
- **`service-account/`**: Simple private/public key pair for signing and verifying Kubernetes ServiceAccount JWT tokens. This is used by the internal pods to prove their identity to the API server, if it needs to send any request to the apiserver.

---

## Worker Nodes & Node Networking

- **`worker-0/` & `worker-1/`**: Identity of the kubelet.
  - Its group must be `O: system:nodes` as its hard coded in the apiserver to be able to. There are other hardcoded "CNs" and "names.O" values that must match. for things to work.

### The Cheat Sheet of Mandatory Strings

| Component                     | What is Mandatory in `CN`?                          | What is Mandatory in `O`?           | Why?                                       |
| :---------------------------- | :-------------------------------------------------- | :---------------------------------- | :----------------------------------------- |
| **Worker (`kubelet`)**        | **`system:node:<nodename>`** _(Mandatory!)_         | **`system:nodes`** _(Mandatory!)_   | Hardcoded prefix in `Node` Authorizer.     |
| **`kube-controller-manager`** | **`system:kube-controller-manager`** _(Mandatory!)_ | _(Ignored / Not needed)_            | Default ClusterRoleBinding matches `User`. |
| **`kube-scheduler`**          | **`system:kube-scheduler`** _(Mandatory!)_          | _(Ignored / Not needed)_            | Default ClusterRoleBinding matches `User`. |
| **`kube-proxy`**              | **`system:kube-proxy`** _(Mandatory!)_              | Optional (`system:node-proxier`)    | Default ClusterRoleBinding matches `User`. |
| **Admin (`kubectl`)**         | _(Any name you want)_                               | **`system:masters`** _(Mandatory!)_ | Hardcoded superuser group in API server.   |

- **`kube-proxy/`**: Needed if you are running kube-proxy, can be skipped if you decide to use cillium.

---

## etcd Cluster Certificates

- **`etcd-0/`, `etcd-1/`, `etcd-2/`**: TLS server and peer certificates for the 3-node etcd consensus cluster.
  - **`etcd-*-server.json`**: Server TLS certificate for an etcd instance (port 2379) with SANs for localhost, node IP, and DNS name to serve client.
  - **`etcd-*-peer.json`**: Peer mTLS certificate for an etcd instance (port 2380) with SANs for cluster members to authenticate and establish Raft consensus communication.
