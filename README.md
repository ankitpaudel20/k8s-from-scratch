# Kubermetes from Scratch

- This repo closely follows the [Kubernetes the Hard Way](https://github.com/kelseyhightower/kubernetes-the-hard-way) guide, but the workloads and vms run locally with incus and is configured with cloudinit scripts.
- By the end of this guide, we will have a Kubernetes cluster running locally using incus and cloudinit.

## Who is this for?

- Begineer to intermediate Kubernetes users who want to learn how to set up a Kubernetes cluster from scratch without any cloud resources.

## Prerequisites

- We will be running total of 5-6 VMs so 16Gb ram system is required.
- Incus.
  - Incus is a docker like container and VM manager that allows managing Vms and containers, with simple docker like CLI interface.
  - You can ask any agent or llm on how to install incus on your system. The docs on how to install it is in https://linuxcontainers.org/incus/docs/main/tutorial/first_steps/
  - Should be straight forward to install.
    - If you are using BTRFS to store your VM data, your disk might thrash hard when running multiple etcd instances, so use a separate volume and create a new pool there, don't use directory based storage backend. [Docs](https://linuxcontainers.org/incus/docs/main/howto/storage_pools/).
- Basic plumbing tools like openssl, curl, cfssl and etcdctl to test and generate certs

## Cloudinit

- Used instead of ansible to setup a newly created vm.
- We will have cloudinit scripts to setup every vm, from etcd to worker nodes.
- Why? Because we will be able to quickly setup and teardown VMs if we get stuck in the middle and if anything happens and we need to start from scratch.

## Sourcing binaries

- As this tutorial is supposed to be easy to startup and teardown from scratch, we will first manually download all the binaries required for the process to our host computer. run two scripts `fetch_k8s_binaries.sh` and `fetch_worker_binaries.sh` inside `control-plane` folder to download them.
- You can change the versions and filenames as required, they have the latest versions of each at the time of writing.
- Once downloaded, we will run a simple python http fileserver to serve the binaries to the VMs we will create.
  `python3 -m http.server 8080 --bind 0.0.0.0 -d ./control-plane/`
  - Notice the -d flag, the curl commands inside the vm will reference files based on the root directory being `control-plane`.
- you can look into cloudinits to see and fix the ip addresses of the network interfaces.

## Incus Networkking and VM profiles

- We will be hosting All the VMs in a single network bridge of incus so all VMs will be able to communicate with each other by default. Production clusters will most likely have separate networks/VPCs/Subnets separating operation boundaries.
- This will be our ip allocation strategy:

```
+-----------------------------------------------------------------------------------------+
|                                    10.240.0.0/24                                        |
|                          Incus VM Host Network (Bridge: k8sbr0)                         |
|                                                                                         |
|   Host Gateway: 10.240.0.1                                                              |
|   ├── etcd-0: 10.240.0.10     ├── cp-0:     10.240.0.20     ├── worker-0: 10.240.0.30   |
|   ├── etcd-1: 10.240.0.11     └── cp-1:     10.240.0.21     └── worker-1: 10.240.0.31   |
|   └── etcd-2: 10.240.0.12                                                               |
+-----------------------------------------------------------------------------------------+
                                    │
                                    │  Pods live inside VMs
                                    ▼
+-----------------------------------------------------------------------------------------+
|                                    10.200.0.0/16                                        |
|                                 Pod CIDR Network                                        |
|                                                                                         |
|   worker-0 Subnet (10.200.0.0/24):                     worker-1 Subnet (10.200.1.0/24): |
|   ├── cni0 Gateway: 10.200.0.1                         ├── cni0 Gateway: 10.200.1.1     |
|   └── Pods:         10.200.0.2 – 10.200.0.254          └── Pods:         10.200.1.2 – .254
+-----------------------------------------------------------------------------------------+
                                    │
                                    │  Virtual IP abstraction (no physical interfaces)
                                    ▼
+-----------------------------------------------------------------------------------------+
|                                    10.32.0.0/24                                         |
|                             Service CIDR (ClusterIPs)                                   |
|                                                                                         |
|   ├── 10.32.0.1  : Kubernetes API Server virtual endpoint                               |
|   └── 10.32.0.10 : CoreDNS cluster internal DNS resolver                                |
+-----------------------------------------------------------------------------------------+
```

- Create the actual incus network with the above CIDR range.
  `incus network create k8sbr0 ipv4.address=10.240.0.1/24 ipv4.nat=true ipv6.address=none dns.domain=k8s.local`. k8sbr0 is the name.
- As we will be creating 3 different types of VMs (etcd, worker, control-plane), we will create separate VM profiles for each type. The profiles are defined in `vm-profiles` folder.
- This command will create a profile from the yaml files given in `vm-profiles` folder.
  `incus profile create k8s-control-plane < ./k8s-etcd.yaml`
  `incus profile create k8s-worker < ./k8s-worker.yaml`
  `incus profile create k8s-control-plane < ./k8s-control-plane.yaml`
- Important: you will need to reregister the cloud-init to the specific profile every time its changed, its done with this command: `incus profile set k8s-control-plane cloud-init.user-data - < ./control-plane/cloudinit/user-data-control-plane.yaml`, replace the right cloudinit for their respective vm profiles.

## Setting up

- Once all the above things are done, we can now start configuration and creation of the VMs.

## Generation of Certificates

- Make sure that you have cfssl and openssl installed for this.
- We will be running commands in this section from `pki` directory.
- First create the self signed root certificate and keys
  - `cfssl gencert -initca ./root-ca/ca-csr.json | cfssljson -bare ./root-ca/root-ca`
- Generate all the reqired certificates using the script in pki folder `bash generate_certs.sh`
- If you change any certitificate or mess anything, you can delete all the .pem files and .csr files using the script `bash del-certs.sh`
  - **Caution: This will delete with glob combination, so make sure you are in the `pki` directory before running this.**
- If you see .pem and -key.pem files, in each folder inside `pki`, we should be good to go.

### etcd

- We will be running 3 node cluster of etcd running in HA.
- Be sure to have downloaded the binaries in the binaries folder and the python server is running as shown before.
- The hard part: understanding the flags in each certificates and knowing trust boundaries where a single etcd instance can act as both server and client.
- You can go to pki/README.md to know what all the folders are, and why are they required.
- Or take help of Agent or llm to understanding the internals if required.
- Based on the ip addresses we planned and setup in the k8sbr0 network and on the cloudinit scripts, this command should create the etcd cluste20

```bash
incus launch images:debian/trixie/cloud etcd-0 --profile k8s-etcd --device eth0,ipv4.address=10.240.0.10 --vm
incus launch images:debian/trixie/cloud etcd-1 --profile k8s-etcd --device eth0,ipv4.address=10.240.0.11 --vm
incus launch images:debian/trixie/cloud etcd-2 --profile k8s-etcd --device eth0,ipv4.address=10.240.0.12 --vm
```

- You can check the status of the etcd cluster using the `etcdctl` command.
  `etcdctl --endpoints=https://10.240.0.10:2379,https://10.240.0.11:2379,https://10.240.0.12:2379 --cacert=./pki/root-ca/root-ca.pem --key=./pki/apiserver/apiserver-etcd-key.pem --cert=./pki/apiserver/apiserver-etcd.pem endpoint health`
  - We are using the certificate of `apiserver` because apiserver would be the one accessing the etcd cluster, so we should make sure that it should work.
- If this fails even after a few mins of VM start, you should exercise debugging the VMs.
  - Start with `incus exec worker-0 -- bash` this will drop you into the shell inside the vm.
  - We are installing all the components using systemd services, so you can check the status of the services using `systemctl status <service-name>`. Get the logs with `journalctl -eu <service-name>`.
  - Debugging the cloudinit: cloudinit has logs in `/var/log/cloud-init-output.log`, you can check what happened during the cloudinit and add logs there to debug.

### Control-plane components

- We will be running all the basic control-plane components in the same VM.
- Be sure to have downloaded the binaries in the binaries folder and the python server is running as shown before.
- Set the specific cloudinit for controlplane vms to the profile of `k8s-controlplane`. before spawning the VMs.
- launch the VM using `incus launch images:debian/trixie/cloud cp-0 --profile k8s-controlplane --device eth0,ipv4.address=10.240.0.20`
- we can now check if the apiserver is working with kubectl in our host network.
  - For this we first need to create a kubeconfig file on our local host computer.
  - We will be taking a snippet from the cloudinit file of control plane, `cloudinit/user-data-control-plane.yaml`. There we write a kubeconfig file in `/root/.kube/config`, we willbe using the same contents with changed path for certificates and the apiserver address.
  ```yaml
  apiVersion: v1
  kind: Config
  clusters:
    - cluster:
        certificate-authority: <path-to-repo>/k8s-the-hard-way/control-plane/pki/root-ca/root-ca.pem
        server: https://10.240.0.20:6443
      name: local-cluster
  contexts:
    - context:
        cluster: local-cluster
        user: admin
      name: default
  current-context: default
  users:
    - name: admin
      user:
        client-certificate: <path-to-repo>/k8s-the-hard-way/control-plane/pki/admin-kubectl/admin-kubectl.pem
        client-key: <path-to-repo>/k8s-the-hard-way/control-plane/pki/admin-kubectl/admin-kubectl-key.pem
  ```
  - run `kubectl config get-contexts` to verify the kubetcl context is set correctly.
  - then we can run `kubectl get all -A` to verify the apiserver is working.
  - we don't yet have worker nodes so calico pods will not be scheduled, and will stay on pending status till we start a worker node in the next step.

### Worker Nodes

- We now can follow the same script, make sure that the right cloudinit is setup for worker-vm profiles, and start the worker node with command `incus launch images:debian/trixie/cloud worker-0 --profile k8s-worker --device eth0,ipv4.address=10.240.0.30 --vm`
- Once the worker node is started, you can get the pods, and check if the calico pods are running.

### Running a default nginx server

- There are two yamls for a nginx pod and a nginx node port service in `test_workload` directory, apply those, and hit the ip of the worker-node created, it should show nginx welcome page.
  - As our host computer is also connected to virtual k8sbr0 of incus, we can use the internal ip of the worker nodes to access the nginx service.
    `kubectl apply -f control-plane/test_workload/nginx_pod.yaml` and `kubectl apply -f control-plane/test_workload/nginx_service.yaml`
- Loadbalancer service type will not work as it requires a separate network interface(physical or virtual) to act as a load balancer to forward traffic to the right node in the cluster.
