# 03-Qouta-Limitation-On-Disk

> `terraform apply` stopped after 60 minutes while waiting for Flux. The cause was a disk quota: the project allows 2048 GiB of Network SSD, and my first design needed about 4600 GiB. I read the real limits with a service account profile, then redesigned every disk to fit.

---

# Issue Description

I ran `terraform apply` to build the cluster. It created the Kubernetes cluster and the node groups without errors. Then it reached the step that waits for Soperator's Slurm cluster to install, and it sat there for one hour. After that it failed with this error:

```
module.slurm.terraform_data.wait_for_slurm_cluster_hr: Still creating... [59m40s elapsed]
module.slurm.terraform_data.wait_for_slurm_cluster_hr (local-exec): [59m] flux-system-soperator-fluxcd-slurm-cluster: Ready=DependencyNotReady, Reconciling=Progressing
module.slurm.terraform_data.wait_for_slurm_cluster_hr (local-exec):   Waiting for dependency: dependency 'flux-system/flux-system-soperator-fluxcd-nfs-server' is not ready
module.slurm.terraform_data.wait_for_slurm_cluster_hr: Still creating... [59m50s elapsed]
module.slurm.terraform_data.wait_for_slurm_cluster_hr: Still creating... [60m00s elapsed]

module.slurm.terraform_data.wait_for_slurm_cluster_hr (local-exec): ERROR: Timeout reached waiting for HelmRelease flux-system-soperator-fluxcd-slurm-cluster to be successfully installed.
module.slurm.terraform_data.wait_for_slurm_cluster_hr (local-exec): === HelmRelease Status: flux-system-soperator-fluxcd-slurm-cluster ===
module.slurm.terraform_data.wait_for_slurm_cluster_hr (local-exec): Conditions:
module.slurm.terraform_data.wait_for_slurm_cluster_hr: Still creating... [60m10s elapsed]
module.slurm.terraform_data.wait_for_slurm_cluster_hr (local-exec):   Reconciling: True (Progressing) - Fulfilling prerequisites
module.slurm.terraform_data.wait_for_slurm_cluster_hr (local-exec):   Ready: False (DependencyNotReady) - dependency 'flux-system/flux-system-soperator-fluxcd-nfs-server' is not ready
module.slurm.terraform_data.wait_for_slurm_cluster_hr (local-exec): Helm history (last 3):
module.slurm.terraform_data.wait_for_slurm_cluster_hr (local-exec): =======================================


│ [58m] flux-system-soperator-fluxcd-slurm-cluster: Ready=DependencyNotReady, Reconciling=Progressing
│   Waiting for dependency: dependency 'flux-system/flux-system-soperator-fluxcd-nfs-server' is not ready
│ [59m] flux-system-soperator-fluxcd-slurm-cluster: Ready=DependencyNotReady, Reconciling=Progressing
│   Waiting for dependency: dependency 'flux-system/flux-system-soperator-fluxcd-nfs-server' is not ready
│
│ ERROR: Timeout reached waiting for HelmRelease flux-system-soperator-fluxcd-slurm-cluster to be successfully installed.
│ === HelmRelease Status: flux-system-soperator-fluxcd-slurm-cluster ===
│ Conditions:
│   Reconciling: True (Progressing) - Fulfilling prerequisites
│   Ready: False (DependencyNotReady) - dependency 'flux-system/flux-system-soperator-fluxcd-nfs-server' is not ready
│ Helm history (last 3):
```

What this means: Terraform builds the base (cluster, nodes, filesystems), then hands the software installation to **Flux**. After that it only waits. The script checks the `slurm-cluster` HelmRelease every 10 seconds for up to 60 minutes. That release cannot start until the `nfs-server` release is ready, and `nfs-server` was never ready. So the failure was not in Terraform. Something inside the cluster was blocking Flux.

For the full error, see [01-error1](/07-Finding-&-Troubleshootings/03-Qouta-Limitation-On-Disk/01-error1.txt)

---

# Troubleshooting steps

## Step 1: Look at the cluster in the console

The Kubernetes cluster was up and running, but the console showed some errors. I opened the cluster details and found two red error points. Both pointed at the persistent volume claim (PVC) of the NFS server.

![image1](/07-Finding-&-Troubleshootings/03-Qouta-Limitation-On-Disk/Images/image1.png)

![image2](/07-Finding-&-Troubleshootings/03-Qouta-Limitation-On-Disk/Images/image2.png)

## Step 2: Log in to the cluster and find the stuck pods

I checked the nodes, the namespaces and the Flux releases:

```bash
kubectl get nodes -o wide
kubectl get ns
kubectl get helmreleases -n flux-system
```

See [03-output1](/07-Finding-&-Troubleshootings/03-Qouta-Limitation-On-Disk/03-output1.txt) for the full HelmRelease output. You will find: `flux-system-soperator-fluxcd-nfs-server | 77m | False | Helm install failed for release nfs-system/nfs-server with chart helm-nfs-server@1.2.2: context deadline exceeded`

Result: the nodes were `Ready`. The `nfs-server` HelmRelease was failing, and the releases that depend on it (`slurm-cluster` and the ones after it) were waiting. This matches the Terraform log.

## Step 3: Check the NFS PVC and find the claims that are not bound

```bash
kubectl -n nfs-system get pvc
```

![image5](/07-Finding-&-Troubleshootings/03-Qouta-Limitation-On-Disk/Images/image5.png)

```bash
kubectl get pvc -A | grep -v Bound
```

See [04-output2](/07-Finding-&-Troubleshootings/03-Qouta-Limitation-On-Disk/04-output2.txt) for the full PVC output.

Result: two claims were stuck in `Pending`.

| Namespace | Claim | Storage class |
|---|---|---|
| `nfs-system` | `nfs-server-storage` | `compute-csi-network-ssd-ext4` |
| `monitoring-system` | `vmsingle-metrics-victoria-metrics-k8s-stack` | `compute-csi-default-sc` |

The NFS server pod could not start because its disk did not exist. The second claim is the VictoriaMetrics disk, which I did not know about at that point.

## Step 4: Describe the claim to see why

```bash
kubectl -n nfs-system get pvc
kubectl -n nfs-system describe pvc nfs-server-storage
```

The events at the bottom gave the reason:

```
Events:
  Type     Reason              Age   From                                                                                            Message
  ----     ------              ----  ----                                                                                            -------
  Warning  ProvisioningFailed  53m   compute.csi.nebius.com_computeinstance-e00c1n7gpx7da8yvb4_24475925-13c2-4374-a48f-fa607b8d06a5  failed to provision volume with StorageClass "compute-csi-network-ssd-ext4": rpc error: code = ResourceExhausted desc = rpc error: code = ResourceExhausted desc = Quota limit exceeded. Exceeded limit for container project-e00hq8rdpr00cb57ha9dkd, quota compute.disk.size.network-ssd.
request = 7dbbf72a-62bf-4b4d-bdd8-e89a79ecd0f4
caused by service error:
  Quota failure QuotaFailure: service compute, violations:
    compute.disk.size.network-ssd (limit 2199023255552, requested 3229815406592): Exceeded limit for container project-e00hq8rdpr00cb57ha9dkd
```

For the full describe output, see [02-error2](/07-Finding-&-Troubleshootings/03-Qouta-Limitation-On-Disk/02-error2.txt)

The numbers are in bytes. Converted:

| | Bytes | GiB |
|---|---|---|
| Limit | 2,199,023,255,552 | **2048** (2 TiB) |
| Requested | 3,229,815,406,592 | **3008** |

My reading is that "requested" is the total the project would hold if this disk were created. If that is right, the request was 960 GiB over the limit.

## Step 5: Understand the problem

I now knew it was a quota problem. It was a surprise, because I had already lowered the disk sizes in `terraform.tfvars` below the recipe's defaults, and I still hit the limit.

## Step 6: Try to read the limit in the console

I wanted the full quota list with usage, but my user does not have permission to see the quota page.

![image3](/07-Finding-&-Troubleshootings/03-Qouta-Limitation-On-Disk/Images/image3.png)

## Step 7: Compare with the published defaults

The Nebius documentation lists default quotas per region. For `eu-north1` it says 4 TiB of Network SSD. My project's error says 2 TiB. The two do not match, so the published defaults were no use for planning.

Source: [Nebius Compute quotas and limits](https://docs.nebius.com/compute/resources/quotas-limits)

## Step 8: Use the service account, which has more rights

From a previous issue I knew that `mlflow-sa` is in the `editors` group. The group may have more rights than my user, so I made a CLI profile for it. I generated an authorized key. I ran this with my own login:

```bash
export NEBIUS_PROJECT_ID='project-<PROJECT-ID>'
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

The disk types `network-ssd-non-replicated`, `network-ssd-io-m3` and `network-hdd` had **no** quota set. I read this as "not available in this project", so I will keep every disk on `NETWORK_SSD`.

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

## Step 11: Check which other components request storage

While reviewing the PVC list, I noticed a second claim stuck in `Pending`: `vmsingle-metrics-victoria-metrics-k8s-stack`, in the namespace `monitoring-system`, with StorageClass `compute-csi-default-sc`. I had not created it in my tfvars. The recipe also installs monitoring and logging components (VictoriaMetrics and VictoriaLogs), and they request disks of their own.

I wanted to know where their storage comes from: the boot disk of the node, a shared filesystem, or a separate disk requested through the CSI driver. I had already destroyed the cluster, so I could not check a running system. Instead I searched the Terraform recipe, starting from the name of this claim.

In `terraform.tfvars` there is a variable `telemetry_enabled`, which is `true` by default. This switches on the monitoring stack. I found two components behind it: `vm_single`, a single-instance VictoriaMetrics that stores metrics, and `vm_logs`, VictoriaLogs, which stores logs. Their default sizes are set in `modules/slurm/variables.tf`.

![image6](/07-Finding-&-Troubleshootings/03-Qouta-Limitation-On-Disk/Images/image6.png)

## Step 12: Look for a workaround 

With telemetry enabled, VictoriaMetrics requests **512 GiB** and VictoriaLogs requests **256 GiB**, which is **768 GiB** in total. Each one is a separate Network SSD disk created through the CSI driver, so both count against the 2048 GiB disk quota.

I had three options:

1. Disable telemetry in the tfvars. I decided against this, because I believe it would affect the requested task of having GPU utilization above 80%.
2. Reduce the sizes in `modules/slurm/variables.tf`. I did not choose this, because I do not know the impact of smaller sizes and I did not want to lose time on it.
3. Keep the 768 GiB as a fixed amount and size all other disks around it. This is what I chose.

> **Round 1:** This was my first assumption, and it turned out to be wrong.

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

When I ran Terraform, it failed with an `Invalid value for variable` error for each node group. The error said that each node type has a minimum boot disk size. I opened `variables.tf` and found validation rules that set these minimums:

| Node | Minimum (GiB) |
|---|---|
| System nodes (each) | 128 |
| Controller | 128 |
| Login | 256 |
| Accounting | 128 |
| NFS node | 128 |
| Worker (each) | 512 |

With 5 system nodes and 2 workers, the boot disks alone need 2304 GiB. This is already above the 2048 GiB quota, before adding the NFS `/home` disk, the controller state disk and the Victoria disks.

At this point I was guessing, because I did not know the reasons behind these minimums or what would break if I went lower. I decided not to change the validation rules. I set every boot disk to its minimum allowed value in the tfvars file, ran Terraform again, and used the result to see what happens next.

> **Round 2:** I hit the same quota limit again. At this point I had to think about my options.

With the minimum sizes from the validation checks, the boot disks alone need **2304 GiB** (assuming 5 nodes in the system group). My limit is **2048 GiB**, so the boot disks are already **256 GiB** over. Several other disks are not in this number:

| Item | GiB |
|---|---|
| Boot disks at the minimum sizes (5 system nodes) | 2304 |
| NFS share (`/home`), assuming 128 GiB | 128 |
| Controller state (default) | 50 |
| VictoriaMetrics + VictoriaLogs (default) | 768 |
| **Total needed** | **3250** |
| Quota limit | 2048 |
| **Missing** | **1202** |

Currently these are my options:

1. **Disable telemetry in the tfvars** (saves 768 GiB). 
2. **Disable accounting in the tfvars** (`accounting_enabled = false`, saves 128 GiB). This removes the accounting node group and the Slurm accounting system. It also removes the accounting shared filesystem and the MariaDB claim, because they are no longer created.
3. **Disable the login node group in the tfvars** (`node_group_enabled = false` saves 256 GiB). The tfvars has an option for this. Its comment says that the login pods then run on the worker nodes. I have not tested this option for my preset yet.
4. **Edit the validation checks in `variables.tf`** and lower the disk sizes to fit the quota. 

I am going to test with options 1, 2 and 3, and I am setting the NFS share (`/home`) disk to 64 GiB. Option 4 stays unused.

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

> **Round 3:** the storage problem was solved, but I hit a new issue in the `flux-system-soperator-fluxcd-soperator` HelmRelease.

The quota error was gone and `nfs-server` installed. But the Soperator controller release failed, because it creates a `soperator-controller-manager-servicemonitor` object, and the cluster has no `ServiceMonitor` CRD (`monitoring.coreos.com/v1`). Every release that depends on it stayed `False`.

```bash
kubectl get helmreleases -A
NAMESPACE     NAME                                                      AGE   READY   STATUS
flux-system   flux-system-soperator-fluxcd-cert-manager                 21m   True    Helm install succeeded for release cert-manager-system/cert-manager
....
flux-system   flux-system-soperator-fluxcd-monitoring-dashboards        21m   False   Helm install failed for release monitoring-system/soperator-monitoring-dashboards with chart helm-soperator-monitoring-dashboards@4.1.13: 7 errors occurred:...
...
flux-system   flux-system-soperator-fluxcd-nodeconfigurator             21m   False   dependency 'flux-system/flux-system-soperator-fluxcd-soperator' is not ready
flux-system   flux-system-soperator-fluxcd-nodesets                     21m   False   dependency 'flux-system/flux-system-soperator-fluxcd-soperator' is not ready
...
flux-system   flux-system-soperator-fluxcd-slurm-cluster                21m   False   dependency 'flux-system/flux-system-soperator-fluxcd-soperator' is not ready
flux-system   flux-system-soperator-fluxcd-slurm-cluster-storage        21m   False   dependency 'flux-system/flux-system-soperator-fluxcd-soperator' is not ready
flux-system   flux-system-soperator-fluxcd-soperator                    21m   False   Helm install failed for release soperator-system/soperator-controller with chart helm-soperator@4.1.13: unable to build kubernetes objects from release manifest: resource mapping not found for name: "soperator-controller-manager-servicemonitor" namespace: "" from "": no matches for kind "ServiceMonitor" in version "monitoring.coreos.com/v1"...
flux-system   flux-system-soperator-fluxcd-soperator-activechecks       21m   False   dependency 'flux-system/flux-system-soperator-fluxcd-slurm-cluster' is not ready
flux-system   flux-system-soperator-fluxcd-soperatorchecks              21m   False   dependency 'flux-system/flux-system-soperator-fluxcd-soperator' is not ready

---

kubectl -n flux-system describe helmrelease flux-system-soperator-fluxcd-soperator
.....
Last Helm logs:
2026-10-11T16:16:19.893060773Z: beginning wait for 6 resources with timeout of 1m0s
2026-10-11T16:16:21.128405816Z: wait for resources succeeded within 1s
2026-10-11T16:16:21.128412497Z: successfully applied 6 CustomResourceDefinition(s)
2026-10-11T16:16:21.12841468Z: clearing REST mapper cache
  Warning  InstallFailed  30m  helm-controller  Helm install failed for release soperator-system/soperator-controller with chart helm-soperator@4.1.13: unable to build kubernetes objects from release manifest: resource mapping not found for name: "soperator-controller-manager-servicemonitor" namespace: "" from "": no matches for kind "ServiceMonitor" in version "monitoring.coreos.com/v1"
ensure CRDs are installed first
```

See [05-output3](/07-Finding-&-Troubleshootings/03-Qouta-Limitation-On-Disk/05-output3.txt) for the full command output.

I expected that disabling telemetry in the tfvars would take care of all its dependencies. It did not. I checked three things:

- `kubectl get crd | grep monitoring.coreos.com` returned nothing, so the Prometheus CRDs were never installed.
- The `monitoring-dashboards` release failed with `namespaces "monitoring-system" not found`. That namespace is created by the telemetry stack.
- The `describe` output of the Soperator release shows that the Flux chart (`helm-soperator-fluxcd`) passes `serviceMonitor.enabled: true` to the controller as an inline value, even with telemetry off.

My conclusion is that in this release, the controller's ServiceMonitor is enabled unconditionally, while the CRD that it needs is installed only when telemetry is on. I did not find a tfvars option to separate the two. I also could not see the chart sources, so I cannot say whether a values override would work.

I chose to turn telemetry back on, and to make its disks smaller. I set `vm_single` (VictoriaMetrics) and `vm_logs` (VictoriaLogs) to 32 GiB each in `main.tf`, inside the `module "slurm"` block. I also lowered the metrics store requests (CPU and memory), because the defaults are large for an 8 vCPU system node. These values are my own estimates.

```hcl
  telemetry_enabled   = var.telemetry_enabled
  public_o11y_enabled = var.public_o11y_enabled
  soperator_notifier  = var.soperator_notifier

  # Demo Day change: smaller monitoring disks and requests, to fit the 2048 GiB Network SSD quota.
  resources_vm_single = {
    memory     = "8Gi"
    cpu        = "2000m"
    size       = "32Gi"
    gomaxprocs = 2
  }
  resources_vm_logs_server = {
    memory = "2Gi"
    cpu    = "1000m"
    size   = "32Gi"
  }

  backups_enabled = local.backups_enabled
```

With these values the disk budget is 1970 GiB with 4 system nodes (78 GiB spare). With a fifth system node it would be 2098 GiB, which is 50 GiB over the quota. So the system node group can be configured for 4–5 nodes, but in practice it cannot reach 5 nodes with this quota.

I ran Terraform again to see the result.

> **Round 4:** i hit another issue related to `GRES data for gpu` as the gres configuraiton is set for 8-GPU node and the nodes we are using is only 1-GPU node.

This is a different issue from the disk qouta and will be troubleshooted in a different page - please refer to [Gress-Data-8-GPU-Issue](/07-Finding-&-Troubleshootings/04-Gres-Data-8-GPU/README.md)

The fact that we did not get another qouta limitation issue means that this fix is working so far - however, i would like to go for another roud after fixing the above issue to make sure everything is working fine 

> **Round 4:** I hit a different issue, this time with the `GRES` data for the GPU. The GRES configuration in the recipe is written for an 8-GPU node. The nodes in this lab have only 1 GPU each.

This issue is not related to the disk quota, so I troubleshoot it on its own page: [Gres-Data-8-GPU-Issue](/07-Finding-&-Troubleshootings/04-Gres-Data-8-GPU/README.md)

This time Terraform did not stop on a quota error. The cluster, the node groups, the Flux releases (with exception to ), soperator-system components, and soperator cluster components (with exception to the soperator-controller) were all created. This tells me the disk quota fix works.

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

NAME                                                   TYPE        CLUSTER-IP     EXTERNAL-IP   PORT(S)    AGE
service/soperator-checks-metrics                       ClusterIP   10.1.222.139   <none>        8443/TCP   15m
service/soperator-controller-metrics                   ClusterIP   10.1.150.69    <none>        8443/TCP   15m

kubectl -n soperator get all
NAME                                                     READY   STATUS             RESTARTS       AGE
pod/controller-0                                         1/2     CrashLoopBackOff   5 (100s ago)   6m42s
pod/controller-placeholder-r56xj                         3/3     Running            0              6m42s
pod/controller-spool-mount-x8szw                         1/1     Running            0              16m
pod/helm-soperator-dcgm-exporter-ds-tnnmn                1/1     Running            0              18m
pod/helm-soperator-dcgm-exporter-ds-znb77                1/1     Running            0              18m
pod/jail-mount-7v2zs                                     1/1     Running            0              16m
pod/jail-mount-8fgrq                                     1/1     Running            0              16m
pod/jail-mount-gv997                                     1/1     Running            0              16m
pod/jail-mount-h5th5                                     1/1     Running            0              16m
pod/jail-mount-r94l4                                     1/1     Running            0              16m
pod/jail-mount-swjsq                                     1/1     Running            0              16m
pod/jail-mount-vx8bd                                     1/1     Running            0              16m
pod/jail-submount-data-mount-4bblc                       1/1     Running            0              16m
pod/jail-submount-data-mount-78pnm                       1/1     Running            0              16m
pod/jail-submount-data-mount-d6nmw                       1/1     Running            0              16m
pod/jail-submount-data-mount-g7gj6                       1/1     Running            0              16m
pod/jail-submount-data-mount-hlxs7                       1/1     Running            0              16m
pod/jail-submount-data-mount-srn9f                       1/1     Running            0              16m
pod/jail-submount-data-mount-w52dp                       1/1     Running            0              16m
pod/login-0                                              0/2     Pending            0              6m41s
pod/run-extensive-check-on-reservations-29862360-g2hfr   0/2     Completed          0              13m
pod/run-extensive-check-on-reservations-29862370-js52q   0/2     Completed          0              2m52s
pod/sconfigcontroller-7b868fdf86-7phxl                   1/1     Running            0              6m42s
pod/sconfigcontroller-7b868fdf86-fj729                   1/1     Running            0              6m42s
pod/slurm-exporter-6cf785fbd7-tvspk                      1/1     Running            0              6m41s
pod/soperator-populate-jail-nnp2g                        0/1     Completed          0              16m
pod/wait-for-active-checks-sjz2c                         1/1     Running            0              15m
pod/worker-0                                             1/2     Init:3/4           1 (59s ago)    6m41s
pod/worker-1                                             1/2     Init:3/4           1 (59s ago)    6m41s

NAME                                          TYPE           CLUSTER-IP     EXTERNAL-IP      PORT(S)        AGE
service/helm-soperator-dcgm-exporter-svc      ClusterIP      10.1.118.55    <none>           9400/TCP       18m
service/soperator-controller-svc              ClusterIP      10.1.89.252    <none>           6817/TCP       6m42s
service/soperator-login-headless-svc          ClusterIP      None           <none>           22/TCP         6m41s
```

I want to confirm this with one more clean round after I fix the GRES issue. I will destroy the lab, fix the GRES issue and apply again from zero. If that run also passes without a quota error, I will treat the quota issue as closed.

> **Round 5:** 



---

# Conclusion

The apply stalled because the project allows only 2048 GiB of Network SSD disks. The disk for the NFS server could not be created, so Flux could not install `nfs-server`, and every release after it waited until Terraform gave up.

My tfvars were already smaller than the recipe's defaults, but that was not enough, for two reasons. I did not know the real limit, and I missed disks that the recipe creates outside the tfvars (VictoriaMetrics and VictoriaLogs). I found the limit only by reading it with the service account, because my user cannot open the quota page.

I now have to redesign the disk allocation (node boot disks, the NFS disk and the shared filesystems) to fit these limits, treating the 768 GiB for VictoriaMetrics and VictoriaLogs as fixed. I did not know exactly what uses these disks, so I could not size them properly in the time available. I sized the rest by common sense and trial and error.

---

# Workaround

I redesigned every disk to fit the limits. All disks stay on `NETWORK_SSD`, because it is the only disk type with a quota in this project.

## Boot disks and NFS disk (limit: 2048 GiB, 32 disks)

The cluster has 4–5 system nodes (autoscaled), plus one controller, one login, one accounting and one NFS node, plus 2 workers. The controller state disk (default from the recipe) is also created.

| Disk | Count | Size each | Total GiB |
|---|---|---|---|
| System node boot | 5 (max) | 96 | 480 |
| Controller node boot | 1 | 96 | 96 |
| Login node boot | 1 | 64 | 64 |
| Accounting node boot | 1 | 64 | 64 |
| NFS node boot | 1 | 64 | 64 |
| Worker boot | 2 | 192 | 384 |
| NFS `/home` disk | 1 | 64 | 64 |
| VictoriaMetrics + VictoriaLogs (fixed) | 2 | 768 in total | 768 |
| **Total** | | | **1984** |

1984 GiB is 97% of the 2048 GiB limit.

## Shared filesystems (limit: 3072 GiB, 32 filesystems)

| Filesystem | Size | Used for |
|---|---|---|
| Jail | 1024 GiB [TO CONFIRM] | Slurm root filesystem: OS, Python environments |
| Data (`/mnt/data`) | 1024 GiB [TO CONFIRM] | Datasets, base model, checkpoints, LoRA weights |
| Controller spool | 128 GiB | Deprecated in this release, probably unused |
| Accounting | 128 GiB | Probably unused; see the MariaDB note |
| **Total** | **2304 GiB** | |

1632 GiB is 75% of the 3072 GiB limit.

---
