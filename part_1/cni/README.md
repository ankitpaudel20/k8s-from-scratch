# Container Network Interface (CNI)

CNI is responsible for making distinct ip address and network devices available to every pod.

---

## What exactly is it

- Just a specification/document on how container manager like containerd/crio should communicate with a program to configure the networking of pods/containers or more specifically, the network namespace created for the pod to reside in.
- The official reference implementation has concept of plugins, that communicate with containerd through stdout and stdin. The containerd invokes the programs in /opt/cni/bin as configured according to the files in `/etc/cni/net.d`.
- Some plugin that we will use are named `bridge` and `host-local`.
  - **Bridge** creates a linux bridge in each worker, mostly named `cni0`. When a pod is scheduled, `containerd` executes the `bridge` binary to create a `veth` pair, placing one end inside the pod namespace as `eth0` and attaching the other end to `cni0`.
    - linux bridge is almost equivalent to a network switch. And we can connect `veth` pairs to it. We almost always connect one veth pair with our host, so the host itself would have a ip address inside that bridge, and we can then create multiple veth pairs to connect to other network namespaces.
    - veth pairs are almost equivalent to a patch cable from the switch to the network namespace. if there are veth pairs, we can then assign ip addresses on that veth pair for a virtual bridge, its connected to.
  - **Host-Local IPAM (`host-local`)** Manages pod IP allocation locally on each worker without a central daemon. It assigns IPs sequentially from the worker's dedicated subnet (`10.200.${NODE_INDEX}.0/24`) and tracks them on disk under `/var/lib/cni/networks/mynet/`.
- **Gateway & Masquerading**:
   - `isGateway: true`: Assigns the first usable IP of the subnet to `cni0` so it acts as the default gateway for pods on that node.
   - `ipMasq: true`: Sets up iptables SNAT rules so traffic leaving the node has its source IP translated to the worker's IP.

---

## Configuration (`/etc/cni/net.d/10-mynet.conf`)

Written automatically by worker cloud-init at boot:

```json
{
  "cniVersion": "0.2.0",
  "name": "mynet",
  "type": "bridge",
  "bridge": "cni0",
  "isGateway": true,
  "ipMasq": true,
  "ipam": {
    "type": "host-local",
    "subnet": "10.200.X.0/24",
    "routes": [
      { "dst": "0.0.0.0/0" }
    ]
  }
}
```

Together with `/etc/cni/net.d/99-loopback.conf` (`type: "loopback"`), this satisfies `containerd` and `kubelet`, allowing nodes to transition to `Ready` and host running pods.
