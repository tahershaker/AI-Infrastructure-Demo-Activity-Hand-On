# 04 - GRES Data Is Written for 8-GPU Nodes

> The Slurm controller (`controller-0`) crashed in a loop after `terraform apply` created the cluster. The GPU (GRES) configuration in the recipe is written for a full 8-GPU server, but my worker nodes have 1 GPU and 16 vCPUs. Slurm refused the configuration and stopped. I changed the GRES lines for the `gpu-h100-sxm` platform in my local copy of the recipe so they describe a 1-GPU node. After this, the controller ran without restarts.

---

# Issue Summary

- After the disk quota fix, `terraform apply` moved forward, but it waited on the Flux release `flux-system-soperator-fluxcd-soperator-activechecks`.
- The Kubernetes cluster was up, but `controller-0` was in `CrashLoopBackOff` with exit code `0`.
- The controller log ended with `fatal: Invalid GRES data for gpu, Cores=0-31 (only 16 CPUs are available)`.
- The recipe has a fixed GRES block for the `gpu-h100-sxm` platform. It has 8 GPU lines, one for each GPU of a full 8-GPU server, and it is chosen by platform name only.
- My nodes use the `1gpu-16vcpu-200gb` preset, so the block does not fit.
- I replaced the 8 lines with 1 line for 1 GPU in `modules/available_resources/gres.tf`.
- After the change, `controller-0` was `2/2 Running` with 0 restarts, and Slurm showed one H100 on each worker.

---

# Questions to Nebius team

1. Is the GRES block for `gpu-h100-sxm` meant for 8-GPU presets only? Is the `1gpu-16vcpu-200gb` preset supported with Soperator `v4.1.13-2`?
2. Is there a supported way to set the GRES lines from `terraform.tfvars` or to use `AutoDetect`, so I do not have to edit the recipe?
3. In `gres.conf`, does `Cores=` count vCPUs or physical cores for this recipe? The stock lines use ids up to 63 on a 128 vCPU node, but the error compares the range with the number of CPUs.
4. To work around the hard-coded GRES lines, I edited `modules/available_resources/gres.tf` in my local copy of the recipe. Is this the expected approach?
5. If not, should I ask the Nebius team for a different approach, for example a supported setting or a fix in the recipe?

---

# Issue Description

## What is GRES

GRES means "generic resource". Slurm knows CPUs and memory by itself, but it does not know special hardware such as GPUs. So Slurm needs to be told about them in two places:

| Where | What it says | Value in this lab |
|---|---|---|
| Node definition (`slurm.conf`) | How many GPUs the node has | `Gres=gpu:nvidia_h100_80gb_hbm3:1` |
| GRES file (`gres.conf`) | One line for each GPU: which device it is and which CPU cores are close to it | See below |

A line in `gres.conf` looks like this:

```text
AutoDetect=off Name=gpu Type=${local.gres_by_platforms[local.platforms.gpu-h100-sxm]} File=/dev/nvidia0 Cores=0-15 Links=-1 Flags=nvidia_gpu_env
```

| Part | Meaning |
|---|---|
| `AutoDetect=off` | Slurm does not detect the GPUs by itself. It uses only the lines that it is given. |
| `Name=gpu` and `Type=...` | The kind of resource. |
| `File=/dev/nvidia0` | The device file of the GPU on the node. |
| `Cores=0-15` | The CPU cores that are close to this GPU. Slurm uses this to place jobs next to their GPU. |
| `Links=-1` | The fast links (NVLink) from this GPU to the other GPUs on the node. `-1` means the GPU itself. |

You can think of it as a seating plan. The node definition says "this room has 1 desk". The GRES lines say "desk 0 is at `/dev/nvidia0`, next to CPU cores 0-15". If the plan lists 8 desks, and seats that do not exist, Slurm refuses to open the room.

`terraform apply` was waiting for the Flux release `flux-system-soperator-fluxcd-soperator-activechecks` to finish. The Kubernetes cluster was up, and I could connect and investigate. The problem looked like it was inside the services that Flux creates. The steps below show how it led to the GRES lines.

---

# Troubleshooting steps

## Step 1: Check the nodes and the Flux releases

All 8 nodes were `Ready`, so the infrastructure was fine.

```bash
kubectl get nodes -o wide
NAME                     STATUS   ROLES    AGE   VERSION   OS-IMAGE             KERNEL-VERSION       CONTAINER-RUNTIME
computeinstance-<id>     Ready    <none>   16m   v1.35.7   Ubuntu 24.04.4 LTS   6.11.0-1016-nvidia   containerd://2.2.6
...                      (8 nodes in total, all Ready)
```

Then I checked the Flux releases. Two of them were `Unknown`, and all the others had succeeded, including `slurm-cluster`.

```bash
kubectl get helmreleases -A
NAMESPACE     NAME                                                              AGE   READY     STATUS
flux-system   flux-system-soperator-fluxcd-opentelemetry-collector-jail-logs    15m   Unknown   Running 'install' action with timeout of 15m0s
flux-system   flux-system-soperator-fluxcd-slurm-cluster                        15m   True      Helm install succeeded for release soperator/soperator.v1 with chart helm-slurm-cluster@4.1.13
flux-system   flux-system-soperator-fluxcd-soperator-activechecks               15m   Unknown   Running 'install' action with timeout of 2h0m0s
...
```

`Unknown` with `Running 'install' action` means that Flux is still waiting. It is not a failure by itself. So the next step is to find what these two releases are waiting for.

---

## Step 2: Find what the two releases wait for

`jail-logs` waited 15 minutes for its pod to become ready. Then the install failed with `context deadline exceeded`, and Flux removed the release to try again.

```bash
kubectl -n flux-system describe helmrelease flux-system-soperator-fluxcd-opentelemetry-collector-jail-logs
...
  Normal   DependencyNotReady  17m (x3 over 18m)  helm-controller  dependency 'flux-system/flux-system-soperator-fluxcd-nodesets' is not ready
  Warning  InstallFailed       94s                helm-controller  Helm install failed for release logs-system/opentelemetry-collector-jail-logs with chart opentelemetry-collector@0.149.0: context deadline exceeded
...
Deployment is not ready: logs-system/opentelemetry-collector-jail-logs. 0 out of 1 expected pods are ready
```

`activechecks` waited for the `slurm-cluster` release first. Then it started a job (`wait-for-active-checks`) that waits for the health checks to run on the Slurm cluster.

```bash
kubectl -n flux-system describe helmrelease flux-system-soperator-fluxcd-soperator-activechecks
...
  Normal  DependencyNotReady  17m (x7 over 20m)  helm-controller  dependency 'flux-system/flux-system-soperator-fluxcd-slurm-cluster' is not ready
```

Result: both releases need a working Slurm cluster, and the `slurm-cluster` release only installs the Slurm objects. The Slurm pods must be running too. So I looked at the pods.

---

## Step 3: Check the Slurm pods

```bash
kubectl -n soperator get pods
NAME                                READY   STATUS             RESTARTS       AGE
controller-0                        1/2     CrashLoopBackOff   5 (100s ago)   6m42s
login-0                             0/2     Pending            0              6m41s
worker-0                            1/2     Init:3/4           1 (59s ago)    6m41s
worker-1                            1/2     Init:3/4           1 (59s ago)    6m41s
wait-for-active-checks-xxxxx        1/1     Running            0              15m
...
```

Four pods were not healthy. I started with the controller, because it is the central Slurm component, and the other Slurm pods connect to it. The `login-0` and worker issues turned out to be separate. See [05-Login-Pod-Stuck-In-Pending](/07-Finding-&-Troubleshootings/05-Login-Pod-Stuck-In-Pending/README.md). and [06-Invalid-Topology-For-Single-GPU-Node](/07-Finding-&-Troubleshootings/06-Invalid-Topology-For-Single-GPU-Node/README.md).

---

## Step 4: Describe the controller pod

```bash
kubectl -n soperator describe pod controller-0
...
  slurmctld:
    State:          Waiting
      Reason:       CrashLoopBackOff
    Last State:     Terminated
      Reason:       Completed
      Exit Code:    0
      Started:      Sun, 11 Oct 2026 22:14:53 +0400
      Finished:     Sun, 11 Oct 2026 22:14:54 +0400
    Restart Count:  6
...
Events:
  Warning  BackOff  2m11s (x27 over 7m14s)  kubelet  spec.containers{slurmctld}: Back-off restarting failed container slurmctld in pod controller-0_soperator
```

This shows two things. The `munge` container was fine (`Running`, 0 restarts), and only `slurmctld` was failing. The `slurmctld` container lived for one second (22:14:53 to 22:14:54) and exited with code `0`, so Kubernetes started it again, again and again. `describe` does not say why. The answer must be in the log of the process.

---

## Step 5: Read the controller log

```bash
kubectl -n soperator logs controller-0
...
[2026-10-11T18:14:54.050] debug:  Reading cgroup.conf file /etc/slurm/cgroup.conf
[2026-10-11T18:14:54.053] topology/tree: init: topology tree plugin loaded
[2026-10-11T18:14:54.058] No node state file (/var/spool/slurmctld/node_state) to recover
[2026-10-11T18:14:54.060] No job state file (/var/spool/slurmctld/job_state) to recover
[2026-10-11T18:14:54.062] debug:  _parse_gres_config: Cores=0-31 is not being converted to machine-local format
[2026-10-11T18:14:54.062] fatal: Invalid GRES data for gpu, Cores=0-31 (only 16 CPUs are available)
```

The configuration files (`slurm.conf`, `cgroup.conf`, topology) were read without a problem. The process stopped when it read the GRES data. `fatal` means that `slurmctld` stops by itself, and this is also why the exit code was `0`.

For the full command outputs, see [01-output1](/07-Finding-&-Troubleshootings/04-Gres-Data-8-GPU/01-output1.txt).

---

## Step 6: Compare the error with my node

The error says that a GPU line uses cores `0-31`, but the node has only 16 CPUs. My workers use the preset `1gpu-16vcpu-200gb`. The recipe describes its CPUs in `modules/available_resources/cpu_topology.tf`:

| | My node (`1gpu-16vcpu-200gb`) | Full server (`8gpu-128vcpu-1600gb`) |
|---|---|---|
| GPUs | 1 | 8 |
| Sockets | 1 | 2 |
| Cores per socket | 8 | 32 |
| Threads per core | 2 | 2 |
| CPUs | **16** | **128** |

The Slurm node definition that the recipe creates for my node is correct: it has `CPUs=16` and `Gres=gpu:nvidia_h100_80gb_hbm3:1`. So the node definition is right, and the wrong part must be the GRES lines. The next step is to find where these lines come from.

---

## Step 7: Find the source of the GRES lines

I searched the recipe for `Cores=0-31`. The GPU lines are hard-coded per platform in `modules/available_resources/gres.tf`. For `gpu-h100-sxm`, there are 8 lines, one for each GPU of the full server:

```text
"AutoDetect=off Name=gpu Type=${local.gres_by_platforms[local.platforms.gpu-h100-sxm]} File=/dev/nvidia4 Cores=0-31 Links=-1,1,1,1,1,1,1,1 Flags=nvidia_gpu_env",
  "AutoDetect=off Name=gpu Type=${local.gres_by_platforms[local.platforms.gpu-h100-sxm]} File=/dev/nvidia5 Cores=0-31 Links=1,-1,1,1,1,1,1,1 Flags=nvidia_gpu_env",
  "AutoDetect=off Name=gpu Type=${local.gres_by_platforms[local.platforms.gpu-h100-sxm]} File=/dev/nvidia6 Cores=0-31 Links=1,1,-1,1,1,1,1,1 Flags=nvidia_gpu_env",
  "AutoDetect=off Name=gpu Type=${local.gres_by_platforms[local.platforms.gpu-h100-sxm]} File=/dev/nvidia7 Cores=0-31 Links=1,1,1,-1,1,1,1,1 Flags=nvidia_gpu_env",
  "AutoDetect=off Name=gpu Type=${local.gres_by_platforms[local.platforms.gpu-h100-sxm]} File=/dev/nvidia0 Cores=32-63 Links=1,1,1,1,-1,1,1,1 Flags=nvidia_gpu_env",
  "AutoDetect=off Name=gpu Type=${local.gres_by_platforms[local.platforms.gpu-h100-sxm]} File=/dev/nvidia1 Cores=32-63 Links=1,1,1,1,1,-1,1,1 Flags=nvidia_gpu_env",
  "AutoDetect=off Name=gpu Type=${local.gres_by_platforms[local.platforms.gpu-h100-sxm]} File=/dev/nvidia2 Cores=32-63 Links=1,1,1,1,1,1,-1,1 Flags=nvidia_gpu_env",
  "AutoDetect=off Name=gpu Type=${local.gres_by_platforms[local.platforms.gpu-h100-sxm]} File=/dev/nvidia3 Cores=32-63 Links=1,1,1,1,1,1,1,-1 Flags=nvidia_gpu_env",
```

The numbers match the full server: 2 sockets with 32 cores each give the ranges `0-31` and `32-63`. The recipe picks these lines by the **platform name only**, and it does not look at the preset: - From main.tf:

```hcl
gres_config                              = lookup(module.resources.gres_config_by_platform, nodeset.resource.platform, null)
```

The nodesets template (`flux_release_nodesets.yaml.tftpl`) then writes each line into the Slurm node set under `gresConfig:`. There is no variable in `terraform.tfvars` that can change it.

So the stock value is wrong for my node in three ways:

| What the recipe says | What my node has | Result |
|---|---|---|
| `Cores=0-31` and `Cores=32-63` | 16 CPUs | Fatal error. The controller stops. This is what I saw. |
| 8 GPU lines | 1 GPU | The node definition says 1 GPU, but the file describes 8. |
| `/dev/nvidia0` to `/dev/nvidia7` | Only `/dev/nvidia0` | Device files that do not exist. |

---

# Conclusion

The GRES lines for the `gpu-h100-sxm` platform describe a full 8-GPU server with 128 CPUs. The recipe selects them by platform name only, and so it also applies them to my 1-GPU node with 16 CPUs. Slurm checks the lines when it starts, finds cores `0-31` on a node with 16 CPUs, and stops with a `fatal` error. Kubernetes starts the container again, and the cycle repeats. The Flux releases that need the Slurm cluster to work wait for it until their timeout.

---

# Workaround

The GRES lines cannot be changed from `terraform.tfvars`, so I edited the recipe file in my local copy. In `modules/available_resources/gres.tf`, I commented out the 8 stock lines for `gpu-h100-sxm` and added one line that matches my preset (1 GPU, 16 vCPUs).

```hcl
(local.platforms.gpu-h100-sxm) = [
  "AutoDetect=off Name=gpu Type=${local.gres_by_platforms[local.platforms.gpu-h100-sxm]} File=/dev/nvidia0 Cores=0-15 Links=-1 Flags=nvidia_gpu_env"
  # "AutoDetect=off Name=gpu Type=${local.gres_by_platforms[local.platforms.gpu-h100-sxm]} File=/dev/nvidia4 Cores=0-31 Links=-1,1,1,1,1,1,1,1 Flags=nvidia_gpu_env",
  # "AutoDetect=off Name=gpu Type=${local.gres_by_platforms[local.platforms.gpu-h100-sxm]} File=/dev/nvidia5 Cores=0-31 Links=1,-1,1,1,1,1,1,1 Flags=nvidia_gpu_env",
  # "AutoDetect=off Name=gpu Type=${local.gres_by_platforms[local.platforms.gpu-h100-sxm]} File=/dev/nvidia6 Cores=0-31 Links=1,1,-1,1,1,1,1,1 Flags=nvidia_gpu_env",
  # "AutoDetect=off Name=gpu Type=${local.gres_by_platforms[local.platforms.gpu-h100-sxm]} File=/dev/nvidia7 Cores=0-31 Links=1,1,1,-1,1,1,1,1 Flags=nvidia_gpu_env",
  # "AutoDetect=off Name=gpu Type=${local.gres_by_platforms[local.platforms.gpu-h100-sxm]} File=/dev/nvidia0 Cores=32-63 Links=1,1,1,1,-1,1,1,1 Flags=nvidia_gpu_env",
  # "AutoDetect=off Name=gpu Type=${local.gres_by_platforms[local.platforms.gpu-h100-sxm]} File=/dev/nvidia1 Cores=32-63 Links=1,1,1,1,1,-1,1,1 Flags=nvidia_gpu_env",
  # "AutoDetect=off Name=gpu Type=${local.gres_by_platforms[local.platforms.gpu-h100-sxm]} File=/dev/nvidia2 Cores=32-63 Links=1,1,1,1,1,1,-1,1 Flags=nvidia_gpu_env",
  # "AutoDetect=off Name=gpu Type=${local.gres_by_platforms[local.platforms.gpu-h100-sxm]} File=/dev/nvidia3 Cores=32-63 Links=1,1,1,1,1,1,1,-1 Flags=nvidia_gpu_env",
]
```

---