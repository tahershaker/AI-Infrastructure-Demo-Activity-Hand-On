# 03 - Provisioning

> Provisioning a Slurm-on-Kubernetes cluster with `Soperator` on `Nebius` Cloud, using Terraform and release `soperator-v4.1.13-2`, adapted to a small GPU allocation of only two single-H100 nodes.

---

# Description

This section holds everything needed to provision the cluster for the Nebius Demo Day task, starting from nothing.

The task is to run a distributed training or fine-tuning job on a Nebius `Soperator` cluster, using the latest Soperator release available at the time, `soperator-v4.1.13-2`.

Soperator is an open-source Kubernetes operator from Nebius. It runs Slurm, the job scheduler that many AI training teams already use, on top of Kubernetes. The Slurm way of working stays the same (a login node, `sbatch`, `srun`, partitions), but every Slurm part runs as a pod. This combines the best of both worlds. Nebius lists these benefits: nodes can be added or removed without manual setup (Kubernetes scalability), pods restart by themselves when they fail (Kubernetes self-healing), all nodes share one root filesystem (the "jail") so software versions do not drift, and automated GPU health checks run on the cluster. To read more, see Nebius' posts on [Slurm vs Kubernetes](https://nebius.com/blog/posts/model-pre-training/slurm-vs-k8s) and on [Soperator explained](https://nebius.com/blog/posts/soperator-in-open-source-explained). The code is in the [Soperator GitHub repo](https://github.com/nebius/nebius-solutions-library/tree/main/soperator).

A Soperator release is a Terraform recipe. It builds everything the cluster needs in one run. Terraform first creates a Nebius managed Kubernetes cluster, its node groups and the shared filesystems. It then installs Flux on the cluster. Flux deploys the Soperator operator and all the Slurm resources on top of Kubernetes, such as the controller, the login node, the workers, the storage, the monitoring and the health checks. When the run ends, the result is a healthy and working Slurm cluster that runs on Kubernetes.

The training job then runs on this cluster. The resources provided for this task are limited: only two worker nodes, and each node has one H100 GPU, not eight. The Soperator Terraform recipe is built for large clusters, so it cannot run as it is. The single-H100 preset cannot join an InfiniBand fabric, and the standard recipe assumes an InfiniBand fabric and a GPU cluster resource. The task therefore expects the recipe to be adapted to single-GPU nodes without InfiniBand. Multi-node jobs then run over the normal Ethernet network, so they are slower than on a production cluster.

InfiniBand is not the only problem. As expected for a task like this, there are several other limits. This README covers how the recipe works, every edit it needs to build a healthy cluster, the `terraform.tfvars` values, and the steps to deploy. Each edit links to an issue page that explains the problem behind it.

This section covers how the recipe works, every edit it needs to build a healthy cluster, the `terraform.tfvars` values, and the steps to deploy. Each edit links to an issue page that explains the problem behind it.

---

# How the Terraform script works

## The big picture

The recipe works in layers. Each layer builds the next one.

1. **`.envrc`** prepares the shell: login token, subnet, Terraform state storage, and the `TF_VAR_*` variables.
2. **Terraform** builds the Nebius base: the managed Kubernetes (Mk8s) cluster, its node groups (virtual machines), and the shared filesystems.
3. **Flux**, installed by Terraform, reads Helm releases and installs the software on the cluster, in a fixed order.
4. **The Soperator operator** reads the `SlurmCluster` and `NodeSet` definitions and turns them into pods: controller, login, workers, accounting, nfs.

The Kubernetes cluster is built from several node groups, and each node group is tied to one Slurm role. The recipe creates a system node group, a controller node group, a login node group, an accounting node group, an NFS node group, and a worker node group. Each node group has one or more virtual machines. The Slurm components do not run on the virtual machines directly. They run as pods on top of these node groups. Every node group carries a label that names its role, and some carry a taint, for example the GPU workers. A pod uses node affinity to ask for the label of its own group. It uses a toleration to be allowed onto a tainted node. This keeps each component on its own dedicated node group: the controller pod on the controller nodes, the login pod on the login nodes, and the Slurm jobs on the GPU workers.

## The files in an installation folder

The recipe is a folder of Terraform files. The `installations/example` folder is the starting point: copy it to a new folder with your own name, and all your work happens in that copy. These are the files in it.

| File | What it does |
|---|---|
| `.envrc` | Prepares the shell before Terraform runs (token, subnet, state storage, `TF_VAR_*` variables). |
| `terraform.tf` | Declares the Terraform version, the providers (`nebius`, `flux`, `kubernetes`, `helm`, `units`, `string-functions`) and how they connect to the new cluster. |
| `variables.tf` | Declares every input variable and checks its value (for example, minimum boot disk sizes). |
| `terraform.tfvars` | Holds the values for the variables: the cluster name, node and disk sizes, storage, and which features are on or off. This is the main file to edit. |
| `main.tf` | Calls the modules that build everything. |
| `driver_presets.tf` | Lists which GPU driver presets are supported per platform for each Kubernetes version. |
| `assets/render/` | Terraform writes the rendered NodeSet Helm values here during `apply`. It is an output, not an input. |

## What `.envrc` does

`source .envrc` must run in the shell before any Terraform command. In order, it:

1. Checks that `NEBIUS_TENANT_ID` and `NEBIUS_PROJECT_ID` are set, and sets the region (default `eu-north1`).
2. Gets an IAM token from the `nebius` CLI (it expires after some time, so source the file again when it does).
3. Looks up the VPC subnet of the project.
4. Selects the service account that Terraform uses for its state (the stock script creates `slurm-terraform-sa` and adds it to the `editors` group).
5. Deletes expired access keys of that account, then creates a new 1-day S3 access key and loads it into the shell as `AWS_ACCESS_KEY_ID` and `AWS_SECRET_ACCESS_KEY`.
6. Selects or creates the bucket that holds the state. By default, the stock script uses a bucket named `tfstate-slurm-k8s-<hash>` if it exists, and creates it (with versioning on) if it does not.
7. Writes `terraform_backend_override.tf`, which tells Terraform to keep its state in that bucket under the key `slurm-k8s.tfstate`.
8. Exports the `TF_VAR_*` variables that Terraform reads (region, token, tenant, project, subnet, o11y values).

## What `terraform.tfvars` does

`terraform.tfvars` is where the cluster is described. `variables.tf` declares the variables, and this file gives them their values. Terraform reads it automatically, so there is no extra step. It holds every choice that is specific to one cluster:

1. **Identity:** the company name, which also names the clusters and the `kubectl` context, and whether the cluster is production.
2. **Storage:** the jail filesystem, the extra shared filesystems, and the NFS server for `/home`.
3. **Nodes:** the node groups (system, controller, login, accounting, NFS, workers), with the VM type and the boot disk size of each. The worker node group also sets the number of workers and the GPU type.
4. **Slurm:** the partitions, the SSH public keys for the login node, and the health check scope.
5. **Features:** telemetry, accounting, backups and observability, each on or off.

A few values do not live in this file. The region, tenant, project, subnet and token come from `.envrc` as `TF_VAR_*` variables.

`variables.tf` checks every value when Terraform runs. For example, it rejects a boot disk below the minimum size for a node type.

## What Terraform does, in order

```bash
source .envrc        # prepare the shell
terraform init       # download providers and modules, connect to the state bucket
terraform validate   # check syntax and variable types, no calls to Nebius
terraform plan       # ask Nebius what exists, and list what would be created
terraform apply      # create the resources, after I type yes
```

During `apply`, `main.tf` calls these modules. Terraform works out the order from the `depends_on` lines and from the values one module hands to another.

| Order | Module | What it does |
|---|---|---|
| 1 | `filestore` | Creates (or attaches) the shared filesystems: jail, `data` submount, controller spool, accounting. |
| 2 | `cleanup` | Registers a clean-up script that runs on `terraform destroy`. It deletes leftover, unattached `pvc-*` disks that the cluster's Kubernetes volumes created (namespaces `logs-system`, `monitoring-system`, `soperator`, `nfs-system`). |
| 3 | `k8s` | Creates the Mk8s cluster and the node groups (system, controller, nfs, login, accounting, workers). Writes a `kubectl` context with `nebius mk8s cluster get-credentials`. Checks that the GPU presets and the `gpu_cluster` settings fit together. |
| 4 | `fluxcd` | Creates the `flux-system` namespace and applies the Flux install manifest (`flux2`, version `v2.7.4` in this release) with `kubectl apply`. |
| 5 | `o11y` | Public observability (logs to Nebius). Only if `public_o11y_enabled = true`. Off in my setup. |
| 6 | `backups_store`, `backups` | Backups of the jail. Only if backups are enabled. Off in my setup. |
| 7 | `slurm` | Hands the whole cluster definition to Flux (see below), then waits until it is healthy. |
| 8 | `login_script` | Writes `login.sh` into the installation folder, to connect to the login pod. |
| (-) | `k8s_cleanup` | Clean-up of Kubernetes leftovers when the cluster is destroyed. |
| (-) | `nvidia_operator_*` | GPU and network operators. Not created in my setup, because `use_preinstalled_gpu_drivers = true`. |

## What the `slurm` module hands to Flux

This is the step where Terraform stops building infrastructure and starts installing software.

1. **`terraform-fluxcd-values`** (a Helm release in `flux-system`). It stores one ConfigMap with all the values Flux needs: which components are on (telemetry, accounting, backups), versions, chart repositories, and the rendered worker NodeSets. Terraform also writes the NodeSet part to `assets/render/flux_release_nodesets.yaml`.
2. **`soperator-fluxcd-bootstrap`**. Installs the chart `helm-soperator-fluxcd-bootstrap` from `oci://cr.nebius.cloud/soperator`. This chart creates the Flux `HelmRelease` objects. From this point **Flux** does the installing.
3. **`soperator-fluxcd-values`**. An empty ConfigMap kept for manual value overrides. Terraform ignores later changes to it.

Flux then installs about 26 `HelmRelease` objects, each waiting for its dependencies:

| Layer | What gets installed |
|---|---|
| Operators | cert-manager, OpenKruise, security-profiles-operator, VictoriaMetrics operator, the Soperator controller manager, Soperator checks |
| Slurm cluster | The `SlurmCluster` (controller, login, config controller, exporter), the worker `NodeSet`, a job that populates the jail filesystem |
| Support | NFS server for `/home`, jail mount DaemonSets, VictoriaMetrics and Grafana, VictoriaLogs and OpenTelemetry, DCGM exporter |
| Checks | About 25 `ActiveCheck` objects (health checks that run as Slurm jobs) |

**Terraform waits for three things** before `apply` finishes:

- `HelmRelease` `flux-system-soperator-fluxcd-slurm-cluster` is ready 
- `HelmRelease` `flux-system-soperator-fluxcd-soperator-activechecks` is ready
- `SlurmCluster` reaches phase `Available` 

---

# Editing the recipe

The sections above explain how the recipe works. If the deployment starts with the stock recipe, it will fail. The Terraform script and some of the files around it must be edited first. This section lists every edit, in the order you need to make them.

## Why the recipe needs editing

The stock `Soperator` recipe builds a standard cluster for a large environment. By default it creates six node groups:

- **System:** runs the Soperator operators, the Flux Helm releases, monitoring and other support services.
- **Controller:** runs the Slurm controller pod.
- **Login:** runs the login pod, where users connect and submit jobs.
- **Accounting:** runs the accounting database (MariaDB) and the Slurm accounting daemon.
- **NFS:** runs the NFS server for `/home`.
- **Worker:** runs the Slurm worker pods, which execute the jobs on the GPUs.

The recipe is also designed mainly for 8-GPU nodes, and it depends heavily on an InfiniBand fabric. Finally, it assumes that the user who runs it has high privileges in the Nebius cloud, so that it can reach all the resources it needs.

This task does not offer a large environment. It provides only two GPU worker nodes, and each node has a single H100 GPU. It also sets a baseline for the other, non-GPU nodes, with a fixed node count and node size. The table below shows this baseline.

| Nodeset | Platform | Preset | vCPU per node | Node count | Baseline vCPU |
|:---|:---|:---|:---|:---|:---|
| System | `cpu-d3` | `8vcpu-32gb` | 8 | 4 to 5, autoscaled | 32 |
| Login | `cpu-d3` | `16vcpu-64gb` | 16 | 1 | 16 |
| Accounting | `cpu-d3` | `8vcpu-32gb` | 8 | 1 | 8 |
| Controller | `cpu-d3` | `4vcpu-16gb` | 4 | 1 | 4 |
| NFS | `cpu-d3` | `4vcpu-16gb` | 4 | 1 | 4 |
| **Baseline total** | | | | **8 nodes** | **64** |

The single-H100 limit causes more problems. The single-H100 preset does not support InfiniBand, so the recipe cannot create the InfiniBand fabric that it depends on. The same problem appears in the Slurm worker setup. A worker pod waits for network topology labels, and Nebius sets these labels only for nodes inside an InfiniBand fabric. Without them, the workers never start.

These are not the only problems. Even after they are fixed, other limits of the environment (small quotas and limited user rights, for example) stop the build. The recipe must therefore be edited before it runs, so that it builds successfully and results in a healthy Slurm cluster.

The edits below are listed one at a time. Each one explains what to change, why it is needed, and how to do it.

**About the edits.** This page does not explain the problems. Every edit has a short note and a link to its issue page, where the symptom, the evidence and the reasoning are written. Read the issue page if you want to know why.

## Download the release into a new folder

The recipe is published as a release of the `nebius-solutions-library` repository. This task uses the latest release - `soperator-v4.1.13-2`. Download the file `soperator-tf-4.1.13-2.tar.gz` from the [Soperator Terraform recipe releases](https://github.com/nebius/nebius-solutions-library/releases/tag/soperator-v4.1.13-2).

Unpack the file. The `soperator` folder inside it holds the recipe. Go into the `soperator` folder and create a new folder for your cluster under `installations/`. All the work for one cluster happens in this new folder. Then copy the content of `installations/example` into it. The `installations/example` folder is the template, and it stays untouched.

```bash
cd soperator-tf-4.1.13-2/soperator
export INSTALLATION_NAME=taher-demoday
mkdir -p installations/$INSTALLATION_NAME
cd installations/$INSTALLATION_NAME
cp -r ../example/* ../example/.* .
```

![image1](/03-Provision/Images/image1.png)

> Not all edits are made in the files you just copied into the installation folder. Some edits are made in the shared module files under `modules/`, which sit in the `soperator` folder and are used by every installation. Check the path at the start of each edit before you change a file.

## Edit summary

| # | File | What changes | Issue page |
|---|---|---|---|
| 1 | `installations/taher-demoday/.envrc` | Use the provided service account and bucket, and skip the `editors` group step | [01](/07-Finding-&-Troubleshootings/01-Provided-SA-Lacks-Required-Permissions/README.md) |
| 2 | `installations/taher-demoday/variables.tf` | Comment out a tenant lookup that the sandbox user is not allowed to run | [02](/07-Finding-&-Troubleshootings/02-Provided-SA-Lacks-Permissions-On-Tenant-Object/README.md) |
| 3 | `modules/k8s/gpu_fabric_validation.tf` | Do not demand a GPU cluster (InfiniBand) for a preset that cannot join one | No issue page yet |
| 4 | `modules/available_resources/gres.tf` | Describe one GPU, not eight, in the Slurm GRES lines | [04](/07-Finding-&-Troubleshootings/04-Gres-Data-8-GPU/README.md) |
| 5 | `modules/k8s/k8s_ng_workers_v2.tf` | Add two demo topology labels to the worker nodes | [05](/07-Finding-&-Troubleshootings/06-Invalid-Worker-Node-Topology-For-Single-GPU-Node/README.md) |
| 6 | `modules/slurm/main.tf` | Run the login pod on the system nodes | [06](/07-Finding-&-Troubleshootings/05-Login-Pod-Stuck-In-Pending/README.md) |
| 7 | `installations/taher-demoday/main.tf` | Set the disk request of the login pod to a fixed 64 GiB | [06](/07-Finding-&-Troubleshootings/05-Login-Pod-Stuck-In-Pending/README.md) |
| 8 | `modules/slurm/variables.tf` | Make the disks, CPU and memory of the monitoring stack smaller | [03](/07-Finding-&-Troubleshootings/03-Qouta-Limitation-On-Disk/README.md) |
| 9 | `installations/taher-demoday/terraform.tfvars` | Set the values for this sandbox | 03, 04, 05, 06 (see the `terraform.tfvars` section) |

Each edit changes a different file, and the commands match text or replace lines in place, so the order of the edits does not matter. After the edits, run `terraform init` and then `terraform validate`. It catches typing mistakes before anything is built.

---

## Edit 1: `.envrc` (service account, group and bucket)

**What to edit**

By default, `.envrc` looks for a service account named `slurm-terraform-sa`. If it does not find one, it creates it and adds it to the `editors` group. It then looks for a bucket named `tfstate-slurm-k8s-<hash>`. If it does not find one, it creates it. The state of Terraform is stored in that bucket.

Nebius provided two service accounts - `mlflow-sa` member of `editor` group | `soperator-taher-shaker-tfstate-sa` memeber of `soperator-taher-shaker-tfstate-writers` group - and one bucket - `csa-soperator-tfstate-taher-shaker-e00hq8rd` - for this task, so `.envrc` is edited to use them instead of creating new ones. The account to use is `mlflow-sa`. The other one, `soperator-taher-shaker-tfstate-sa`, does not have the permissions it needs.

So `.envrc` is edited in three places. It selects the provided account `mlflow-sa`, it skips the `editors` group step, and it uses the provided bucket.

**Why to edit**

The stock `.envrc` assumes it starts from nothing: it creates its own service account, adds that account to the `editors` group, and creates its own bucket for the Terraform state. That does not work in this sandbox, for two reasons.

First, the sandbox user cannot change group membership, so the step that adds a new service account to `editors` fails. Second, Nebius has already provided what the script would otherwise create: a state bucket and two service accounts. `mlflow-sa` is already a member of `editors` and can read and write the bucket, so it can be used as it is, and the group step is not needed. The other account, `soperator-taher-shaker-tfstate-sa`, has no permission on the bucket. It gets a `PermissionDenied` error when it tries to access the state, so it cannot be used.

Selecting `mlflow-sa`, pointing the script at the provided bucket, and skipping the group step avoids all of these failures. For the full investigation, see [01-Provided-SA-Lacks-Required-Permissions](/07-Finding-&-Troubleshootings/01-Provided-SA-Lacks-Required-Permissions/README.md).

**How to edit**

Open `installations/taher-demoday/.envrc` in VS Code, or any editor, and make three changes. Each change has a command that does it for you. Run the commands from inside `installations/taher-demoday/`.

**Change 1: use `mlflow-sa`.** At line 66, change `slurm-terraform-sa` to `mlflow-sa`. The script then looks for the account that the task provided.

> [!NOTE]
> If the name is not found, the script does not stop. It goes on to create a new account called `slurm-terraform-sa`. No safety check is added, to keep the number of changes small.

The end result looks like this:

    ...
    # region Service account

    NEBIUS_SA_TERRAFORM_ID=$(retry_nebius iam service-account list \
      --page-size 999 \
      --parent-id "${NEBIUS_PROJECT_ID}" \
      --format json \
      --page-size 1000 \
      | jq -r '.items[]? | select(.metadata.name == "mlflow-sa").metadata.id')

    if [ -z "$NEBIUS_SA_TERRAFORM_ID" ]; then
    ...

To make the change with a command:

```bash
sed -i.bak 's/select(.metadata.name == "slurm-terraform-sa")/select(.metadata.name == "mlflow-sa")/' .envrc
```

**Change 2: skip the `editors` group.** At line 81 starts the region `editors` group. Comment out the whole region (lines 83 to 104). The script then skips the group check and the group membership step.

The end result looks like this:

    # region `editors` group

    # NEBIUS_GROUP_EDITORS_ID=$(retry_nebius iam group get-by-name \
    #   --parent-id "${NEBIUS_TENANT_ID}" \
    #   --name 'editors' \
    #   --format json \
    #   | jq -r '.metadata.id')

    # IS_MEMBER=$(retry_nebius iam group-membership list-members \
    #   --parent-id "${NEBIUS_GROUP_EDITORS_ID}" \
    #   --page-size 1000 \
    #   --format json \
    #   | jq -r --arg SAID "${NEBIUS_SA_TERRAFORM_ID}" '.memberships[] | select(.spec.member_id == $SAID) | .spec.member_id')

    # # Add service account to group editors only if not already a member
    # if [ -z "${IS_MEMBER}" ]; then
    #   nebius iam group-membership create \
    #     --parent-id "${NEBIUS_GROUP_EDITORS_ID}" \
    #     --member-id "${NEBIUS_SA_TERRAFORM_ID}"
    #   echo "Added service account to editors group"
    # else
    #   echo "Service account is already a member of editors group"
    # fi

    # endregion `editors` group

To make the change with a command:
```bash
sed -i.bak '83,104{/^$/!s/^/# /;}' .envrc
```

**Change 3: use the provided bucket.** At line 171, replace the generated bucket name with the name of the bucket that Nebius provided. You can find the name in the console, or with `nebius storage bucket list --parent-id "$NEBIUS_PROJECT_ID"`.

> [!NOTE]
> The name must be exact. If it is wrong, the script does not find the bucket, and it creates a new one. After you source `.envrc`, check that the output says "Using existing bucket" and not "Created bucket".

The end result looks like this:

    ...
    NEBIUS_BUCKET_NAME="csa-soperator-tfstate-taher-shaker-e00hq8rd"
    export NEBIUS_BUCKET_NAME
    # Check if bucket exists
    EXISTING_BUCKET=$(retry_nebius storage bucket list \
      --parent-id "${NEBIUS_PROJECT_ID}" \
      --format json \
      | jq -r --arg BUCKET "${NEBIUS_BUCKET_NAME}" '.items[]? | select(.metadata.name == $BUCKET) | .metadata.name')
    ...

To make the change with a command, first put the bucket name in a variable:

```bash
sed -i.bak "s|^NEBIUS_BUCKET_NAME=\"tfstate-slurm-k8s-.*\$|NEBIUS_BUCKET_NAME=\"csa-soperator-tfstate-taher-shaker-e00hq8rd\"|" .envrc
```

---

## Edit 2: `variables.tf` (unused tenant lookup)

**What to edit**

At lines 49 to 51, `variables.tf` declares a `data` block that asks Nebius to read the tenant `csa-hiring-sandbox`. The sandbox user is not allowed to read the tenant object, so Terraform fails with a `PermissionDenied` error. Nothing else in the release uses the result of this block, so the three lines are commented out.

**Why to edit**

Terraform runs every `data` block during `terraform plan`. The sandbox user can work inside the project, but is not allowed to read the tenant itself, so the Terrafom plan stops with a `PermissionDenied` error. A search of the whole release shows that nothing uses the result of this lookup, and the tenant ID is still available as `var.iam_tenant_id`. Removing the block loses nothing. For the full story, see [02-Permission-Denied-Reading-Tenant-Data-Source](/07-Finding-&-Troubleshootings/02-Provided-SA-Lacks-Permissions-On-Tenant-Object/README.md).

**How to edit**

Open `installations/taher-demoday/variables.tf` in VS Code, or any editor, and comment out lines 49 to 51.

The end result looks like this:

```hcl
...
# data "nebius_iam_v1_tenant" "this" {
#   id = var.iam_tenant_id
# }
...
```

To make the change with a command:

```bash
sed -i.bak '49,51s/^/# /' variables.tf
```

---

## Edit 3: `modules/k8s/gpu_fabric_validation.tf` (InfiniBand check)

**What to edit**

Before it builds anything, Terraform checks the network setting of each worker node group. A GPU worker must have a `gpu_cluster` (an InfiniBand GPU cluster). A CPU worker must not. The provided worker preset, `1gpu-16vcpu-200gb`, cannot join an InfiniBand fabric (GPU cluster), so `gpu_cluster` must be set to `null` in the `terraform.tfvars` file. The check in `gpu_fabric_validation.tf` then fails, because it demands a GPU cluster for every GPU preset. The check is edited so that it passes for this preset. Two small changes are made:

- a new field `gpu_cluster_compatible` in the local value
- the condition uses `is_gpu && gpu_cluster_compatible` instead of `is_gpu`

**Why to edit**

The provided GPU worker preset is a single-GPU H100 node, `1gpu-16vcpu-200gb`. It is a GPU preset, but it cannot join a GPU cluster (`gpu_cluster_compatible = false`). So in `terraform.tfvars`, the value of `gpu_cluster` must be set to `null`.

The file `modules/k8s/gpu_fabric_validation.tf` reads the details of each worker preset. If the preset is a GPU preset, it checks that a `gpu_cluster` is set. If none is set, the validation fails and Terraform stops.

This recipe is designed for a large cluster with InfiniBand, not for a small cluster without it. So the check needs these changes before it passes for this node.

**How to edit**

Open `modules/k8s/gpu_fabric_validation.tf` in VS Code, or any editor, and make two changes.

- **Change 1: load the compatibility flag.** After line 8 (the `is_gpu` line), add a new line `gpu_cluster_compatible = module.resources.by_platform[worker.resource.platform][worker.resource.preset].gpu_cluster_compatible`. The validation then also knows whether the preset can join a GPU cluster.

The end result looks like this:

```hcl
...
      platform               = worker.resource.platform
      is_gpu                 = module.resources.by_platform[worker.resource.platform][worker.resource.preset].gpus > 0
      gpu_cluster_compatible = module.resources.by_platform[worker.resource.platform][worker.resource.preset].gpu_cluster_compatible
      has_gpu_cluster        = worker.gpu_cluster != null
...
```

To make the change with a command:

```bash
perl -pi.bak -e 'if (/^\s+is_gpu\s+=/) { $_ .= "      gpu_cluster_compatible = module.resources.by_platform[worker.resource.platform][worker.resource.preset].gpu_cluster_compatible\n" }' ../../modules/k8s/gpu_fabric_validation.tf
```

- **Change 2: use the flag in the condition.** In the `condition` of the `precondition` block (line 22 in the stock file, line 23 after change 1), change `each.value.is_gpu` to `(each.value.is_gpu && each.value.gpu_cluster_compatible)`. The validation then takes the compatibility of the preset into account, which is `false` for this preset, and not only whether the preset has a GPU.

The end result looks like this:

```hcl
...
    precondition {
      condition = (
        (each.value.is_gpu && each.value.gpu_cluster_compatible)
        ? (each.value.has_gpu_cluster && (length(each.value.cluster_id) > 0 || length(each.value.fabric) > 0))
        : !each.value.has_gpu_cluster
...
```

To make the change with a command:

```bash
perl -pi -e '$n && s/each\.value\.is_gpu$/(each.value.is_gpu && each.value.gpu_cluster_compatible)/; $n = /condition = \($/;' ../../modules/k8s/gpu_fabric_validation.tf
```

---

## Edit 4: `modules/available_resources/gres.tf` (GRES Config - GPU lines for one GPU)

**What to edit**

GRES (Generic Resources) lines tell Slurm which GPUs a node has. The recipe sets them by platform name in `modules/available_resources/gres.tf`. For the platform `gpu-h100-sxm`, it lists eight lines (lines 20 to 27), one for each GPU of a full 8-GPU server, and it has no option for a single GPU. The provided worker has one GPU only. So the eight lines are commented out, and one line for a single GPU is added.

**Why to edit**

The stock lines describe eight GPUs, but the node has only one. Slurm stops with a fatal error when it finds GPUs that do not exist, and the controller restarts again and again. The lines are fixed in the module, so `terraform.tfvars` cannot change them.

`Cores` lists the numbers of the CPU cores next to the GPU. The node has 8 cores (16 CPUs, with 2 threads per core), so the cores are numbered 0 to 7. For the full story, see [04-Gres-Data-8-GPU](/07-Finding-&-Troubleshootings/04-Gres-Data-8-GPU/README.md).

> [!NOTE]
> This edit changes the lines of the whole `gpu-h100-sxm` platform. It is correct for 1-GPU H100 nodes only, and it cannot be used for an 8-GPU node.

**How to edit**

Open `modules/available_resources/gres.tf`. in VS Code, or any editor, and make two changes.

- **Change 1: remove the 8-GPU lines.** Comment out lines 20 to 27 - This will remove the setting for an 8-GPU node.

The end result looks like this:

```hcl
(local.platforms.gpu-h100-sxm) = [
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

To make the change with a command:

```bash
sed -i.bak '20,27s|^\( *\)|\1# |' ../../modules/available_resources/gres.tf
```

- **Change 2: add the 1-GPU line.** After line 19 (`(local.platforms.gpu-h100-sxm) = [`), add this line:
  `"AutoDetect=off Name=gpu Type=${local.gres_by_platforms[local.platforms.gpu-h100-sxm]} File=/dev/nvidia0 Cores=0-7 Links=-1 Flags=nvidia_gpu_env"` - this will add the seting for a 1-GPU node

The end result looks like this:

```hcl
(local.platforms.gpu-h100-sxm) = [
    "AutoDetect=off Name=gpu Type=${local.gres_by_platforms[local.platforms.gpu-h100-sxm]} File=/dev/nvidia0 Cores=0-7 Links=-1 Flags=nvidia_gpu_env"
    # "AutoDetect=off Name=gpu Type=${local.gres_by_platforms[local.platforms.gpu-h100-sxm]} File=/dev/nvidia4 Cores=0-31 Links=-1,1,1,1,1,1,1,1 Flags=nvidia_gpu_env",
    ....
]
```

To make the change with a command:

```bash
perl -pi -e 'if (/^\s+\(local\.platforms\.gpu-h100-sxm\) = \[$/) { $_ .= "      \"AutoDetect=off Name=gpu Type=\${local.gres_by_platforms[local.platforms.gpu-h100-sxm]} File=/dev/nvidia0 Cores=0-7 Links=-1 Flags=nvidia_gpu_env\"\n" }' ../../modules/available_resources/gres.tf
```

---

## Edit 5: `modules/k8s/k8s_ng_workers_v2.tf` (topology labels)

**What to edit**

Soperator expects two labels on every worker node: `topology.nebius.com/tier-1` and `topology.nebius.com/tier-2`. They describe where the node sits in the network. Nebius adds them only to nodes inside an InfiniBand GPU cluster. The provided worker nodes are not in one, so the labels are missing. The worker node group in `modules/k8s/k8s_ng_workers_v2.tf` builds its labels with `merge(...)`. One line with the two labels, set to the demo values `demo-tier1` and `demo-tier2`, is added at the end of that list, after line 136.

**Why to edit**

Each Slurm worker pod starts with a step called `worker-init`. This step waits until it knows where its node sits in the network. Soperator reads this from the two labels and passes it to Slurm, which uses it to place the nodes of a job close together. When the labels are missing, `worker-init` stops after 180 seconds with the error `Topology for node ... not found`, and it tries again. The worker pod stays in `Init`, and `terraform apply` keeps waiting for the cluster. The recipe has no setting to skip this wait.

A cluster with one GPU per node and no InfiniBand has no real network layout to describe. So any fixed values are enough to remove the wait. The demo values do not describe a real network. For the full story, see [05-Topology-Wait](/07-Finding-&-Troubleshootings/06-Invalid-Worker-Node-Topology-For-Single-GPU-Node/README.md).


**How to edit**

Open `modules/k8s/k8s_ng_workers_v2.tf` and add one line after line 136 (`module.labels.label_exclude_from_external_lb,`).

The end result looks like this:

```hcl
...
        module.labels.label_exclude_from_external_lb,
        { "topology.nebius.com/tier-1" = "demo-tier1", "topology.nebius.com/tier-2" = "demo-tier2" },
      )
...
```

To make the change with a command:

```bash
perl -pi.bak -e 'if (/label_exclude_from_external_lb,$/) { $_ .= qq(        { "topology.nebius.com/tier-1" = "demo-tier1", "topology.nebius.com/tier-2" = "demo-tier2" },\n) }' ../../modules/k8s/k8s_ng_workers_v2.tf
```

---

## Edit 6: `modules/slurm/main.tf` (login pod placement)

**What to edit**

Soperator decides where each Slurm pod runs with node filters. A node filter has two rules: a node affinity (run only on nodes with this label) and a toleration (accept nodes with this taint). Every node group has its own label, `slurm.nebius.ai/nodeset`, and every Slurm component names the filter it uses: `system`, `controller`, `login`, `accounting` or `worker`.

At line 246 of `modules/slurm/main.tf`, the login pod uses the `login` filter, so it runs only on nodes labelled `login`. The edit changes it to the `system` filter, so the login pod runs on the system nodes.

**Why to edit**

The login node group is turned off in `terraform.tfvars`, because its 256 GiB boot disk would use part of the 2048 GiB disk quota. Without the group, no node has the `login` label. The login pod stays `Pending`, and the scheduler reports that four nodes do not match its affinity.

The comment in `terraform.tfvars` says that login pods then run on the worker nodes. That is true for GB300 nodes only. For H100 nodes the recipe always uses the `login` filter, and it has no fallback. The `system` filter is a safe choice, because the module already uses it for another pod. For the full story, see [06-Login-Pod-Pending](/07-Finding-&-Troubleshootings/05-Login-Pod-Stuck-In-Pending/README.md) and [03-Qouta-Limitation-On-Disk](/07-Finding-&-Troubleshootings/03-Qouta-Limitation-On-Disk/README.md).

> [!NOTE]
> The login pod is also sized for a 16 vCPU login node, so it does not fit on a system node yet. Edit 7 fixes this.

**How to edit**

Open `modules/slurm/main.tf` and change `login` to `system` at the end of line 246.

The end result looks like this:

```hcl
...
          k8s_node_filter_name     = var.login_on_worker_nodes ? local.node_filters.worker.name : local.node_filters.system.name
...
```

To make the change with a command:

```bash
sed -i.bak '246s/node_filters\.login\.name/node_filters.system.name/' ../../modules/slurm/main.tf
```

---

## Edit 7: `installations/taher-demoday/main.tf` (login pod disk request)

**What to edit**

Kubernetes places a pod on a node only if the node has enough free CPU, memory and disk for what the pod asks for. The recipe works out these requests for the login pod. CPU and memory come from the login preset in `terraform.tfvars`. The disk request, `ephemeral_storage_gibibytes`, is calculated in `main.tf` from the boot disk of the login node group (lines 460 to 463). The edit replaces this calculation with a fixed value of 64 GiB.

**Why to edit**

The recipe sizes the login pod for a dedicated login node. Its validation requires a boot disk of at least 256 GiB, and the calculation turns this into a disk request of about 164 GiB. The login node group is off in this setup, and the login pod now runs on the system nodes (edit 6). A system node offers only about 109.6 GiB of usable disk, so the pod does not fit on any of them. Kubernetes places a pod by what it asks for, not by what it uses, so the pod stays `Pending` even though the nodes are almost idle.

The boot disk cannot be lowered, because the validation requires 256 GiB, and the disk is not even created while the login node group is off. So the disk request is fixed at 64 GiB, which fits a system node. For the full story, see [06-Login-Pod-Pending](/07-Finding-&-Troubleshootings/05-Login-Pod-Stuck-In-Pending/README.md).

> [!NOTE]
> The fixed value is correct only while the login node group is off. If the group is turned on again, this edit has to be reverted. The 64 GiB is an estimate, not a measurement.

**How to edit**

Open `installations/taher-demoday/main.tf` in VS Code, or any editor, and replace lines 460 to 463 with one line `ephemeral_storage_gibibytes = 64`.

The end result looks like this:

```hcl
    login = local.gb300_enabled ? var.gb300_login_pod_worker_reserve : {
      cpu_cores        = local.resources.login.cpu_cores
      memory_gibibytes = floor(local.resources.login.memory_gibibytes)
      ephemeral_storage_gibibytes = 64
    }
```

To make the change with a command:

```bash
sed -i.bak \
  -e '460s/.*/      ephemeral_storage_gibibytes = 64/' \
  -e '461,463d' \
  main.tf
```

---

## Edit 8: `modules/slurm/variables.tf` (VictoriaMetrics and VictoriaLogs sizes)

**What to edit**

The recipe installs a monitoring stack on the cluster: VictoriaMetrics stores the metrics and VictoriaLogs stores the logs. Each one creates its own disk, and their sizes come from the defaults in `modules/slurm/variables.tf` (lines 541 to 565). The sizes are not in `terraform.tfvars`, so they cannot be changed there. Five of these default values are lowered:

| Component | Setting | Stock | Edited |
|---|---|---|---|
| VictoriaLogs | disk `size` | `256Gi` | `32Gi` |
| VictoriaMetrics | disk `size` | `512Gi` | `32Gi` |
| | `memory` | `24Gi` | `8Gi` |
| | `cpu` | `6000m` | `2000m` |
| | `gomaxprocs` | `6` | `2` |

**Why to edit**

The Nebius project allows 2048 GiB of Network SSD disks in total, and the stock recipe needs more than that. In this setup the first design needed about 4600 GiB, and `terraform apply` stopped after 60 minutes, because the NFS server disk could not be created (`Quota limit exceeded`). All disks were then cut to the smallest sizes the recipe allows. Even then, the two monitoring disks, 768 GiB together (512 GiB and 256 GiB), were the biggest remaining item.

The first idea was to switch off telemetry in `terraform.tfvars`. This saves all 768 GiB, but it breaks the Soperator controller. In this release the controller always creates a `ServiceMonitor` object, and the definition for it (the CRD) is installed only when telemetry is on. With telemetry off, the controller release fails and the cluster never becomes ready. There is no setting to separate the two.

So telemetry stays on, and its disks are made smaller: 32 GiB each, which saves 704 GiB. The CPU and memory of VictoriaMetrics are lowered too, because the stock requests (6 CPU and 24 GiB) are too big for an 8 vCPU system node. The new sizes are estimates, not measurements. For the full story, see [03-Qouta-Limitation-On-Disk](/07-Finding-&-Troubleshootings/03-Qouta-Limitation-On-Disk/README.md).

**How to edit**

Open `modules/slurm/variables.tf` and change the five values.

The end result looks like this:

```hcl
variable "resources_vm_logs_server" {
  ...
  default = {
    memory = "2Gi"
    cpu    = "1000m"
    size   = "32Gi"
  }
}

variable "resources_vm_single" {
  ...
  default = {
    memory     = "8Gi"
    cpu        = "2000m"
    size       = "32Gi"
    gomaxprocs = 2
  }
}
```

To make the change with a command:

```bash
sed -i.bak \
  -e '550s/"256Gi"/"32Gi"/' \
  -e '562s/"24Gi"/"8Gi"/' \
  -e '563s/"6000m"/"2000m"/' \
  -e '564s/"512Gi"/"32Gi"/' \
  -e '565s/= 6$/= 2/' \
  ../../modules/slurm/variables.tf
```

---

# The `terraform.tfvars` file

## What it is

Terraform is configured through variables. The file `variables.tf` declares all of them. Each variable is one setting that the recipe lets you choose, with a name, a type, a value, and sometimes a default value. The main script reads these variables and uses their values to build the cluster.

To keep a deployment repeatable, the values should not be changed inside `variables.tf`. That would edit the recipe itself, and the changes would be hard to track. Instead, the values are given from outside the recipe: in a `terraform.tfvars` file, on the command line (`terraform apply -var 'name=value'`), or as `TF_VAR_*` environment variables. This setup uses a `terraform.tfvars` file for the settings of the cluster, and `.envrc` for the few values that come from the environment.

`terraform.tfvars` is a plain file with one `name = value` line for each variable. Terraform reads it automatically. It holds every choice that is specific to this cluster: names, node sizes, disk sizes, storage, and which features are on. A few values (region, tenant, project, subnet, token) are not in this file, because `.envrc` exports them as `TF_VAR_*` environment variables.

## All available options

For all available options in the terraform.tfvars, please refer to [tfvars_value_list.md](/03-Provision/tfvars_value_list.md)

## Know before you change

The stock `terraform.tfvars` is written for a large production cluster. The sandbox is much smaller, and some of its limits are lower than the recipe expects. The next section lists the values that are changed. This section explains the limits behind them, so that each value makes sense when you meet it.

> **The disk quota**

The Nebius project allows 2048 GiB of Network SSD disks in total, and at most 32 disks. It also allows 3072 GiB of shared filesystems, and at most 32 filesystems. The published defaults for `eu-north1` are 4 TiB for each, so both limits are lower than the documentation suggests. Only the disk type `NETWORK_SSD` has a quota in this project, so every disk in the setup uses it.

Many things count against the 2048 GiB: the boot disk of every node, and the disks that the cluster creates for itself (the NFS share for `/home`, the controller state, and the two monitoring disks). The shared filesystems, the jail and the data filesystem, count against the separate 3072 GiB limit.

> **The minimum boot disk of each node type**

The recipe checks the boot disk size of every node group and refuses to run below these minimums:

| Node type | Minimum boot disk |
|---|---|
| System node (each) | 128 GiB |
| Controller | 128 GiB |
| Login | 256 GiB |
| Accounting | 128 GiB |
| NFS node | 128 GiB |
| Worker (each) | 512 GiB |

These checks are left as they are. It is not known what breaks below the minimums, so the plan is to fit inside the quota without changing them.

> **Why the stock design does not fit**

Even with the boot disks at the minimum sizes, the first design needed far more than the quota:

| Item | GiB |
|---|---|
| Boot disks at the minimum sizes (5 system nodes, controller, 2 workers, NFS node, login, accounting) | 2304 |
| NFS share for `/home` (assumed) | 128 |
| Controller state (default) | 50 |
| VictoriaMetrics and VictoriaLogs (defaults, created outside `terraform.tfvars`) | 768 |
| **Total needed** | **3250** |
| **Quota** | **2048** |

The gap is about 1200 GiB. The next four decisions close it.

To fit the disk quota, we reduce the disk capacity that the cluster needs. We do this by disabling the parts of the recipe that this demo does not need, and by making the remaining disks smaller. The changes are:

**Disable Slurm accounting.** Slurm accounting records every job in a database: who ran it, when, for how long, and with which resources. It is what makes `sacct` (job history) work, and it is also needed for fair-share scheduling and per-user limits. It needs its own node group with a 128 GiB boot disk, a database disk, and a filesystem. This demo has a single user and a few test jobs, so none of this is needed. Accounting is not created at all (`accounting_enabled = false`). The cluster runs jobs as usual, but it keeps no job history.

**Disable the login node group.** A dedicated login node needs a 256 GiB boot disk. We turn this node group off, and the login pod runs on a system node instead. This needs two changes in the recipe (edits 6 and 7) and a smaller login preset.

**Make the NFS share smaller.** The `/home` share is set to 64 GiB. It is only for code and settings. Datasets and checkpoints go to the data filesystem.

**Make the monitoring disks smaller.** VictoriaMetrics (metrics) and VictoriaLogs (logs) create disks of 512 GiB and 256 GiB. These sizes come from defaults in the recipe, and `terraform.tfvars` cannot change them. So we lower the defaults (edit 8). We cannot switch the monitoring off instead. In this release, the Soperator controller needs the monitoring definitions that only the telemetry stack installs, and it fails without them.

**Set the boot disks to the minimum.** The recipe refuses to run below a minimum boot disk for each node type, so we use exactly the minimum for the node groups that remain: 128 GiB for the system nodes, the controller and the NFS node, and 512 GiB for the workers. In the stock file, the system nodes have 192 GiB and the controller has 256 GiB, so these two are reduced. The NFS node and the workers are already at the minimum. The login node group keeps its 256 GiB setting in the file, because the recipe still checks it, but no disk is created while the group is off.

The result with four system nodes:

| Disk | Count | GiB each | Total GiB |
|---|---|---|---|
| System node boot | 4 | 128 | 512 |
| Controller boot | 1 | 128 | 128 |
| Worker boot | 2 | 512 | 1024 |
| NFS node boot | 1 | 128 | 128 |
| NFS share (`/home`) | 1 | 64 | 64 |
| Controller state | 1 | 50 | 50 |
| VictoriaMetrics | 1 | 32 | 32 |
| VictoriaLogs | 1 | 32 | 32 |
| **Total** | 12 disks | | **1970** |
| **Quota** | 32 disks | | 2048 |
| **Spare** | | | **78** |

A fifth system node adds 128 GiB and takes the total to 2098 GiB, which is over the quota. So the system node group can run four nodes at most, even though it is configured to autoscale between four and five nodes, as the task requires.

For the shared filesystems, the jail and the data filesystem take 1024 GiB each, which is 2048 of the 3072 GiB. The recipe also creates a controller spool filesystem of 128 GiB. The recipe marks it as deprecated, because the controller state now lives on a disk, but the setting is still in the stock file and the filesystem is still created. That makes 2176 of the 3072 GiB, which fits the quota.

The stock `terraform.tfvars` expects some filesystem to exist already (example jail and jail_submount), and asks for their IDs. A jail filesystem cannot be shared by two environments, so a filesystem from another cluster cannot be reused here. The Nebius sandbox also has no pre-provisioned shared filesystems to point to. Creating one by hand would add extra manual work, and it would have to be deleted by hand later. To avoid this, `terraform.tfvars` is changed to create any filesystems with Terraform (`spec` instead of `existing`). The same Terraform then removes them with `terraform destroy`, so nothing is left behind.

For more details on the infrastructure architecture, see [Infra-Arch](/01-Infra-Arch/README.md).

## Values to change

Based on the explanation above, the table below lists the variables that are changed from the stock template in `installations/taher-demoday/terraform.tfvars`. For each one, it shows the stock value, the value used here, and the reason. Where an issue page exists, the "Why" column links to it.

Before you start, create an SSH key pair. You need it to log in to the Slurm login node, and its public key goes into `terraform.tfvars` (line 477, in the table below).

```bash
# Create an ssh key
ssh-keygen -t ed25519 -f ~/.ssh/taher-soperator-demoday -C "taher-soperator-demoday" -N ""

# Print the public key
cat ~/.ssh/taher-soperator-demoday.pub
```

| Option | Stock (default) | My value (what and how) | Why |
|---|---|---|---|
| `company_name` (line 10) | Empty `""` | Set to `"taher-demoday"` | Required. It names the clusters and the `kubectl` context. |
| `production` (line 13) | `true` | Set to `false`. | A sandbox cluster has no IAM merge request. Avoids the `iam_merge_request_url` rule. |
| `iam_merge_request_url` (line 17) | Empty `""` | Empty `""` | Not needed when `production = false`. |
| `filestore_jail` (lines 61 to 74) | Uses an existing filesystem and expects its ID. The `existing` block (lines 70 to 74) is active. The `spec` block (lines 61 to 67) is commented out. | Create a new filesystem. Comment out lines 70 to 74. Uncomment lines 61 to 67. On line 63, change `size_gibibytes` from `2048` to `1024`. | The sandbox has no existing filesystem. 1024 GiB fits the 3072 GiB filesystem quota. [03](/07-Finding-&-Troubleshootings/03-Qouta-Limitation-On-Disk/README.md) |
| `filestore_jail_submounts` (lines 80 to 97) | Uses an existing filesystem for `/mnt/data` and expects its ID. The `existing`. block (lines 91 to 97) is active. The `spec` block (lines 80 to 88) is commented out. | Create a new filesystem. Comment out lines 91 to 97. Uncomment lines 80 to 88. On line 84, change `size_gibibytes` from `2048` to `1024`. | Same as above. Datasets and checkpoints go to `/mnt/data`, not to `/home`. |
| `nfs_in_k8s` (lines 138 to 141) | A 3720 GiB disk of type `NETWORK_SSD_IO_M3`, with 32 threads. | Use a small, standard disk. Line 138: `3720` to `64`. Line 139: `NETWORK_SSD_IO_M3` to `NETWORK_SSD`. Line 141: `32` to `4`. | Network SSD disk quota. The stock comment says `threads` must match the NFS preset, which is now 4 vCPU. [03](/07-Finding-&-Troubleshootings/03-Qouta-Limitation-On-Disk/README.md) |
| `slurm_nodeset_system` (lines 244 to 252) | 3 to 9 nodes. Boot disk 192 GiB. | Four to five nodes with a smaller boot disk. Line 244: `3` to `4`. Line 245: `9` to `5`. Line 252: `192` to `128`. | Disk quota. 128 GiB is the validation minimum. [03](/07-Finding-&-Troubleshootings/03-Qouta-Limitation-On-Disk/README.md) |
| `slurm_nodeset_controller` (lines 263 to 267) | 16 vCPU, 64 GB. Boot disk 256 GiB. | Smaller VM and disk. Line 263: `16vcpu-64gb` to `4vcpu-16gb`. Line 267: `256` to `128`. | Disk quota. 128 GiB is the validation minimum. |
| `slurm_nodeset_nfs` (line 435) | 32 vCPU, 128 GB. | Smaller VM. Line 435: `32vcpu-128gb` to `4vcpu-16gb`. | The NFS share is small. |
| `slurm_nodeset_workers`: `size` (line 289) | 128 nodes. | Two nodes. Line 289: `128` to `2`. | Two H100 nodes are provided. |
| `slurm_nodeset_workers`: `autoscaling` (line 292) | `enabled = true`. The node group scales between a minimum and a maximum number of nodes. | Turn autoscaling off, so the node group has a fixed number of nodes. Line 292: `true` to `false`. `min_size` (line 297) stays `null`. | In the tests, with autoscaling on and `min_size` at 0, the worker nodes were not all deployed. With autoscaling off, the module creates exactly `size` nodes (2). |
| `slurm_nodeset_workers`: `resource` (line 301) | The 8-GPU preset `8gpu-128vcpu-1600gb`. | The 1-GPU preset. Line 301: `8gpu-128vcpu-1600gb` to `1gpu-16vcpu-200gb`. | The sandbox gives one GPU per node. |
| `slurm_nodeset_workers`: `gpu_cluster` (lines 308 to 311) | Creates a GPU cluster on an InfiniBand fabric. The block is active. | No GPU cluster. On line 308, change `gpu_cluster = {` to `gpu_cluster = null`. Comment out lines 310 and 311. Line 309 is already a comment. | The 1-GPU preset cannot join an InfiniBand fabric. Needs [edit 3](#edit-3-modulesk8sgpu_fabric_validationtf). |
| `slurm_nodeset_workers`: `node_local_jail_submounts` (lines 354 to 362) | Creates an extra 1024 GiB disk on each worker. The disk block (lines 356 to 362) is active. The empty form (line 354) is commented out. | No extra disk. Comment out lines 356 to 362. Uncomment line 354 (`node_local_jail_submounts = []`). | Disk quota. |
| `slurm_nodeset_workers`: `node_local_image_disk` (lines 368 to 380) | Creates an extra 930 GiB disk on each worker for container images. The block (lines 372 to 380) is active. The disabled form (lines 368 to 370) is commented out. | No extra disk. Comment out lines 372 to 380. Uncomment lines 368 to 370 (`enabled = false`). | Disk quota. Containers still work with Enroot. |
| `slurm_nodeset_login` (lines 399 to 404) | 2 login pods on their own node group. 32 vCPU, 128 GB. The line `node_group_enabled` (line 401) is commented out. | One login pod, with no login node group. Line 399: `2` to `1`. Line 401: uncomment it and change `true` to `false`. Line 404: `32vcpu-128gb` to `4vcpu-16gb`. The boot disk (256 GiB, line 408) stays as it is. | No login node group saves 256 GiB of disk. The small preset sizes the pod for a system node. The boot disk stays because the validation requires 256 GiB. Needs [edits 6 and 7](#edit-6-modulesslurmmaintf). [06](/07-Finding-&-Troubleshootings/06-Login-Pod-Pending/README.md) |
| `active_checks_scope` (line 507) | Empty `""`. Runs the default set of checks. | Run only the essential checks. Line 507: `""` to `"essential"`. | Fewest checks. Terraform waits for them to finish. |
| `slurm_shared_memory_size_gibibytes` (line 523) | 1024 GiB. This is higher than the default of 64 GiB, which is stated in the comment on line 521. | Back to the default. Line 523: `1024` to `64`. | Uses the default value (64 GiB). |
| `public_o11y_enabled` (line 574) | `true`. Terraform creates a CLI profile, a project and a service account in a separate tenant. | Turn it off. Line 574: `true` to `false`. | The sandbox does not provide that tenant. The in-cluster monitoring (`telemetry_enabled`, line 557) stays `true`, because the Soperator controller needs it. [03](/07-Finding-&-Troubleshootings/03-Qouta-Limitation-On-Disk/README.md) |
| `accounting_enabled` (line 592) | `true`. | Turn it off. Line 592: `true` to `false`. | Saves a node group, a filesystem and a database disk. `sacct` and job history do not work. [03](/07-Finding-&-Troubleshootings/03-Qouta-Limitation-On-Disk/README.md) |
| `backups_enabled` (line 608) | `"auto"`. | Turn backups off. Line 608: `"auto"` to `"force_disable"`. | There is no backup bucket in the sandbox. |
| `slurm_login_ssh_root_public_keys` (lines 476 to 478) | One empty key `""`. | Put your public key on line 477, between the quotes. Use one line, the content of your `.pub` file. | Needed to log in to the login node over SSH. |

The command below makes all of these changes in one run. Run it once, from inside `installations/taher-demoday/`. It does not add the SSH key, so add the key yourself on line 477. Copy the public key with the command shown earlier, and paste it between the quotes on that line.

```bash
sed -i.bak \
  -e '10s|""|"taher-demoday"|' -e '13s/true/false/' \
  -e '70,74s/^/# /' -e '91,97s/^/# /' -e '61,67s/^# //' -e '80,88s/^# //' \
  -e '63s/2048/1024/' -e '84s/2048/1024/' \
  -e '138s/3720/64/' -e '139s/NETWORK_SSD_IO_M3/NETWORK_SSD/' -e '141s/32/4/' \
  -e '244s/3/4/' -e '245s/9/5/' -e '252s/192/128/' \
  -e '263s/16vcpu-64gb/4vcpu-16gb/' -e '267s/256/128/' \
  -e '289s/128/2/' -e '292s/true/false/' -e '301s/8gpu-128vcpu-1600gb/1gpu-16vcpu-200gb/' \
  -e '308s/{/null/' -e '310,311s/^    /    # /' \
  -e '354s/# //' -e '356,362s/^    /    # /' \
  -e '368,370s/# //' -e '372,380s/^    /    # /' \
  -e '399s/2/1/' -e '401s/# //' -e '401s/true/false/' -e '404s/32vcpu-128gb/4vcpu-16gb/' \
  -e '435s/32vcpu-128gb/4vcpu-16gb/' \
  -e '507s/""/"essential"/' -e '523s/1024/64/' -e '574s/true/false/' \
  -e '592s/true/false/' -e '608s/"auto"/"force_disable"/' \
  terraform.tfvars
```

---

# Deployment steps

This section takes you from the downloaded release to a running cluster. Steps 1 to 4 prepare the files and are done in the sections named in each step. Steps 5 to 10 run the deployment. Run every command from the folder named in the step.

## Step 0: Install the tools

Install these tools on the machine from which you run the deployment, before you start. Every later step uses them.

- [Terraform](https://developer.hashicorp.com/terraform/tutorials/aws-get-started/install-cli), version 1.12.0 or later. The recipe sets this minimum in `terraform.tf`.
- [Nebius CLI](https://nebius.com/docs/cli/quickstart)
- [kubectl](https://kubernetes.io/docs/tasks/tools/) - (Homebrew on macOS, - brew install kubectl).
- [jq](https://jqlang.github.io/jq/download/) - (Homebrew on macOS, - brew install jq).
- `coreutils`, installed with the package manager of your system (Homebrew on macOS, - brew install coreutils).
- `yq` - `.envrc` uses it only to print the time when the IAM token expires. Without it, the script works and skips that line. (Homebrew on macOS, - brew install yq).

## Step 1: Download the release

You should have done this already in [Step 0: Download the release into a new folder](#step-0-download-the-release-into-a-new-folder).

Download the file `soperator-tf-4.1.13-2.tar.gz` from the release `soperator-v4.1.13-2` of the Soperator Terraform recipe (`nebius/nebius-solutions-library`). Use the download link on the release page [Soperator Terraform recipe releases](https://github.com/nebius/nebius-solutions-library/releases/tag/soperator-v4.1.13-2).

```bash
curl -L -o soperator-tf-4.1.13-2.tar.gz "<download-url-from-the-release-page>"
```

## Step 2: Unpack it into a new folder

You should have done this already in [Step 0: Download the release into a new folder](#step-0-download-the-release-into-a-new-folder).

Unpack the file into a new folder, so it stays separate from any earlier attempt. The archive contains a folder called `soperator`.

```bash
mkdir <new-folder>
tar -xzf soperator-tf-4.1.13-2.tar.gz -C <new-folder>
```

## Step 3: Create the installation folder and copy the example

You should have done this already in [Step 0: Download the release into a new folder](#step-0-download-the-release-into-a-new-folder).

The recipe is never edited in the `example` folder. You copy `example` to a folder of your own and work there. The `cp` also copies the hidden `.envrc`.

```bash
cd <new-folder>/soperator
export INSTALLATION_NAME=taher-demoday
mkdir -p installations/$INSTALLATION_NAME
cd installations/$INSTALLATION_NAME
cp -r ../example/* ../example/.* .
```

## Step 4: Make the edits

You should have done this already in [Editing the recipe](#editing-the-recipe) (Edits 1 to 8) and in [Values to change](#values-to-change) (Edit 9, the `terraform.tfvars` file).

## Step 5: Set the Nebius variables

`.envrc` reads three variables from your shell: the tenant ID, the project ID and the region. Set them before you load the file. If a variable is missing, `.envrc` stops with an error.

You can find the tenant ID and the project ID in the Nebius web console. The tenant is `csa-hiring-sandbox`. The region is `eu-north1`.

First check that the `nebius` CLI works and uses the right profile:

```bash
nebius iam whoami
```

Then set the variables:

```bash
export NEBIUS_TENANT_ID='tenant-...'      # csa-hiring-sandbox
export NEBIUS_PROJECT_ID='project-...'
export NEBIUS_REGION='eu-north1'
```

## Step 6: Load `.envrc`

`.envrc` prepares everything Terraform needs: an IAM token, the service account and the state bucket (Edit 1), a new 1-day access key, and the `TF_VAR_*` variables. It also writes `terraform_backend_override.tf`, which tells Terraform to keep its state in the bucket. Use `source`, not `./.envrc`. A script run on its own cannot set variables in your shell, and Terraform needs them there.

```bash
source .envrc
```

Expected: the messages "Found existing service account" and "Using existing bucket", the time when the IAM token expires, and a list of the exported variables. The token lasts a few hours. If a later step fails with an authentication error, run `source .envrc` again.

## Step 7: Initialize Terraform

This downloads the providers and the modules, and connects Terraform to the state bucket.

```bash
terraform init
```

![image2](/03-Provision/Images/image2.png)

Expected: "Terraform has been successfully initialized". A `403` here is the problem of issue [01](/07-Finding-&-Troubleshootings/01-Provided-SA-Lacks-Required-Permissions/README.md). Check that Edit 1 is in place, so `.envrc` uses `mlflow-sa` and the right bucket.

## Step 8: Validate the configuration

This checks the syntax and the rules for the variables, without calling Nebius. The size rules for the boot disks and the node groups are checked here, so a typing mistake in an edit shows up before anything is created.

```bash
terraform validate
```

![image3](/03-Provision/Images/image3.png)

Expected: "Success! The configuration is valid." If a rule fails, the message names the variable and the limit.

Ignore warnings about deprecated features, for example the deprecated Nebius project API. They are warnings, not errors. They come from the Nebius provider and the recipe, they do not stop the run, and they do not affect the deployment.

## Step 9: Plan

This asks Nebius what already exists and lists what Terraform would create. Nothing is created yet. The plan is saved to a file, so the apply runs exactly what you reviewed.

```bash
terraform plan
```

![image4](/03-Provision/Images/image4.png)

Expected: a line `Plan: 42 to add, 0 to change, 0 to destroy.`

## Step 10: Apply

This creates the infrastructure. Then Flux installs Soperator and Slurm. Terraform waits for the `slurm-cluster` release, the active checks and the `SlurmCluster` before it finishes.

```bash
terraform apply
```

The apply takes a long time: usually 40 to 50 minutes, and sometimes more. Do not wait for it to finish before you check the environment. The next section lists the checks for each stage. Run each check in a second terminal as soon as its stage is done, so a problem is found while the apply is still running.

---

# Validating the environment

Run these checks while `terraform apply` is still running. Use a second terminal. Each check belongs to a stage of the apply. Terraform prints the module name in front of every line it writes, so you can see which stage it is in. Run the check for a stage as soon as that stage is done. A problem found early saves the wait for a failed apply.

| Terraform shows | Stage | Check |
|---|---|---|
| `module.filestore` | Shared filesystems | [Check 1](#check-1-shared-filesystems) |
| `module.k8s` | Kubernetes cluster and nodes | [Check 2](#check-2-kubernetes-cluster-and-nodes) and [Check 3](#check-3-topology-labels-on-the-workers) |
| `module.fluxcd`, `module.slurm` | Flux and the Helm releases | [Check 4](#check-4-flux-and-the-helm-releases) |
| `module.slurm` (waiting) | Soperator pods | [Check 5](#check-5-soperator-pods) |
| Apply finished | Slurm | [Check 6](#check-6-slurm) |

## Check 1: Shared filesystems

Terraform creates the shared filesystems first, so check them first. If one is missing, nothing after it can start. Use the Nebius web console: open the project, then go to **Storage** and **Shared filesystems**. You should see three filesystems, all with the status `Ready`: the jail (1 TiB), the `data` filesystem (1 TiB) and the controller spool (128 GiB). Their names are built from `company_name`: `soperator-<company_name>-jail`, `soperator-<company_name>-jail-submount-data` and `soperator-<company_name>-controller-spool`.

**Expected.** Two filesystems of 1024 GiB (the jail and `data`) and one of 128 GiB (the controller spool).

![image5](/03-Provision/Images/image5.png)

## Check 2: Kubernetes cluster and nodes

The cluster is the base for everything else, and the workers take the longest to start, so check it as soon as Terraform has created it. First use the Nebius web console. Open **Compute**, then **Kubernetes**. You should see one cluster, named `soperator-<company_name>`, with the status `Running`. Open the cluster and go to the **Node groups** tab. You should see four node groups, all `Running`: `worker-0` with 2 nodes (1 H100 GPU, 16 CPUs and 200 GiB of RAM each), `system` with 4 to 5 nodes (8 CPUs and 32 GiB each), `nfs` with 1 node and `controller` with 1 node (4 CPUs and 16 GiB each). There is no `login` and no `accounting` node group.

![image6](/03-Provision/Images/image6.png)

![image7](/03-Provision/Images/image7.png)


Then click **How to connect** at the top of the cluster page. The console shows the command that adds this cluster to your `kubectl`. Copy it, run it in your terminal, and then check the nodes with `kubectl`:

```bash
kubectl get nodes
kubectl get nodes -L slurm.nebius.ai/nodeset
```

![image8](/03-Provision/Images/image8.png)

**Expected.** Eight nodes, all `Ready`: 4 `system`, 1 `controller`, 1 `nfs` and 2 `worker`. There is no `login` and no `accounting` node. The nodes appear one by one, so repeat the command until all eight are there. To check the GPUs:

```bash
kubectl get nodes -l slurm.nebius.ai/nodeset=worker -o custom-columns='NAME:.metadata.name,GPU:.status.allocatable.nvidia\.com/gpu'
```

![image9](/03-Provision/Images/image9.png)

**Expected.** One GPU on each worker.

## Check 3: Topology labels on the workers

Edit 5 adds two labels, `topology.nebius.com/tier-1` and `tier-2`, to the worker nodes. A worker pod does not start without them. It waits, fails after 180 seconds, and tries again, again and again. In testing, the labels reached only one of the two workers, so check this as soon as the workers are `Ready`. This check uses the CLI. The command lists the worker nodes, with one column for each label:

```bash
kubectl get nodes -l slurm.nebius.ai/nodeset=worker -L topology.nebius.com/tier-1 -L topology.nebius.com/tier-2
```

![image10](/03-Provision/Images/image10.png)

**Expected.** `demo-tier1` and `demo-tier2` on both workers. 

**If a node has empty values in the `TIER-1` and `TIER-2` columns**, label it by hand with the command below. Replace `xxx` with the name of the compute instance that has no labels (the first column of the check above). Run the command once for each node that is missing the labels.

```bash
kubectl label node xxx topology.nebius.com/tier-1=demo-tier1 topology.nebius.com/tier-2=demo-tier2 --overwrite
```

Then run the check again. Both nodes must now show the labels. - Issue page: [05](/07-Finding-&-Troubleshootings/06-Invalid-Worker-Node-Topology-For-Single-GPU-Node/README.md).

## Check 4: Flux and the Helm releases

Once the cluster is up, Flux installs about 25 Helm releases, and each one waits for the releases it depends on. Most of the problems of this deployment show up at this stage, as a release that stays `False`. Check the Flux pods and the releases while the apply is running. The last command lists only the releases that are not ready yet:


```bash
kubectl -n flux-system get pods
```

![image11](/03-Provision/Images/image11.png)


```bash
kubectl get helmreleases -A
```

![image12](/03-Provision/Images/image12.png)

```bash
kubectl get helmreleases -A | grep -v True
```

![image13](/03-Provision/Images/image13.png)

Expected: the Flux pods are `Running`, and the releases turn `True` one after the other. A release that is still installing shows `Unknown`. The release `soperator-activechecks` may stay `Unknown` for a long time, because it is still working and running the active checks. A release that says `DependencyNotReady` is normal while the release before it is still installing. Only a release that stays `False` with another message is a problem.

## Check 5: Active checks

Active checks are health checks that run as jobs after the cluster is created. The release `soperator-activechecks` stays `Unknown` until they finish, and Terraform waits for them before the apply ends. The checks need Slurm to be running, so they wait until the controller, login and worker pods are up. Some checks also wait for other checks, so the list fills in step by step. To see the state of each check, and the pods that run them, use:

```bash
kubectl -n soperator get activechecks
```

![image14](/03-Provision/Images/image14.png)

```bash
kubectl -n soperator get pods | grep -E 'check|wait'
```

![image15](/03-Provision/Images/image15.png)


Expected: the checks move to a finished state one after the other, and the pod `wait-for-active-checks` completes when they are done. If a check stays without a status for a long time, look at its details with `kubectl -n soperator describe activecheck <check-name>`. To see what the pod waits for, read its log with `kubectl -n soperator logs <wait-for-active-checks-pod> --tail=30`. If the log keeps saying that `ensure-healthy-nodes` is `Pending`, and the Slurm pods have been `Running` for more than about 10 minutes, do not wait any longer. Follow the note below: check by hand that the nodes are healthy, and then patch the check.

```bash
# 1. Check by hand that the nodes are healthy (this is what ensure-healthy-nodes tests)
kubectl -n soperator exec controller-0 -c slurmctld -- sinfo -N -o "%N %T %E"

# 2. Only if the workers are idle and the reason is none, mark the check as complete
kubectl -n soperator patch activecheck ensure-healthy-nodes --subresource=status --type=merge -p '{"status":{"slurmJobsStatus":{"lastRunStatus":"Complete"}}}'

# 3. Check that the waiting job has finished
kubectl -n soperator get pods | grep wait-for-active-checks
```

## Check 6: Soperator pods

The pods in the `soperator` namespace are the Slurm cluster itself, so check them next. You can run the check while the apply is still waiting, or after it has finished. The Slurm pods start after the job `soperator-populate-jail` has copied the OS image into the jail filesystem, so in the first minutes you see only the mount pods and this job. Use `-o wide` to see on which node each pod runs:

```bash
kubectl -n soperator get pods -o wide
```

![image16](/03-Provision/Images/image16.png)

**Expected.** `controller-0`, `login-0`, `worker-0` and `worker-1` become `Running`. `login-0` runs on a system node.

## Check 7: Slurm

The pods can be `Running` while Slurm still has a wrong view of the workers or the GPUs, so check Slurm itself. You do not need to wait for the apply to finish. Slurm is usable as soon as `controller-0`, `login-0`, `worker-0` and `worker-1` are `Running` (Check 5). First, look at Slurm from the controller pod. The first command lists the nodes with their GPUs and states. The second shows the details of one worker. The third searches the controller log for GRES errors (Edit 4):

```bash
kubectl -n soperator exec controller-0 -c slurmctld -- sinfo -N -o "%N %G %T"
```

![image17](/03-Provision/Images/image17.png)

```bash
kubectl -n soperator exec controller-0 -c slurmctld -- scontrol show node
```

![image18](/03-Provision/Images/image18.png)

```bash
kubectl -n soperator exec controller-0 -c slurmctld -- scontrol show node | grep -E 'NodeName|Gres=|State='
```

![image19](/03-Provision/Images/image19.png)

```bash
kubectl -n soperator logs controller-0 -c slurmctld --tail=200 | grep -i gres
```

Expected: both workers are `idle`, and each shows `gpu:nvidia_h100_80gb_hbm3:1(S:0)`. `sinfo` lists each worker twice, once for each partition (`main` and `hidden`). The log command prints nothing, which means there are no GRES errors.

Now log in to the login node, the way a user would. The login pod is exposed through a load balancer with a public IP. Get the IP from the login service:

```bash
kubectl -n soperator get svc soperator-login-svc 
```

![image20](/03-Provision/Images/image20.png)

Terraform also wrote the script `login.sh` into the installation folder. It connects as `root` and needs the **private** key that belongs to the public key in `terraform.tfvars`. Run it from the `installations/taher-demoday/` folder. The first time, it asks you to accept the host key. Type `yes`.

```bash
./login.sh -k ~/.ssh/taher-soperator-demoday
```

![image21](/03-Provision/Images/image21.png)

Inside the login node, run:

```bash
sinfo
srun -N2 hostname
```

![image22](/03-Provision/Images/image22.png)

Expected: `sinfo` shows both workers `idle`. `srun` prints `worker-0` and `worker-1`.

---

## Terraform apply: complete

Go back to the terminal where you started `terraform apply`. It should now have finished. It ends only after the active checks release is ready, so it can take a long time. If you patched `ensure-healthy-nodes` (see the active checks check), it finishes soon after.

![image23](/03-Provision/Images/image23.png)

Expected: the last lines say `Apply complete! Resources: **[TO COMPLETE]** added, 0 changed, 0 destroyed.`, followed by the outputs. If you see an error instead, stop here and fix it before you go on.

Ignore the warnings about deprecated arguments in the output. They come from the recipe code, do not stop the apply, and do not need any action.

---

## After the apply: suspend the GPU health checks

The recipe ships GPU health checks that run on a schedule: `all-reduce-perf-nccl-with-ib`, `all-reduce-perf-nccl-without-ib`, `cuda-samples`, `gpu-fryer`, `ib-gpu-perf` and `mem-perf`. On this cluster there are only two GPUs and no InfiniBand. A check that runs on a worker blocks your own jobs on that GPU. The InfiniBand checks cannot pass at all. Suspend all six once the apply has finished:

```bash
for c in all-reduce-perf-nccl-with-ib all-reduce-perf-nccl-without-ib cuda-samples gpu-fryer ib-gpu-perf mem-perf; do kubectl -n soperator patch activecheck $c --type=merge -p '{"spec":{"suspend":true}}'; done
```

![image24](/03-Provision/Images/image24.png)

Expected: six lines ending with `patched`. To check, run `kubectl -n soperator get activecheck`. Suspending only stops new runs. It does not delete the checks.

---

# Testing Slurm

Now that the infrastructure is up, we also need to check that Slurm works as expected. We do this by running three small jobs from the login node. The first is a distributed job without a GPU. The second is a distributed job that uses the GPU on each worker. The third is an NCCL all-reduce test between the two GPUs. The scripts are adapted from the `test/quickcheck` folder of the Soperator release. I changed only the resource lines, to fit 2 workers with 1 GPU each. The release version asks for 8 GPUs per node, and Slurm would reject that here. The three scripts are in the `slurm-check-scripts` folder of this repository.

### Step 1: Copy the scripts to the login node

What: send the `slurm-check-scripts` folder to the login node. Why: Slurm jobs start from the login node, and its home folder is on the shared jail, so the workers see the same files. Run this on your laptop, from the `03-Provisioning` folder, with the login IP from Check 7:

```bash
scp -i ~/.ssh/taher-soperator-demoday -r ../../../../slurm-check-scripts root@<login-ip>:~
```

![image25](/03-Provision/Images/image25.png)

Log in to the login pod, go to the scripts folder, and create a folder to hold the output of the scripts we will run. Slurm does not create this folder, and without it a job writes no output file. Run the first command on your laptop, from the installation folder. The other two run on the login pod:

```bash
./login.sh -k ~/.ssh/taher-soperator-demoday
cd ~/slurm-check-scripts
mkdir -p results
```

![image26](/03-Provision/Images/image26.png)

### Step 2: Distributed job without a GPU

What: one task on each worker, with no GPU requested. Why: it proves that Slurm can place a job on both workers.

```bash
sbatch --wait 01_hello_distributed.sh
cat results/hello.out
```

![image28](/03-Provision/Images/image28.png)

Expected: `Hello from worker-0` and `Hello from worker-1`, then the CPU count (2) for the second step on each worker.

You can check the details of a job with `scontrol`. Accounting is disabled on this cluster, so `sacct` does not work. The full output is long, so the command keeps only the fields that matter. Replace `<job-id>` with the number that `sbatch` printed:


```bash
scontrol show job <job-id> | tr ' ' '\n' | grep -E '^(JobId|JobName|JobState|RunTime|StartTime|EndTime|NodeList|NumNodes|TRES|ExitCode)='
```

Expected: `JobState=COMPLETED`, `ExitCode=0:0`, `NodeList=worker-[0-1]` and `NumNodes=2`.

### Step 3: Distributed job with a GPU

What: one task on each worker, each with its own GPU. The job prints the GPU model, the GPU memory and the driver version on each worker. Why: it proves that the NVIDIA driver works on both workers and that Slurm hands a GPU to the job on each node.

```bash
sbatch --wait 02_gpu_distributed.sh
cat results/gpu.out
```

![image29](/03-Provision/Images/image29.png)

Expected: one block per worker with `NVIDIA H100 80GB HBM3`, `81559 MiB` of GPU memory and the driver version.

### Step 4: NCCL test between the two GPUs

What: a networking test based on `all_reduce_perf_mpi` benchmark from NVIDIA's `nccl-tests`. It makes the GPU on `worker-0` and the GPU on `worker-1` send data to each other, and it measures how fast the data moves. Why: AI training on more than one node depends on this, because the GPUs must exchange data all the time. If this works, the two workers can run one job together. This cluster has no InfiniBand, so the data goes over the normal network, which is much slower. That is expected here.

The NCCL job runs one time, with tuned socket settings, to get as much bandwidth as the network gives. The script tells NCCL to use more parallel TCP connections because a single connection rarely fills a fast link.

```bash
sbatch --wait 03_nccl_multi_node.sh
cat results/nccl.out
```

Expected: the data goes over `NET/Socket`, the `#wrong` column is `0` in every row, and the `busbw` column shows about 3.9 to 4.0 GB/s, with an average of 3.96 GB/s at the end (`Avg bus bandwidth`).

Expected: one row per message size, from 512 MiB to 8 GiB, with `0` in the `#wrong` column. The log shows `NET/Socket` as the transport, not `NET/IB`. The `busbw` column shows about 3.9 to 4.0 GB/s in every row, and the average at the end (`Avg bus bandwidth`) is 3.96 GB/s.

Expected: one row per message size, from 512 MiB to 8 GiB, with `0` in the `#wrong` column. The log shows `NET/Socket` as the transport, not `NET/IB`. In the `busbw` column I measured about 3 GB/s on the first cluster. **[TO COMPLETE with the number from this run]**

![image30](/03-Provision/Images/image30.png)

---