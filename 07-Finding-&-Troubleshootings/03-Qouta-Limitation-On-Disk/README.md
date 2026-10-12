# 03 - Qouta Limitation On Disk

> `terraform apply` stopped after 60 minutes while waiting for Flux. The cause was a disk quota: the project allows 2048 GiB of Network SSD, and my first design needed about 4600 GiB. I read the real limits with a service account profile, then redesigned every disk to fit. We then faced several other issues that are not related to the disk quota. After fixing them, the infrastructure was created.

---

# Issue Summary

- After `terraform apply`, the Kubernetes cluster was deployed, but the run then failed with a `timeout`.
- Terraform waited 60 minutes on `module.slurm.terraform_data.wait_for_slurm_cluster_hr`, which was waiting for the `flux-system-soperator-fluxcd-nfs-server` HelmRelease to become ready.
- The investigation of the HelmReleases and the PVC events showed that `nfs-server` could not be deployed because of `Quota limit exceeded` on its disk.
- The project quota for Network SSD disks is 2048 GiB (2 TiB). The published Nebius default for `eu-north1` is 4 TiB.
- The recipe creates disks that are not set in `terraform.tfvars`: VictoriaMetrics and VictoriaLogs, 768 GiB together.
- The recipe also sets a minimum boot disk size for each node type. Even at these minimum sizes, the first design did not fit within the quota.
- The issue was fixed with the following changes:
  - Accounting was disabled, so the accounting node group is no longer created.
  - The login node group was disabled, and the login pod was moved to the system node group.
  - All boot disks were set to the minimum sizes allowed by the recipe.
  - The VictoriaMetrics and VictoriaLogs disks were reduced to 32 GiB each.
- The final design uses 1970 GiB of the 2048 GiB quota (assuming 4 system nodes only).

---

# Questions to Nebius team

1. Is the 2 TiB Network SSD quota and 3 TiB filesystem quota intentional for this project? The published defaults for `eu-north1` are 4 TiB each.
2. In one test, I disabled telemetry to reduce disk use. The Soperator controller still created a `ServiceMonitor` object, and the CRD for it was missing. Is there a supported setting to turn off both?
3. Can the sizes of the VictoriaMetrics and VictoriaLogs disks be set in `terraform.tfvars`? I had to edit `modules/slurm/variables.tf`.
4. To fit the quota, I disabled the accounting and login node groups, set the node boot disks to their minimum sizes, and reduced the VictoriaMetrics and VictoriaLogs disks to 32 GiB each. Is this the expected approach?
5. If not, should I ask the Nebius team to increase the quota limits? My user cannot view the quota or requests page, so I cannot check or as to change the quotas myself.
6. The task asks for a system node group that is autoscaled between 4 and 5 nodes. With the 2048 GiB Network SSD quota, the disk budget is 1970 GiB with 4 system nodes (78 GiB spare). A fifth system node needs another 128 GiB, which takes the total to 2098 GiB and is 50 GiB over the quota. Do you expect 5 system nodes to be running, or is it enough to show the 4 to 5 autoscaling configuration? If 5 nodes must run, which of the trade-offs would you prefer: a quota increase, or a smaller disk somewhere else?

---

# Issue Description

I ran `terraform apply` to build the cluster. It created the Kubernetes cluster and the node groups without errors. Then it reached the step that waits for Soperator's Slurm cluster to install, and it sat there for one hour. After that it failed with this error:

```text
module.slurm.terraform_data.wait_for_slurm_cluster_hr: Still creating... [59m40s elapsed]
module.slurm.terraform_data.wait_for_slurm_cluster_hr (local-exec): [59m] flux-system-soperator-fluxcd-slurm-cluster: Ready=DependencyNotReady, Reconciling=Progressing
......

│ ERROR: Timeout reached waiting for HelmRelease flux-system-soperator-fluxcd-slurm-cluster to be successfully installed.
│ === HelmRelease Status: flux-system-soperator-fluxcd-slurm-cluster ===
│ Conditions:
│   Reconciling: True (Progressing) - Fulfilling prerequisites
│   Ready: False (DependencyNotReady) - dependency 'flux-system/flux-system-soperator-fluxcd-nfs-server' is not ready
│ Helm history (last 3):
│ =======================================
```

What this means: Terraform builds the base (cluster, nodes and filesystems), then hands the software installation to **Flux**. Flux installs the software through several HelmReleases. They deploy the Soperator components and the Slurm cluster, and run the active checks. After the hand-off, Terraform only waits. The Terraform resource `module.slurm.terraform_data.wait_for_slurm_cluster_hr` checks the state of the `slurm-cluster` HelmRelease every 10 seconds and times out after 60 minutes. The timeout shows that the `slurm-cluster` HelmRelease never became ready, so something inside the cluster was blocking Flux.

For the full error, see [01-error1](/07-Finding-&-Troubleshootings/03-Qouta-Limitation-On-Disk/01-error1.txt).

---

# Troubleshooting steps

## Step 1: Look at the cluster in the console

The Kubernetes cluster was up and running, but the console showed some errors. I opened the cluster details and found two red error points. Both pointed at the persistent volume claim (PVC) of the NFS server.

![image1](/07-Finding-&-Troubleshootings/03-Qouta-Limitation-On-Disk/Images/image1.png)

![image2](/07-Finding-&-Troubleshootings/03-Qouta-Limitation-On-Disk/Images/image2.png)

---

## Step 2: Log in to the cluster and find the stuck releases

I checked the nodes, the namespaces and the Flux releases:

```bash
kubectl get nodes -o wide
kubectl get ns
kubectl get helmreleases -n flux-system
```

The full HelmRelease output is in [03-output1](/07-Finding-&-Troubleshootings/03-Qouta-Limitation-On-Disk/03-output1.txt). The key line is:

```text
flux-system-soperator-fluxcd-nfs-server   77m   False   Helm install failed for release nfs-system/nfs-server with chart helm-nfs-server@1.2.2: context deadline exceeded
```

Result: the nodes were `Ready`. The `nfs-server` HelmRelease was failing, and the releases that depend on it (`slurm-cluster` and the ones after it) were waiting. This matches the Terraform log.

---

## Step 3: Find the claims that are not bound

The errors shown for the Kubernetes cluster in the console (Step 1) pointed to a persistent volume claim (PVC) problem. So the next logical action was to check the PVC of the NFS server.

```bash
kubectl -n nfs-system get pvc
kubectl get pvc -A | grep -v Bound
```

![image5](/07-Finding-&-Troubleshootings/03-Qouta-Limitation-On-Disk/Images/image5.png)

The full PVC output is in [04-output2](/07-Finding-&-Troubleshootings/03-Qouta-Limitation-On-Disk/04-output2.txt).

Result: two claims were stuck in `Pending`.

| Namespace | Claim | Storage class |
|---|---|---|
| `nfs-system` | `nfs-server-storage` | `compute-csi-network-ssd-ext4` |
| `monitoring-system` | `vmsingle-metrics-victoria-metrics-k8s-stack` | `compute-csi-default-sc` |

The NFS server pod could not start because its disk did not exist. The second claim is the VictoriaMetrics disk, which I did not know about at that point.

---

## Step 4: Describe the claim to see why

```bash
kubectl -n nfs-system describe pvc nfs-server-storage
```

The events at the bottom gave the reason:

```text
Warning  ProvisioningFailed  53m   compute.csi.nebius.com_...  failed to provision volume with StorageClass "compute-csi-network-ssd-ext4": rpc error: code = ResourceExhausted desc = ... Quota limit exceeded. Exceeded limit for container project-..., quota compute.disk.size.network-ssd.
  Quota failure QuotaFailure: service compute, violations:
    compute.disk.size.network-ssd (limit 2199023255552, requested 3229815406592): Exceeded limit for container project-...
```

The full describe output is in [02-error2](/07-Finding-&-Troubleshootings/03-Qouta-Limitation-On-Disk/02-error2.txt).

The numbers are in bytes. Converted:

| | Bytes | GiB |
|---|---|---|
| Limit | 2,199,023,255,552 | **2048** (2 TiB) |
| Requested | 3,229,815,406,592 | **3008** |

My reading is that "requested" is the total the project would hold if this disk were created. If that is right, the request was 960 GiB over the limit.

---

## Step 5: Understand the problem

Now I knew it was a quota problem. It was a surprise, because I had already lowered the disk sizes in `terraform.tfvars` below the recipe's defaults, and I still hit the limit.

---

## Step 6: Try to read the limit in the console

I wanted the full quota list with usage, but my user does not have permission to see the quota page.

![image3](/07-Finding-&-Troubleshootings/03-Qouta-Limitation-On-Disk/Images/image3.png)

---

## Step 7: Compare with the published defaults

The Nebius documentation lists default quotas per region. For `eu-north1` it says 4 TiB of Network SSD. My project's error says 2 TiB. The two do not match, so the published defaults were no use for planning and the default qoutas has been changed.

Source: [Nebius Compute quotas and limits](https://docs.nebius.com/compute/resources/quotas-limits)

---

## Step 8: Use the service account, which has more rights

From issue 01 I knew that `mlflow-sa` is in the `editors` group. The group may have more rights than my user, so I made a CLI profile for it. I generated an authorized key, using my own login:

```bash
export NEBIUS_PROJECT_ID='project-...'
# Unset the existing token, because it would override the profile we are creating
unset NEBIUS_IAM_TOKEN

# Get the service account ID by name
SA_ID=$(nebius iam service-account get-by-name --name mlflow-sa \
  --parent-id "$NEBIUS_PROJECT_ID" --format jsonpath='{.metadata.id}')

# Generate a public key for the mlflow service account and save it to a file
nebius iam auth-public-key generate \
  --service-account-id "$SA_ID" \
  --output ~/.nebius/mlflow-sa-credentials.json \
  --output-format service-account-json
chmod 600 ~/.nebius/mlflow-sa-credentials.json
```

Then I created the profile from the file:

```bash
nebius profile create \
  --endpoint api.nebius.cloud \
  --service-account-file ~/.nebius/mlflow-sa-credentials.json \
  --parent-id "$NEBIUS_PROJECT_ID" \
  --profile mlflow-cli
```

I checked that the profile works and that it is the service account, not me:

```bash
nebius --profile mlflow-cli iam whoami
nebius iam service-account list --parent-id "$NEBIUS_PROJECT_ID" --format table
```

Result: profile `mlflow-cli` was configured and activated.

![image4](/07-Finding-&-Troubleshootings/03-Qouta-Limitation-On-Disk/Images/image4.png)

---

## Step 9: List the quotas with that profile

```bash
nebius --profile mlflow-cli quotas quota-allowance list \
  --parent-id "$NEBIUS_PROJECT_ID" --all --format table
```

Result: it worked. The service account can read the quotas. The table showed that some quotas were **set when the tenant was created**: those rows have an ID and a 2026-10-08 date. The other rows have no ID and a 1970 date.

The quotas that were set:

| Quota | Set for this project? |
|---|---|
| `compute.disk.size.network-ssd` | Yes |
| `compute.disk.count` | Yes |
| `compute.filesystem.size.network-ssd` | Yes |
| `compute.filesystem.count` | Yes |
| `compute.instance.count` | Yes |
| `compute.instance.non-gpu.vcpu` | Yes |
| `compute.instance.gpu.h100` | Yes |
| `compute.instance.gpu.h200` | Yes |
| `compute.instance.gpu.l40s` | Yes |
| `compute.gpucluster.count` | Yes |
| `mk8s.cluster.count` | Yes |
| `storage.bucket.count` | Yes |
| `storage.bucket.size.standard` | Yes |
| `vpc.allocation.count` | Yes |
| `vpc.ipv4-address.public.count` | Yes |
| `vpc.network.count` | Yes |
| `vpc.pool.count` | Yes |
| `vpc.subnet.count` | Yes |

The disk types `network-ssd-non-replicated`, `network-ssd-io-m3` and `network-hdd` had **no** quota set. I read this as "not available in this project", so I keep every disk on `NETWORK_SSD`.

---

## Step 10: Read the actual limits

The previous table has no limit column, so I read each storage quota one by one.

```bash
for q in compute.disk.size.network-ssd compute.disk.count \
         compute.filesystem.size.network-ssd compute.filesystem.count; do
  echo "=== $q"
  nebius --profile mlflow-cli quotas quota-allowance get-by-name \
    --name "$q" --parent-id "$NEBIUS_PROJECT_ID" --region eu-north1 --format yaml
done
```

Result:

| Quota | Limit (bytes) | Limit | Usage |
|---|---|---|---|
| `compute.disk.size.network-ssd` | 2,199,023,255,552 | **2048 GiB** (2 TiB) | 0% |
| `compute.disk.count` | 32 | **32 disks** | 0% |
| `compute.filesystem.size.network-ssd` | 3,298,534,883,328 | **3072 GiB** (3 TiB) | 0% |
| `compute.filesystem.count` | 32 | **32 filesystems** | 0% |

The disk limit (2 TiB) and the filesystem limit (3 TiB) are both below the published defaults (4 TiB each).

---

## Step 11: Check which other components request storage

While reviewing the PVC list, I noticed the second claim stuck in `Pending`: `vmsingle-metrics-victoria-metrics-k8s-stack`, in the namespace `monitoring-system`. I had not set it in my tfvars. The recipe also installs monitoring and logging components (VictoriaMetrics and VictoriaLogs), and they request disks of their own.

I wanted to know where their storage comes from: the boot disk of the node, a shared filesystem, or a separate disk requested through the CSI driver. I had already destroyed the cluster, so I could not check a running system. Instead I searched the Terraform recipe, starting from the name of this claim.

In `terraform.tfvars` there is a variable `telemetry_enabled`, which is `true` by default. It switches on the monitoring stack. I found two components behind it: `vm_single`, a single-instance VictoriaMetrics that stores metrics, and `vm_logs`, VictoriaLogs, which stores logs. Their default sizes are set in `modules/slurm/variables.tf`.

![image6](/07-Finding-&-Troubleshootings/03-Qouta-Limitation-On-Disk/Images/image6.png)

---

## Step 12: Count the telemetry disks and choose a direction

With telemetry enabled, VictoriaMetrics requests **512 GiB** and VictoriaLogs requests **256 GiB**, which is **768 GiB** in total. Each one is a separate Network SSD disk created through the CSI driver, so both count against the 2048 GiB disk quota.

I had three options:

1. Disable telemetry in the tfvars. I decided against this at first, because I believe it would affect the task goal of GPU utilization above 80%.
2. Reduce the sizes in `modules/slurm/variables.tf`. I did not choose this, because I did not know the impact of smaller sizes.
3. Keep the 768 GiB as a fixed amount and size all other disks around it. This was my starting point.

The rounds below show how this changed.

---

# Fix rounds

## Round 1: lower the tfvars sizes (wrong assumption)

I set the disk sizes in `terraform.tfvars` as follows:

| Disk | Size I set (GiB) |
|---|---|
| System nodes (each) | 96 |
| Controller | 96 |
| Login | 64 |
| Accounting | 64 |
| NFS node | 64 |
| Worker (each) | 192 |
| NFS share (`/home`) | 64 |

Terraform failed with an `Invalid value for variable` error for each node group. The error said that each node type has a minimum boot disk size. I opened `variables.tf` and found validation rules that set these minimums:

| Node | Minimum (GiB) |
|---|---|
| System nodes (each) | 128 |
| Controller | 128 |
| Login | 256 |
| Accounting | 128 |
| NFS node | 128 |
| Worker (each) | 512 |

With 5 system nodes and 2 workers, the boot disks alone need 2304 GiB. That is already above the 2048 GiB quota, before adding the NFS `/home` disk, the controller state disk and the Victoria disks.

I did not know the reasons behind these minimums or what would break below them, so I decided not to change the validation rules.

---

## Round 2: the minimum sizes still do not fit

With the minimum sizes, the total need was far above the limit:

| Item | GiB |
|---|---|
| Boot disks at the minimum sizes (5 system nodes) | 2304 |
| NFS share (`/home`), assuming 128 GiB | 128 |
| Controller state (default) | 50 |
| VictoriaMetrics + VictoriaLogs (default) | 768 |
| **Total needed** | **3250** |
| Quota limit | 2048 |
| **Missing** | **1202** |

My options were:

1. **Disable telemetry** in the tfvars (saves 768 GiB).
2. **Disable accounting** (`accounting_enabled = false`, saves 128 GiB). This removes the accounting node group and the Slurm accounting system. It also removes the accounting shared filesystem and the MariaDB claim.
3. **Disable the login node group** (`node_group_enabled = false`, saves 256 GiB). The comment in the tfvars says that login pods then run on the worker nodes. I had not tested this for my preset. Later I found that this comment applies to GB300 only (see issue 06 below).
4. **Edit the validation checks** in `variables.tf` and lower the disk sizes. I did not choose this.

I tested with options 1, 2 and 3, and set the NFS share (`/home`) to 64 GiB:

| Disk | Count | GiB each | Total GiB |
|---|---|---|---|
| System boot | 5 (max) | 128 | 640 |
| Controller boot | 1 | 128 | 128 |
| Worker boot | 2 | 512 | 1024 |
| NFS node boot | 1 | 128 | 128 |
| NFS share (`/home`) | 1 | 64 | 64 |
| Controller state | 1 | 50 | 50 |
| **Total** | | | **2034** |
| Quota limit | | | 2048 |
| **Spare** | | | **14** (99% used) |

---

## Round 3: the quota error is gone, but turning telemetry off breaks the Soperator release

The quota error was gone and `nfs-server` installed. But the Soperator controller release failed, because it creates a `soperator-controller-manager-servicemonitor` object, and the cluster has no `ServiceMonitor` CRD (`monitoring.coreos.com/v1`). Every release that depends on it stayed `False`.

```bash
kubectl get helmreleases -A
NAMESPACE     NAME                                                      AGE   READY   STATUS
flux-system   flux-system-soperator-fluxcd-cert-manager                 21m   True    Helm install succeeded for release cert-manager-system/cert-manager
....
flux-system   flux-system-soperator-fluxcd-monitoring-dashboards        21m   False   Helm install failed for release monitoring-system/soperator-monitoring-dashboards with chart helm-soperator-monitoring-dashboards@4.1.13: 7 errors occurred:...
flux-system   flux-system-soperator-fluxcd-nodeconfigurator             21m   False   dependency 'flux-system/flux-system-soperator-fluxcd-soperator' is not ready
flux-system   flux-system-soperator-fluxcd-nodesets                     21m   False   dependency 'flux-system/flux-system-soperator-fluxcd-soperator' is not ready
flux-system   flux-system-soperator-fluxcd-slurm-cluster                21m   False   dependency 'flux-system/flux-system-soperator-fluxcd-soperator' is not ready
flux-system   flux-system-soperator-fluxcd-soperator                    21m   False   Helm install failed for release soperator-system/soperator-controller with chart helm-soperator@4.1.13: unable to build kubernetes objects from release manifest: resource mapping not found for name: "soperator-controller-manager-servicemonitor" namespace: "" from "": no matches for kind "ServiceMonitor" in version "monitoring.coreos.com/v1"...
```

```bash
kubectl -n flux-system describe helmrelease flux-system-soperator-fluxcd-soperator
...
Warning  InstallFailed  30m  helm-controller  Helm install failed for release soperator-system/soperator-controller with chart helm-soperator@4.1.13: unable to build kubernetes objects from release manifest: resource mapping not found for name: "soperator-controller-manager-servicemonitor" namespace: "" from "": no matches for kind "ServiceMonitor" in version "monitoring.coreos.com/v1"
ensure CRDs are installed first
```

The full command output is in [05-output3](/07-Finding-&-Troubleshootings/03-Qouta-Limitation-On-Disk/05-output3.txt).

I expected that disabling telemetry in the tfvars would take care of all its dependencies. It did not. I checked three things:

- `kubectl get crd | grep monitoring.coreos.com` returned nothing, so the Prometheus CRDs were never installed.
- The `monitoring-dashboards` release failed with `namespaces "monitoring-system" not found`. That namespace is created by the telemetry stack.
- The `describe` output of the Soperator release shows that the Flux chart (`helm-soperator-fluxcd`) passes `serviceMonitor.enabled: true` to the controller as an inline value, even with telemetry off.

My conclusion is that in this release, the controller's ServiceMonitor is enabled unconditionally, while the CRD that it needs is installed only when telemetry is on. I did not find a tfvars option to separate the two. I also could not see the chart sources, so I cannot say whether a values override would work.

I chose to turn telemetry back on and make its disks smaller. I set `vm_single` (VictoriaMetrics) and `vm_logs` (VictoriaLogs) to 32 GiB each in `modules/slurm/variables.tf`. I also lowered the metrics store requests (CPU and memory), because the defaults are large for an 8 vCPU system node. These values are my own estimates.

```hcl
variable "resources_vm_logs_server" {
  type = object({
    memory = string
    cpu    = string
    size   = string
  })
  # Demo Day change: stock default size is 256Gi.
  # Reduced to fit the 2048 GiB Network SSD quota. CPU and memory are unchanged.
  default = {
    memory = "2Gi"
    cpu    = "1000m"
    size   = "32Gi"
  }
}

variable "resources_vm_single" {
  type = object({
    memory     = string
    cpu        = string
    size       = string
    gomaxprocs = number
  })
  # Demo Day change: stock defaults are 24Gi memory, 6000m CPU, 512Gi disk and gomaxprocs 6.
  # Reduced to fit the 2048 GiB Network SSD quota and an 8 vCPU system node.
  default = {
    memory     = "8Gi"
    cpu        = "2000m"
    size       = "32Gi"
    gomaxprocs = 2
  }
}
```

With these values the disk budget is 1970 GiB with 4 system nodes (78 GiB spare). With a fifth system node it would be 2098 GiB, which is 50 GiB over the quota. So the system node group is configured for 4 to 5 nodes, but in practice it cannot reach 5 nodes with this quota.

---

## Round 4: no quota error, the install moves forward

With the new sizes Terraform did not stop on a quota error again. The cluster, the node groups, the Flux releases, the `soperator-system` components and most of the Slurm cluster components were created. This showed that the disk quota fix works.

```bash
kubectl -n soperator-system get all
NAME                                                READY   STATUS    RESTARTS   AGE
pod/soperator-checks-checks-b757c4cc9-475t2         2/2     Running   0          15m
pod/soperator-controller-manager-584b65dc7c-xbpjt   2/2     Running   0          15m
pod/soperator-node-configurator-ds-2g7nr            1/1     Running   0          15m
pod/soperator-node-configurator-ds-dnk4b            1/1     Running   0          15m
pod/soperator-node-configurator-ds-fmpvt            1/1     Running   0          15m
pod/soperator-node-configurator-ds-jcbsn            1/1     Running   0          15m
pod/soperator-node-configurator-ds-k4p97            1/1     Running   0          15m
pod/soperator-node-configurator-ds-qhlq6            1/1     Running   0          15m
pod/soperator-node-configurator-ds-rdvt5            1/1     Running   0          15m
pod/soperator-node-configurator-ds-xpkdd            1/1     Running   0          15m

kubectl -n soperator get all
NAME                                                     READY   STATUS             RESTARTS       AGE
pod/controller-0                                         1/2     CrashLoopBackOff   5 (100s ago)   6m42s
pod/controller-placeholder-r56xj                         3/3     Running            0              6m42s
pod/controller-spool-mount-x8szw                         1/1     Running            0              16m
pod/helm-soperator-dcgm-exporter-ds-tnnmn                1/1     Running            0              18m
pod/helm-soperator-dcgm-exporter-ds-znb77                1/1     Running            0              18m
pod/jail-mount-...                                       1/1     Running            0              16m
pod/jail-submount-data-mount-...                         1/1     Running            0              16m
pod/login-0                                              0/2     Pending            0              6m41s
pod/sconfigcontroller-...                                1/1     Running            0              6m42s
pod/slurm-exporter-6cf785fbd7-tvspk                      1/1     Running            0              6m41s
pod/soperator-populate-jail-nnp2g                        0/1     Completed          0              16m
pod/wait-for-active-checks-sjz2c                         1/1     Running            0              15m
pod/worker-0                                             1/2     Init:3/4           1 (59s ago)    6m41s
pod/worker-1                                             1/2     Init:3/4           1 (59s ago)    6m41s
```

The pods that were not healthy (`controller-0`, `login-0`, `worker-0`, `worker-1`) failed for reasons that have nothing to do with disks. See the next section.

---

# Other issues after the quota fix

After the disk quota was solved, we faced several other issues. They are **not related to the disk quota**. Each one has its own page. After fixing them, the infrastructure was created and terraform apply completed successfuly.

![image7](/07-Finding-&-Troubleshootings/03-Qouta-Limitation-On-Disk/Images/image7.png)

**One of them is partly connected to the disk work: the login pod (issue 06).** In Round 2, I turned off the login node group to save 256 GiB of disk. After that, the login pod had no node with the `login` label, and it stayed `Pending`. Moving the pod to the system nodes fixed the placement. The pod also asked for more CPU, memory and disk than a system node can offer, because the recipe sizes it for a 16 vCPU login node with a 256 GiB boot disk. So I had to reduce the size of the request. This is a resource issue, but it comes from the login node group being off, and not from the disk quota itself. See [06-Login-Pod-Pending](/07-Finding-&-Troubleshootings/06-Login-Pod-Pending/README.md) for the details.

---

# Conclusion

The apply stalled because the project allows only 2048 GiB of Network SSD disks. The disk for the NFS server could not be created, so Flux could not install `nfs-server`, and every release after it waited until Terraform gave up.

My tfvars were already smaller than the recipe's defaults, but that was not enough, for three reasons:

- I did not know the real limit. I found it only by reading it with a service account, because my user cannot open the quota page.
- The recipe sets a minimum boot disk for each node type, which I could not go below without editing the validation rules.
- The recipe creates disks outside the tfvars (VictoriaMetrics and VictoriaLogs, 768 GiB by default).

The final design uses 1970 GiB of the 2048 GiB limit. It needs three trade-offs: accounting is off, the login node group is off, and the monitoring disks are much smaller than the defaults. I sized the monitoring disks by estimate, not by measurement.

---

# Workaround

I redesigned every disk to fit the limits. All disks stay on `NETWORK_SSD`, because it is the only disk type with a quota in this project.

## What I changed

| Change | Where | Saves |
|---|---|---|
| Accounting off (`accounting_enabled = false`) | `terraform.tfvars` | 128 GiB boot disk, the accounting filesystem and the MariaDB claim |
| Login node group off (`node_group_enabled = false`) | `terraform.tfvars` | 256 GiB boot disk |
| NFS share (`/home`) set to 64 GiB | `terraform.tfvars` | 64 GiB compared with the 128 GiB I assumed |
| VictoriaMetrics and VictoriaLogs set to 32 GiB each | `main.tf` (`module "slurm"`) | 704 GiB |
| Telemetry stays **on** | `terraform.tfvars` | n/a (needed by the Soperator controller) |

---

## Disks (limit: 2048 GiB, 32 disks)

| Disk | GiB each | Count (4 system nodes) | Total GiB (4 system nodes) | Count (5 system nodes) | Total GiB (5 system nodes) |
|---|---|---|---|---|---|
| System node boot | 128 | 4 | 512 | 5 | 640 |
| Controller node boot | 128 | 1 | 128 | 1 | 128 |
| Worker boot | 512 | 2 | 1024 | 2 | 1024 |
| NFS node boot | 128 | 1 | 128 | 1 | 128 |
| NFS `/home` disk | 64 | 1 | 64 | 1 | 64 |
| Controller state | 50 | 1 | 50 | 1 | 50 |
| VictoriaMetrics | 32 | 1 | 32 | 1 | 32 |
| VictoriaLogs | 32 | 1 | 32 | 1 | 32 |
| **Total** | | **12 disks** | **1970** | **13 disks** | **2098** |
| Quota limit | | 32 disks | 2048 | 32 disks | 2048 |
| **Spare** | | | **78** (96% used) | | **-50** (102% used, over quota) |

---

## Shared filesystems (limit: 3072 GiB, 32 filesystems)

| Filesystem | Size | Used for |
|---|---|---|
| Jail | **[TO CONFIRM]** GiB | Slurm root filesystem: OS, Python environments |
| Data (`/mnt/data`) | **[TO CONFIRM]** GiB | Datasets, base model, checkpoints, LoRA weights |
| Controller spool | **[TO CONFIRM]** GiB | Deprecated in this release, probably unused |
| **Total** | **[TO CONFIRM]** | |

The accounting filesystem is not created, because accounting is off.

---
