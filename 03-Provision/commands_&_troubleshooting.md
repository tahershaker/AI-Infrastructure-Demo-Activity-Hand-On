# Soperator troubleshooting: Kubernetes and Slurm commands

Use this file when something looks wrong. Each section answers one question. Each command has a short note on what it shows. Work from the top down: Kubernetes first, then Slurm.

**Where to run what.**
- `kubectl` and `helm` commands run on your laptop, with the kubeconfig of the cluster.
- `sinfo`, `squeue`, `srun`, `sbatch` and `scontrol` run on the login pod (`login-0`), or inside `controller-0`.
- Before you share any output, remove IPs, node names, cluster IDs, tokens and the load balancer address.

**Quick rule for finding the cause.** Start with the layer that is lowest and broken. Order: node, then Flux and HelmRelease, then operator, then pod, then Slurm. A Slurm problem is often a pod problem, and a pod problem is often a Flux or node problem.

---

## 1. Is the cluster healthy? (first five minutes)

```bash
# Are all nodes Ready?
kubectl get nodes -o wide

# Show the Slurm role labels next to each node
kubectl get nodes -L slurm.nebius.ai/nodeset -L slurm.nebius.ai/workload -L topology.nebius.com/tier-1 -L topology.nebius.com/tier-2

# Which pods are NOT Running or Completed? (empty output is good)
kubectl get pods -A | grep -v -E 'Running|Completed'

# Which HelmReleases are not Ready? (look at READY and STATUS)
kubectl get helmreleases -A

# Is the SlurmCluster Available, and are the workers ready?
kubectl -n soperator get slurmcluster,nodeset
```

What to look for: a node `NotReady`, a pod in `Pending`, `CrashLoopBackOff` or `ImagePullBackOff`, a HelmRelease with `READY False`, or a SlurmCluster that is not `Available`.

---

## 2. Nodes

```bash
# Full detail of one node: labels, taints, capacity, conditions, pods on it
kubectl describe node <node-name>

# How much CPU and memory is requested on each node (look at "Allocated resources")
kubectl describe nodes | grep -E '^Name:|cpu .*%|memory .*%'

# Live CPU and memory use (needs metrics-server, which is installed)
kubectl top nodes

# Taints on every node
kubectl get nodes -o custom-columns=NAME:.metadata.name,TAINTS:.spec.taints

# Does the node report a GPU to Kubernetes?
kubectl get nodes -o custom-columns=NAME:.metadata.name,GPU:.status.allocatable.nvidia\\.com/gpu

# Node conditions, including GPU faults from the problem detector
kubectl get nodes -o json | jq -r '.items[] | .metadata.name as $n | .status.conditions[] | select(.status=="True" and .type!="Ready") | "\($n) \(.type) \(.message)"'
```

**Example.** A pod is `Pending` with "0/8 nodes are available: ... Insufficient cpu". `describe nodes` shows the system nodes at 90% CPU requests. The fix is more room, not a restart.

---

## 3. Flux and HelmReleases

Flux installs everything. If a component is missing or old, look here first.

```bash
# All HelmReleases with ready state and message
kubectl -n flux-system get helmreleases

# Why is one HelmRelease failing? (read the Conditions and Events at the bottom)
kubectl -n flux-system describe helmrelease <name>

# Which HelmReleases are blocked, and by what? (dependsOn shows the order)
kubectl -n flux-system get helmrelease <name> -o jsonpath='{.spec.dependsOn}' ; echo

# Can Flux reach the chart sources?
kubectl -n flux-system get helmrepositories,helmcharts

# Flux controller logs (the helm-controller does the install work)
kubectl -n flux-system logs deploy/helm-controller --tail=100
kubectl -n flux-system logs deploy/source-controller --tail=100

# Force Flux to try again now (needs the flux CLI)
flux reconcile helmrelease <name> -n flux-system

# Helm's own view of what is installed
helm list -A
helm -n <namespace> history <release>
```

What to look for: `install retries exhausted`, `dependency ... is not ready`, `timeout`, or a chart that cannot be pulled. A HelmRelease that waits on a dependency is normal during the first apply. It is only a problem if it stays that way.

---

## 4. Pods

```bash
# All pods of the Slurm cluster, with their nodes
kubectl -n soperator get pods -o wide

# Only the four main pods
kubectl -n soperator get pods -o wide | grep -E '^(NAME|controller-0|login-0|worker-0|worker-1) '

# Why is a pod Pending, restarting or failing? Read "Events" at the bottom
kubectl -n soperator describe pod <pod>

# Logs of a pod. Add -c <container> if it has more than one
kubectl -n soperator logs <pod> --tail=100

# Logs of the previous run (use after a crash or restart)
kubectl -n soperator logs <pod> --previous --tail=100

# Which containers does a pod have? (container and init container names)
kubectl -n soperator get pod <pod> -o jsonpath='{.spec.initContainers[*].name}{"\n"}{.spec.containers[*].name}{"\n"}'

# Logs of an init container (for example the jail check)
kubectl -n soperator logs <pod> -c ensure-jail-virtiofs

# Recent events in a namespace, newest last
kubectl -n soperator get events --sort-by=.lastTimestamp | tail -30

# CPU and memory use per pod
kubectl top pods -n soperator

# Open a shell in a pod
kubectl -n soperator exec -it <pod> -c <container> -- bash
```

**Reading pod states.**

| State | Usual cause | First command |
|---|---|---|
| `Pending` | No node fits: not enough CPU or memory, taint, or label mismatch | `describe pod`, read Events |
| `Init:0/1` stuck | Init container waiting, for example the jail is not mounted | `logs <pod> -c ensure-jail-virtiofs` |
| `ImagePullBackOff` | Wrong image name or no access to the registry | `describe pod`, read Events |
| `CrashLoopBackOff` | The program starts and exits | `logs --previous` |
| `ContainerCreating` for long | A volume cannot be attached or mounted | `describe pod`, read Events |
| `Error` or `Completed` on a Job pod | Normal for one-shot checks. Read the logs only if the job failed | `logs <pod>` |

---

## 5. The Soperator objects

```bash
# The SlurmCluster in full: status and the settings the operator uses
kubectl -n soperator get slurmcluster soperator -o yaml

# Only the status part
kubectl -n soperator get slurmcluster soperator -o jsonpath='{.status}' | jq

# Worker node set: desired and ready
kubectl -n soperator get nodeset
kubectl -n soperator describe nodeset worker

# Config files managed by the operator
kubectl -n soperator get jailedconfigs

# The node configurator
kubectl get nodeconfigurators

# The operator itself: this is where reconcile errors show up
kubectl -n soperator-system get pods
kubectl -n soperator-system logs deploy/soperator-controller-manager --tail=100
```

If a worker pod does not appear, read the operator log first. If the SlurmCluster is not `Available`, `describe` it and look at the conditions.

---

## 6. Health checks (ActiveChecks)

```bash
# All checks: type, schedule, suspended or not, last status
kubectl -n soperator get activechecks

# One check in detail
kubectl -n soperator describe activecheck <name>

# The Kubernetes side: CronJobs, Jobs and their pods
kubectl -n soperator get cronjobs
kubectl -n soperator get jobs
kubectl -n soperator get pods | grep -E 'Error|Failed|Init'

# Logs of one failed check job
kubectl -n soperator logs job/<job-name>

# The checks controller
kubectl -n soperator-system logs deploy/soperator-checks-checks --tail=100
```

Notes:
- `SUSPEND true` with a schedule of `0 0 1 1 *` means the check does not run on its own.
- A check that never finishes can block others. Example: `ensure-healthy-nodes` waits for the nodes to be healthy before the next release starts.
- `wait-for-topology` waits for the topology labels on the nodes. If it hangs, check the labels (section 2).

---

## 7. Networking

```bash
# All services in the Slurm namespace
kubectl -n soperator get svc

# The login service and its public address (IP removed before sharing)
kubectl -n soperator get svc soperator-login-svc

# Which pods sit behind a service?
kubectl -n soperator get endpoints

# Test DNS from inside a pod
kubectl -n soperator exec -it worker-0 -c <container> -- getent hosts controller-0

# Cilium: is the network plugin healthy on every node?
kubectl -n kube-system get pods -l k8s-app=cilium -o wide
kubectl -n kube-system logs ds/cilium --tail=50

# CoreDNS
kubectl -n kube-system get pods -l k8s-app=kube-dns
kubectl -n kube-system logs deploy/coredns --tail=50

# Network policies (only flux-system has them)
kubectl get networkpolicy -A

# Pod network details from inside a worker (MTU, address)
kubectl -n soperator exec -it worker-0 -c <container> -- ip addr show eth0
```

**Example.** SSH to the login address times out. Check that `soperator-login-svc` has an external address, that `login-0` is `Running`, and that the service has an endpoint.

---

## 8. Storage

```bash
# Storage classes and which one is the default
kubectl get sc

# Claims and volumes
kubectl -n soperator get pvc
kubectl get pv

# Why is a claim Pending or not bound? Read Events
kubectl -n soperator describe pvc <name>

# CSI drivers and the node plugins
kubectl get csidrivers
kubectl -n kube-system get pods | grep csi

# The jail mount DaemonSets (one pod per node)
kubectl -n soperator get ds
kubectl -n soperator get pods -o wide | grep -E 'jail|spool'

# Disk use inside a pod (jail, home, data)
kubectl -n soperator exec -it worker-0 -c <container> -- df -h

# The NFS server behind /home
kubectl -n nfs-system get pods,pvc
kubectl -n nfs-system logs sts/nfs-server --tail=50
```

What to look for: a claim `Pending`, a `jail-mount` pod missing on a node, or a full disk (`df -h` shows 100%).

---

## 9. GPUs

```bash
# Does Kubernetes see the GPU on the node?
kubectl describe node <gpu-node> | grep -i -E 'nvidia.com/gpu|gpu'

# NVIDIA device plugin pods (one per GPU node)
kubectl -n kube-system get pods | grep nvidia-device-plugin

# GPU metrics exporter
kubectl -n soperator get pods | grep dcgm

# GPU problem detector
kubectl -n kube-system get pods | grep problem-detector

# Inside a worker: is the driver working? (also try it through srun, section 11)
kubectl -n soperator exec -it worker-0 -c <container> -- nvidia-smi
```

---

## 10. Logs and metrics stack

```bash
kubectl -n logs-system get pods
kubectl -n monitoring-system get pods

# Grafana from your laptop (then open http://localhost:3000)
kubectl -n monitoring-system port-forward svc/<grafana-service> 3000:80
kubectl -n monitoring-system get svc
```

Use the Grafana dashboards for GPU use and Slurm queue length. Use VictoriaLogs (via the Grafana data source) to search logs after a pod is gone.

---

## 11. Slurm: state of the cluster

Run these on `login-0`.

```bash
# Partitions and node states (summary)
sinfo

# One line per node: name, GRES, state
sinfo -N -o "%N %G %T"

# Why are nodes down or drained? (reason, who, when)
sinfo -R

# Detail of one node: state, GRES, features, reason
scontrol show node worker-0

# Only the useful lines
scontrol show node worker-0 | grep -E 'State=|Gres=|Reason=|CPUTot|RealMemory|AvailableFeatures'

# Running and waiting jobs
squeue

# Jobs with the reason they wait
squeue -o "%.10i %.9P %.12j %.8u %.2t %.10M %.6D %R"

# Test that both workers answer
srun -N2 hostname

# Test that both workers see their GPU
srun -N2 --gpus-per-node=1 nvidia-smi --query-gpu=name,memory.total,driver_version --format=csv,noheader
```

**Node states.**

| State | Meaning | What to do |
|---|---|---|
| `idle` | Free and ready | Nothing |
| `alloc` or `mixed` | Running jobs | Nothing |
| `idle~` or `CLOUD` flag | Powered-down style flag from the cloud mode | Normal here. Check with `scontrol show node` |
| `drain` or `drng` | Node removed from scheduling, with a reason | Read `sinfo -R`, fix the cause, then resume |
| `down` | Slurm lost contact with the node | Check the worker pod (section 4) |

```bash
# Put a node back into service (after you fixed the cause)
scontrol update nodename=worker-0 state=resume

# Take a node out for maintenance
scontrol update nodename=worker-0 state=drain reason="maintenance"
```

---

## 12. Slurm: jobs

```bash
# A pending job: why? (look at Reason=)
scontrol show job <jobid> | grep -E 'JobState=|Reason=|NodeList=|StartTime=|EndTime=|RunTime='

# A finished job (kept for about 8 hours here, MinJobAge is 28800)
scontrol show job <jobid> | grep -E 'JobState=|ExitCode=|StartTime=|EndTime=|NodeList=|StdOut=|StdErr='

# Cancel a job
scancel <jobid>

# Cancel all your jobs
scancel -u $USER

# Submit a script and follow its output
sbatch my_script.sh
tail -f slurm-<jobid>.out
```

**Notes.**
- Accounting is off, so `sacct` does not work. Use `scontrol show job` and `squeue`.
- Finished jobs disappear from `scontrol` after `MinJobAge`. Check the value with `scontrol show config | grep -i MinJobAge`.
- Common pending reasons: `Resources` (no free node), `Priority` (others first), `ReqNodeNotAvail` (a node is down or drained), `PartitionDown`.

---

## 13. Slurm: configuration

```bash
# Full running config
scontrol show config

# The settings you will be asked about
scontrol show config | grep -i -E 'SelectType|SchedulerType|TaskPlugin|ProctrackType|GresTypes|AccountingStorageType|MinJobAge|TopologyPlugin'

# Partitions
scontrol show partition

# Topology as Slurm sees it
scontrol show topology

# Is the controller up?
scontrol ping

# Reload the config after a change
scontrol reconfigure
```

The Slurm config files are managed by the operator through ConfigMaps (`soperator-slurm-configs`, `topology-config`). Do not edit them inside a pod. Change them through the Helm values or the SlurmCluster object, or the operator will overwrite them.

---

## 14. Slurm logs from Kubernetes

```bash
# Find the container names first
kubectl -n soperator get pod controller-0 -o jsonpath='{.spec.containers[*].name}{"\n"}'
kubectl -n soperator get pod worker-0 -o jsonpath='{.spec.containers[*].name}{"\n"}'

# Controller log (container name slurmctld)
kubectl -n soperator logs controller-0 -c slurmctld --tail=100

# Worker log (use the slurmd container name from the command above)
kubectl -n soperator logs worker-0 -c <slurmd-container> --tail=100

# Run a Slurm command inside the controller
kubectl -n soperator exec -it controller-0 -c slurmctld -- sinfo -N -o "%N %G %T"

# Slurm config reloader
kubectl -n soperator logs deploy/soperator-sconfigcontroller --tail=50
```

---

## 15. NCCL and network speed tests

```bash
# Multi-node NCCL test from login-0 (script from slurm-check-scripts)
sbatch 03_nccl_multi_node.sh

# Which network did NCCL use? (look for NET/Socket or NET/IB in the output)
grep -E 'NET/|Using network' <output-file>
```

Reading the result: `NET/Socket` means TCP over `eth0`. There is no InfiniBand here, so about 4 GB/s bus bandwidth is the level we measured. `#wrong` must be 0.

---

## 16. Common problems and where to start

| Symptom | Start here |
|---|---|
| `terraform apply` hangs or times out | `kubectl get helmreleases -A` (section 3), then `kubectl get activechecks -n soperator` (section 6) |
| A HelmRelease says "dependency not ready" | Follow `dependsOn` to the release at the bottom of the chain |
| Worker pod missing | Operator log (section 5), then `describe nodeset worker` |
| Pod stuck `Pending` | `describe pod`, read Events. Then node resources and taints (section 2) |
| Pod stuck in `Init` | Init container logs, jail mount (sections 4 and 8) |
| Node in `drain` | `sinfo -R` for the reason (section 11) |
| `srun` hangs | `sinfo`, `squeue`, then worker pod logs |
| GPU not seen in a job | `Gres=` on the node (section 11), device plugin pods (section 9) |
| Cannot SSH to the login node | Login service external address and `login-0` state (section 7) |
| `sacct` returns an error | Expected. Accounting is off. Use `scontrol` |
| NCCL result is slow | Check `NET/Socket` vs `NET/IB`, MTU on `eth0`, and the NCCL variables in the script |

---

## 17. What to collect before asking for help

```bash
kubectl get nodes -o wide
kubectl get pods -A | grep -v -E 'Running|Completed'
kubectl -n flux-system get helmreleases
kubectl -n soperator get slurmcluster,nodeset,activechecks
kubectl -n soperator get events --sort-by=.lastTimestamp | tail -30
kubectl -n soperator describe pod <problem-pod>
kubectl -n soperator logs <problem-pod> --tail=100
```

Remove IPs, node names, IDs and tokens first. Never paste state files or keys.

---