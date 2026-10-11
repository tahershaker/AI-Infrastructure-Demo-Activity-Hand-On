# GRES Data Is Written for 8-GPU Nodes

> The Slurm controller crashed in a loop after `terraform apply` created the cluster. The cause was the GPU (GRES) configuration in the recipe. It is written for an 8-GPU node, but my nodes have 1 GPU and 16 vCPUs each. I found the file in the recipe and changed it in my local copy so it describes a 1-GPU node.

---

# Issue Description

I found this issue whilst I was fixing the disk quota limit. See [03-Qouta-Limitation-On-Disk](/07-Finding-&-Troubleshootings/03-Qouta-Limitation-On-Disk/README.md). This issue is not related to the disk quota.

`terraform apply` was stuck, waiting for the Flux release `flux-system-soperator-fluxcd-soperator-activechecks` to finish. The Kubernetes cluster was up and running, and I could connect to it and investigate.

At first look, the problem seemed to be in the services that Flux tries to create. Flux was stuck and could not finish the installation.

---

# Troubleshooting steps

## Step 1: Look at the full Kubernetes cluster

The cluster was up and all nodes were `Ready`.

```bash
kubectl get nodes -o wide
NAME                      STATUS   ROLES    AGE   VERSION   OS-IMAGE             KERNEL-VERSION       CONTAINER-RUNTIME
computeinstance-<id-1>    Ready    <none>   16m   v1.35.7   Ubuntu 24.04.4 LTS   6.11.0-1016-nvidia   containerd://2.2.6
computeinstance-<id-2>    Ready    <none>   16m   v1.35.7   Ubuntu 24.04.4 LTS   6.11.0-1016-nvidia   containerd://2.2.6
...
(8 nodes in total, all Ready)
```

Next, I checked the Flux HelmReleases. Two of them were in the `Unknown` state, and `flux-system-soperator-fluxcd-soperator-activechecks` is one of them. All the others had succeeded.

```bash
kubectl get helmreleases -A
NAMESPACE     NAME                                                             AGE   READY     STATUS
...
flux-system   flux-system-soperator-fluxcd-opentelemetry-collector-jail-logs   15m   Unknown   Running 'install' action with timeout of 15m0s
...
flux-system   flux-system-soperator-fluxcd-slurm-cluster                       15m   True      Helm install succeeded for release soperator/soperator.v1 with chart helm-slurm-cluster@4.1.13
...
flux-system   flux-system-soperator-fluxcd-soperator-activechecks              15m   Unknown   Running 'install' action with timeout of 2h0m0s
...
```

`Unknown` with `Running 'install' action` means that Flux is still waiting. It is not a failure by itself. So I looked at the Soperator components to see what was failing, and I found that the controller was in `CrashLoopBackOff`.

```bash
kubectl -n soperator get pods
NAME                                READY   STATUS             RESTARTS       AGE
pod/controller-0                    1/2     CrashLoopBackOff   5 (100s ago)   6m42s
pod/login-0                         0/2     Pending            0              6m41s
pod/worker-0                        1/2     Init:3/4           1 (59s ago)    6m41s
pod/worker-1                        1/2     Init:3/4           1 (59s ago)    6m41s
pod/wait-for-active-checks-xxxxx    1/1     Running            0              15m
...
```

The workers are in `Init:3/4`, and I expected that they were waiting for the controller.

## Step 2: Check the resources and find the root cause

First, I checked the HelmRelease `flux-system-soperator-fluxcd-opentelemetry-collector-jail-logs`, which was in the `Unknown` state. I found that Helm waited 15 minutes for the pod to become ready, and then the install failed with `context deadline exceeded`. Flux then removed the release and will try again.

```bash
kubectl -n flux-system describe helmrelease flux-system-soperator-fluxcd-opentelemetry-collector-jail-logs
...
Events:
  Type     Reason              Age                From             Message
  ----     ------              ----               ----             -------
  Normal   DependencyNotReady  17m (x3 over 18m)  helm-controller  dependency 'flux-system/flux-system-soperator-fluxcd-nodesets' is not ready
  Warning  InstallFailed       94s                helm-controller  Helm install failed for release logs-system/opentelemetry-collector-jail-logs with chart opentelemetry-collector@0.149.0: context deadline exceeded

Last Helm logs:
...
Deployment is not ready: logs-system/opentelemetry-collector-jail-logs. 0 out of 1 expected pods are ready (447 duplicate lines omitted)
wait for resources failed after 15m0s: context deadline exceeded
  Normal  UninstallSucceeded  94s  helm-controller  Helm uninstall remediation for release logs-system/opentelemetry-collector-jail-logs.v1 with chart opentelemetry-collector@0.149.0 succeeded
```

Second, I checked `flux-system-soperator-fluxcd-soperator-activechecks`. It was waiting for the `slurm-cluster` release first. Then it started and waited for a job to finish.

```bash
kubectl -n flux-system describe helmrelease flux-system-soperator-fluxcd-soperator-activechecks
...
Events:
  Type    Reason              Age                From             Message
  ----    ------              ----               ----             -------
  Normal  DependencyNotReady  17m (x7 over 20m)  helm-controller  dependency 'flux-system/flux-system-soperator-fluxcd-slurm-cluster' is not ready
```

Third, I checked the controller pod. `describe` showed nothing clear. The container started, exited with code 0, and was restarted by Kubernetes again and again.

```bash
kubectl -n soperator describe pod controller-0
...
    State:          Waiting
      Reason:       CrashLoopBackOff
    Last State:     Terminated
      Reason:       Completed
      Exit Code:    0
...
Events:
  Warning  BackOff  2m11s (x27 over 7m14s)  kubelet  spec.containers{slurmctld}: Back-off restarting failed container slurmctld in pod controller-0_soperator
```

Last, I read the log of the controller. This is where I found the real error on the last line:

```bash
kubectl -n soperator logs controller-0
...
[2026-10-11T18:14:54.018] warning: CONMGR_THREADS=32 is configured outside of the suggested range of [2, 8] for 4 CPUs. ...
...
[2026-10-11T18:14:54.062] debug:  _parse_gres_config: Cores=0-31 is not being converted to machine-local format
[2026-10-11T18:14:54.062] fatal: Invalid GRES data for gpu, Cores=0-31 (only 16 CPUs are available)
```

Please refer to [01-output1.txt](/07-Finding-&-Troubleshootings/04-Gres-Data-8-GPU/01-output1.txt) for the full command outputs.

## Step 3: Understand the error

GRES means "generic resource". It is how Slurm describes the GPUs on each node. The line `fatal: Invalid GRES data for gpu, Cores=0-31 (only 16 CPUs are available)` says that Slurm read a GPU description that uses CPU cores 0 to 31, but the node has only 16 CPUs. This is a `fatal` error, so `slurmctld` stops. Kubernetes starts it again, and it fails again. This is why the exit code was 0 and the pod was still in `CrashLoopBackOff`.

My worker nodes use the `1gpu-16vcpu-200gb` preset: 1 H100 GPU and 16 vCPUs. So I needed to find where `Cores=0-31` comes from.

## Step 4: Find the source in the recipe

I searched the recipe files. The GPU description is fixed per platform in `modules/available_resources/gres.tf`. For `gpu-h100-sxm`, it has 8 lines, one for each GPU of a full 8-GPU server:

```text
AutoDetect=off Name=gpu Type=nvidia_h100_80gb_hbm3 File=/dev/nvidia4 Cores=0-31  Links=-1,1,1,1,1,1,1,1 Flags=nvidia_gpu_env
AutoDetect=off Name=gpu Type=nvidia_h100_80gb_hbm3 File=/dev/nvidia5 Cores=0-31  Links=1,-1,1,1,1,1,1,1 Flags=nvidia_gpu_env
...
AutoDetect=off Name=gpu Type=nvidia_h100_80gb_hbm3 File=/dev/nvidia0 Cores=32-63 Links=1,1,1,1,-1,1,1,1 Flags=nvidia_gpu_env
...
```

The recipe picks this file by the **platform name only**. It does not look at the preset, so it does not know if the node has 1 GPU or 8 GPUs. The value goes into the Slurm node configuration through `installations/example/main.tf`:

```hcl
gres_config = lookup(module.resources.gres_config_by_platform, nodeset.resource.platform, null)
```

There is no variable in `terraform.tfvars` that can change it.

This stock value is wrong for my node in three ways:

| What the recipe says | What my node has | Result |
|---|---|---|
| `Cores=0-31` and `Cores=32-63` | 16 vCPUs | Fatal error. The controller stops. This is what I saw. |
| 8 GPU lines | 1 GPU | Slurm would see 8 GPUs, but the node is defined with 1. |
| `/dev/nvidia0` to `/dev/nvidia7` | Only `/dev/nvidia0` | Device files that do not exist. |

---

# Workaround

The value cannot be changed from `terraform.tfvars`, so I changed the recipe file itself. 

In `modules/available_resources/gres.tf`, I replaced the 8 lines of `gpu-h100-sxm` with one line for one GPU. I kept the old lines as comments, so the stock value stays visible:

```hcl
(local.platforms.gpu-h100-sxm) = [
      "AutoDetect=off Name=gpu Type=${local.gres_by_platforms[local.platforms.gpu-h100-sxm]} File=/dev/nvidia0 Cores=0-15 Links=-1 Flags=nvidia_gpu_env"
      # "AutoDetect=off Name=gpu Type=${local.gres_by_platforms[local.platforms.gpu-h100-sxm]} File=/dev/nvidia4 Cores=0-31 Links=-1,1,1,1,1,1,1,1 Flags=nvidia_gpu_env",
      # ... 
    ]
```

What each part means:

- **One GPU line.** The node has one GPU, and it is `/dev/nvidia0`.
- **`Cores=0-15`.** The node has 16 vCPUs, so the range is now inside what the node has.
- **`Links=-1`.** `Links` lists the link to each GPU on the node. With one GPU, there is only the GPU itself, which is `-1`.

**Open point.** I am not sure if `Cores=` counts vCPUs or physical cores. The node has 8 physical cores with 2 threads each. The stock 8-GPU lines use ids up to 63 for a 128-vCPU node, which suggests physical cores. The error message compared against 16 CPUs, which suggests vCPUs. I chose `0-15`, because the error message is the direct evidence from my own cluster. If Slurm rejects it, my next tries are `Cores=0-7`, and then no `Cores=` at all. With one GPU, the `Cores=` value does not change anything in practice.

I destroyed the lab and applied again from zero, to prove that the change works from a clean start.











**[TO COMPLETE: paste the outputs after the rebuild]**

| Check | Command | Expected | Result |
|---|---|---|---|
| Controller is healthy | `kubectl -n soperator get pods` | `controller-0` is `2/2 Running` | [TO COMPLETE] |
| Workers started | same | `worker-0` and `worker-1` are `Running` | [TO COMPLETE] |
| Both HelmReleases finish | `kubectl get helmreleases -A` | `jail-logs` and `activechecks` are `True` | [TO COMPLETE] |
| Slurm sees the GPU | `sinfo -N -o "%N %G %T"` from a worker pod | one `gpu:nvidia_h100_80gb_hbm3:1` per node, state `idle` | [TO COMPLETE] |

## Note for production

The GPU layout in this recipe is fixed per platform and assumes full 8-GPU servers. This is fine for production nodes, but it breaks small test sizes, such as a 1-GPU node. A better design would choose the GPU lines from the preset, or let Slurm detect the GPUs by itself. For a customer who wants to start small, this is a step to plan for, and a feedback item for the Soperator team.

---
