# CoreDNS

CoreDNS provides in-cluster DNS resolution so that pods can discover services by name (e.g. `nginx.default.svc.cluster.local`).

---

## How it works

CoreDNS is **not** a system daemon like `kubelet` or `kube-proxy`. It runs as a standard Kubernetes `Deployment`, scheduled onto worker nodes like any other pod.

It talks to the API server using **In-Cluster Config**: this is why we need `service-account` pki during the pki generation phase. The kubelet automatically mounts a simple jwt token in the pod, which determines the identity of the pod. That OIDC token is then checked by the api-server to make the pod able to talk to the cluster
The `kubelet` automatically mounts a `ServiceAccount` token into the pod, and CoreDNS uses that token to authenticate and watch for `Service` and `Endpoint` changes.

---

## How pods find CoreDNS

The `kubelet` on every worker node is configured with:

```yaml
clusterDNS:
  - 10.32.0.10
clusterDomain: cluster.local
```

When `containerd` creates a pod, `kubelet` injects `nameserver 10.32.0.10` into the pod's `/etc/resolv.conf`(We have set this ip in kubelet's argument when starting up, you can check that out in the control-plane's cloudinit). This IP (`10.32.0.10`) is the hardcoded `clusterIP` of the `kube-dns` Service defined in `coredns.yaml`.

---

## What `coredns.yaml` deploys

1. **ServiceAccount + RBAC**: Grants CoreDNS read-only access to watch `Services`, `Endpoints`, `Pods`, and `Namespaces`.
2. **ConfigMap (`Corefile`)**: The CoreDNS configuration file. The `kubernetes` plugin resolves `*.cluster.local` queries. The `forward` plugin forwards everything else (e.g. `google.com`) to the node's upstream DNS.
3. **Deployment**: 2 replicas of `coredns/coredns:1.11.1` with health/readiness probes.
4. **Service (`kube-dns`)**: A `ClusterIP` service pinned to `10.32.0.10` so it matches the `kubelet` configuration.

---

## Deployment

CoreDNS is automatically fetched and applied by `cp-0` during cloud-init bootstrap after the API server is healthy:

```bash
curl -fsSL -o /tmp/coredns.yaml "${HOST_SERVER}/coredns/coredns.yaml"
kubectl apply -f /tmp/coredns.yaml
```

## Configfile breakdown

```text
.:53 {
    errors
    health {
        lameduck 5s
    }
    ready
    kubernetes cluster.local in-addr.arpa ip6.arpa {
        pods insecure
        fallthrough in-addr.arpa ip6.arpa
        ttl 30
    }
    prometheus :9153
    forward . /etc/resolv.conf {
        max_concurrent 1000
    }
    cache 30
    loop
    reload
    loadbalance
}
```
- THis can be read more like a caddyfile, everything is declarative and the first word represents a plugin, the other words or a block inside that are other arguments and extra configs to change the functionality of the plugin.

Everything is wrapped inside `.:53 { ... }`, which tells CoreDNS to listen on port `53` for all DNS zones (`.`). Rather than reading it line-by-line, it helps to group the plugins by their job:

* **Internal Cluster DNS (`kubernetes`):** Translates Kubernetes Services and Pods (`cluster.local`) and reverse IP lookups (`in-addr.arpa` / `ip6.arpa`) into DNS records with a 30-second TTL (`ttl 30`). The `fallthrough` rule ensures that if a reverse IP lookup isn't found inside Kubernetes, the request is passed upstream instead of failing immediately.
* **External DNS (`forward`):** Any query not meant for `cluster.local` (like `google.com`) is forwarded to the upstream nameservers listed in the node's `/etc/resolv.conf`, capped at `1000` concurrent requests to prevent overload.
* **Performance & Routing (`cache` & `loadbalance`):** `cache 30` stores DNS responses in memory for up to 30 seconds to reduce latency, while `loadbalance` shuffles multiple `A`/`AAAA` records in responses for simple round-robin load balancing.
* **Health & Observability (`health`, `ready`, `prometheus`, `errors`):** Exposes liveness (`:8080/health`) and readiness (`:8181/ready`) probes for Kubernetes, serves Prometheus metrics on `:9153`, and logs query errors to `stdout`. During Pod shutdown, `lameduck 5s` gives Kubernetes 5 seconds to stop sending traffic before CoreDNS exits.
* **Safety & Lifecycle (`loop` & `reload`):** `loop` detects infinite DNS forwarding loops on startup and halts the process before it can spike CPU usage, while `reload` automatically applies ConfigMap changes on the fly without restarting the Pod.

