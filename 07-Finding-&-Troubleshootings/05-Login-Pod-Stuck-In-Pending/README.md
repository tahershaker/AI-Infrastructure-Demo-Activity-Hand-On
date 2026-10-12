# 05 - Login Pod Stays Pending When the Login Node Group Is Off

> `login-0` stayed `Pending` because Soperator only allows it to run on nodes labelled `login`, and I had turned the login node group off to save disk quota. Even on a system node the pod would not fit, because the recipe sizes it for a 16 vCPU login node. I proved the fix with a live patch, then made it permanent with three small edits in Terraform.

---

# Issue Summary

- To fit the disk quota, I turned off the login node group (`node_group_enabled = false`). See [03 - Quota Limitation on Disk](/07-Finding-&-Troubleshootings/03-Qouta-Limitation-On-Disk/README.md).
- `login-0` then stayed `Pending`, and the cluster showed `LOGIN 0`.
- The scheduler event says no node matches the pod: 4 nodes fail the node affinity, 4 nodes have taints the pod does not tolerate.
- The reason is in the recipe. The login pod always uses the `login` filter, unless `login_on_worker_nodes` is true, and that is true for GB300 only.
- The pod would also not fit on a system node. It asks for 14 vCPU, 54 GiB memory and 164 GiB disk. A system node has 7.9 vCPU, about 30.7 GiB and about 109.6 GiB.
- A live patch (filter set to `system`, smaller requests) started the pod. Three edits in Terraform make the same change permanent:
  1. `modules/slurm/main.tf` (line 246): the login pod now uses the `system` node filter instead of the `login` filter, so it can run on the system nodes.
  2. `terraform.tfvars`: the login preset is lowered from `16vcpu-64gb` to `4vcpu-16gb`, so the CPU and memory request fits on a system node.
  3. `installations/<my-folder>/main.tf` (around line 457): when the login node group is off, the disk request is fixed at 64 GiB. It was 164 GiB, calculated from the 256 GiB boot disk.

---

# Questions to Nebius team

1. The comment in `terraform.tfvars` says login pods run on worker nodes when the login node group is off. Does this apply to GB300 only? Should the recipe offer a fallback to the system nodes for other platforms?
2. For H100, is the login node group expected to stay enabled?
3. If yes, I am back at the disk quota issue, and the only option is to increase the quota.
4. Is it an accepted approach to disable the login node group and change the node affinity, taints and tolerations of the login pod?
5. If not, should I ask the Nebius team for a different approach? For example, a supported way to disable the login node group on a single-GPU H100 setup, or an increase of the disk quota.

---

# Issue Description

**How Soperator decides where the login pod runs.** Kubernetes places a pod on a node using four things, and Soperator uses all of them:

| Term | Meaning | 
|---|---|
| Label | A tag on a node, for example `slurm.nebius.ai/nodeset=login` | 
| Node affinity | A rule on the pod: "only nodes with this label" | 
| Taint | A mark on a node: "keep out unless you accept it" |
| Toleration | A mark on the pod: "I accept that taint" |

In the SlurmCluster resource, Soperator keeps a list of these rules, called node filters (`k8sNodeFilters`): `system`, `accounting`, `controller`, `login` and `worker`. Each filter has an affinity on the label `slurm.nebius.ai/nodeset` and, for most, a toleration. Each Slurm component names the filter it uses (`k8sNodeFilterName`). The login pod uses the filter `login`. So it can only run on a node labelled `slurm.nebius.ai/nodeset=login`, and those nodes come only from the login node group.

Then there is the size. Kubernetes places a pod by what it **requests**, not by what the node really uses. A node that is idle can still be "full" on paper.

In my build, the login node group is off, so no `login` node exists. The pod waits for ever.

---

# Troubleshooting steps

## Step 1: Ask the scheduler why the pod is Pending

`login-0` was `Pending` in every round of the apply, and the `LOGIN` column of the cluster showed `0`. At first I accepted this as a result of the quota work. It was not safe to leave, because the active checks (`ssh-check`, `create-user-*`) were `Pending` too, and `terraform apply` waits for them. So I asked the scheduler:

```bash
kubectl -n soperator describe pod login-0 
```

```text
Warning  FailedScheduling   default-scheduler   0/8 nodes are available: 4 node(s) didn't match Pod's node affinity/selector, 4 node(s) had untolerated taint(s). ...
Normal   NotTriggerScaleUp  cluster-autoscaler  pod didn't trigger scale-up: 1 node(s) didn't match Pod's node affinity/selector
```

Result: of 8 nodes, 4 do not match the pod's affinity and 4 have taints the pod does not accept. The autoscaler also cannot help, because no node group can give a node with the right label. Next, I need the exact rule of the pod.

---

## Step 2: Read the rule of the pod

```text
Node affinity:  slurm.nebius.ai/nodeset In [login]
Tolerations:    slurm.nebius.ai/nodeset=login:NoSchedule
```

Then I listed the nodes by their `nodeset` label:

```bash
kubectl get nodes -L slurm.nebius.ai/nodeset
```

```text
kubectl get nodes -L slurm.nebius.ai/nodeset

NAME                                 STATUS   ROLES    AGE     VERSION   NODESET
computeinstance-e00dpf5e97eft6c4sg   Ready    <none>   5h23m   v1.35.7   nfs
computeinstance-e00f0f6eqqzeg61nng   Ready    <none>   5h23m   v1.35.7   controller
computeinstance-e00gp55x6krjw7dmd6   Ready    <none>   5h23m   v1.35.7   worker
computeinstance-e00hjf3m4dg1k2ebnj   Ready    <none>   5h23m   v1.35.7   system
computeinstance-e00mv1d3sabb2nj8pe   Ready    <none>   5h23m   v1.35.7   worker
computeinstance-e00pmdsyqcadj9tp8g   Ready    <none>   5h23m   v1.35.7   system
computeinstance-e00s52tt1ma5gsb7zf   Ready    <none>   5h23m   v1.35.7   system
computeinstance-e00x7j626d1a3pm55f   Ready    <none>   5h23m   v1.35.7   system
```

| Node group (`nodeset` label) | Nodes |
|---|---|
| system | 4 |
| controller | 1 |
| nfs | 1 |
| worker | 2 |
| **login** | **0** |

Result: the pod asks for a `login` node, and none exists. 

---

## Step 3: Find the cause in the recipe

The `terraform.tfvars` file has this comment above the login block - `Optional. For GB300, this is set to false internally so login pods run on worker nodes`.

The comment is clear that it covers GB300. It does not say what happens on other platforms such as H100, so I checked the code. The search shows that `node_group_enabled` only decides whether the login node group is created:

```bash
grep -rn "node_group_enabled" modules installations/tshaker-demoday/main.tf
```

```text
modules/k8s/k8s_ng_login.tf:2:  count = var.node_group_login.node_group_enabled ? 1 : 0
installations/tshaker-demoday/main.tf:29:  node_group_enabled = local.gb300_enabled ? false : var.slurm_nodeset_login.node_group_enabled
```

The filter is chosen in `modules/slurm/main.tf`:

```text
:246  k8s_node_filter_name = var.login_on_worker_nodes ? local.node_filters.worker.name : local.node_filters.login.name     # login pod
```

`login_on_worker_nodes` is true for GB300 only. So the comment is true for GB300 only. For H100 it is false, and the login pod always goes to the `login` filter.

I also checked the live object, and it shows the same:

```bash
kubectl -n soperator get pod login-0 -o yaml | grep -A8 "affinity:"
  affinity:
    nodeAffinity:
      requiredDuringSchedulingIgnoredDuringExecution:
        nodeSelectorTerms:
        - matchExpressions:
          - key: slurm.nebius.ai/nodeset
            operator: In
            values:
            - login
```

```bash
kubectl -n soperator get slurmcluster soperator -o yaml | grep -A40 "k8sNodeFilters:"
...
      value: controller
  - affinity:
      nodeAffinity:
        requiredDuringSchedulingIgnoredDuringExecution:
          nodeSelectorTerms:
          - matchExpressions:
            - key: slurm.nebius.ai/nodeset
              operator: In
              values:
              - login
    name: login
    tolerations:
....
```

```bash
kubectl -n soperator get slurmcluster soperator -o jsonpath='{.spec.slurmNodes.login.k8sNodeFilterName}{"\n"}'
login
```

The entry named `login` has `slurm.nebius.ai/nodeset In [login]`. Next question: if I point the pod to the `system` nodes, will it fit?

---

## Step 4: Check if the pod would fit on a system node

The pod request, from the SlurmCluster object:

```text
sshd   cpu: 14000m   memory: 54Gi   ephemeral-storage: 164Gi
```

To see what each node can offer, I listed the allocatable resources of every node:

```bash
kubectl get nodes -o custom-columns='NAME:.metadata.name,NODESET:.metadata.labels.slurm\.nebius\.ai/nodeset,CPU:.status.allocatable.cpu,MEM:.status.allocatable.memory,EPH:.status.allocatable.ephemeral-storage'
```

```text
NAME                           NODESET      CPU      MEM           EPH
computeinstance-e00dpf...      nfs          3900m    15749436Ki    117736614921
computeinstance-e00f0f...      controller   3900m    15749428Ki    117736614921
computeinstance-e00gp5...      worker       15900m   194634712Ki   477199885545
computeinstance-e00hjf...      system       7900m    32238480Ki    117736614921
computeinstance-e00mv1...      worker       15900m   194634716Ki   477199885545
computeinstance-e00pmd...      system       7900m    32238480Ki    117736614921
computeinstance-e00s52...      system       7900m    32238480Ki    117736614921
computeinstance-e00x7j...      system       7900m    32238476Ki    117736614921
```

A system node offers 7.9 vCPU, about 30.7 GiB of memory and about 109.6 GiB of disk. I compared this with what the login pod asks for:

| | Login pod asks | System node allocatable | Free on the emptiest system node |
|---|---|---|---|
| CPU | 14 | 7.9 | about 4.9 |
| Memory | 54 GiB | about 30.7 GiB | about 25 GiB |
| Ephemeral disk | 164 GiB | about 109.6 GiB | about 109 GiB |

The free values come from `kubectl describe node`. They show what the other pods already request on each node. One system node had 41% of its CPU and 31% of its memory requested.

The nodes were nearly idle. I checked the real use:

```bash
kubectl top nodes
```

```text
NAME                        CPU(cores)   CPU(%)   MEMORY(bytes)   MEMORY(%)
computeinstance-e00dpf...   84m          2%       1061Mi          6%
computeinstance-e00f0f...   118m         3%       1136Mi          7%
computeinstance-e00gp5...   88m          0%       1361Mi          0%
computeinstance-e00hjf...   217m         2%       1842Mi          5%
computeinstance-e00mv1...   74m          0%       1390Mi          0%
computeinstance-e00pmd...   154m         1%       1564Mi          4%
computeinstance-e00s52...   173m         2%       1756Mi          5%
computeinstance-e00x7j...   142m         1%       1518Mi          4%
```

Every node used 3% CPU or less. But this does not help, because the scheduler places pods by what they request, and not by what the node really uses. 

The pod asks for more than any system node can give. This means that changing the filter alone is not enough, and the pod must also become smaller. Next, I looked for where the size comes from:

- CPU and memory come from the login preset in `terraform.tfvars` (`16vcpu-64gb`, minus some overhead).
- Disk comes from the boot disk of the login node group: `boot_disk.size_gibibytes * k8s_ephemeral_storage_coefficient - k8s_ephemeral_storage_reserve`, in `installations/tshaker-demoday/main.tf` (around line 457). The recipe requires a boot disk of at least 256 GiB, and this gives the 164 GiB.

So the plan has two parts: send the pod to the system nodes, and make it smaller.

---

## Step 5: Test the idea with a live patch

Before touching the code, I tested it on the running cluster. One patch changes the `login` filter from the label `login` to the label `system`, and lowers the pod requests to 3 vCPU, 12 GiB and 64 GiB (the emptiest system node had about 4.9 vCPU free):

```bash
kubectl -n soperator patch slurmcluster soperator --type=json -p='[
 {"op":"replace","path":"/spec/k8sNodeFilters/3/affinity/nodeAffinity/requiredDuringSchedulingIgnoredDuringExecution/nodeSelectorTerms/0/matchExpressions/0/values/0","value":"system"},
 {"op":"replace","path":"/spec/slurmNodes/login/sshd/resources/cpu","value":"3000m"},
 {"op":"replace","path":"/spec/slurmNodes/login/sshd/resources/memory","value":"12Gi"},
 {"op":"replace","path":"/spec/slurmNodes/login/sshd/resources/ephemeral-storage","value":"64Gi"}
]'
```

The operator recreated the pod and the scheduler placed it:

```bash
kubectl -n soperator get pod | grep login-0
login-0                                                 2/2     Running     0          17s

```

```bash
kubectl -n soperator get slurmcluster
NAME        STATUS      CONTROLLERS   LOGIN   SCONFIGCTRL   ACCOUNTING
soperator   Available   True          1       True          False
```

The cluster changed from `Not available` / `LOGIN 0` to `Available` / `LOGIN 1`. `ACCOUNTING False` is expected, because accounting is off (see 03). The login pod works on a system node.

---

# Conclusion

The login pod is tied to nodes labelled `login`. Turning off the login node group removes those nodes, but nothing moves the pod to another place. The comment in `terraform.tfvars` suggests otherwise, but it applies to GB300 only. In addition, the pod is sized for a 16 vCPU login node, so even on a system node it would not fit. Both parts need a fix: the filter and the size. The live patch proved that a login pod on a system node works.

---

# Workaround

Three small edits.

**1. Send the login pod to the system filter.** `modules/slurm/main.tf`, line 246:

```diff
-          k8s_node_filter_name     = var.login_on_worker_nodes ? local.node_filters.worker.name : local.node_filters.login.name
+          k8s_node_filter_name     = var.login_on_worker_nodes ? local.node_filters.worker.name : local.node_filters.system.name
```

The `system` filter already exists, so nothing else is needed.

**2. Use a smaller preset for the login pod.** `terraform.tfvars`:

```diff
   resource = {
     platform = "cpu-d3"
-    preset   = "16vcpu-64gb"
+    preset   = "4vcpu-16gb"
   }
```

The boot disk stays at 256 GiB, because the validation requires it. It is not created while the node group is off.

**3. Fix the disk request.** `installations/<my-folder>/main.tf`, in the login resources:

```diff
-      ephemeral_storage_gibibytes = floor(
+      ephemeral_storage_gibibytes = var.slurm_nodeset_login.node_group_enabled ? floor(
         var.slurm_nodeset_login.boot_disk.size_gibibytes * module.resources.k8s_ephemeral_storage_coefficient
         -module.resources.k8s_ephemeral_storage_reserve.gibibytes
-      )
+      ) : 64
```

With the node group on, the stock formula still applies. With it off, the pod asks for a fixed 64 GiB, which fits on a system node (about 109.6 GiB usable).

---


