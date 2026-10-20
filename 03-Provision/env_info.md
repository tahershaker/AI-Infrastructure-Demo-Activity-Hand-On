# Kubernetes structure of the Soperator deployment

A recap of what runs inside the Kubernetes cluster that Terraform built: namespaces, labels, HelmReleases, CRDs, networking and storage. It is not about the VMs underneath.

**The short version.** Terraform builds the managed Kubernetes cluster and the node groups. Then it installs Flux and one bootstrap chart. From there, Flux installs 25 HelmReleases in a fixed order. Those install the operators and their CRDs. The operator then reads a few custom resources (`SlurmCluster`, `NodeSet`, `ActiveCheck`) and creates the Slurm pods: `controller-0`, `login-0`, `worker-0`, `worker-1`. Slurm is just another application on Kubernetes, with its own scheduler inside.

---

## 0. How to read this file

Every fact has one of three tags, so you know how sure to sound.

| Tag | Meaning |
|---|---|
| **[live]** | Seen in real `kubectl` or `helm` output from my cluster |
| **[code]** | Read in the Terraform release code (`soperator-v4.1.13-2`) |
| **[inferred]** | My reading from names and behavior. Not proven. Say "I believe" in the interview |

**Source and date.** The live output comes from my first full inventory (12 October 2026, 8 nodes). I rebuilt the cluster on 13 October with the same settings, so the structure is the same. Names, IPs and IDs differ. I removed node names, IDs and public IPs from this file.

---

## 1. The big picture

```
Terraform
  ├─ filestore module     → shared filesystems (jail, data, controller spool)
  ├─ k8s module           → managed Kubernetes cluster + node groups (labels, taints)
  ├─ fluxcd module        → installs Flux into namespace flux-system
  ├─ slurm module         → installs ONE bootstrap chart (helm-soperator-fluxcd)
  └─ login_script module  → writes login.sh

Flux (6 controllers in flux-system)
  └─ 25 HelmReleases, installed in dependency order
       ├─ CRDs and platform  (cert-manager, Kruise, Prometheus + VictoriaMetrics CRDs, NFS CSI, storage classes)
       ├─ the operator       (soperator-controller-manager) + checks controller + node configurator
       ├─ custom resources   (SlurmCluster, NodeSet, 25 ActiveChecks)
       └─ observability      (VictoriaMetrics, VictoriaLogs, Grafana, OpenTelemetry, DCGM exporter)

Operator
  └─ creates the Slurm pods in namespace soperator: controller-0, login-0, worker-0, worker-1
```

**Why it matters.** Terraform does not install the Slurm components one by one. It installs Flux and hands over one bootstrap chart. That chart describes all the other releases. Flux keeps them in sync every 5 minutes. **[code]**

**GitOps without Git.** Flux normally reads from a Git repository. Here there are no Git sources. Flux reads Helm charts from Helm and OCI registries, and the values come from Terraform. **[live]**

---

## 2. Namespaces

| Namespace | What it holds | Installed by | Pods |
|---|---|---|---|
| `default`, `kube-public`, `kube-node-lease` | Standard Kubernetes namespaces. Nothing of ours | Kubernetes | 0 |
| `kube-system` | The platform that Nebius manages: Cilium (network), CoreDNS, CSI node plugin, metrics-server, Hubble, GPU device plugin, node-problem-detector | Managed Kubernetes (Helm releases `cilium`, `coredns`, `compute-csi-driver`, and others) | 52 |
| `cilium-secrets` | Secrets for Cilium. No workloads **[inferred]** | Cilium | 0 |
| `flux-system` | The 6 Flux controllers, all 25 HelmReleases, the Helm sources, 3 NetworkPolicies, 1 ResourceQuota | Terraform (`fluxcd` module) | 6 |
| `cert-manager-system` | cert-manager (controller, cainjector, webhook) | HelmRelease `cert-manager` | 3 |
| `kruise-system` | OpenKruise: 2 controller managers and a daemon on every node | HelmRelease `kruise` | 10 |
| `kruise-daemon-config` | Config for the Kruise daemon. No pods **[inferred]** | Kruise | 0 |
| `soperator-system` | The Soperator operator, the checks controller, the node configurator DaemonSet | HelmReleases `soperator`, `soperatorchecks`, `nodeconfigurator` | 10 |
| `soperator` | **The Slurm cluster itself**: controller, login, workers, jail mounts, ActiveChecks and their jobs | HelmReleases `slurm-cluster`, `nodesets`, `soperator-activechecks`, and others | 47 |
| `nfs-system` | The NFS CSI driver and an in-cluster NFS server (`nfs-server-0`) for `/home` | HelmReleases `csi-driver-nfs`, `nfs-server` | 10 |
| `monitoring-system` | VictoriaMetrics (`vmsingle`, `vmagent`), Grafana, kube-state-metrics, node-exporter | HelmReleases `vm-stack`, `monitoring-dashboards` | 13 |
| `logs-system` | VictoriaLogs and three OpenTelemetry collectors | HelmReleases `vm-logs`, `opentelemetry-collector-*` | 11 |
| `security-profiles-operator-system` | Security Profiles Operator (manages seccomp and AppArmor profiles) | HelmRelease `security-profiles-operator` | 13 |

Pod counts are from the first inventory **[live]**. Completed Jobs count as pods in `soperator`.

**One open point.** `helm list` shows the release `soperator-storageclasses` in a namespace called `storage-system`. That namespace is not in the `kubectl get ns` output. I do not have an explanation. Do not claim one. **[live]**

---

## 3. Labels, taints and node filters

### The nodes

| Node group | Count | Preset | `slurm.nebius.ai/nodeset` | What runs there |
|---|---|---|---|---|
| system | 4 | 8vcpu-32gb | `system` | Platform pods, operators, Flux, monitoring, `login-0` in my setup |
| controller | 1 | 4vcpu-16gb | `controller` | `controller-0` (slurmctld) |
| nfs | 1 | 4vcpu-16gb | `nfs` | `nfs-server-0` |
| worker | 2 | 1gpu-16vcpu-200gb | `worker` | `worker-0`, `worker-1` |

In the inventory, `login-0` is not on a dedicated login node. Check with `kubectl -n soperator get pod login-0 -o wide` before you say where it runs. **[unverified]**

### Labels and where they come from

| Label | Meaning | Who adds it |
|---|---|---|
| `slurm.nebius.ai/nodeset` = `system` / `controller` / `worker` / `nfs` (`login`, `accounting` if enabled) | Which Slurm role the node has. The SlurmCluster node filters select on this label | **Terraform**: `modules/labels` and the node group templates in `modules/k8s` **[code]** |
| `slurm.nebius.ai/workload` = `cpu` / `gpu` | Type of work on the node | Terraform **[code]** |
| `slurm.nebius.ai/jail` = `true` | The node mounts the shared "jail" filesystem. Set on all system, controller and worker nodes. Not on the NFS node | Terraform **[code]**, **[live]** |
| `slurm.nebius.ai/nodeset-name` = `worker` | The name of the worker node set. Only on workers | Terraform **[code]** |
| `nebius.com/gpu` = `true` | The node has a GPU. The DCGM exporter and the GPU problem detector select on it | Terraform **[code]** |
| `node.kubernetes.io/exclude-from-external-load-balancers` = `true` | Do not put this node behind a load balancer | Terraform **[code]** |
| `topology.nebius.com/tier-1`, `tier-2` | Where the node sits in the network. Normally set from the InfiniBand fabric. Slurm builds `topology.conf` from them | **Not Terraform by default.** I added them with Edit 5 and labelled the second worker by hand. **[live]** |
| `nebius.com/node-group-id`, `resource-preset`, `node-version` | Nebius metadata | Managed Kubernetes **[live]** |
| `nebius.com/nvidia_driver_version`, `cuda_version`, `nccl_version`, `ofed_version`, `drivers-preset` | The pre-installed GPU software on the node image | Managed Kubernetes **[live]** |
| `nvidia.com/gpu.deploy.operands` = `false` | The NVIDIA GPU Operator is not used. The driver is already on the node image **[inferred]** | Managed Kubernetes **[live]** |
| `kubernetes.io/arch`, `os`, `hostname`, `topology.kubernetes.io/region` | Standard labels | Kubernetes and the cloud provider |

### Labels on objects (not nodes)

- `app.kubernetes.io/*` and `helm.sh/chart`: added by Helm on everything it installs.
- `helm.toolkit.fluxcd.io/name` and `/namespace`: added by Flux. They tell you which HelmRelease owns an object. **[live]**
- `slurm.nebius.ai/controller-type=main`: on the controller service selector. **[live]**
- Annotation `slurm.nebius.ai/parental-cluster-ref: soperator`: ties a NodeSet to its SlurmCluster. **[live]**

### Taints

| Taint | On which nodes | Effect |
|---|---|---|
| `slurm.nebius.ai/nodeset=controller` (also `nfs`, `login`, `accounting`) | Controller and NFS nodes. Login and accounting if enabled | `NoSchedule`: only pods that tolerate it can run there **[code]**, **[live]** |
| `nvidia.com/gpu=1` | GPU workers | `NoSchedule`: keeps non-GPU pods off the GPU nodes **[code]**, **[live]** |
| none | System nodes | Anything can run there |

### How the pods find their nodes

The `SlurmCluster` has a list called `k8sNodeFilters` with five entries: `system`, `accounting`, `controller`, `login`, `worker`. Each entry is a node affinity on `slurm.nebius.ai/nodeset` plus the matching tolerations. Every Slurm component names one filter (`k8sNodeFilterName`). For example, the controller uses `controller` and the exporter uses `system`. **[live]**

---

## 4. Flux and the 25 HelmReleases

### The controllers (namespace `flux-system`)

| Controller | Job |
|---|---|
| `source-controller` | Fetches charts from the Helm and OCI repositories |
| `helm-controller` | Installs and upgrades the HelmReleases. This is the one that does the work here |
| `kustomize-controller` | Applies Kustomizations. Not used by Soperator, but it is part of Flux |
| `notification-controller` | Sends alerts and receives webhooks |
| `image-reflector-controller`, `image-automation-controller` | Watch image registries and update manifests. Not used here |

### Sources

11 HelmRepositories **[live]**. Seven are public Helm repositories (bedag `raw`, Jetstack, `csi-driver-nfs`, OpenKruise, OpenTelemetry, prometheus-community, VictoriaMetrics). Four point to Nebius's own OCI registry, `cr.nebius.cloud/soperator`, for the Soperator charts, the NFS server chart, the security profiles chart and the bootstrap chart.

### Settings every HelmRelease shares **[live]**

Check every 5 minutes, timeout 5 minutes, 3 retries on failure, CRDs skipped on install and upgrade (the CRDs come from separate releases), drift detection in `warn` mode, each release has a `targetNamespace`.

### The 25 releases

| HelmRelease (short name) | Chart@version | Runs in | What it does | Depends on |
|---|---|---|---|---|
| `soperator-fluxcd` | helm-soperator-fluxcd@4.1.13 | flux-system | **The root.** It defines all the other HelmReleases and sources | none |
| `ns` | raw@2.0.0 | flux-system | Creates the namespaces **[inferred]**. Nearly everything depends on it | none |
| `prometheus-operator-crds` | prometheus-operator-crds@19.1.0 | flux-system | The Prometheus Operator CRDs (`monitoring.coreos.com`) | none |
| `victoria-metrics-operator-crds` | victoria-metrics-operator-crds@0.0.3 | flux-system | The VictoriaMetrics CRDs | none |
| `cert-manager` | cert-manager@v1.19.6 | cert-manager-system | Certificates, and the certificates for the webhooks of the other operators | ns, prometheus-operator-crds |
| `kruise` | kruise@1.8.0 | kruise-system | OpenKruise: extra workload types, such as an advanced StatefulSet | ns, cert-manager |
| `soperator` | helm-soperator@4.1.13 | soperator-system | **The Soperator operator** (`soperator-controller-manager`) and its webhooks | ns, kruise, cert-manager |
| `soperatorchecks` | helm-soperatorchecks@4.1.13 | soperator-system | The controller for the ActiveChecks **[inferred from name]** | soperator |
| `nodeconfigurator` | helm-nodeconfigurator@4.1.13 | soperator-system | A DaemonSet on every node. It configures the nodes and can reboot them | soperator |
| `storageclasses` | helm-storageclasses@4.1.13 | storage-system | Creates extra storage classes, at least `slurm-local-pv` **[inferred]** | ns |
| `csi-driver-nfs` | csi-driver-nfs@4.11.0 | nfs-system | The CSI driver for NFS (`nfs.csi.k8s.io`) | ns |
| `nfs-server` | helm-nfs-server@1.2.2 | nfs-system | An NFS server in the cluster. It serves `/home` | ns, csi-driver-nfs |
| `slurm-cluster-storage` | helm-slurm-cluster-storage@4.1.13 | soperator | The volumes for the jail, the data submount and the controller spool. They map to the Nebius filesystems (`filestoreDeviceName`) | ns, storageclasses, soperator |
| `security-profiles-operator` | security-profiles-operator@0.8.5-soperator | security-profiles-operator-system | Manages seccomp and AppArmor profiles | ns |
| `custom-configmaps` | helm-soperator-custom-configmaps@4.1.13 | soperator | Extra ConfigMaps for the Slurm pods **[inferred]** | ns |
| `slurm-cluster` | helm-slurm-cluster@4.1.13 | soperator | **Creates the `SlurmCluster` custom resource.** The operator builds controller and login from it | ns, soperator, slurm-cluster-storage, security-profiles-operator, nfs-server |
| `nodesets` | helm-nodesets@4.1.13 | soperator | Creates the `NodeSet` named `worker` (2 replicas) | ns, soperator, slurm-cluster |
| `soperator-activechecks` | helm-soperator-activechecks@4.1.13 | soperator | Creates the 25 `ActiveCheck` resources | slurm-cluster, soperatorchecks |
| `dcgm-exporter` | helm-soperator-dcgm-exporter@4.1.13 | soperator | GPU metrics (DaemonSet on GPU nodes, port 9400) | none |
| `vm-stack` | victoria-metrics-k8s-stack@0.39.4 | monitoring-system | Metrics: `vmsingle`, `vmagent`, Grafana, kube-state-metrics, node-exporter, VM operator | ns, cert-manager, victoria-metrics-operator-crds |
| `monitoring-dashboards` | helm-soperator-monitoring-dashboards@4.1.13 | monitoring-system | Grafana dashboards for Slurm and GPUs | ns |
| `vm-logs` | victoria-logs-single@0.9.8 | logs-system | VictoriaLogs, the log store | none |
| `opentelemetry-collector-logs` | opentelemetry-collector@0.149.0 | logs-system | A log agent on every node **[inferred from name]** | ns, vm-logs |
| `opentelemetry-collector-events` | opentelemetry-collector@0.149.0 | logs-system | Collects Kubernetes events **[inferred from name]** | ns, vm-logs |
| `opentelemetry-collector-jail-logs` | opentelemetry-collector@0.149.0 | logs-system | Collects logs from the jail **[inferred from name]** | ns, vm-logs, nodesets |

### The install order (from `dependsOn`)

1. No dependencies, so they start first: `ns`, the two CRD charts, `vm-logs`, `dcgm-exporter`, `soperator-fluxcd`.
2. Next: `cert-manager`, `storageclasses`, `csi-driver-nfs`, `security-profiles-operator`.
3. Then: `kruise`, `nfs-server`.
4. Then the operator: `soperator`.
5. Then: `soperatorchecks`, `nodeconfigurator`, `slurm-cluster-storage`.
6. Then the cluster: `slurm-cluster`, then `nodesets`.
7. Last: `soperator-activechecks` (needs the cluster and the checks controller).

This order is why the apply takes a long time. The `soperator-activechecks` release must wait for everything above it. In my case it also waited for the `ensure-healthy-nodes` check (check your own issue notes for details).

---

## 5. CRDs

90 CRDs. The command I used showed 91 because it counted the header line. **[live]**

| API group | CRDs | Added by | What they are for |
|---|---|---|---|
| `operator.victoriametrics.com` | 16 | victoria-metrics-operator-crds | Objects of the VictoriaMetrics operator (such as `VMSingle`, `VMAgent`) |
| `apps.kruise.io` | 16 | kruise | Extra workload types (such as Advanced StatefulSet, CloneSet, ImagePullJob) |
| `cilium.io` | 12 | Cilium (managed) | Cilium network policies and internal objects |
| `monitoring.coreos.com` | 10 | prometheus-operator-crds | `ServiceMonitor`, `PodMonitor`, `PrometheusRule` and others. Used by the metrics scraping |
| `security-profiles-operator.x-k8s.io` | 8 | security-profiles-operator | Seccomp and AppArmor profiles |
| `slurm.nebius.ai` | 6 | soperator | **The Slurm objects. See below** |
| Flux toolkit (`source`, `notification`, `image`, `kustomize`, `helm`) | 6 + 3 + 3 + 1 + 1 = 14 | Flux | `HelmRelease`, `HelmRepository`, `HelmChart`, `Kustomization` and others |
| `cert-manager.io`, `acme.cert-manager.io` | 4 + 2 | cert-manager | `Certificate`, `Issuer`, `ClusterIssuer` and the ACME objects |
| `policy.kruise.io` | 1 | kruise | Kruise policy object |
| `autoscaling.x-k8s.io` | 1 | managed (`ca-provisioning-request`) | Probably the `ProvisioningRequest` for autoscaling **[inferred]** |

### The six `slurm.nebius.ai` CRDs

| Kind | What it is | What I saw **[live]** |
|---|---|---|
| `SlurmCluster` (v1) | The whole Slurm cluster in one object: images, resources, node filters, partitions, Slurm settings | `soperator`: status `Available`, controllers `True`, login 1, sconfigcontroller `True`, accounting `False` |
| `NodeSet` (v1alpha1) | A group of Slurm workers | `worker`: `Ready`, desired 2, ready 2 |
| `ActiveCheck` (v1alpha1) | A health check or housekeeping task. Either a Slurm job or a Kubernetes job, with a schedule | 25 objects. See the next table |
| `JailedConfig` | Takes a ConfigMap and writes it as a file into the jail, then reloads Slurm | 3: `soperator-slurm-configs` → `/etc/slurm/slurm.conf`, `topology-config` → `/etc/slurm/topology.conf`, `activecheck-prolog` → `/etc/slurm/activecheck-prolog.sh` |
| `NodeConfigurator` | Settings for the node configurator DaemonSet and its rebooter | `soperator-node-configurator`, rebooter enabled |
| `NodeSetPowerState` | Power state of a node set. Not used here | "No resources found" |

### The 25 ActiveChecks

Each ActiveCheck becomes a `CronJob` in Kubernetes. Two types:

| Type | What it does | Examples |
|---|---|---|
| `k8sJob` | Runs as a Kubernetes job | `create-user-nebius`, `create-user-soperatorchecks`, `ensure-dir-snccld-logs`, `ssh-check`, `wait-for-topology`, `wait-for-soperatorchecks-srun-ready`, `soperator-outputs-logs-cleaner`, `manage-jail-state*`, `retrigger-checks`, `upgrade-health-checker` |
| `slurmJob` | Submits a job into Slurm and follows it | `ensure-healthy-nodes`, `all-reduce-perf-nccl-with-ib`, `all-reduce-perf-nccl-without-ib`, `cuda-samples`, `gpu-fryer`, `ib-gpu-perf`, `mem-perf`, `dcgmi-diag-r2/r3`, `enroot-cleanup`, `prepull-container-image`, `extensive-check` |

Three fields matter: `INIT` (run once after the cluster is created), `SUSPEND` (stop scheduling it), and the cron `SCHEDULE`. A schedule of `0 0 1 1 *` together with `SUSPEND=true` means the check does not run on its own. It runs only when triggered. **[live]**

The first inventory shows all 25 checks. My rebuild uses `active_checks_scope = "essential"`, so the set on the current cluster may be different. I did not re-check. **[unverified]**

---

## 6. What runs in the `soperator` namespace

| Object | Kind | What it is |
|---|---|---|
| `controller-0` | pod, 2/2 containers | `slurmctld`, the Slurm scheduler, plus `munge` (authentication). Runs on the controller node |
| `login-0` | pod, 2/2 | The SSH entry point for users |
| `worker-0`, `worker-1` | pods, 2/2 | One per GPU node. `slurmd` runs the jobs. The second container looks like `munge` **[inferred from the volumes]** |
| `sconfigcontroller` | Deployment, 2 replicas | Watches the Slurm config and reloads it when a ConfigMap changes |
| `slurm-exporter` | Deployment | Slurm metrics for Prometheus |
| `jail-mount`, `jail-submount-data-mount` | DaemonSets (7 each) | Mount the shared filesystems on each node (see section 8) |
| `controller-spool-mount`, `controller-placeholder` | DaemonSets (1 each) | The same, for the controller spool |
| `helm-soperator-dcgm-exporter-ds` | DaemonSet (2) | GPU metrics, only on GPU nodes |
| `soperator-populate-jail` | Job | Fills the jail with the OS files once, at the start |
| ActiveCheck CronJobs and Jobs | CronJob, Job | See section 5 |

**Pod anatomy.** The controller, login and worker pods each have an init container called `ensure-jail-virtiofs`. It checks that the jail is mounted with the `virtiofs` type before the main containers start. **[code]**, **[live]**

**Not a normal StatefulSet.** `controller-0`, `login-0` and the workers do not appear in `kubectl get sts` for `apps/v1`. Only `nfs-server` and `vm-logs` do. kubectl also warns that `sts` could match `statefulsets.apps.kruise.io`. So I believe the Slurm pods are Kruise StatefulSets. **[inferred]**

**Config as ConfigMaps.** `soperator-slurm-configs` (Slurm config), `slurm-scripts` (22 files: prolog, epilog and others), `topology-config` and `topology-node-labels`, `sbatch-script-*` (one per slurmJob check), and the SSH and limits configs. **[live]**

---

## 7. Networking

### Address space **[live]**

| Range | Used for |
|---|---|
| `10.5.x.x` | Service (ClusterIP) addresses. CoreDNS is `10.5.0.10`, the API server service is `10.5.0.1` |
| `10.6.x.x` | Node addresses and pod addresses. Each node gets its own `/24` range for pods |

### CNI: Cilium

Cilium is the network plugin (a `cilium` pod on every node, plus `cilium-envoy`, an operator and Hubble for visibility). There are no `kube-proxy` pods in `kube-system`, so I believe Cilium also handles Services. **[inferred]** Inside a worker pod, `eth0` has a `/32` address and the default route has an MTU of 1400. Note this for NCCL tests: the pod network has a smaller MTU than the usual 1500. **[live]**

### DNS

CoreDNS answers on `10.5.0.10`. It forwards everything outside the cluster to `8.8.8.8`. A worker's `resolv.conf` has the search domains `soperator.svc.cluster.local`, the cluster domains, and the headless services `soperator-nodeset-svc` and `soperator-login-headless-svc`. That lets Slurm nodes find each other by short name. `ndots:5`. **[live]**

### Services in `soperator`

| Service | Type | Port | What it does |
|---|---|---|---|
| `soperator-login-svc` | **LoadBalancer** | 22 | **The only public entry.** A public IP, SSH to `login-0`. `login.sh` reads this IP |
| `soperator-login-headless-svc` | ClusterIP, headless | 22 | Direct pod DNS for the login pod |
| `soperator-controller-svc` | ClusterIP | 6817 | slurmctld |
| `soperator-nodeset-svc`, `soperator-nodeset-worker-svc` | ClusterIP, headless | 6818 | slurmd on the workers. Headless means DNS returns the pod addresses, so each worker has a stable name |
| `helm-soperator-dcgm-exporter-svc` | ClusterIP | 9400 | GPU metrics |
| `soperator-sconfigcontroller-metrics` | ClusterIP | 8080 | Metrics |

Other namespaces have mostly metrics and webhook services: `nfs-server` (2049, 111, 20048), Grafana (80), `vmsingle` and `vmagent` (8429), the operator webhooks (443). **[live]**

### Network policies and webhooks

- Only `flux-system` has NetworkPolicies: `allow-egress`, `allow-scraping`, `allow-webhooks`. The `soperator` namespace has none. **[live]**
- No Ingress at all. **[live]**
- Admission webhooks: cert-manager, Kruise (22 validating, 12 mutating), VictoriaMetrics operator, Soperator (3 validating, 1 mutating), Security Profiles Operator (2 mutating). cert-manager supplies their certificates. **[live]**

### Traffic between the workers

Workers talk to each other over `eth0`, as plain TCP. There is no InfiniBand, so NCCL uses `NET/Socket`. My NCCL test measured about 3.9 to 4.0 GB/s bus bandwidth between the two GPUs. MPI also uses `eth0`: the SlurmCluster has `pmixEnv: OMPI_MCA_btl_tcp_if_include=eth0`. **[live]**

---

## 8. Storage

### Storage classes **[live]**

| Class | Provisioner | Mode | Used for |
|---|---|---|---|
| `compute-csi-default-sc` (default) | `compute.csi.nebius.com` | WaitForFirstConsumer | VictoriaLogs (32 Gi) and `vmsingle` (32 Gi) |
| `compute-csi-network-ssd-ext4` | `compute.csi.nebius.com` | WaitForFirstConsumer | NFS server disk (64 Gi), controller spool disk (50 Gi) |
| Five more `compute-csi-network-ssd-*` classes (xfs, io-m3, non-replicated) | `compute.csi.nebius.com` | WaitForFirstConsumer | Not used here |
| `nfs` | `nfs.csi.k8s.io` | Immediate | The `home-dir` volume (`/home`) |
| `slurm-local-pv` | `kubernetes.io/no-provisioner` | WaitForFirstConsumer | The three filestore volumes (jail, data, controller spool). No dynamic provisioning: the PVs are created by hand in the chart |

Two CSI drivers: the Nebius compute CSI (block disks, with attach) and the NFS CSI (no attach). **[live]**

### PersistentVolumes and claims **[live]**

| Claim | Namespace | Size | Mode | Class | Backed by |
|---|---|---|---|---|---|
| `jail-pvc` | soperator | 1 Ti | RWX | `slurm-local-pv` | Nebius shared filesystem (the "jail"). PV reclaim policy `Retain` |
| `jail-submount-data-pvc` | soperator | 1 Ti | RWX | `slurm-local-pv` | Nebius shared filesystem (data). `Retain` |
| `controller-spool-pvc` | soperator | 128 Gi | RWX | `slurm-local-pv` | Nebius shared filesystem. `Retain`. I did not check which pod mounts this claim |
| `controller-spool-controller-0` | soperator | 50 Gi | RWO | `compute-csi-network-ssd-ext4` | A network SSD disk. It is `/var/spool/slurmctld` in `controller-0` |
| `home-dir` | soperator | shows `42` | RWX | `nfs` | The in-cluster NFS server. `df` shows 63 G for `/home`. I do not know why the claim shows `42` |
| `nfs-server-storage` | nfs-system | 64 Gi | RWO | `compute-csi-network-ssd-ext4` | The disk behind the NFS server |
| `server-volume-vm-logs-...` | logs-system | 32 Gi | RWO | `compute-csi-default-sc` | VictoriaLogs data |
| `vmsingle-...` | monitoring-system | 32 Gi | RWO | `compute-csi-default-sc` | Metrics data |

### The jail

The jail is a shared filesystem that looks like one Linux root to every Slurm node. Users log in to it, jobs run in it, and the same files are on the login node and both workers. The chain, as far as the evidence shows: a Nebius shared filesystem is attached to each VM as a `virtiofs` device, a `jail-mount` DaemonSet mounts it on the node, a PV with class `slurm-local-pv` points to it, and the pods mount `jail-pvc` as `/mnt/jail`. The `virtiofs` part is proven by the init container check. The "DaemonSet mounts, local PV points to it" part is my reading of the object names. **[live]**, **[inferred]**

In a worker (`df -h`): `jail` 1.0T at `/mnt/jail`, the NFS home at `/mnt/jail/home`, the data filesystem at `/mnt/jail/mnt/data` (1.0T), a RAM disk at `/mnt/jail/mnt/memory` (176G, the `memory` submount), `/dev/shm` 64G. **[live]**

---

## 9. Scheduling and limits

| PriorityClass | Value | For |
|---|---|---|
| `soperator-worker-high-priority` | 10,000,000 | Workers that must win |
| `soperator-slurm-controller` | 1,000,001 | Controller |
| `soperator-slurm-worker` | 1,000,000 | Workers |
| `soperator-slurm-accounting`, `-login`, `-exporter`, `-rest`, `-sconfigcontroller`, `-populate-jail` | 100,002 to 100,007 | The other Slurm components |
| `nfs-server-high` | 10,000 | NFS server |
| `system-cluster-critical`, `system-node-critical` | about 2,000,000,000 | Kubernetes system pods |

Slurm pods are ranked above the platform pods. If a node is short of room, Kubernetes can preempt lower-priority pods first. **[live]**

- **ResourceQuota:** one only, `critical-pods` in `flux-system`. **[live]**
- **PodDisruptionBudgets:** six in `kube-system` (Cilium operator, CoreDNS, Hubble, metrics-server). None for Slurm. **[live]**
- **No headroom:** on the system nodes, CPU requests were at 71 to 96% and memory at 82 to 86%. Little headroom is left for extra pods. **[live]**

---

## 10. The GPU stack

| Component | Where | Job |
|---|---|---|
| `nvidia-device-plugin-<node>` | `kube-system`, one per GPU node | Tells Kubernetes the node has `nvidia.com/gpu: 1` |
| Driver, CUDA, NCCL | In the node image (labels show 580.x driver, CUDA 13.0) | No GPU Operator. The `nvidia.com/gpu.deploy.operands=false` label is consistent with that |
| `helm-soperator-dcgm-exporter-ds` | `soperator`, GPU nodes only | GPU metrics on port 9400 |
| `nebius-node-problem-detector-gpu` | `kube-system`, GPU nodes | Reports GPU faults as node conditions (`NebiusGPUError`) |
| `dranet`, `nebius-dcgm` | `kube-system`, DaemonSets with 0 pods | Wait for labels that no node has (RDMA-capable, container toolkit) |

The worker pod sees the GPU through the Slurm GRES config (`gres.conf`), not through a Kubernetes resource request. **[inferred]**

---

## 11. Slurm as Kubernetes shows it

- **Partitions:** `main` (the default) and `hidden`. Both contain `worker-[0-1]`. **[live]**
- **Key Slurm settings (from the SlurmCluster):** `MinJobAge` 28800 seconds (8 hours), `topology/tree` with `SwitchAsNodeRank`, cgroup v2, `select/cons_tres`, `sched/backfill`, `GresTypes=gpu`, Pyxis for containers. **[live]**
- **Accounting is off:** `AccountingStorageType` is empty, so `sacct` does not work. Use `scontrol show job` and `squeue`. **[live]**
- **Each worker:** 16 CPUs (`1:8:2`), 176 GiB, one H100, features `gpu_h100_sxm,network_ssd`. **[live]**

---

## 12. Commands to show it live

```bash
kubectl get ns
kubectl get nodes -L slurm.nebius.ai/nodeset -L slurm.nebius.ai/workload -L topology.nebius.com/tier-1
kubectl get helmreleases -A
kubectl api-resources --api-group=slurm.nebius.ai
kubectl -n soperator get slurmcluster,nodeset
kubectl -n soperator get activechecks
kubectl -n soperator get pods -o wide | grep -E '^(NAME|controller-0|login-0|worker-0|worker-1) '
kubectl -n soperator get svc
kubectl get sc
kubectl -n soperator get pvc
kubectl -n soperator exec controller-0 -c slurmctld -- sinfo -N -o "%N %G %T"
```

Before you share any output, remove IPs, node names, cluster IDs and the load balancer address.

---

## 13. Likely questions, with short answers

**Why Flux and Helm, and not Terraform for everything?**
Terraform is good at cloud resources. Operators and their charts have their own order and drift. Flux keeps them in sync and retries. Terraform installs Flux once and hands over.

**What is the operator for?**
It turns the `SlurmCluster` object into running pods and keeps them correct. I change one object, not many pods.

**Why is Slurm on Kubernetes?**
Kubernetes gives self-healing, one platform for platform pods and Slurm, and easy upgrades. Slurm gives what researchers expect: `sbatch`, `srun`, queues and gang scheduling. Soperator joins the two.

**What is the jail?**
One shared root filesystem that every Slurm node mounts. Users install software once, and every node sees it.

**Why do you have taints and node labels?**
Labels say what a node is (`nodeset`, `workload`). Taints keep other pods off the controller, NFS and GPU nodes. The SlurmCluster node filters connect pods to nodes.

**What did you change from the stock recipe, and why?**
The recipe assumes 8-GPU nodes with InfiniBand. I use 1-GPU nodes. I turned off the GPU cluster, fixed the GRES, added the topology labels, and sized filesystems to fit the quota. Check the exact list against your issue notes before you say it.

**What was the biggest problem?**
The topology labels (`wait-for-topology`) and the `ensure-healthy-nodes` check, which waited for checks that never start in the `essential` scope. Both came from the recipe expecting an InfiniBand fabric.

**What is the network performance, and what limits it?**
About 4 GB/s between the two GPUs over TCP. No InfiniBand, so NCCL cannot use RDMA. The pod network also has an MTU of 1400. The limit is not fully explained, so I would measure more before I promised more.

**What would you do for production?**
Use 8-GPU nodes with InfiniBand, turn accounting on, spread the system nodes, add Slurm PodDisruptionBudgets, and keep Flux values in Git.

---

## 14. Corrections and open points

- **Job history lifetime.** Earlier I told you `scontrol show job` keeps a finished job for about 5 minutes. That was wrong for this cluster. The SlurmCluster sets `minJobAge: 28800`, which is 8 hours. Check it with `scontrol show config | grep -i MinJobAge` on the controller, and fix the README text.
- **`storage-system`:** the namespace appears in `helm list` and not in `kubectl get ns`. Not explained.
- **`home-dir` PVC size:** shows `42`. Not explained.
- **Which pod uses `controller-spool-pvc`:** not checked.
- **Current cluster:** this file comes from the first cluster's inventory plus the code. Run section 12 on the current cluster if it is still up, and compare the ActiveCheck list with your `essential` scope.
- **All `[inferred]` items** are my reading from names and behavior. Say "I believe" for those.
