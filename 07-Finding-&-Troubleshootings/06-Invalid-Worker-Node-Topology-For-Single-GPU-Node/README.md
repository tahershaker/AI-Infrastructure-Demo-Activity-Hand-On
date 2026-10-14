# 06 - Worker Pods Wait for Topology Labels That Single-H100 Nodes Do Not Have
 
> After the GRES fix the controller was healthy, but `worker-0` and `worker-1` stayed in `Init:3/4`. Their init container waits until Soperator knows where each node sits in the network (its switch tiers). Nebius sets this data as node labels, but only on nodes that are inside an InfiniBand GPU cluster. My single-H100 nodes are not in one, so the labels never came and the init container timed out every 180 seconds. I proved the cause by adding two labels by hand. For a permanent fix, I added the same labels to the worker node group in Terraform.

---

# Issue Summary

- After the GRES fix ([04 - GRES](/07-Finding-&-Troubleshootings/04-Gres-Data-8-GPU/README.md)), the controller was healthy, but both workers were stuck at `Init:3/4`. They never started, so `terraform apply` kept waiting.
- One helper step inside the worker pod, `worker-init`, kept failing after 180 seconds. Its error was `Topology for node ... not found`.
- This step needs to know where the node sits in the network. It looks for the node in a list called `topology-node-labels`. The list was empty.
- The list is built from labels on the node (`topology.nebius.com/tier-*`). My nodes had no such labels.
- Nebius adds these labels only to nodes in a GPU cluster with InfiniBand. My single-H100 nodes are not in one.
- The recipe has no way to skip this step for my setup.
- I added two labels by hand with made-up values. The list filled up and both workers started.
- I then put the same two labels in Terraform, on the worker node group, so every new node gets them.

---

# Questions to Nebius team

1. Is it expected that single-GPU H100 nodes get no `topology.nebius.com` labels?
2. Is there a supported way to use a flat network layout, so that the workers do not need switch tiers or topology labels?
3. I added made-up labels to the worker nodes, so that the `topology-node-labels` ConfigMap picks them up and `worker-init` passes. Is this the expected approach?
4. If not, should I ask the Nebius team for a different approach? For example, a supported setting to skip the topology wait when there is no GPU cluster or a flat network layout.

---

# Issue Description

**What is topology?** In a large GPU cluster, nodes are not equally close to each other. Nodes in the same rack are connected through one switch. Nodes in different racks need more switches in between, and the traffic gets slower. A distributed training job sends a lot of data between its nodes (gradients, activations), so the placement of the job matters. If a job lands on nodes under the same switch, it runs faster. If its nodes are far apart, the network becomes the bottleneck. "Topology" is the map of this network: which node sits under which switch, and which switch sits under which.

**How Slurm uses it.** Slurm has a plugin, `topology/tree`, that reads this map from a file (`topology.conf`). Leaf switches list the nodes under them, and higher switches list the switches under them. When a job asks for several nodes, Slurm looks for the lowest switch that can hold the whole job and keeps the job under it. For example, with 4 nodes under switch `leaf1` and 4 under `leaf2`, a job for 4 nodes goes to one leaf and not 2 + 2.

**How Nebius describes it.** Nebius puts the position of a node into node labels:

| Label | Meaning (from the Nebius docs) |
|---|---|
| `topology.nebius.com/gpu-cluster-id` | Nodes with the same value have a high-speed network between them |
| `topology.nebius.com/tier-0` | Closest level, for example multi-node NVLink |
| `topology.nebius.com/tier-1` | Locality domain, for example rack-level switches |
| `topology.nebius.com/tier-2` | Wider domain, for example spine-level switches |

The docs also say that a node without these labels "usually means that the node is not attached to a GPU cluster, or TAS is not enabled". See [Topology-aware scheduling](https://docs.nebius.com/kubernetes/gpu/topology-aware-scheduling).

**How Soperator connects the two.** Each worker pod has an init container, `worker-init`, that must finish before `slurmd` starts. One of its jobs is `wait-topology`. It waits until the ConfigMap `topology-node-labels` has an entry for its own node, and the entry holds the tier labels of that node. The worker pod then passes the tiers (`$TOPO_SWITCH_TIER1`, `$TOPO_SWITCH_TIER2`) into the Slurm node settings. So Soperator expects every worker to have tier labels, and it will not start the worker without them.

**Why I hit it.** My workers are single-H100 nodes (1 GPU per node, no InfiniBand), so they are not in a GPU cluster and Nebius sets no tier labels. The recipe has no way around the wait for this case. On GB300 the recipe uses the other plugin (`topology/block`), and that path is different.

---

# Troubleshooting steps

## Step 1: Find which init container is stuck

The workers stayed in `Init:3/4` while the controller was `2/2 Running` with no restarts. My first idea was that the workers wait for the controller, but the controller was healthy, so I looked at the init containers:

```bash
kubectl -n soperator describe pod worker-0
```

```text
  worker-init:
    Image:         cr.nebius.cloud/soperator/worker_slurmd:4.1.13-slurm25.11.8
    Command:
      python3
      /opt/bin/slurm/worker_init.py
      wait-controller
      wait-topology
    State:          Running
    Last State:     Terminated
      Reason:       Error
      Exit Code:    1
      Started:      Mon, 12 Oct 2026 00:56:52 +0400
      Finished:     Mon, 12 Oct 2026 00:59:52 +0400
    Restart Count:  3
    Environment:
      TOPOLOGY_CONFIGMAP_PATH:   /tmp/slurm/topology-node-labels
      TOPOLOGY_WAIT_TIMEOUT:     180
      TOPOLOGY_POLL_INTERVAL:    5
      SLURM_TOPOLOGY_PLUGIN:     topology/tree
```

Result: the first three init containers finished, and `worker-init` keeps failing. The last run lasted exactly 180 seconds, which is `TOPOLOGY_WAIT_TIMEOUT`. The controller wait allows 300 seconds (60 attempts x 5 seconds), so the failure is in the topology wait, not in the controller wait. Next, I read its log.

---

## Step 2: Read the log of `worker-init`

```bash
kubectl -n soperator logs worker-0 -c worker-init
```

```text
2026-10-11 21:04:16 - INFO - Waiting for topology data for node: computeinstance-...
2026-10-11 21:04:16 - INFO - Topology ConfigMap path: /tmp/slurm/topology-node-labels
2026-10-11 21:04:16 - INFO - Node computeinstance-... not found in topology ConfigMap, retrying... (0s elapsed)
2026-10-11 21:04:21 - INFO - Node computeinstance-... not found in topology ConfigMap, retrying... (5s elapsed)
...
2026-10-11 21:07:11 - INFO - Node computeinstance-... not found in topology ConfigMap, retrying... (175s elapsed)
2026-10-11 21:07:16 - ERROR - Topology for node computeinstance-... not found after 180s
2026-10-11 21:07:16 - ERROR - Available nodes in ConfigMap: []
```

Result: the init container checks every 5 seconds, gives up after 180 seconds, and the list of nodes in the ConfigMap is empty (`[]`). Kubernetes then restarts the container, and the back-off grows up to 5 minutes. Next, I looked at the ConfigMap itself.

---

## Step 3: Look at the ConfigMap

```bash
kubectl -n soperator describe configmap topology-node-labels
Name:         topology-node-labels
Namespace:    soperator
Labels:       <none>
Annotations:  kruise.io/resourcedistribution.resource.from: topology-soperator
              kruise.io/resourcedistribution.resource.hashcode: be92a688da96cc26ecc0e5afb493f418bb10944189dd0b7926bf4cba06f8167f

Data
====

BinaryData
====
```

There is no `data:` section at all. The ConfigMap is a copy made by a Kruise `ResourceDistribution` called `topology-soperator`. I checked its source:

```bash
kubectl get resourcedistribution topology-soperator -o yaml
```

```text
spec:
  resource:
    apiVersion: v1
    kind: ConfigMap
    metadata:
      name: topology-node-labels
  targets:
    includedNamespaces:
      list:
      - name: soperator-system
      - name: soperator
```

Result: the source has a name and no data either. The ResourceDistribution only copies. So something else must write the node entries, and that something has nothing to write. Next, I checked what the nodes carry.

---

## Step 4: Check the labels on the nodes

```bash
kubectl get nodes --show-labels | tr ',' '\n' | grep -i -E 'tier|switch|topology' | sort | uniq -c
   8 topology.kubernetes.io/region=eu-north1
```

Result: the worker node has only the region label. There is no `topology.nebius.com/tier-*` label. This matches the empty ConfigMap, and I now need to know if Terraform should have added them.

---

## Step 5: Check if Terraform can provide the topology data

The worker needs a network map for its node. I checked if Terraform provides one, or if there is a setting to turn the topology off.

1. In `main.tf` (line 611), the plugin is `topology/block` for GB300 and `topology/tree` for everything else. For H100, it is `topology/tree`.
```bash
grep -rn -i "topology" installations/tshaker-demoday/terraform.tfvars installations/tshaker-demoday/main.tf
installations/tshaker-demoday/main.tf:610:  topology = {
installations/tshaker-demoday/main.tf:611:    plugin     = local.gb300_enabled ? "topology/block" : "topology/tree"
```

2. In `modules/slurm/variables.tf` (line 64), only these two values are allowed. There is no `flat` or `off`.
```bash
grep -rn -i "topology" --include='*.tf' modules | head -40
modules/slurm/variables.tf:59:    plugin = "topology/tree"
modules/slurm/variables.tf:64:    condition     = contains(["topology/tree", "topology/block"], var.topology.plugin)
```

3. In the template, topology settings are written only for `topology/block`. For `topology/tree`, Terraform sends no topology data.

Result: for H100, Terraform provides no network map and has no switch to skip the wait. The map must come from the node labels, which Nebius sets only for GPU-cluster nodes.

So Terraform does not provide the data for `topology/tree`. It must come from the node labels, which Nebius should set. That is what the Nebius docs describe, and my nodes are not in a GPU cluster.

---

## Step 6: Prove the cause with a manual test

I added the two tier labels by hand to both worker nodes. Both got the same values, because there is no real network to describe:

```bash
for n in computeinstance-e00md5edqrbbxfh3tg computeinstance-e00rtzex28cyw4brba; do
  kubectl label node $n topology.nebius.com/tier-1=demo-tier1 topology.nebius.com/tier-2=demo-tier2
done

node/computeinstance-e00md5edqrbbxfh3tg labeled
node/computeinstance-e00rtzex28cyw4brba labeled
```

```bash
kubectl -n soperator get configmap topology-node-labels -o yaml
```

```text
apiVersion: v1
data:
  computeinstance-...1: '{"tier-1":"demo-tier1","tier-2":"demo-tier2"}'
  computeinstance-...2: '{"tier-1":"demo-tier1","tier-2":"demo-tier2"}'
kind: ConfigMap
```

Result: the ConfigMap filled within seconds, so Soperator builds it from the node labels. `worker-0` passed on its next retry. `worker-1` was in the 5-minute back-off (`CrashLoopBackOff`, exit code 1), so I deleted the pod to skip the wait. The StatefulSet made a new pod and it passed. Both workers became `2/2 Running`, and Slurm showed one GPU per node:

```bash
kubectl -n soperator get pods
...
worker-0                                             2/2     Running     0          40m
worker-1                                             2/2     Running     0          11s
```

```bash
kubectl -n soperator delete pod worker-1
```

The StatefulSet made a new pod and it passed. Both workers became `2/2 Running`, and Slurm showed one GPU per node:

```bash
kubectl -n soperator exec -it controller-0 -c slurmctld -- sinfo -N -o "%N %G %T"

NODELIST GRES STATE
worker-0 gpu:nvidia_h100_80gb_hbm3:1 idle
worker-1 gpu:nvidia_h100_80gb_hbm3:1 idle
```

---

# Conclusion

Soperator will not start a worker until the ConfigMap `topology-node-labels` has an entry for it, and the entry is built from the `topology.nebius.com/tier-*` node labels. Nebius sets these labels only for nodes in a GPU cluster (InfiniBand). Single-H100 nodes are not in one, so the ConfigMap stays empty and `worker-init` fails after 180 seconds, again and again. The recipe uses `topology/tree` for H100, Terraform adds no topology data for it, and there is no setting to skip the wait. Two demo labels per worker node fix it.

---

# Workaround

The labels are set on the worker node group, so every node that joins gets them (a new node, a replaced node, or a bigger `size`). In `modules/k8s/k8s_ng_workers_v2.tf`, inside `template.metadata.labels`:

```hcl
        module.labels.label_exclude_from_external_lb,
        # Demo Day change: single-H100 nodes have no InfiniBand fabric, so Nebius
        # sets no topology labels. Soperator's worker-init waits for them.
        # These are demo values. They do not describe a real network.
        {
          "topology.nebius.com/tier-1" = "demo-tier1"
          "topology.nebius.com/tier-2" = "demo-tier2"
        },
      )
```

If a node does not get the labels (Step 8), label it by hand and delete its pod:

```bash
kubectl label node <worker-node> topology.nebius.com/tier-1=demo-tier1 topology.nebius.com/tier-2=demo-tier2 --overwrite
kubectl -n soperator delete pod <worker-pod>
```

---