# Soperator Cluster Full Inventory

## Nodes: what exists, what each node is for, what it offers.

```bash
kubectl get nodes -o wide

NAME                                 STATUS   ROLES    AGE     VERSION   INTERNAL-IP   EXTERNAL-IP   OS-IMAGE             KERNEL-VERSION       CONTAINER-RUNTIME
computeinstance-e00dpf5e97eft6c4sg   Ready    <none>   7h18m   v1.35.7   10.6.0.3      <none>        Ubuntu 24.04.5 LTS   6.11.0-1016-nvidia   containerd://2.2.6
computeinstance-e00f0f6eqqzeg61nng   Ready    <none>   7h18m   v1.35.7   10.6.0.108    <none>        Ubuntu 24.04.5 LTS   6.11.0-1016-nvidia   containerd://2.2.6
computeinstance-e00gp55x6krjw7dmd6   Ready    <none>   7h18m   v1.35.7   10.6.38.15    <none>        Ubuntu 24.04.4 LTS   6.11.0-1016-nvidia   containerd://2.2.6
computeinstance-e00hjf3m4dg1k2ebnj   Ready    <none>   7h18m   v1.35.7   10.6.0.47     <none>        Ubuntu 24.04.5 LTS   6.11.0-1016-nvidia   containerd://2.2.6
computeinstance-e00mv1d3sabb2nj8pe   Ready    <none>   7h18m   v1.35.7   10.6.0.0      <none>        Ubuntu 24.04.4 LTS   6.11.0-1016-nvidia   containerd://2.2.6
computeinstance-e00pmdsyqcadj9tp8g   Ready    <none>   7h18m   v1.35.7   10.6.38.4     <none>        Ubuntu 24.04.5 LTS   6.11.0-1016-nvidia   containerd://2.2.6
computeinstance-e00s52tt1ma5gsb7zf   Ready    <none>   7h18m   v1.35.7   10.6.0.79     <none>        Ubuntu 24.04.5 LTS   6.11.0-1016-nvidia   containerd://2.2.6
computeinstance-e00x7j626d1a3pm55f   Ready    <none>   7h18m   v1.35.7   10.6.38.3     <none>        Ubuntu 24.04.5 LTS   6.11.0-1016-nvidia   containerd://2.2.6
```

---

```bash
kubectl get nodes -o custom-columns='NAME:.metadata.name,NODESET:.metadata.labels.slurm\.nebius\.ai/nodeset,TAINTS:.spec.taints[*].key,PROVIDER:.spec.providerID'

NAME                                 NODESET      TAINTS                    PROVIDER
computeinstance-e00dpf5e97eft6c4sg   nfs          slurm.nebius.ai/nodeset   nebius://computeinstance-e00dpf5e97eft6c4sg
computeinstance-e00f0f6eqqzeg61nng   controller   slurm.nebius.ai/nodeset   nebius://computeinstance-e00f0f6eqqzeg61nng
computeinstance-e00gp55x6krjw7dmd6   worker       nvidia.com/gpu            nebius://computeinstance-e00gp55x6krjw7dmd6
computeinstance-e00hjf3m4dg1k2ebnj   system       <none>                    nebius://computeinstance-e00hjf3m4dg1k2ebnj
computeinstance-e00mv1d3sabb2nj8pe   worker       nvidia.com/gpu            nebius://computeinstance-e00mv1d3sabb2nj8pe
computeinstance-e00pmdsyqcadj9tp8g   system       <none>                    nebius://computeinstance-e00pmdsyqcadj9tp8g
computeinstance-e00s52tt1ma5gsb7zf   system       <none>                    nebius://computeinstance-e00s52tt1ma5gsb7zf
computeinstance-e00x7j626d1a3pm55f   system       <none>                    nebius://computeinstance-e00x7j626d1a3pm55f
```

---

```bash
kubectl get nodes -o custom-columns='NAME:.metadata.name,CPU:.status.allocatable.cpu,MEM:.status.allocatable.memory,EPH:.status.allocatable.ephemeral-storage,GPU:.status.allocatable.nvidia\.com/gpu,PODS:.status.allocatable.pods'

NAME                                 CPU      MEM           EPH            GPU      PODS
computeinstance-e00dpf5e97eft6c4sg   3900m    15749436Ki    117736614921   <none>   110
computeinstance-e00f0f6eqqzeg61nng   3900m    15749428Ki    117736614921   <none>   110
computeinstance-e00gp55x6krjw7dmd6   15900m   194634712Ki   477199885545   1        110
computeinstance-e00hjf3m4dg1k2ebnj   7900m    32238480Ki    117736614921   <none>   110
computeinstance-e00mv1d3sabb2nj8pe   15900m   194634716Ki   477199885545   1        110
computeinstance-e00pmdsyqcadj9tp8g   7900m    32238480Ki    117736614921   <none>   110
computeinstance-e00s52tt1ma5gsb7zf   7900m    32238480Ki    117736614921   <none>   110
computeinstance-e00x7j626d1a3pm55f   7900m    32238476Ki    117736614921   <none>   110
```

---

```bash
kubectl top nodes

NAME                                 CPU(cores)   CPU(%)   MEMORY(bytes)   MEMORY(%)
computeinstance-e00dpf5e97eft6c4sg   75m          1%       1059Mi          6%
computeinstance-e00f0f6eqqzeg61nng   110m         2%       1135Mi          7%
computeinstance-e00gp55x6krjw7dmd6   88m          0%       1363Mi          0%
computeinstance-e00hjf3m4dg1k2ebnj   229m         2%       1894Mi          6%
computeinstance-e00mv1d3sabb2nj8pe   87m          0%       1394Mi          0%
computeinstance-e00pmdsyqcadj9tp8g   148m         1%       1553Mi          4%
computeinstance-e00s52tt1ma5gsb7zf   144m         1%       1735Mi          5%
computeinstance-e00x7j626d1a3pm55f   141m         1%       1524Mi          4%
```

---

```bash
S=$(kubectl get nodes -l slurm.nebius.ai/nodeset=system -o name | head -1); kubectl get $S --show-labels | tr ',' '\n'
NAME                                 STATUS   ROLES    AGE     VERSION   LABELS
computeinstance-e00hjf3m4dg1k2ebnj   Ready    <none>   7h23m   v1.35.7   beta.kubernetes.io/arch=amd64
beta.kubernetes.io/instance-type=cpu-d3
beta.kubernetes.io/os=linux
failure-domain.beta.kubernetes.io/region=eu-north1
kubernetes.io/arch=amd64
kubernetes.io/hostname=computeinstance-e00hjf3m4dg1k2ebnj
kubernetes.io/os=linux
nebius.com/node-group-id=mk8snodegroup-e00rnjbbavh47px2wv
nebius.com/node-version=v1.35.7-nebius-node.75
nebius.com/resource-preset=8vcpu-32gb
node.kubernetes.io/instance-type=cpu-d3
slurm.nebius.ai/jail=true
slurm.nebius.ai/nodeset=system
slurm.nebius.ai/workload=cpu
topology.kubernetes.io/region=eu-north1
```

```bash
S=$(kubectl get nodes -l slurm.nebius.ai/nodeset=worker -o name | head -1); kubectl get $S --show-labels | tr ',' '\n'
NAME                                 STATUS   ROLES    AGE     VERSION   LABELS
computeinstance-e00gp55x6krjw7dmd6   Ready    <none>   7h24m   v1.35.7   beta.kubernetes.io/arch=amd64
beta.kubernetes.io/instance-type=gpu-h100-sxm
beta.kubernetes.io/os=linux
failure-domain.beta.kubernetes.io/region=eu-north1
kubernetes.io/arch=amd64
kubernetes.io/hostname=computeinstance-e00gp55x6krjw7dmd6
kubernetes.io/os=linux
nebius.com/containerd-major-minor-version=v2.2
nebius.com/cuda_version=13.0.3-1
nebius.com/driverful=true
nebius.com/drivers-preset=cuda13.0
nebius.com/gdrcopy_version=2.5.1
nebius.com/gpu-name=H100
nebius.com/gpu=true
nebius.com/linux-kernel-version=6.11.0-1016.16
nebius.com/mlnx_openmpi_version=4.1.9a1-1.20250722.92f9fca4eb.2507097
nebius.com/nccl_version=2.31.2-1-cuda13.0
nebius.com/node-group-id=mk8snodegroup-e00nbp193sk1jskjvy
nebius.com/node-version=v1.35.7-nebius-node.75
nebius.com/nvidia_driver_version=580.173.02
nebius.com/ofed_version=25.07.OFED.25.07.0.9.7.1-1
nebius.com/resource-preset=1gpu-16vcpu-200gb
node.kubernetes.io/exclude-from-external-load-balancers=true
node.kubernetes.io/instance-type=gpu-h100-sxm
nvidia.com/gpu.deploy.operands=false
slurm.nebius.ai/jail=true
slurm.nebius.ai/nodeset-name=worker
slurm.nebius.ai/nodeset=worker
slurm.nebius.ai/workload=gpu
topology.kubernetes.io/region=eu-north1
topology.nebius.com/tier-1=demo-tier1
topology.nebius.com/tier-2=demo-tier2
```

```bash
S=$(kubectl get nodes -l slurm.nebius.ai/nodeset=controller -o name | head -1); kubectl get $S --show-labels | tr ',' '\n'
NAME                                 STATUS   ROLES    AGE     VERSION   LABELS
computeinstance-e00f0f6eqqzeg61nng   Ready    <none>   7h25m   v1.35.7   beta.kubernetes.io/arch=amd64
beta.kubernetes.io/instance-type=cpu-d3
beta.kubernetes.io/os=linux
failure-domain.beta.kubernetes.io/region=eu-north1
kubernetes.io/arch=amd64
kubernetes.io/hostname=computeinstance-e00f0f6eqqzeg61nng
kubernetes.io/os=linux
nebius.com/node-group-id=mk8snodegroup-e00egz4pxv2kzwtxbk
nebius.com/node-version=v1.35.7-nebius-node.75
nebius.com/resource-preset=4vcpu-16gb
node.kubernetes.io/exclude-from-external-load-balancers=true
node.kubernetes.io/instance-type=cpu-d3
slurm.nebius.ai/jail=true
slurm.nebius.ai/nodeset=controller
slurm.nebius.ai/workload=cpu
topology.kubernetes.io/region=eu-north1
```

```bash
S=$(kubectl get nodes -l slurm.nebius.ai/nodeset=nfs -o name | head -1); kubectl get $S --show-labels | tr ',' '\n'
NAME                                 STATUS   ROLES    AGE     VERSION   LABELS
computeinstance-e00dpf5e97eft6c4sg   Ready    <none>   7h25m   v1.35.7   beta.kubernetes.io/arch=amd64
beta.kubernetes.io/instance-type=cpu-d3
beta.kubernetes.io/os=linux
failure-domain.beta.kubernetes.io/region=eu-north1
kubernetes.io/arch=amd64
kubernetes.io/hostname=computeinstance-e00dpf5e97eft6c4sg
kubernetes.io/os=linux
nebius.com/node-group-id=mk8snodegroup-e00n4ncrd2fxgmn141
nebius.com/node-version=v1.35.7-nebius-node.75
nebius.com/resource-preset=4vcpu-16gb
node.kubernetes.io/exclude-from-external-load-balancers=true
node.kubernetes.io/instance-type=cpu-d3
slurm.nebius.ai/nodeset=nfs
slurm.nebius.ai/workload=cpu
topology.kubernetes.io/region=eu-north1
```

---

> Separator

## Namespaces and pod count: how the cluster is divided.

```bash
kubectl get ns

NAME                                STATUS   AGE
cert-manager-system                 Active   7h24m
cilium-secrets                      Active   7h33m
default                             Active   7h33m
flux-system                         Active   7h25m
kruise-daemon-config                Active   7h23m
kruise-system                       Active   7h23m
kube-node-lease                     Active   7h33m
kube-public                         Active   7h33m
kube-system                         Active   7h33m
logs-system                         Active   7h24m
monitoring-system                   Active   7h24m
nfs-system                          Active   7h24m
security-profiles-operator-system   Active   7h24m
soperator                           Active   7h24m
soperator-system                    Active   7h24m
```

---

```bash
kubectl get pods -A --no-headers | awk '{print $1}' | sort | uniq -c | sort -rn

  52 kube-system
  47 soperator
  13 security-profiles-operator-system
  13 monitoring-system
  11 logs-system
  10 soperator-system
  10 nfs-system
  10 kruise-system
   6 flux-system
   3 cert-manager-system
```

---

```bash
kubectl get pods -A -o wide
NAMESPACE                           NAME                                                           READY   STATUS      RESTARTS   AGE     IP             NODE                                 NOMINATED NODE   READINESS GATES
cert-manager-system                 cert-manager-689dbf96cf-n8dd7                                  1/1     Running     0          7h26m   10.6.28.32     computeinstance-e00pmdsyqcadj9tp8g   <none>           <none>
cert-manager-system                 cert-manager-cainjector-7c8d57866-fncbw                        1/1     Running     0          7h26m   10.6.36.112    computeinstance-e00x7j626d1a3pm55f   <none>           <none>
cert-manager-system                 cert-manager-webhook-5b78b88bc6-9nz82                          1/1     Running     0          7h26m   10.6.28.142    computeinstance-e00pmdsyqcadj9tp8g   <none>           <none>
flux-system                         helm-controller-b654b75f8-j7hrk                                1/1     Running     0          7h27m   10.6.96.78     computeinstance-e00s52tt1ma5gsb7zf   <none>           <none>
flux-system                         image-automation-controller-86497776cd-ztmxl                   1/1     Running     0          7h27m   10.6.36.210    computeinstance-e00x7j626d1a3pm55f   <none>           <none>
flux-system                         image-reflector-controller-684c57479b-7s4g2                    1/1     Running     0          7h27m   10.6.28.190    computeinstance-e00pmdsyqcadj9tp8g   <none>           <none>
flux-system                         kustomize-controller-6f87798dcc-jjsq6                          1/1     Running     0          7h27m   10.6.36.184    computeinstance-e00x7j626d1a3pm55f   <none>           <none>
flux-system                         notification-controller-6966dcb565-px6fc                       1/1     Running     0          7h27m   10.6.28.108    computeinstance-e00pmdsyqcadj9tp8g   <none>           <none>
flux-system                         source-controller-c7c5b47d6-v8m7r                              1/1     Running     0          7h27m   10.6.96.50     computeinstance-e00s52tt1ma5gsb7zf   <none>           <none>
kruise-system                       kruise-controller-manager-7c6f58d74-88r72                      1/1     Running     0          7h25m   10.6.36.205    computeinstance-e00x7j626d1a3pm55f   <none>           <none>
kruise-system                       kruise-controller-manager-7c6f58d74-l5dcr                      1/1     Running     0          7h25m   10.6.28.94     computeinstance-e00pmdsyqcadj9tp8g   <none>           <none>
kruise-system                       kruise-daemon-64qfl                                            1/1     Running     0          7h25m   10.6.0.47      computeinstance-e00hjf3m4dg1k2ebnj   <none>           <none>
kruise-system                       kruise-daemon-66mjj                                            1/1     Running     0          7h25m   10.6.0.108     computeinstance-e00f0f6eqqzeg61nng   <none>           <none>
kruise-system                       kruise-daemon-9xkwh                                            1/1     Running     0          7h25m   10.6.38.15     computeinstance-e00gp55x6krjw7dmd6   <none>           <none>
kruise-system                       kruise-daemon-d2rgg                                            1/1     Running     0          7h25m   10.6.0.0       computeinstance-e00mv1d3sabb2nj8pe   <none>           <none>
kruise-system                       kruise-daemon-lb52x                                            1/1     Running     0          7h25m   10.6.38.4      computeinstance-e00pmdsyqcadj9tp8g   <none>           <none>
kruise-system                       kruise-daemon-pqbmx                                            1/1     Running     0          7h25m   10.6.0.3       computeinstance-e00dpf5e97eft6c4sg   <none>           <none>
kruise-system                       kruise-daemon-pw69z                                            1/1     Running     0          7h25m   10.6.38.3      computeinstance-e00x7j626d1a3pm55f   <none>           <none>
kruise-system                       kruise-daemon-wljqm                                            1/1     Running     0          7h25m   10.6.0.79      computeinstance-e00s52tt1ma5gsb7zf   <none>           <none>
kube-system                         cilium-278rk                                                   1/1     Running     0          7h28m   10.6.38.3      computeinstance-e00x7j626d1a3pm55f   <none>           <none>
kube-system                         cilium-76vqw                                                   1/1     Running     0          7h28m   10.6.0.0       computeinstance-e00mv1d3sabb2nj8pe   <none>           <none>
kube-system                         cilium-cv9t4                                                   1/1     Running     0          7h28m   10.6.38.4      computeinstance-e00pmdsyqcadj9tp8g   <none>           <none>
kube-system                         cilium-envoy-52fw4                                             1/1     Running     0          7h28m   10.6.0.3       computeinstance-e00dpf5e97eft6c4sg   <none>           <none>
kube-system                         cilium-envoy-98fw2                                             1/1     Running     0          7h28m   10.6.38.3      computeinstance-e00x7j626d1a3pm55f   <none>           <none>
kube-system                         cilium-envoy-9bhcr                                             1/1     Running     0          7h28m   10.6.38.15     computeinstance-e00gp55x6krjw7dmd6   <none>           <none>
kube-system                         cilium-envoy-9x2tl                                             1/1     Running     0          7h28m   10.6.0.0       computeinstance-e00mv1d3sabb2nj8pe   <none>           <none>
kube-system                         cilium-envoy-hfsgb                                             1/1     Running     0          7h28m   10.6.0.47      computeinstance-e00hjf3m4dg1k2ebnj   <none>           <none>
kube-system                         cilium-envoy-nlmn9                                             1/1     Running     0          7h28m   10.6.0.79      computeinstance-e00s52tt1ma5gsb7zf   <none>           <none>
kube-system                         cilium-envoy-qxxtz                                             1/1     Running     0          7h28m   10.6.0.108     computeinstance-e00f0f6eqqzeg61nng   <none>           <none>
kube-system                         cilium-envoy-zx2rn                                             1/1     Running     0          7h28m   10.6.38.4      computeinstance-e00pmdsyqcadj9tp8g   <none>           <none>
kube-system                         cilium-frmcf                                                   1/1     Running     0          7h28m   10.6.0.47      computeinstance-e00hjf3m4dg1k2ebnj   <none>           <none>
kube-system                         cilium-l7rds                                                   1/1     Running     0          7h28m   10.6.0.3       computeinstance-e00dpf5e97eft6c4sg   <none>           <none>
kube-system                         cilium-operator-7cf67ddb5b-gccfj                               1/1     Running     0          7h35m   10.6.38.3      computeinstance-e00x7j626d1a3pm55f   <none>           <none>
kube-system                         cilium-operator-7cf67ddb5b-kdncx                               1/1     Running     0          7h35m   10.6.38.4      computeinstance-e00pmdsyqcadj9tp8g   <none>           <none>
kube-system                         cilium-qlsft                                                   1/1     Running     0          7h28m   10.6.38.15     computeinstance-e00gp55x6krjw7dmd6   <none>           <none>
kube-system                         cilium-th8ll                                                   1/1     Running     0          7h28m   10.6.0.108     computeinstance-e00f0f6eqqzeg61nng   <none>           <none>
kube-system                         cilium-x6mc2                                                   1/1     Running     0          7h28m   10.6.0.79      computeinstance-e00s52tt1ma5gsb7zf   <none>           <none>
kube-system                         compute-csi-node-6lp9k                                         2/2     Running     0          7h28m   10.6.38.3      computeinstance-e00x7j626d1a3pm55f   <none>           <none>
kube-system                         compute-csi-node-d5kkx                                         2/2     Running     0          7h28m   10.6.0.108     computeinstance-e00f0f6eqqzeg61nng   <none>           <none>
kube-system                         compute-csi-node-g95wg                                         2/2     Running     0          7h28m   10.6.0.47      computeinstance-e00hjf3m4dg1k2ebnj   <none>           <none>
kube-system                         compute-csi-node-ghzdf                                         2/2     Running     0          7h28m   10.6.0.79      computeinstance-e00s52tt1ma5gsb7zf   <none>           <none>
kube-system                         compute-csi-node-nk6d4                                         2/2     Running     0          7h28m   10.6.0.0       computeinstance-e00mv1d3sabb2nj8pe   <none>           <none>
kube-system                         compute-csi-node-rv4qq                                         2/2     Running     0          7h28m   10.6.38.4      computeinstance-e00pmdsyqcadj9tp8g   <none>           <none>
kube-system                         compute-csi-node-vfnh8                                         2/2     Running     0          7h28m   10.6.0.3       computeinstance-e00dpf5e97eft6c4sg   <none>           <none>
kube-system                         compute-csi-node-xd5l4                                         2/2     Running     0          7h28m   10.6.38.15     computeinstance-e00gp55x6krjw7dmd6   <none>           <none>
kube-system                         container-runtime-monitor-installer-42m48                      1/1     Running     0          7h28m   10.6.38.15     computeinstance-e00gp55x6krjw7dmd6   <none>           <none>
kube-system                         container-runtime-monitor-installer-k75sd                      1/1     Running     0          7h28m   10.6.0.47      computeinstance-e00hjf3m4dg1k2ebnj   <none>           <none>
kube-system                         container-runtime-monitor-installer-ln6kf                      1/1     Running     0          7h28m   10.6.0.108     computeinstance-e00f0f6eqqzeg61nng   <none>           <none>
kube-system                         container-runtime-monitor-installer-mnnkq                      1/1     Running     0          7h28m   10.6.0.3       computeinstance-e00dpf5e97eft6c4sg   <none>           <none>
kube-system                         container-runtime-monitor-installer-nkbnt                      1/1     Running     0          7h28m   10.6.38.3      computeinstance-e00x7j626d1a3pm55f   <none>           <none>
kube-system                         container-runtime-monitor-installer-rjvcb                      1/1     Running     0          7h28m   10.6.0.0       computeinstance-e00mv1d3sabb2nj8pe   <none>           <none>
kube-system                         container-runtime-monitor-installer-sshh5                      1/1     Running     0          7h28m   10.6.38.4      computeinstance-e00pmdsyqcadj9tp8g   <none>           <none>
kube-system                         container-runtime-monitor-installer-zfqjk                      1/1     Running     0          7h28m   10.6.0.79      computeinstance-e00s52tt1ma5gsb7zf   <none>           <none>
kube-system                         coredns-77c89844c-5jxjk                                        1/1     Running     0          7h27m   10.6.96.246    computeinstance-e00s52tt1ma5gsb7zf   <none>           <none>
kube-system                         coredns-77c89844c-9pb75                                        1/1     Running     0          7h35m   10.6.55.131    computeinstance-e00hjf3m4dg1k2ebnj   <none>           <none>
kube-system                         coredns-autoscaler-695db474c-m77lv                             1/1     Running     0          7h35m   10.6.55.32     computeinstance-e00hjf3m4dg1k2ebnj   <none>           <none>
kube-system                         coredns-autoscaler-695db474c-qjfg2                             1/1     Running     0          7h35m   10.6.55.19     computeinstance-e00hjf3m4dg1k2ebnj   <none>           <none>
kube-system                         hubble-relay-6868665797-clzxz                                  1/1     Running     0          7h35m   10.6.55.145    computeinstance-e00hjf3m4dg1k2ebnj   <none>           <none>
kube-system                         hubble-ui-55c9496fb6-xmxf6                                     2/2     Running     0          7h35m   10.6.55.98     computeinstance-e00hjf3m4dg1k2ebnj   <none>           <none>
kube-system                         metrics-server-8694976875-8s7ks                                1/1     Running     0          7h35m   10.6.55.163    computeinstance-e00hjf3m4dg1k2ebnj   <none>           <none>
kube-system                         metrics-server-8694976875-qd6ps                                1/1     Running     0          7h35m   10.6.55.151    computeinstance-e00hjf3m4dg1k2ebnj   <none>           <none>
kube-system                         nebius-node-problem-detector-cpu-7rtqv                         1/1     Running     0          7h28m   10.6.0.108     computeinstance-e00f0f6eqqzeg61nng   <none>           <none>
kube-system                         nebius-node-problem-detector-cpu-j5qht                         1/1     Running     0          7h27m   10.6.38.4      computeinstance-e00pmdsyqcadj9tp8g   <none>           <none>
kube-system                         nebius-node-problem-detector-cpu-khrdb                         1/1     Running     0          7h28m   10.6.0.47      computeinstance-e00hjf3m4dg1k2ebnj   <none>           <none>
kube-system                         nebius-node-problem-detector-cpu-tmnfn                         1/1     Running     0          7h27m   10.6.38.3      computeinstance-e00x7j626d1a3pm55f   <none>           <none>
kube-system                         nebius-node-problem-detector-cpu-v67sq                         1/1     Running     0          7h27m   10.6.0.3       computeinstance-e00dpf5e97eft6c4sg   <none>           <none>
kube-system                         nebius-node-problem-detector-cpu-v7b6f                         1/1     Running     0          7h28m   10.6.0.79      computeinstance-e00s52tt1ma5gsb7zf   <none>           <none>
kube-system                         nebius-node-problem-detector-gpu-954zv                         1/1     Running     0          7h28m   10.6.0.0       computeinstance-e00mv1d3sabb2nj8pe   <none>           <none>
kube-system                         nebius-node-problem-detector-gpu-qvdr8                         1/1     Running     0          7h28m   10.6.38.15     computeinstance-e00gp55x6krjw7dmd6   <none>           <none>
kube-system                         nvidia-device-plugin-computeinstance-e00gp55x6krjw7dmd6        1/1     Running     0          7h28m   10.6.22.73     computeinstance-e00gp55x6krjw7dmd6   <none>           <none>
kube-system                         nvidia-device-plugin-computeinstance-e00mv1d3sabb2nj8pe        1/1     Running     0          7h28m   10.6.130.222   computeinstance-e00mv1d3sabb2nj8pe   <none>           <none>
logs-system                         opentelemetry-collector-events-79df7d748d-9vltc                1/1     Running     0          7h25m   10.6.96.20     computeinstance-e00s52tt1ma5gsb7zf   <none>           <none>
logs-system                         opentelemetry-collector-jail-logs-56cf85d4dc-jkmn7             1/1     Running     0          7h24m   10.6.36.61     computeinstance-e00x7j626d1a3pm55f   <none>           <none>
logs-system                         opentelemetry-collector-logs-agent-6rdnt                       1/1     Running     0          7h25m   10.6.28.58     computeinstance-e00pmdsyqcadj9tp8g   <none>           <none>
logs-system                         opentelemetry-collector-logs-agent-9wh6z                       1/1     Running     0          7h25m   10.6.36.149    computeinstance-e00x7j626d1a3pm55f   <none>           <none>
logs-system                         opentelemetry-collector-logs-agent-fzr79                       1/1     Running     0          7h25m   10.6.37.250    computeinstance-e00f0f6eqqzeg61nng   <none>           <none>
logs-system                         opentelemetry-collector-logs-agent-hfr9h                       1/1     Running     0          7h25m   10.6.55.248    computeinstance-e00hjf3m4dg1k2ebnj   <none>           <none>
logs-system                         opentelemetry-collector-logs-agent-pwh9h                       1/1     Running     0          7h25m   10.6.130.247   computeinstance-e00mv1d3sabb2nj8pe   <none>           <none>
logs-system                         opentelemetry-collector-logs-agent-pxtj8                       1/1     Running     0          7h25m   10.6.96.213    computeinstance-e00s52tt1ma5gsb7zf   <none>           <none>
logs-system                         opentelemetry-collector-logs-agent-w2hdk                       1/1     Running     0          7h25m   10.6.22.56     computeinstance-e00gp55x6krjw7dmd6   <none>           <none>
logs-system                         opentelemetry-collector-logs-agent-zdj65                       1/1     Running     0          7h25m   10.6.95.108    computeinstance-e00dpf5e97eft6c4sg   <none>           <none>
logs-system                         vm-logs-victoria-logs-single-server-0                          1/1     Running     0          7h26m   10.6.96.77     computeinstance-e00s52tt1ma5gsb7zf   <none>           <none>
monitoring-system                   metrics-grafana-58795cdb5-f9xkt                                2/2     Running     0          7h26m   10.6.55.56     computeinstance-e00hjf3m4dg1k2ebnj   <none>           <none>
monitoring-system                   metrics-kube-state-metrics-789d8df697-vww25                    1/1     Running     0          7h26m   10.6.55.103    computeinstance-e00hjf3m4dg1k2ebnj   <none>           <none>
monitoring-system                   metrics-prometheus-node-exporter-5t9rv                         1/1     Running     0          7h26m   10.6.0.3       computeinstance-e00dpf5e97eft6c4sg   <none>           <none>
monitoring-system                   metrics-prometheus-node-exporter-6b4cd                         1/1     Running     0          7h26m   10.6.0.0       computeinstance-e00mv1d3sabb2nj8pe   <none>           <none>
monitoring-system                   metrics-prometheus-node-exporter-bfj2r                         1/1     Running     0          7h26m   10.6.0.47      computeinstance-e00hjf3m4dg1k2ebnj   <none>           <none>
monitoring-system                   metrics-prometheus-node-exporter-dj8vk                         1/1     Running     0          7h26m   10.6.0.79      computeinstance-e00s52tt1ma5gsb7zf   <none>           <none>
monitoring-system                   metrics-prometheus-node-exporter-n6gz6                         1/1     Running     0          7h26m   10.6.38.15     computeinstance-e00gp55x6krjw7dmd6   <none>           <none>
monitoring-system                   metrics-prometheus-node-exporter-p6446                         1/1     Running     0          7h26m   10.6.38.4      computeinstance-e00pmdsyqcadj9tp8g   <none>           <none>
monitoring-system                   metrics-prometheus-node-exporter-zhb8v                         1/1     Running     0          7h26m   10.6.38.3      computeinstance-e00x7j626d1a3pm55f   <none>           <none>
monitoring-system                   metrics-prometheus-node-exporter-zxh72                         1/1     Running     0          7h26m   10.6.0.108     computeinstance-e00f0f6eqqzeg61nng   <none>           <none>
monitoring-system                   metrics-victoria-metrics-operator-6b488645c9-w7nqm             1/1     Running     0          7h26m   10.6.55.187    computeinstance-e00hjf3m4dg1k2ebnj   <none>           <none>
monitoring-system                   vmagent-metrics-victoria-metrics-k8s-stack-6586588b9c-md8tf    2/2     Running     0          7h25m   10.6.55.83     computeinstance-e00hjf3m4dg1k2ebnj   <none>           <none>
monitoring-system                   vmsingle-metrics-victoria-metrics-k8s-stack-649c5d79df-9gvv5   1/1     Running     0          7h25m   10.6.96.112    computeinstance-e00s52tt1ma5gsb7zf   <none>           <none>
nfs-system                          csi-nfs-controller-5f9c78d959-bdqtv                            5/5     Running     0          7h26m   10.6.38.4      computeinstance-e00pmdsyqcadj9tp8g   <none>           <none>
nfs-system                          csi-nfs-node-4s684                                             3/3     Running     0          7h26m   10.6.38.4      computeinstance-e00pmdsyqcadj9tp8g   <none>           <none>
nfs-system                          csi-nfs-node-6ck5r                                             3/3     Running     0          7h26m   10.6.0.47      computeinstance-e00hjf3m4dg1k2ebnj   <none>           <none>
nfs-system                          csi-nfs-node-9z55l                                             3/3     Running     0          7h26m   10.6.38.3      computeinstance-e00x7j626d1a3pm55f   <none>           <none>
nfs-system                          csi-nfs-node-c7d5q                                             3/3     Running     0          7h26m   10.6.0.108     computeinstance-e00f0f6eqqzeg61nng   <none>           <none>
nfs-system                          csi-nfs-node-k8j6n                                             3/3     Running     0          7h26m   10.6.0.0       computeinstance-e00mv1d3sabb2nj8pe   <none>           <none>
nfs-system                          csi-nfs-node-qdq2j                                             3/3     Running     0          7h26m   10.6.0.79      computeinstance-e00s52tt1ma5gsb7zf   <none>           <none>
nfs-system                          csi-nfs-node-sq29f                                             3/3     Running     0          7h26m   10.6.0.3       computeinstance-e00dpf5e97eft6c4sg   <none>           <none>
nfs-system                          csi-nfs-node-wkbxg                                             3/3     Running     0          7h26m   10.6.38.15     computeinstance-e00gp55x6krjw7dmd6   <none>           <none>
nfs-system                          nfs-server-0                                                   2/2     Running     0          7h26m   10.6.95.94     computeinstance-e00dpf5e97eft6c4sg   <none>           <none>
security-profiles-operator-system   security-profiles-operator-bf6c8455c-d975r                     1/1     Running     0          7h26m   10.6.28.133    computeinstance-e00pmdsyqcadj9tp8g   <none>           <none>
security-profiles-operator-system   security-profiles-operator-bf6c8455c-trw29                     1/1     Running     0          7h26m   10.6.36.138    computeinstance-e00x7j626d1a3pm55f   <none>           <none>
security-profiles-operator-system   security-profiles-operator-webhook-56b6f8df7f-4klmj            1/1     Running     0          7h26m   10.6.55.70     computeinstance-e00hjf3m4dg1k2ebnj   <none>           <none>
security-profiles-operator-system   security-profiles-operator-webhook-56b6f8df7f-jnxp7            1/1     Running     0          7h26m   10.6.130.100   computeinstance-e00mv1d3sabb2nj8pe   <none>           <none>
security-profiles-operator-system   security-profiles-operator-webhook-56b6f8df7f-nwpw2            1/1     Running     0          7h26m   10.6.22.103    computeinstance-e00gp55x6krjw7dmd6   <none>           <none>
security-profiles-operator-system   spod-54xkz                                                     2/2     Running     0          7h26m   10.6.96.102    computeinstance-e00s52tt1ma5gsb7zf   <none>           <none>
security-profiles-operator-system   spod-5gg6f                                                     2/2     Running     0          7h26m   10.6.36.78     computeinstance-e00x7j626d1a3pm55f   <none>           <none>
security-profiles-operator-system   spod-5jr4k                                                     2/2     Running     0          7h26m   10.6.95.109    computeinstance-e00dpf5e97eft6c4sg   <none>           <none>
security-profiles-operator-system   spod-fxb82                                                     2/2     Running     0          7h26m   10.6.130.242   computeinstance-e00mv1d3sabb2nj8pe   <none>           <none>
security-profiles-operator-system   spod-jknst                                                     2/2     Running     0          7h26m   10.6.37.55     computeinstance-e00f0f6eqqzeg61nng   <none>           <none>
security-profiles-operator-system   spod-sg7fd                                                     2/2     Running     0          7h26m   10.6.55.206    computeinstance-e00hjf3m4dg1k2ebnj   <none>           <none>
security-profiles-operator-system   spod-srdp2                                                     2/2     Running     0          7h26m   10.6.28.154    computeinstance-e00pmdsyqcadj9tp8g   <none>           <none>
security-profiles-operator-system   spod-wfh54                                                     2/2     Running     0          7h26m   10.6.22.184    computeinstance-e00gp55x6krjw7dmd6   <none>           <none>
soperator-system                    soperator-checks-checks-b757c4cc9-jvkrc                        2/2     Running     0          7h24m   10.6.28.1      computeinstance-e00pmdsyqcadj9tp8g   <none>           <none>
soperator-system                    soperator-controller-manager-584b65dc7c-s9lmn                  2/2     Running     0          7h25m   10.6.36.193    computeinstance-e00x7j626d1a3pm55f   <none>           <none>
soperator-system                    soperator-node-configurator-ds-5p2h5                           1/1     Running     0          7h24m   10.6.0.47      computeinstance-e00hjf3m4dg1k2ebnj   <none>           <none>
soperator-system                    soperator-node-configurator-ds-6hj2x                           1/1     Running     0          7h24m   10.6.38.15     computeinstance-e00gp55x6krjw7dmd6   <none>           <none>
soperator-system                    soperator-node-configurator-ds-6tj7t                           1/1     Running     0          7h24m   10.6.0.0       computeinstance-e00mv1d3sabb2nj8pe   <none>           <none>
soperator-system                    soperator-node-configurator-ds-bd2dg                           1/1     Running     0          7h24m   10.6.0.3       computeinstance-e00dpf5e97eft6c4sg   <none>           <none>
soperator-system                    soperator-node-configurator-ds-c8gv8                           1/1     Running     0          7h24m   10.6.38.4      computeinstance-e00pmdsyqcadj9tp8g   <none>           <none>
soperator-system                    soperator-node-configurator-ds-hwk8q                           1/1     Running     0          7h24m   10.6.0.79      computeinstance-e00s52tt1ma5gsb7zf   <none>           <none>
soperator-system                    soperator-node-configurator-ds-wrj69                           1/1     Running     0          7h24m   10.6.38.3      computeinstance-e00x7j626d1a3pm55f   <none>           <none>
soperator-system                    soperator-node-configurator-ds-xdhkc                           1/1     Running     0          7h24m   10.6.0.108     computeinstance-e00f0f6eqqzeg61nng   <none>           <none>
soperator                           all-reduce-perf-nccl-with-ib-29863485-w7vf4                    0/2     Completed   0          3h19m   10.6.36.150    computeinstance-e00x7j626d1a3pm55f   <none>           <none>
soperator                           all-reduce-perf-nccl-without-ib-29863405-hv6f2                 0/2     Completed   0          4h39m   10.6.96.165    computeinstance-e00s52tt1ma5gsb7zf   <none>           <none>
soperator                           controller-0                                                   2/2     Running     0          7h15m   10.6.37.13     computeinstance-e00f0f6eqqzeg61nng   <none>           2/2
soperator                           controller-placeholder-jmrts                                   3/3     Running     0          7h15m   10.6.37.170    computeinstance-e00f0f6eqqzeg61nng   <none>           <none>
soperator                           controller-spool-mount-vj5hs                                   1/1     Running     0          7h24m   10.6.37.65     computeinstance-e00f0f6eqqzeg61nng   <none>           <none>
soperator                           create-user-nebius-initial-run-d8zjc                           0/1     Completed   0          7h12m   10.6.36.194    computeinstance-e00x7j626d1a3pm55f   <none>           <none>
soperator                           create-user-soperatorchecks-initial-run-hdcq5                  0/1     Completed   0          7h13m   10.6.36.232    computeinstance-e00x7j626d1a3pm55f   <none>           <none>
soperator                           cuda-samples-29863470-cgdcz                                    0/2     Completed   0          3h34m   10.6.36.152    computeinstance-e00x7j626d1a3pm55f   <none>           <none>
soperator                           ensure-dir-snccld-logs-initial-run-2vhds                       0/1     Completed   0          7h13m   10.6.36.137    computeinstance-e00x7j626d1a3pm55f   <none>           <none>
soperator                           ensure-healthy-nodes-initial-run-cfd58                         0/2     Completed   0          7h13m   10.6.96.135    computeinstance-e00s52tt1ma5gsb7zf   <none>           <none>
soperator                           gpu-fryer-29863275-sq44d                                       0/2     Completed   0          6h49m   10.6.96.31     computeinstance-e00s52tt1ma5gsb7zf   <none>           <none>
soperator                           helm-soperator-dcgm-exporter-ds-kvx8x                          1/1     Running     0          7h26m   10.6.22.60     computeinstance-e00gp55x6krjw7dmd6   <none>           <none>
soperator                           helm-soperator-dcgm-exporter-ds-nh6hp                          1/1     Running     0          7h26m   10.6.130.88    computeinstance-e00mv1d3sabb2nj8pe   <none>           <none>
soperator                           ib-gpu-perf-29863315-r9z7p                                     0/2     Completed   0          6h9m    10.6.96.185    computeinstance-e00s52tt1ma5gsb7zf   <none>           <none>
soperator                           ib-gpu-perf-29863555-v489w                                     0/2     Completed   0          129m    10.6.96.138    computeinstance-e00s52tt1ma5gsb7zf   <none>           <none>
soperator                           jail-mount-9kk9n                                               1/1     Running     0          7h24m   10.6.96.227    computeinstance-e00s52tt1ma5gsb7zf   <none>           <none>
soperator                           jail-mount-btlk5                                               1/1     Running     0          7h24m   10.6.22.136    computeinstance-e00gp55x6krjw7dmd6   <none>           <none>
soperator                           jail-mount-hlz6m                                               1/1     Running     0          7h24m   10.6.130.6     computeinstance-e00mv1d3sabb2nj8pe   <none>           <none>
soperator                           jail-mount-hncj5                                               1/1     Running     0          7h24m   10.6.37.94     computeinstance-e00f0f6eqqzeg61nng   <none>           <none>
soperator                           jail-mount-nr98r                                               1/1     Running     0          7h24m   10.6.28.85     computeinstance-e00pmdsyqcadj9tp8g   <none>           <none>
soperator                           jail-mount-shxqc                                               1/1     Running     0          7h24m   10.6.55.207    computeinstance-e00hjf3m4dg1k2ebnj   <none>           <none>
soperator                           jail-mount-xfqgz                                               1/1     Running     0          7h24m   10.6.36.73     computeinstance-e00x7j626d1a3pm55f   <none>           <none>
soperator                           jail-submount-data-mount-5shsv                                 1/1     Running     0          7h24m   10.6.130.251   computeinstance-e00mv1d3sabb2nj8pe   <none>           <none>
soperator                           jail-submount-data-mount-7d79k                                 1/1     Running     0          7h24m   10.6.36.133    computeinstance-e00x7j626d1a3pm55f   <none>           <none>
soperator                           jail-submount-data-mount-fs9gd                                 1/1     Running     0          7h24m   10.6.28.244    computeinstance-e00pmdsyqcadj9tp8g   <none>           <none>
soperator                           jail-submount-data-mount-ptn44                                 1/1     Running     0          7h24m   10.6.37.219    computeinstance-e00f0f6eqqzeg61nng   <none>           <none>
soperator                           jail-submount-data-mount-rx6cc                                 1/1     Running     0          7h24m   10.6.22.38     computeinstance-e00gp55x6krjw7dmd6   <none>           <none>
soperator                           jail-submount-data-mount-vhxrt                                 1/1     Running     0          7h24m   10.6.96.110    computeinstance-e00s52tt1ma5gsb7zf   <none>           <none>
soperator                           jail-submount-data-mount-w2d2k                                 1/1     Running     0          7h24m   10.6.55.139    computeinstance-e00hjf3m4dg1k2ebnj   <none>           <none>
soperator                           login-0                                                        2/2     Running     0          7h15m   10.6.28.71     computeinstance-e00pmdsyqcadj9tp8g   <none>           1/1
soperator                           manage-jail-state-dry-run-29863380-vhldg                       0/1     Completed   0          5h4m    10.6.36.246    computeinstance-e00x7j626d1a3pm55f   <none>           <none>
soperator                           mem-perf-29863340-gsvzt                                        0/2     Completed   0          5h44m   10.6.96.138    computeinstance-e00s52tt1ma5gsb7zf   <none>           <none>
soperator                           run-extensive-check-on-reservations-29863670-9cnk2             0/2     Completed   0          14m     10.6.36.177    computeinstance-e00x7j626d1a3pm55f   <none>           <none>
soperator                           run-extensive-check-on-reservations-29863675-dpj54             0/2     Completed   0          9m40s   10.6.36.131    computeinstance-e00x7j626d1a3pm55f   <none>           <none>
soperator                           run-extensive-check-on-reservations-29863680-7d45s             0/2     Completed   0          4m40s   10.6.36.70     computeinstance-e00x7j626d1a3pm55f   <none>           <none>
soperator                           sconfigcontroller-7b868fdf86-9952j                             1/1     Running     0          7h15m   10.6.96.241    computeinstance-e00s52tt1ma5gsb7zf   <none>           <none>
soperator                           sconfigcontroller-7b868fdf86-fk7pf                             1/1     Running     0          7h15m   10.6.28.110    computeinstance-e00pmdsyqcadj9tp8g   <none>           <none>
soperator                           slurm-exporter-6cf785fbd7-8nqgf                                1/1     Running     0          7h15m   10.6.96.214    computeinstance-e00s52tt1ma5gsb7zf   <none>           <none>
soperator                           soperator-outputs-logs-cleaner-29863540-gs8cf                  0/1     Completed   0          144m    10.6.36.36     computeinstance-e00x7j626d1a3pm55f   <none>           <none>
soperator                           soperator-outputs-logs-cleaner-29863600-6xjbv                  0/1     Completed   0          84m     10.6.36.240    computeinstance-e00x7j626d1a3pm55f   <none>           <none>
soperator                           soperator-outputs-logs-cleaner-29863660-6989p                  0/1     Completed   0          24m     10.6.36.126    computeinstance-e00x7j626d1a3pm55f   <none>           <none>
soperator                           soperator-populate-jail-nszw7                                  0/1     Completed   0          7h24m   10.6.36.2      computeinstance-e00x7j626d1a3pm55f   <none>           <none>
soperator                           ssh-check-initial-run-lc8cw                                    0/1     Completed   0          7h11m   10.6.36.31     computeinstance-e00x7j626d1a3pm55f   <none>           <none>
soperator                           wait-for-soperatorchecks-srun-ready-initial-run-d5p9n          0/2     Completed   0          7h12m   10.6.36.34     computeinstance-e00x7j626d1a3pm55f   <none>           <none>
soperator                           wait-for-topology-initial-run-lr7tr                            0/1     Completed   0          7h13m   10.6.36.176    computeinstance-e00x7j626d1a3pm55f   <none>           <none>
soperator                           worker-0                                                       2/2     Running     0          7h15m   10.6.130.62    computeinstance-e00mv1d3sabb2nj8pe   <none>           2/2
soperator                           worker-1                                                       2/2     Running     0          6h38m   10.6.22.178    computeinstance-e00gp55x6krjw7dmd6   <none>           2/2
```

---

> Separator

## Workloads: what kind of controller runs each thing.

```bash
kubectl get deploy,sts,ds -A

Warning: short name "sts" could also match lower priority resource statefulsets.apps.kruise.io
NAMESPACE                           NAME                                                          READY   UP-TO-DATE   AVAILABLE   AGE
cert-manager-system                 deployment.apps/cert-manager                                  1/1     1            1           7h28m
cert-manager-system                 deployment.apps/cert-manager-cainjector                       1/1     1            1           7h28m
cert-manager-system                 deployment.apps/cert-manager-webhook                          1/1     1            1           7h28m
flux-system                         deployment.apps/helm-controller                               1/1     1            1           7h29m
flux-system                         deployment.apps/image-automation-controller                   1/1     1            1           7h29m
flux-system                         deployment.apps/image-reflector-controller                    1/1     1            1           7h29m
flux-system                         deployment.apps/kustomize-controller                          1/1     1            1           7h29m
flux-system                         deployment.apps/notification-controller                       1/1     1            1           7h29m
flux-system                         deployment.apps/source-controller                             1/1     1            1           7h28m
kruise-system                       deployment.apps/kruise-controller-manager                     2/2     2            2           7h27m
kube-system                         deployment.apps/cilium-operator                               2/2     2            2           7h37m
kube-system                         deployment.apps/coredns                                       2/2     2            2           7h37m
kube-system                         deployment.apps/coredns-autoscaler                            2/2     2            2           7h37m
kube-system                         deployment.apps/hubble-relay                                  1/1     1            1           7h37m
kube-system                         deployment.apps/hubble-ui                                     1/1     1            1           7h37m
kube-system                         deployment.apps/metrics-server                                2/2     2            2           7h37m
logs-system                         deployment.apps/opentelemetry-collector-events                1/1     1            1           7h26m
logs-system                         deployment.apps/opentelemetry-collector-jail-logs             1/1     1            1           7h25m
monitoring-system                   deployment.apps/metrics-grafana                               1/1     1            1           7h27m
monitoring-system                   deployment.apps/metrics-kube-state-metrics                    1/1     1            1           7h27m
monitoring-system                   deployment.apps/metrics-victoria-metrics-operator             1/1     1            1           7h27m
monitoring-system                   deployment.apps/vmagent-metrics-victoria-metrics-k8s-stack    1/1     1            1           7h27m
monitoring-system                   deployment.apps/vmsingle-metrics-victoria-metrics-k8s-stack   1/1     1            1           7h26m
nfs-system                          deployment.apps/csi-nfs-controller                            1/1     1            1           7h28m
security-profiles-operator-system   deployment.apps/security-profiles-operator                    2/2     2            2           7h28m
security-profiles-operator-system   deployment.apps/security-profiles-operator-webhook            3/3     3            3           7h27m
soperator-system                    deployment.apps/soperator-checks-checks                       1/1     1            1           7h26m
soperator-system                    deployment.apps/soperator-controller-manager                  1/1     1            1           7h26m
soperator                           deployment.apps/sconfigcontroller                             2/2     2            2           7h17m
soperator                           deployment.apps/slurm-exporter                                1/1     1            1           7h17m

NAMESPACE                           NAME                                                          READY   AGE
logs-system                         statefulset.apps/vm-logs-victoria-logs-single-server          1/1     7h28m
nfs-system                          statefulset.apps/nfs-server                                   1/1     7h27m

NAMESPACE                           NAME                                                 DESIRED   CURRENT   READY   UP-TO-DATE   AVAILABLE   NODE SELECTOR                                  AGE
kruise-system                       daemonset.apps/kruise-daemon                         8         8         8       8            8           <none>                                         7h27m
kube-system                         daemonset.apps/cilium                                8         8         8       8            8           kubernetes.io/os=linux                         7h37m
kube-system                         daemonset.apps/cilium-envoy                          8         8         8       8            8           kubernetes.io/os=linux                         7h37m
kube-system                         daemonset.apps/compute-csi-node                      8         8         8       8            8           kubernetes.io/os=linux                         7h37m
kube-system                         daemonset.apps/container-runtime-monitor-installer   8         8         8       8            8           <none>                                         7h37m
kube-system                         daemonset.apps/dranet                                0         0         0       0            0           nebius.com/dranet-rdma-capable=true            7h37m
kube-system                         daemonset.apps/nebius-dcgm                           0         0         0       0            0           nvidia.com/gpu.deploy.container-toolkit=true   7h37m
kube-system                         daemonset.apps/nebius-node-problem-detector-cpu      6         6         6       6            6           <none>                                         7h37m
kube-system                         daemonset.apps/nebius-node-problem-detector-gpu      2         2         2       2            2           nebius.com/gpu=true                            7h37m
logs-system                         daemonset.apps/opentelemetry-collector-logs-agent    8         8         8       8            8           <none>                                         7h26m
monitoring-system                   daemonset.apps/metrics-prometheus-node-exporter      8         8         8       8            8           kubernetes.io/os=linux                         7h27m
nfs-system                          daemonset.apps/csi-nfs-node                          8         8         8       8            8           kubernetes.io/os=linux                         7h28m
security-profiles-operator-system   daemonset.apps/spod                                  8         8         8       8            8           kubernetes.io/os=linux                         7h27m
soperator-system                    daemonset.apps/soperator-node-configurator-ds        8         8         8       8            8           <none>                                         7h26m
soperator                           daemonset.apps/controller-placeholder                1         1         1       1            1           <none>                                         7h17m
soperator                           daemonset.apps/controller-spool-mount                1         1         1       1            1           <none>                                         7h26m
soperator                           daemonset.apps/helm-soperator-dcgm-exporter-ds       2         2         2       2            2           nebius.com/gpu=true                            7h28m
soperator                           daemonset.apps/jail-mount                            7         7         7       7            7           <none>                                         7h26m
soperator                           daemonset.apps/jail-submount-data-mount              7         7         7       7            7           <none>                                         7h26m
```

---

```bash
kubectl get jobs,cronjobs -A
NAMESPACE   NAME                                                        STATUS     COMPLETIONS   DURATION   AGE
soperator   job.batch/all-reduce-perf-nccl-with-ib-29863485             Complete   1/1           7s         3h24m
soperator   job.batch/all-reduce-perf-nccl-without-ib-29863405          Complete   1/1           6s         4h44m
soperator   job.batch/create-user-nebius-initial-run                    Complete   1/1           64s        7h16m
soperator   job.batch/create-user-soperatorchecks-initial-run           Complete   1/1           72s        7h18m
soperator   job.batch/cuda-samples-29863470                             Complete   1/1           7s         3h39m
soperator   job.batch/ensure-dir-snccld-logs-initial-run                Complete   1/1           72s        7h18m
soperator   job.batch/ensure-healthy-nodes-initial-run                  Complete   1/1           2m14s      7h18m
soperator   job.batch/gpu-fryer-29863275                                Complete   1/1           6s         6h54m
soperator   job.batch/ib-gpu-perf-29863315                              Complete   1/1           6s         6h14m
soperator   job.batch/ib-gpu-perf-29863555                              Complete   1/1           6s         134m
soperator   job.batch/manage-jail-state-dry-run-29863380                Complete   1/1           5m8s       5h9m
soperator   job.batch/mem-perf-29863340                                 Complete   1/1           6s         5h49m
soperator   job.batch/run-extensive-check-on-reservations-29863675      Complete   1/1           6s         14m
soperator   job.batch/run-extensive-check-on-reservations-29863680      Complete   1/1           6s         9m12s
soperator   job.batch/run-extensive-check-on-reservations-29863685      Complete   1/1           6s         4m12s
soperator   job.batch/soperator-outputs-logs-cleaner-29863540           Complete   1/1           3s         149m
soperator   job.batch/soperator-outputs-logs-cleaner-29863600           Complete   1/1           4s         89m
soperator   job.batch/soperator-outputs-logs-cleaner-29863660           Complete   1/1           3s         29m
soperator   job.batch/soperator-populate-jail                           Complete   1/1           8m53s      7h29m
soperator   job.batch/ssh-check-initial-run                             Complete   1/1           33s        7h16m
soperator   job.batch/wait-for-soperatorchecks-srun-ready-initial-run   Complete   1/1           64s        7h16m
soperator   job.batch/wait-for-topology-initial-run                     Complete   1/1           72s        7h18m

NAMESPACE   NAME                                                SCHEDULE            TIMEZONE   SUSPEND   ACTIVE   LAST SCHEDULE   AGE
soperator   cronjob.batch/all-reduce-perf-nccl-in-docker        0 0 1 1 *           <none>     True      0        <none>          7h15m
soperator   cronjob.batch/all-reduce-perf-nccl-with-ib          45 0-18/6 * * *     <none>     False     0        3h24m           7h15m
soperator   cronjob.batch/all-reduce-perf-nccl-without-ib       25 5-23/6 * * *     <none>     False     0        4h44m           7h15m
soperator   cronjob.batch/create-user-nebius                    0 0 1 1 *           <none>     True      0        <none>          7h16m
soperator   cronjob.batch/create-user-soperatorchecks           0 0 1 1 *           <none>     True      0        <none>          7h18m
soperator   cronjob.batch/cuda-samples                          30 0-18/6 * * *     <none>     False     0        3h39m           7h15m
soperator   cronjob.batch/dcgmi-diag-r2                         5 12 * * *          <none>     True      0        <none>          7h15m
soperator   cronjob.batch/dcgmi-diag-r3                         0 0 1 1 *           <none>     True      0        <none>          7h15m
soperator   cronjob.batch/enroot-cleanup                        10 8-20/12 * * *    <none>     False     0        <none>          7h15m
soperator   cronjob.batch/ensure-dir-snccld-logs                15 0 * * *          <none>     False     0        <none>          7h18m
soperator   cronjob.batch/ensure-healthy-nodes                  0 0 1 1 *           <none>     True      0        <none>          7h18m
soperator   cronjob.batch/extensive-check                       0 0 1 1 *           <none>     True      0        <none>          7h15m
soperator   cronjob.batch/gpu-fryer                             15 9-21/12 * * *    <none>     False     0        6h54m           7h15m
soperator   cronjob.batch/ib-gpu-perf                           55 1-21/4 * * *     <none>     False     0        134m            7h15m
soperator   cronjob.batch/manage-jail-state                     0 0 1 1 *           <none>     True      0        <none>          7h16m
soperator   cronjob.batch/manage-jail-state-dry-run             0 11 * * *          <none>     False     0        5h9m            7h16m
soperator   cronjob.batch/manage-jail-state-force               0 0 1 1 *           <none>     True      0        <none>          7h16m
soperator   cronjob.batch/mem-perf                              20 10-22/12 * * *   <none>     False     0        5h49m           7h15m
soperator   cronjob.batch/prepull-container-image               0 0 1 1 *           <none>     True      0        <none>          7h15m
soperator   cronjob.batch/retrigger-checks                      0 0 1 1 *           <none>     True      0        <none>          7h18m
soperator   cronjob.batch/run-extensive-check-on-reservations   */5 * * * *         <none>     False     0        4m13s           7h28m
soperator   cronjob.batch/soperator-outputs-logs-cleaner        40 */1 * * *        <none>     False     0        29m             7h18m
soperator   cronjob.batch/ssh-check                             0 0 1 1 *           <none>     True      0        <none>          7h16m
soperator   cronjob.batch/upgrade-health-checker                0 0 1 1 *           <none>     True      0        <none>          7h16m
soperator   cronjob.batch/wait-for-soperatorchecks-srun-ready   0 0 1 1 *           <none>     True      0        <none>          7h16m
soperator   cronjob.batch/wait-for-topology                     0 0 1 1 *           <none>     True      0        <none>          7h18m
```

---

> Separator

## Flux (GitOps layer): what installs everything, and in what order.

```bash
kubectl -n flux-system get pods

NAME                                           READY   STATUS    RESTARTS   AGE
helm-controller-b654b75f8-j7hrk                1/1     Running   0          7h33m
image-automation-controller-86497776cd-ztmxl   1/1     Running   0          7h33m
image-reflector-controller-684c57479b-7s4g2    1/1     Running   0          7h33m
kustomize-controller-6f87798dcc-jjsq6          1/1     Running   0          7h33m
notification-controller-6966dcb565-px6fc       1/1     Running   0          7h33m
source-controller-c7c5b47d6-v8m7r              1/1     Running   0          7h33m
```

```bash
kubectl api-resources | grep -i -E "fluxcd|toolkit"
NAME                                SHORTNAMES                          APIVERSION                                     NAMESPACED   KIND
helmreleases                        hr                                  helm.toolkit.fluxcd.io/v2                      true         HelmRelease
imagepolicies                       imgpol,imagepol                     image.toolkit.fluxcd.io/v1                     true         ImagePolicy
imagerepositories                   imgrepo,imagerepo                   image.toolkit.fluxcd.io/v1                     true         ImageRepository
imageupdateautomations              iua,imgupd,imgauto                  image.toolkit.fluxcd.io/v1                     true         ImageUpdateAutomation
kustomizations                      ks                                  kustomize.toolkit.fluxcd.io/v1                 true         Kustomization
alerts                                                                  notification.toolkit.fluxcd.io/v1beta3         true         Alert
providers                                                               notification.toolkit.fluxcd.io/v1beta3         true         Provider
receivers                                                               notification.toolkit.fluxcd.io/v1              true         Receiver
buckets                                                                 source.toolkit.fluxcd.io/v1                    true         Bucket
externalartifacts                                                       source.toolkit.fluxcd.io/v1                    true         ExternalArtifact
gitrepositories                     gitrepo                             source.toolkit.fluxcd.io/v1                    true         GitRepository
helmcharts                          hc                                  source.toolkit.fluxcd.io/v1                    true         HelmChart
helmrepositories                    helmrepo                            source.toolkit.fluxcd.io/v1                    true         HelmRepository
ocirepositories                     ocirepo                             source.toolkit.fluxcd.io/v1                    true         OCIRepository
```

```bash
kubectl get helmrepositories,gitrepositories,ocirepositories,helmcharts -A

NAMESPACE     NAME                                                                                              URL                                                                             AGE     READY   STATUS
flux-system   helmrepository.source.toolkit.fluxcd.io/flux-system-soperator-fluxcd-bedag                        https://bedag.github.io/helm-charts                                             7h34m   True    stored artifact: revision 'sha256:14cc37c191f8a1ef022212116e43ebf9bb7b8e6c4028303bcb56716f83edc68c'
flux-system   helmrepository.source.toolkit.fluxcd.io/flux-system-soperator-fluxcd-cert-manager                 https://charts.jetstack.io                                                      7h34m   True    stored artifact: revision 'sha256:8976420b58e5046cf910c362b67a039651c6ddc69c3cc0c1442646746d29ccd3'
flux-system   helmrepository.source.toolkit.fluxcd.io/flux-system-soperator-fluxcd-csi-driver-nfs               https://raw.githubusercontent.com/kubernetes-csi/csi-driver-nfs/master/charts   7h34m   True    stored artifact: revision 'sha256:bc4b1ded59d040edd11f8cd7883c63edfd197fa57cb184225d5d62717474c06e'
flux-system   helmrepository.source.toolkit.fluxcd.io/flux-system-soperator-fluxcd-kruise                       https://openkruise.github.io/charts/                                            7h34m   True    stored artifact: revision 'sha256:b867a270f9661bef70dd5997b746163ff4a9744d5f8b18704b1f09d17c06f88f'
flux-system   helmrepository.source.toolkit.fluxcd.io/flux-system-soperator-fluxcd-nfs-server                   oci://cr.nebius.cloud/soperator                                                 7h34m
flux-system   helmrepository.source.toolkit.fluxcd.io/flux-system-soperator-fluxcd-opentelemetry-collector      https://open-telemetry.github.io/opentelemetry-helm-charts                      7h34m   True    stored artifact: revision 'sha256:d6f8f5e1e2fb875fc642d09c26a9880a31f928e03e70afd7bf2788a1456e3d1e'
flux-system   helmrepository.source.toolkit.fluxcd.io/flux-system-soperator-fluxcd-prometheus-operator-crds     https://prometheus-community.github.io/helm-charts                              7h34m   True    stored artifact: revision 'sha256:f2b9ffbe660e25ea72a4cf4a11bc86e7c1f05fcd1868fb363eaa701074734ac2'
flux-system   helmrepository.source.toolkit.fluxcd.io/flux-system-soperator-fluxcd-security-profiles-operator   oci://cr.nebius.cloud/soperator                                                 7h34m
flux-system   helmrepository.source.toolkit.fluxcd.io/flux-system-soperator-fluxcd-soperator                    oci://cr.nebius.cloud/soperator                                                 7h34m
flux-system   helmrepository.source.toolkit.fluxcd.io/flux-system-soperator-fluxcd-victoriametrics              https://victoriametrics.github.io/helm-charts/                                  7h34m   True    stored artifact: revision 'sha256:1a84f8ced0a029301b0bcfde73f8ec3528a5be4efb26358703f7b1e35a9a99a4'
flux-system   helmrepository.source.toolkit.fluxcd.io/soperator-fluxcd                                          oci://cr.nebius.cloud/soperator                                                 7h34m

NAMESPACE     NAME                                                                                                            CHART                                  VERSION           SOURCE KIND      SOURCE NAME                                               AGE     READY   STATUS
flux-system   helmchart.source.toolkit.fluxcd.io/flux-system-flux-system-soperator-fluxcd-cert-manager                        cert-manager                           v1.19.*           HelmRepository   flux-system-soperator-fluxcd-cert-manager                 7h34m   True    pulled 'cert-manager' chart with version 'v1.19.6'
flux-system   helmchart.source.toolkit.fluxcd.io/flux-system-flux-system-soperator-fluxcd-csi-driver-nfs                      csi-driver-nfs                         4.11.0            HelmRepository   flux-system-soperator-fluxcd-csi-driver-nfs               7h34m   True    pulled 'csi-driver-nfs' chart with version '4.11.0'
flux-system   helmchart.source.toolkit.fluxcd.io/flux-system-flux-system-soperator-fluxcd-custom-configmaps                   helm-soperator-custom-configmaps       4.1.13            HelmRepository   flux-system-soperator-fluxcd-soperator                    7h34m   True    pulled 'helm-soperator-custom-configmaps' chart with version '4.1.13'
flux-system   helmchart.source.toolkit.fluxcd.io/flux-system-flux-system-soperator-fluxcd-dcgm-exporter                       helm-soperator-dcgm-exporter           4.1.13            HelmRepository   flux-system-soperator-fluxcd-soperator                    7h34m   True    pulled 'helm-soperator-dcgm-exporter' chart with version '4.1.13'
flux-system   helmchart.source.toolkit.fluxcd.io/flux-system-flux-system-soperator-fluxcd-kruise                              kruise                                 1.8.0             HelmRepository   flux-system-soperator-fluxcd-kruise                       7h34m   True    pulled 'kruise' chart with version '1.8.0'
flux-system   helmchart.source.toolkit.fluxcd.io/flux-system-flux-system-soperator-fluxcd-monitoring-dashboards               helm-soperator-monitoring-dashboards   4.1.13            HelmRepository   flux-system-soperator-fluxcd-soperator                    7h34m   True    pulled 'helm-soperator-monitoring-dashboards' chart with version '4.1.13'
flux-system   helmchart.source.toolkit.fluxcd.io/flux-system-flux-system-soperator-fluxcd-nfs-server                          helm-nfs-server                        1.2.2             HelmRepository   flux-system-soperator-fluxcd-nfs-server                   7h34m   True    pulled 'helm-nfs-server' chart with version '1.2.2'
flux-system   helmchart.source.toolkit.fluxcd.io/flux-system-flux-system-soperator-fluxcd-nodeconfigurator                    helm-nodeconfigurator                  4.1.13            HelmRepository   flux-system-soperator-fluxcd-soperator                    7h34m   True    pulled 'helm-nodeconfigurator' chart with version '4.1.13'
flux-system   helmchart.source.toolkit.fluxcd.io/flux-system-flux-system-soperator-fluxcd-nodesets                            helm-nodesets                          4.1.13            HelmRepository   flux-system-soperator-fluxcd-soperator                    7h34m   True    pulled 'helm-nodesets' chart with version '4.1.13'
flux-system   helmchart.source.toolkit.fluxcd.io/flux-system-flux-system-soperator-fluxcd-ns                                  raw                                    2.0.0             HelmRepository   flux-system-soperator-fluxcd-bedag                        7h34m   True    pulled 'raw' chart with version '2.0.0'
flux-system   helmchart.source.toolkit.fluxcd.io/flux-system-flux-system-soperator-fluxcd-opentelemetry-collector-events      opentelemetry-collector                0.149.*           HelmRepository   flux-system-soperator-fluxcd-opentelemetry-collector      7h34m   True    pulled 'opentelemetry-collector' chart with version '0.149.0'
flux-system   helmchart.source.toolkit.fluxcd.io/flux-system-flux-system-soperator-fluxcd-opentelemetry-collector-jail-logs   opentelemetry-collector                0.149.*           HelmRepository   flux-system-soperator-fluxcd-opentelemetry-collector      7h34m   True    pulled 'opentelemetry-collector' chart with version '0.149.0'
flux-system   helmchart.source.toolkit.fluxcd.io/flux-system-flux-system-soperator-fluxcd-opentelemetry-collector-logs        opentelemetry-collector                0.149.*           HelmRepository   flux-system-soperator-fluxcd-opentelemetry-collector      7h34m   True    pulled 'opentelemetry-collector' chart with version '0.149.0'
flux-system   helmchart.source.toolkit.fluxcd.io/flux-system-flux-system-soperator-fluxcd-prometheus-operator-crds            prometheus-operator-crds               19.1.*            HelmRepository   flux-system-soperator-fluxcd-prometheus-operator-crds     7h34m   True    pulled 'prometheus-operator-crds' chart with version '19.1.0'
flux-system   helmchart.source.toolkit.fluxcd.io/flux-system-flux-system-soperator-fluxcd-security-profiles-operator          security-profiles-operator             0.8.5-soperator   HelmRepository   flux-system-soperator-fluxcd-security-profiles-operator   7h34m   True    pulled 'security-profiles-operator' chart with version '0.8.5-soperator'
flux-system   helmchart.source.toolkit.fluxcd.io/flux-system-flux-system-soperator-fluxcd-slurm-cluster                       helm-slurm-cluster                     4.1.13            HelmRepository   flux-system-soperator-fluxcd-soperator                    7h34m   True    pulled 'helm-slurm-cluster' chart with version '4.1.13'
flux-system   helmchart.source.toolkit.fluxcd.io/flux-system-flux-system-soperator-fluxcd-slurm-cluster-storage               helm-slurm-cluster-storage             4.1.13            HelmRepository   flux-system-soperator-fluxcd-soperator                    7h34m   True    pulled 'helm-slurm-cluster-storage' chart with version '4.1.13'
flux-system   helmchart.source.toolkit.fluxcd.io/flux-system-flux-system-soperator-fluxcd-soperator                           helm-soperator                         4.1.13            HelmRepository   flux-system-soperator-fluxcd-soperator                    7h34m   True    pulled 'helm-soperator' chart with version '4.1.13'
flux-system   helmchart.source.toolkit.fluxcd.io/flux-system-flux-system-soperator-fluxcd-soperator-activechecks              helm-soperator-activechecks            4.1.13            HelmRepository   flux-system-soperator-fluxcd-soperator                    7h34m   True    pulled 'helm-soperator-activechecks' chart with version '4.1.13'
flux-system   helmchart.source.toolkit.fluxcd.io/flux-system-flux-system-soperator-fluxcd-soperatorchecks                     helm-soperatorchecks                   4.1.13            HelmRepository   flux-system-soperator-fluxcd-soperator                    7h34m   True    pulled 'helm-soperatorchecks' chart with version '4.1.13'
flux-system   helmchart.source.toolkit.fluxcd.io/flux-system-flux-system-soperator-fluxcd-storageclasses                      helm-storageclasses                    4.1.13            HelmRepository   flux-system-soperator-fluxcd-soperator                    7h34m   True    pulled 'helm-storageclasses' chart with version '4.1.13'
flux-system   helmchart.source.toolkit.fluxcd.io/flux-system-flux-system-soperator-fluxcd-victoria-metrics-operator-crds      victoria-metrics-operator-crds         0.0.3             HelmRepository   flux-system-soperator-fluxcd-victoriametrics              7h34m   True    pulled 'victoria-metrics-operator-crds' chart with version '0.0.3'
flux-system   helmchart.source.toolkit.fluxcd.io/flux-system-flux-system-soperator-fluxcd-vm-logs                             victoria-logs-single                   0.9.*             HelmRepository   flux-system-soperator-fluxcd-victoriametrics              7h34m   True    pulled 'victoria-logs-single' chart with version '0.9.8'
flux-system   helmchart.source.toolkit.fluxcd.io/flux-system-flux-system-soperator-fluxcd-vm-stack                            victoria-metrics-k8s-stack             0.39.*            HelmRepository   flux-system-soperator-fluxcd-victoriametrics              7h34m   True    pulled 'victoria-metrics-k8s-stack' chart with version '0.39.4'
flux-system   helmchart.source.toolkit.fluxcd.io/flux-system-soperator-fluxcd                                                 helm-soperator-fluxcd                  4.1.13            HelmRepository   soperator-fluxcd                                          7h34m   True    pulled 'helm-soperator-fluxcd' chart with version '4.1.13'
```

```bash
kubectl get helmreleases -A -o custom-columns='NS:.metadata.namespace,NAME:.metadata.name,CHART:.spec.chart.spec.chart,VERSION:.status.lastAppliedRevision,READY:.status.conditions[0].status,DEPENDS:.spec.dependsOn[*].name'

NS            NAME                                                             CHART                                  VERSION   READY   DEPENDS
flux-system   flux-system-soperator-fluxcd-cert-manager                        cert-manager                           <none>    True    flux-system-soperator-fluxcd-ns,flux-system-soperator-fluxcd-prometheus-operator-crds
flux-system   flux-system-soperator-fluxcd-csi-driver-nfs                      csi-driver-nfs                         <none>    True    flux-system-soperator-fluxcd-ns
flux-system   flux-system-soperator-fluxcd-custom-configmaps                   helm-soperator-custom-configmaps       <none>    True    flux-system-soperator-fluxcd-ns
flux-system   flux-system-soperator-fluxcd-dcgm-exporter                       helm-soperator-dcgm-exporter           <none>    True    <none>
flux-system   flux-system-soperator-fluxcd-kruise                              kruise                                 <none>    True    flux-system-soperator-fluxcd-ns,flux-system-soperator-fluxcd-cert-manager
flux-system   flux-system-soperator-fluxcd-monitoring-dashboards               helm-soperator-monitoring-dashboards   <none>    True    flux-system-soperator-fluxcd-ns
flux-system   flux-system-soperator-fluxcd-nfs-server                          helm-nfs-server                        <none>    True    flux-system-soperator-fluxcd-ns,flux-system-soperator-fluxcd-csi-driver-nfs
flux-system   flux-system-soperator-fluxcd-nodeconfigurator                    helm-nodeconfigurator                  <none>    True    flux-system-soperator-fluxcd-soperator
flux-system   flux-system-soperator-fluxcd-nodesets                            helm-nodesets                          <none>    True    flux-system-soperator-fluxcd-ns,flux-system-soperator-fluxcd-soperator,flux-system-soperator-fluxcd-slurm-cluster
flux-system   flux-system-soperator-fluxcd-ns                                  raw                                    <none>    True    <none>
flux-system   flux-system-soperator-fluxcd-opentelemetry-collector-events      opentelemetry-collector                <none>    True    flux-system-soperator-fluxcd-ns,flux-system-soperator-fluxcd-vm-logs
flux-system   flux-system-soperator-fluxcd-opentelemetry-collector-jail-logs   opentelemetry-collector                <none>    True    flux-system-soperator-fluxcd-ns,flux-system-soperator-fluxcd-vm-logs,flux-system-soperator-fluxcd-nodesets
flux-system   flux-system-soperator-fluxcd-opentelemetry-collector-logs        opentelemetry-collector                <none>    True    flux-system-soperator-fluxcd-ns,flux-system-soperator-fluxcd-vm-logs
flux-system   flux-system-soperator-fluxcd-prometheus-operator-crds            prometheus-operator-crds               <none>    True    <none>
flux-system   flux-system-soperator-fluxcd-security-profiles-operator          security-profiles-operator             <none>    True    flux-system-soperator-fluxcd-ns
flux-system   flux-system-soperator-fluxcd-slurm-cluster                       helm-slurm-cluster                     <none>    True    flux-system-soperator-fluxcd-ns,flux-system-soperator-fluxcd-soperator,flux-system-soperator-fluxcd-slurm-cluster-storage,flux-system-soperator-fluxcd-security-profiles-operator,flux-system-soperator-fluxcd-nfs-server
flux-system   flux-system-soperator-fluxcd-slurm-cluster-storage               helm-slurm-cluster-storage             <none>    True    flux-system-soperator-fluxcd-ns,flux-system-soperator-fluxcd-storageclasses,flux-system-soperator-fluxcd-soperator
flux-system   flux-system-soperator-fluxcd-soperator                           helm-soperator                         <none>    True    flux-system-soperator-fluxcd-ns,flux-system-soperator-fluxcd-kruise,flux-system-soperator-fluxcd-cert-manager
flux-system   flux-system-soperator-fluxcd-soperator-activechecks              helm-soperator-activechecks            <none>    True    flux-system-soperator-fluxcd-slurm-cluster,flux-system-soperator-fluxcd-soperatorchecks
flux-system   flux-system-soperator-fluxcd-soperatorchecks                     helm-soperatorchecks                   <none>    True    flux-system-soperator-fluxcd-soperator
flux-system   flux-system-soperator-fluxcd-storageclasses                      helm-storageclasses                    <none>    True    flux-system-soperator-fluxcd-ns
flux-system   flux-system-soperator-fluxcd-victoria-metrics-operator-crds      victoria-metrics-operator-crds         <none>    True    <none>
flux-system   flux-system-soperator-fluxcd-vm-logs                             victoria-logs-single                   <none>    True    <none>
flux-system   flux-system-soperator-fluxcd-vm-stack                            victoria-metrics-k8s-stack             <none>    True    flux-system-soperator-fluxcd-ns,flux-system-soperator-fluxcd-cert-manager,flux-system-soperator-fluxcd-victoria-metrics-operator-crds
flux-system   soperator-fluxcd                                                 helm-soperator-fluxcd                  <none>    True    <none>
```

```bash
helm list -A

NAME                                                 	NAMESPACE                        	REVISION	UPDATED                                	STATUS  	CHART                                      	APP VERSION
ca-provisioning-request                              	kube-system                      	1       	2026-10-12 08:28:40.780493952 +0000 UTC	deployed	ca-provisioning-request-0.1.0              	0.1.0
cert-manager                                         	cert-manager-system              	1       	2026-10-12 08:38:01.348426247 +0000 UTC	deployed	cert-manager-v1.19.6                       	v1.19.6
cilium                                               	kube-system                      	1       	2026-10-12 08:28:40.732246313 +0000 UTC	deployed	cilium-1.19.6                              	1.19.6
compute-csi-driver                                   	kube-system                      	1       	2026-10-12 08:28:40.757210656 +0000 UTC	deployed	compute-csi-driver-0.1.35                  	0.1.35
container-runtime-monitor                            	kube-system                      	1       	2026-10-12 08:28:40.785316568 +0000 UTC	deployed	container-runtime-monitor-0.0.9            	0.0.9
coredns                                              	kube-system                      	1       	2026-10-12 08:28:40.718106264 +0000 UTC	deployed	coredns-1.31.0-nebius.1                    	1.11.1
csi-driver-nfs                                       	nfs-system                       	1       	2026-10-12 08:38:01.435327535 +0000 UTC	deployed	csi-driver-nfs-4.11.0                      	4.11.0
dranet                                               	kube-system                      	1       	2026-10-12 08:28:40.617928584 +0000 UTC	deployed	dranet-1.4.0                               	v1.4.0
flux-system-soperator-fluxcd                         	flux-system                      	1       	2026-10-12 08:37:29.994064549 +0000 UTC	deployed	helm-soperator-fluxcd-4.1.13               	4.1.13
flux-system-soperator-fluxcd-ns                      	flux-system                      	1       	2026-10-12 08:37:34.498803027 +0000 UTC	deployed	raw-2.0.0                                  	1.0.0
flux-system-soperator-fluxcd-prometheus-operator-crds	flux-system                      	1       	2026-10-12 08:37:37.738983746 +0000 UTC	deployed	prometheus-operator-crds-19.1.0            	v0.81.0
flux-system-soperator-fluxcd-victoria-me-6b4d61dd349d	flux-system                      	1       	2026-10-12 08:37:33.65423049 +0000 UTC 	deployed	victoria-metrics-operator-crds-0.0.3       	v0.55.0
metrics                                              	monitoring-system                	1       	2026-10-12 08:38:31.687758205 +0000 UTC	deployed	victoria-metrics-k8s-stack-0.39.4          	v1.114.0
metrics-server                                       	kube-system                      	1       	2026-10-12 08:28:40.750333906 +0000 UTC	deployed	metrics-server-3.12.1                      	0.7.1
nebius-dcgm                                          	kube-system                      	1       	2026-10-12 08:28:40.709716863 +0000 UTC	deployed	nebius-dcgm-0.1.7                          	0.1.0
nebius-dranet-deviceclass                            	kube-system                      	1       	2026-10-12 08:28:40.783874294 +0000 UTC	deployed	nebius-dranet-deviceclass-0.1.2            	0.1.2
nebius-node-problem-detector                         	kube-system                      	1       	2026-10-12 08:28:40.618899601 +0000 UTC	deployed	nebius-node-problem-detector-1.0.21        	1.0.21
nebius-roles                                         	kube-system                      	1       	2026-10-12 08:28:40.723740484 +0000 UTC	deployed	nebius-roles-0.2.1                         	0.2.1
nfs-server                                           	nfs-system                       	1       	2026-10-12 08:38:12.596535947 +0000 UTC	deployed	helm-nfs-server-1.2.2                      	1.2.2
opentelemetry-collector-events                       	logs-system                      	1       	2026-10-12 08:39:14.629984656 +0000 UTC	deployed	opentelemetry-collector-0.149.0            	0.149.0
opentelemetry-collector-jail-logs                    	logs-system                      	1       	2026-10-12 08:40:25.28165106 +0000 UTC 	deployed	opentelemetry-collector-0.149.0            	0.149.0
opentelemetry-collector-logs                         	logs-system                      	1       	2026-10-12 08:39:10.312910832 +0000 UTC	deployed	opentelemetry-collector-0.149.0            	0.149.0
security-profiles-operator                           	security-profiles-operator-system	1       	2026-10-12 08:38:02.266891024 +0000 UTC	deployed	security-profiles-operator-0.8.5-soperator 	0.8.4
slurm-cluster-storage                                	soperator                        	1       	2026-10-12 08:39:44.590334066 +0000 UTC	deployed	helm-slurm-cluster-storage-4.1.13          	4.1.13
soperator                                            	soperator                        	1       	2026-10-12 08:39:55.178475775 +0000 UTC	deployed	helm-slurm-cluster-4.1.13                  	4.1.13
soperator-activechecks                               	soperator                        	1       	2026-10-12 08:40:14.634651813 +0000 UTC	deployed	helm-soperator-activechecks-4.1.13         	4.1.13
soperator-checks                                     	soperator-system                 	1       	2026-10-12 08:39:55.07609654 +0000 UTC 	deployed	helm-soperatorchecks-4.1.13                	4.1.13
soperator-controller                                 	soperator-system                 	1       	2026-10-12 08:39:19.491627051 +0000 UTC	deployed	helm-soperator-4.1.13                      	4.1.13
soperator-custom-configmaps                          	soperator                        	1       	2026-10-12 08:38:10.549222177 +0000 UTC	deployed	helm-soperator-custom-configmaps-4.1.13    	4.1.13
soperator-dcgm-exporter                              	soperator                        	1       	2026-10-12 08:37:44.449715307 +0000 UTC	deployed	helm-soperator-dcgm-exporter-4.1.13        	4.1.13
soperator-fluxcd-bootstrap                           	flux-system                      	1       	2026-10-12 12:37:25.432918 +0400 +04   	deployed	helm-soperator-fluxcd-bootstrap-4.1.13     	4.1.13
soperator-fluxcd-values                              	flux-system                      	1       	2026-10-12 12:37:19.55514 +0400 +04    	deployed	raw-2.0.0                                  	1.0.0
soperator-kruise                                     	soperator                        	1       	2026-10-12 08:38:44.653833021 +0000 UTC	deployed	kruise-1.8.0                               	1.8.0
soperator-monitoring-dashboards                      	monitoring-system                	1       	2026-10-12 08:38:10.296177226 +0000 UTC	deployed	helm-soperator-monitoring-dashboards-4.1.13	4.1.13
soperator-node-configurator                          	soperator-system                 	1       	2026-10-12 08:39:44.587896452 +0000 UTC	deployed	helm-nodeconfigurator-4.1.13               	4.1.13
soperator-nodesets                                   	soperator                        	1       	2026-10-12 08:40:12.389075056 +0000 UTC	deployed	helm-nodesets-4.1.13                       	4.1.13
soperator-storageclasses                             	storage-system                   	1       	2026-10-12 08:37:36.690890956 +0000 UTC	deployed	helm-storageclasses-4.1.13                 	4.1.13
terraform-fluxcd-values                              	flux-system                      	1       	2026-10-12 12:37:19.395326 +0400 +04   	deployed	raw-2.0.0                                  	1.0.0
vm-logs                                              	logs-system                      	1       	2026-10-12 08:37:40.185497363 +0000 UTC	deployed	victoria-logs-single-0.9.8                 	v1.21.0
```

```bash
kubectl get helmreleases -A -o json | jq -r '.items[] | .metadata.name + "  <-  " + ((.spec.dependsOn // []) | map(.name) | join(", "))'
flux-system-soperator-fluxcd-cert-manager  <-  flux-system-soperator-fluxcd-ns, flux-system-soperator-fluxcd-prometheus-operator-crds
flux-system-soperator-fluxcd-csi-driver-nfs  <-  flux-system-soperator-fluxcd-ns
flux-system-soperator-fluxcd-custom-configmaps  <-  flux-system-soperator-fluxcd-ns
flux-system-soperator-fluxcd-dcgm-exporter  <-
flux-system-soperator-fluxcd-kruise  <-  flux-system-soperator-fluxcd-ns, flux-system-soperator-fluxcd-cert-manager
flux-system-soperator-fluxcd-monitoring-dashboards  <-  flux-system-soperator-fluxcd-ns
flux-system-soperator-fluxcd-nfs-server  <-  flux-system-soperator-fluxcd-ns, flux-system-soperator-fluxcd-csi-driver-nfs
flux-system-soperator-fluxcd-nodeconfigurator  <-  flux-system-soperator-fluxcd-soperator
flux-system-soperator-fluxcd-nodesets  <-  flux-system-soperator-fluxcd-ns, flux-system-soperator-fluxcd-soperator, flux-system-soperator-fluxcd-slurm-cluster
flux-system-soperator-fluxcd-ns  <-
flux-system-soperator-fluxcd-opentelemetry-collector-events  <-  flux-system-soperator-fluxcd-ns, flux-system-soperator-fluxcd-vm-logs
flux-system-soperator-fluxcd-opentelemetry-collector-jail-logs  <-  flux-system-soperator-fluxcd-ns, flux-system-soperator-fluxcd-vm-logs, flux-system-soperator-fluxcd-nodesets
flux-system-soperator-fluxcd-opentelemetry-collector-logs  <-  flux-system-soperator-fluxcd-ns, flux-system-soperator-fluxcd-vm-logs
flux-system-soperator-fluxcd-prometheus-operator-crds  <-
flux-system-soperator-fluxcd-security-profiles-operator  <-  flux-system-soperator-fluxcd-ns
flux-system-soperator-fluxcd-slurm-cluster  <-  flux-system-soperator-fluxcd-ns, flux-system-soperator-fluxcd-soperator, flux-system-soperator-fluxcd-slurm-cluster-storage, flux-system-soperator-fluxcd-security-profiles-operator, flux-system-soperator-fluxcd-nfs-server
flux-system-soperator-fluxcd-slurm-cluster-storage  <-  flux-system-soperator-fluxcd-ns, flux-system-soperator-fluxcd-storageclasses, flux-system-soperator-fluxcd-soperator
flux-system-soperator-fluxcd-soperator  <-  flux-system-soperator-fluxcd-ns, flux-system-soperator-fluxcd-kruise, flux-system-soperator-fluxcd-cert-manager
flux-system-soperator-fluxcd-soperator-activechecks  <-  flux-system-soperator-fluxcd-slurm-cluster, flux-system-soperator-fluxcd-soperatorchecks
flux-system-soperator-fluxcd-soperatorchecks  <-  flux-system-soperator-fluxcd-soperator
flux-system-soperator-fluxcd-storageclasses  <-  flux-system-soperator-fluxcd-ns
flux-system-soperator-fluxcd-victoria-metrics-operator-crds  <-
flux-system-soperator-fluxcd-vm-logs  <-
flux-system-soperator-fluxcd-vm-stack  <-  flux-system-soperator-fluxcd-ns, flux-system-soperator-fluxcd-cert-manager, flux-system-soperator-fluxcd-victoria-metrics-operator-crds
soperator-fluxcd  <-
```

```bash
kubectl get helmreleases -A                                                                                                                                                                                                     ─╯
NAMESPACE     NAME                                                             AGE     READY   STATUS
flux-system   flux-system-soperator-fluxcd-cert-manager                        7h38m   True    Helm install succeeded for release cert-manager-system/cert-manager.v1 with chart cert-manager@v1.19.6
flux-system   flux-system-soperator-fluxcd-csi-driver-nfs                      7h38m   True    Helm install succeeded for release nfs-system/csi-driver-nfs.v1 with chart csi-driver-nfs@4.11.0
flux-system   flux-system-soperator-fluxcd-custom-configmaps                   7h38m   True    Helm install succeeded for release soperator/soperator-custom-configmaps.v1 with chart helm-soperator-custom-configmaps@4.1.13
flux-system   flux-system-soperator-fluxcd-dcgm-exporter                       7h38m   True    Helm install succeeded for release soperator/soperator-dcgm-exporter.v1 with chart helm-soperator-dcgm-exporter@4.1.13
flux-system   flux-system-soperator-fluxcd-kruise                              7h38m   True    Helm install succeeded for release soperator/soperator-kruise.v1 with chart kruise@1.8.0
flux-system   flux-system-soperator-fluxcd-monitoring-dashboards               7h38m   True    Helm install succeeded for release monitoring-system/soperator-monitoring-dashboards.v1 with chart helm-soperator-monitoring-dashboards@4.1.13
flux-system   flux-system-soperator-fluxcd-nfs-server                          7h38m   True    Helm install succeeded for release nfs-system/nfs-server.v1 with chart helm-nfs-server@1.2.2
flux-system   flux-system-soperator-fluxcd-nodeconfigurator                    7h38m   True    Helm install succeeded for release soperator-system/soperator-node-configurator.v1 with chart helm-nodeconfigurator@4.1.13
flux-system   flux-system-soperator-fluxcd-nodesets                            7h38m   True    Helm install succeeded for release soperator/soperator-nodesets.v1 with chart helm-nodesets@4.1.13
flux-system   flux-system-soperator-fluxcd-ns                                  7h38m   True    Helm install succeeded for release flux-system/flux-system-soperator-fluxcd-ns.v1 with chart raw@2.0.0
flux-system   flux-system-soperator-fluxcd-opentelemetry-collector-events      7h38m   True    Helm install succeeded for release logs-system/opentelemetry-collector-events.v1 with chart opentelemetry-collector@0.149.0
flux-system   flux-system-soperator-fluxcd-opentelemetry-collector-jail-logs   7h38m   True    Helm install succeeded for release logs-system/opentelemetry-collector-jail-logs.v1 with chart opentelemetry-collector@0.149.0
flux-system   flux-system-soperator-fluxcd-opentelemetry-collector-logs        7h38m   True    Helm install succeeded for release logs-system/opentelemetry-collector-logs.v1 with chart opentelemetry-collector@0.149.0
flux-system   flux-system-soperator-fluxcd-prometheus-operator-crds            7h38m   True    Helm install succeeded for release flux-system/flux-system-soperator-fluxcd-prometheus-operator-crds.v1 with chart prometheus-operator-crds@19.1.0
flux-system   flux-system-soperator-fluxcd-security-profiles-operator          7h38m   True    Helm install succeeded for release security-profiles-operator-system/security-profiles-operator.v1 with chart security-profiles-operator@0.8.5-soperator
flux-system   flux-system-soperator-fluxcd-slurm-cluster                       7h38m   True    Helm install succeeded for release soperator/soperator.v1 with chart helm-slurm-cluster@4.1.13
flux-system   flux-system-soperator-fluxcd-slurm-cluster-storage               7h38m   True    Helm install succeeded for release soperator/slurm-cluster-storage.v1 with chart helm-slurm-cluster-storage@4.1.13
flux-system   flux-system-soperator-fluxcd-soperator                           7h38m   True    Helm install succeeded for release soperator-system/soperator-controller.v1 with chart helm-soperator@4.1.13
flux-system   flux-system-soperator-fluxcd-soperator-activechecks              7h38m   True    Helm install succeeded for release soperator/soperator-activechecks.v1 with chart helm-soperator-activechecks@4.1.13
flux-system   flux-system-soperator-fluxcd-soperatorchecks                     7h38m   True    Helm install succeeded for release soperator-system/soperator-checks.v1 with chart helm-soperatorchecks@4.1.13
flux-system   flux-system-soperator-fluxcd-storageclasses                      7h38m   True    Helm install succeeded for release storage-system/soperator-storageclasses.v1 with chart helm-storageclasses@4.1.13
flux-system   flux-system-soperator-fluxcd-victoria-metrics-operator-crds      7h38m   True    Helm install succeeded for release flux-system/flux-system-soperator-fluxcd-victoria-me-6b4d61dd349d.v1 with chart victoria-metrics-operator-crds@0.0.3
flux-system   flux-system-soperator-fluxcd-vm-logs                             7h38m   True    Helm install succeeded for release logs-system/vm-logs.v1 with chart victoria-logs-single@0.9.8
flux-system   flux-system-soperator-fluxcd-vm-stack                            7h38m   True    Helm install succeeded for release monitoring-system/metrics.v1 with chart victoria-metrics-k8s-stack@0.39.4
flux-system   soperator-fluxcd                                                 7h38m   True    Helm install succeeded for release flux-system/flux-system-soperator-fluxcd.v1 with chart helm-soperator-fluxcd@4.1.13
```

---

> Separator

## One Helm release in detail: what Terraform passes to Flux (review before pasting).

```bash
kubectl -n flux-system get helmrelease flux-system-soperator-fluxcd-nodesets -o yaml | head -150

apiVersion: helm.toolkit.fluxcd.io/v2
kind: HelmRelease
metadata:
  annotations:
    meta.helm.sh/release-name: flux-system-soperator-fluxcd
    meta.helm.sh/release-namespace: flux-system
  creationTimestamp: "2026-10-12T08:37:30Z"
  finalizers:
  - finalizers.fluxcd.io
  generation: 1
  labels:
    app.kubernetes.io/instance: flux-system-soperator-fluxcd
    app.kubernetes.io/managed-by: Helm
    app.kubernetes.io/name: helm-soperator-fluxcd
    app.kubernetes.io/version: 4.1.13
    helm.sh/chart: helm-soperator-fluxcd-4.1.13
    helm.toolkit.fluxcd.io/name: soperator-fluxcd
    helm.toolkit.fluxcd.io/namespace: flux-system
  name: flux-system-soperator-fluxcd-nodesets
  namespace: flux-system
  resourceVersion: "311433"
  uid: acf4b447-3432-4da3-8986-17b5ccd1693a
spec:
  chart:
    spec:
      chart: helm-nodesets
      interval: 5m
      reconcileStrategy: ChartVersion
      sourceRef:
        kind: HelmRepository
        name: flux-system-soperator-fluxcd-soperator
      version: 4.1.13
  dependsOn:
  - name: flux-system-soperator-fluxcd-ns
  - name: flux-system-soperator-fluxcd-soperator
  - name: flux-system-soperator-fluxcd-slurm-cluster
  driftDetection:
    mode: warn
  install:
    crds: Skip
    remediation:
      retries: 3
  interval: 5m
  releaseName: soperator-nodesets
  targetNamespace: soperator
  timeout: 5m
  upgrade:
    crds: Skip
    remediation:
      remediateLastFailure: true
      retries: 3
  values:
    nodesets:
    - annotations:
        slurm.nebius.ai/parental-cluster-ref: soperator
      configMapRefSshd: null
      configMapRefSupervisord: custom-supervisord-config
      customInitContainers:
      - command:
        - grep
        - ' /volume-mount virtiofs '
        - /proc/mounts
        image: cr.nebius.cloud/soperator/busybox
        name: ensure-jail-virtiofs
        volumeMounts:
        - mountPath: /volume-mount
          name: jail
      - command:
        - grep
        - ' /volume-mount virtiofs '
        - /proc/mounts
        image: cr.nebius.cloud/soperator/busybox
        name: ensure-jail-submount-data-virtiofs
        volumeMounts:
        - mountPath: /volume-mount
          name: data
      enableHostUserNamespace: true
      gpu:
        enabled: true
        nvidia:
          gdrCopyEnabled: true
      maxUnavailable: 20%
      munge:
        resources:
          cpu: 100m
          ephemeralStorage: 5Gi
          memory: 0.5Gi
        security:
          appArmorProfile: unconfined
      name: worker
      nodeConfig:
        dynamic: '"{ \"ib_pod\": \"$TOPO_SWITCH_TIER2\", \"ib_su\": \"$TOPO_SWITCH_TIER1\"
          }"'
        features:
        - gpu_h100_sxm
        - network_ssd
        gresConfig:
        - AutoDetect=off Name=gpu Type=nvidia_h100_80gb_hbm3 File=/dev/nvidia0 Cores=0-15
          Links=-1 Flags=nvidia_gpu_env
        static: CPUs=16 Boards=1 SocketsPerBoard=1 CoresPerSocket=8 ThreadsPerCore=2
          Gres=gpu:nvidia_h100_80gb_hbm3:1
      nodeSelector:
        slurm.nebius.ai/nodeset-name: worker
      priorityClass: soperator-worker-high-priority
      replicas: 2
      slurmd:
        customEnv:
        - name: NVIDIA_DRIVER_CAPABILITIES
          value: compute,graphics,utility,video
        resources:
          cpu: 13950m
          ephemeralStorage: 382Gi
          gpu: 1
          memory: 176Gi
        security:
          appArmorProfile: unconfined
        volumes:
          customVolumeMounts:
          - mountPath: /opt/slurm_scripts/
            name: slurm-scripts
            volumeSource:
              configMap:
                defaultMode: 493
                name: slurm-scripts
          - mountPath: /mnt/jail.upper/opt/slurm_scripts/
            name: slurm-scripts-jail
            volumeSource:
              configMap:
                defaultMode: 493
                name: slurm-scripts
          - mountPath: /mnt/jail.upper/sys-host
            name: sys-host
            readOnly: true
            volumeSource:
              hostPath:
                path: /sys
                type: Directory
          - mountPath: /var/run/nebius/slurm
            name: hpc-jobs-dir
            volumeSource:
              hostPath:
                path: /var/run/nebius/slurm
                type: DirectoryOrCreate
          - mountPath: /run/nvidia/driver
            name: nvidia-driver-root
            readOnly: false
            volumeSource:
              hostPath:
                path: /
                type: ""
```

```bash
kubectl -n flux-system get helmrelease flux-system-soperator-fluxcd-soperator -o yaml | head -150
apiVersion: helm.toolkit.fluxcd.io/v2
kind: HelmRelease
metadata:
  annotations:
    meta.helm.sh/release-name: flux-system-soperator-fluxcd
    meta.helm.sh/release-namespace: flux-system
  creationTimestamp: "2026-10-12T08:37:30Z"
  finalizers:
  - finalizers.fluxcd.io
  generation: 1
  labels:
    app.kubernetes.io/instance: flux-system-soperator-fluxcd
    app.kubernetes.io/managed-by: Helm
    app.kubernetes.io/name: helm-soperator-fluxcd
    app.kubernetes.io/version: 4.1.13
    helm.sh/chart: helm-soperator-fluxcd-4.1.13
    helm.toolkit.fluxcd.io/name: soperator-fluxcd
    helm.toolkit.fluxcd.io/namespace: flux-system
  name: flux-system-soperator-fluxcd-soperator
  namespace: flux-system
  resourceVersion: "311893"
  uid: 53987928-299e-4a2c-b78b-2d318e048567
spec:
  chart:
    spec:
      chart: helm-soperator
      interval: 5m
      reconcileStrategy: ChartVersion
      sourceRef:
        kind: HelmRepository
        name: flux-system-soperator-fluxcd-soperator
      version: 4.1.13
  dependsOn:
  - name: flux-system-soperator-fluxcd-ns
  - name: flux-system-soperator-fluxcd-kruise
  - name: flux-system-soperator-fluxcd-cert-manager
  driftDetection:
    mode: warn
  install:
    crds: CreateReplace
    remediation:
      retries: 3
  interval: 5m
  releaseName: soperator-controller
  targetNamespace: soperator-system
  timeout: 5m
  upgrade:
    crds: CreateReplace
    remediation:
      remediateLastFailure: true
      retries: 3
  values:
    certManager:
      enabled: true
    controllerManager:
      kruise:
        installOperator: false
      kubeRbacProxy:
        image:
          repository: registry.k8s.io/kubebuilder/kube-rbac-proxy
          tag: v0.15.0
      manager:
        env:
          isApparmorCrdInstalled: true
          isPrometheusCrdInstalled: true
        resources:
          limits:
            memory: 2Gi
          requests:
            cpu: 1000m
            memory: 2Gi
    serviceMonitor:
      enabled: true
  valuesFrom:
  - kind: ConfigMap
    name: terraform-soperator
    optional: true
    valuesKey: values.yaml
  - kind: ConfigMap
    name: soperator
    optional: true
    valuesKey: values.yaml
status:
  conditions:
  - lastTransitionTime: "2026-10-12T08:39:38Z"
    message: Helm install succeeded for release soperator-system/soperator-controller.v1
      with chart helm-soperator@4.1.13
    observedGeneration: 1
    reason: InstallSucceeded
    status: "True"
    type: Ready
  - lastTransitionTime: "2026-10-12T08:39:38Z"
    message: Helm install succeeded for release soperator-system/soperator-controller.v1
      with chart helm-soperator@4.1.13
    observedGeneration: 1
    reason: InstallSucceeded
    status: "True"
    type: Released
  helmChart: flux-system/flux-system-flux-system-soperator-fluxcd-soperator
  history:
  - appVersion: 4.1.13
    chartName: helm-soperator
    chartVersion: 4.1.13
    configDigest: sha256:5332e63912903eae14dd84e343b8befff5aa547de645ac6825ca5033a9d2b78d
    digest: sha256:49a8ee6af6dc99e3e9ca4b63cea2721a30be4874ca2d1dde2bd9174eb962025c
    firstDeployed: "2026-10-12T08:39:19Z"
    lastDeployed: "2026-10-12T08:39:19Z"
    name: soperator-controller
    namespace: soperator-system
    status: deployed
    version: 1
  lastAttemptedConfigDigest: sha256:5332e63912903eae14dd84e343b8befff5aa547de645ac6825ca5033a9d2b78d
  lastAttemptedGeneration: 1
  lastAttemptedReleaseAction: install
  lastAttemptedReleaseActionDuration: 24.196765749s
  lastAttemptedRevision: 4.1.13
  observedGeneration: 1
  storageNamespace: flux-system
```

---

> Separator

## CRDs: which APIs the installation added.

```bash
kubectl get crd | wc -l
91
```

```bash
kubectl get crd -o custom-columns=NAME:.metadata.name --no-headers | sed -E 's/^[^.]*\.//' | sort | uniq -c | sort -rn

  16 operator.victoriametrics.com
  16 apps.kruise.io
  12 cilium.io
  10 monitoring.coreos.com
   8 security-profiles-operator.x-k8s.io
   6 source.toolkit.fluxcd.io
   6 slurm.nebius.ai
   4 cert-manager.io
   3 notification.toolkit.fluxcd.io
   3 image.toolkit.fluxcd.io
   2 acme.cert-manager.io
   1 policy.kruise.io
   1 kustomize.toolkit.fluxcd.io
   1 helm.toolkit.fluxcd.io
   1 autoscaling.x-k8s.io
```

```bash
kubectl api-resources --api-group=slurm.nebius.ai -o wide

NAME                 SHORTNAMES   APIVERSION                 NAMESPACED   KIND                VERBS                                                        CATEGORIES
activechecks                      slurm.nebius.ai/v1alpha1   true         ActiveCheck         delete,deletecollection,get,list,patch,create,update,watch
jailedconfigs                     slurm.nebius.ai/v1alpha1   true         JailedConfig        delete,deletecollection,get,list,patch,create,update,watch
nodeconfigurators                 slurm.nebius.ai/v1alpha1   true         NodeConfigurator    delete,deletecollection,get,list,patch,create,update,watch
nodesetpowerstates                slurm.nebius.ai/v1alpha1   true         NodeSetPowerState   delete,deletecollection,get,list,patch,create,update,watch
nodesets                          slurm.nebius.ai/v1alpha1   true         NodeSet             delete,deletecollection,get,list,patch,create,update,watch
slurmclusters                     slurm.nebius.ai/v1         true         SlurmCluster        delete,deletecollection,get,list,patch,create,update,watch`bash
```

```bash
for r in $(kubectl api-resources --api-group=slurm.nebius.ai -o name); do echo "== $r"; kubectl get $r -A; done
== activechecks.slurm.nebius.ai
NAMESPACE   NAME                                  TYPE       INIT    SUSPEND   SCHEDULE            K8S STATUS   SLURM STATUS   SLURM SUBMIT TIME   SLURM ID   AGE
soperator   all-reduce-perf-nccl-in-docker        slurmJob   false   true      0 0 1 1 *                                                                      7h39m
soperator   all-reduce-perf-nccl-with-ib          slurmJob   false   false     45 0-18/6 * * *                                                                7h39m
soperator   all-reduce-perf-nccl-without-ib       slurmJob   false   false     25 5-23/6 * * *                                                                7h39m
soperator   create-user-nebius                    k8sJob     true    true      0 0 1 1 *           Complete                                                   7h39m
soperator   create-user-soperatorchecks           k8sJob     true    true      0 0 1 1 *           Complete                                                   7h39m
soperator   cuda-samples                          slurmJob   false   false     30 0-18/6 * * *                                                                7h39m
soperator   dcgmi-diag-r2                         slurmJob   false   true      5 12 * * *                                                                     7h39m
soperator   dcgmi-diag-r3                         slurmJob   false   true      0 0 1 1 *                                                                      7h39m
soperator   enroot-cleanup                        slurmJob   false   false     10 8-20/12 * * *                                                               7h39m
soperator   ensure-dir-snccld-logs                k8sJob     true    false     15 0 * * *          Complete                                                   7h39m
soperator   ensure-healthy-nodes                  slurmJob   true    true      0 0 1 1 *                        Complete                                      7h39m
soperator   extensive-check                       slurmJob   false   true      0 0 1 1 *                                                                      7h39m
soperator   gpu-fryer                             slurmJob   false   false     15 9-21/12 * * *                                                               7h39m
soperator   ib-gpu-perf                           slurmJob   false   false     55 1-21/4 * * *                                                                7h39m
soperator   manage-jail-state                     k8sJob     false   true      0 0 1 1 *                                                                      7h39m
soperator   manage-jail-state-dry-run             k8sJob     false   false     0 11 * * *          Complete                                                   7h39m
soperator   manage-jail-state-force               k8sJob     false   true      0 0 1 1 *                                                                      7h39m
soperator   mem-perf                              slurmJob   false   false     20 10-22/12 * * *                                                              7h39m
soperator   prepull-container-image               slurmJob   false   true      0 0 1 1 *                                                                      7h39m
soperator   retrigger-checks                      k8sJob     false   true      0 0 1 1 *                                                                      7h39m
soperator   soperator-outputs-logs-cleaner        k8sJob     false   false     40 */1 * * *        Complete                                                   7h39m
soperator   ssh-check                             k8sJob     true    true      0 0 1 1 *           Complete                                                   7h39m
soperator   upgrade-health-checker                k8sJob     false   true      0 0 1 1 *                                                                      7h39m
soperator   wait-for-soperatorchecks-srun-ready   k8sJob     true    true      0 0 1 1 *           Complete                                                   7h39m
soperator   wait-for-topology                     k8sJob     true    true      0 0 1 1 *           Complete                                                   7h39m
== jailedconfigs.slurm.nebius.ai
NAMESPACE   NAME                      FILES WRITTEN   RECONFIGURATION STATUS   JAILED PATH                        AGE
soperator   activecheck-prolog        Success         MissingAction            /etc/slurm/activecheck-prolog.sh   7h39m
soperator   soperator-slurm-configs   Success         Refresh                  /etc/slurm/slurm.conf              7h30m
soperator   topology-config           Success         Refresh                  /etc/slurm/topology.conf           7h39m
== nodeconfigurators.slurm.nebius.ai
NAMESPACE          NAME                          REBOOTER ENABLED   NODECONFIGURATOR ENABLED   AGE
soperator-system   soperator-node-configurator   true                                          7h40m
== nodesetpowerstates.slurm.nebius.ai
No resources found
== nodesets.slurm.nebius.ai
NAMESPACE   NAME     STATUS   DESIRED   READY   EPHEMERAL
soperator   worker   Ready    2         2       false
== slurmclusters.slurm.nebius.ai
NAMESPACE   NAME        STATUS      CONTROLLERS   LOGIN   SCONFIGCTRL   ACCOUNTING
soperator   soperator   Available   True          1       True          False
```

---

> Separator

## Soperator objects: the Slurm cluster as Kubernetes sees it.

```bash
kubectl -n soperator get slurmcluster soperator -o yaml | head -300

apiVersion: slurm.nebius.ai/v1
kind: SlurmCluster
metadata:
  annotations:
    meta.helm.sh/release-name: soperator
    meta.helm.sh/release-namespace: soperator
  creationTimestamp: "2026-10-12T08:39:55Z"
  generation: 1
  labels:
    app.kubernetes.io/instance: soperator
    app.kubernetes.io/managed-by: Helm
    app.kubernetes.io/name: soperator
    app.kubernetes.io/version: 4.1.13
    helm.sh/chart: helm-slurm-cluster-4.1.13
    helm.toolkit.fluxcd.io/name: flux-system-soperator-fluxcd-slurm-cluster
    helm.toolkit.fluxcd.io/namespace: flux-system
  name: soperator
  namespace: soperator
  resourceVersion: "16883"
  uid: 5c880f0f-d686-400d-b92f-7e2c9f62eb4b
spec:
  cgroupVersion: v2
  crVersion: 4.1.13
  healthCheckConfig:
    healthCheckInterval: 120
    healthCheckNodeState:
    - state: ANY
    - state: CYCLE
    healthCheckProgram: /opt/slurm_scripts/hc_program.sh
  k8sNodeFilters:
  - affinity:
      nodeAffinity:
        requiredDuringSchedulingIgnoredDuringExecution:
          nodeSelectorTerms:
          - matchExpressions:
            - key: slurm.nebius.ai/nodeset
              operator: In
              values:
              - system
    name: system
  - affinity:
      nodeAffinity:
        requiredDuringSchedulingIgnoredDuringExecution:
          nodeSelectorTerms:
          - matchExpressions:
            - key: slurm.nebius.ai/nodeset
              operator: In
              values:
              - accounting
    name: accounting
    tolerations:
    - effect: NoSchedule
      key: slurm.nebius.ai/nodeset
      operator: Equal
      value: accounting
  - affinity:
      nodeAffinity:
        requiredDuringSchedulingIgnoredDuringExecution:
          nodeSelectorTerms:
          - matchExpressions:
            - key: slurm.nebius.ai/nodeset
              operator: In
              values:
              - controller
    name: controller
    tolerations:
    - effect: NoSchedule
      key: slurm.nebius.ai/nodeset
      operator: Equal
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
    - effect: NoSchedule
      key: slurm.nebius.ai/nodeset
      operator: Equal
      value: login
  - affinity:
      nodeAffinity:
        requiredDuringSchedulingIgnoredDuringExecution:
          nodeSelectorTerms:
          - matchExpressions:
            - key: slurm.nebius.ai/nodeset
              operator: In
              values:
              - worker
    name: worker
    tolerations:
    - effect: NoSchedule
      key: slurm.nebius.ai/nodeset
      operator: Equal
      value: worker
    - effect: NoSchedule
      key: nvidia.com/gpu
      operator: Exists
  maintenance: none
  mpiConfig:
    pmixEnv: OMPI_MCA_btl_tcp_if_include=eth0
  partitionConfiguration:
    configType: structured
    partitions:
    - config: Default=YES PriorityTier=10 PreemptMode=OFF MaxTime=INFINITE State=UP
        OverSubscribe=YES
      isAll: true
      name: main
    - config: Default=NO PriorityTier=10 PreemptMode=OFF Hidden=YES MaxTime=INFINITE
        State=UP OverSubscribe=YES
      isAll: true
      name: hidden
  plugStackConfig:
    customPlugins: []
    ncclDebug:
      enabled: true
      logLevel: INFO
      outputDirectory: /opt/soperator-outputs/nccl_logs
      outputToFile: true
      outputToStdOut: false
      required: false
    pyxis:
      importerPath: /opt/slurm_scripts/pyxis_caching_importer.sh
      required: true
  populateJail:
    appArmorProfile: unconfined
    image: cr.nebius.cloud/soperator/populate_jail:4.1.13-slurm25.11.8-cuda13.0.2
    imagePullPolicy: IfNotPresent
    k8sNodeFilterName: system
    overwrite: false
    priorityClass: soperator-slurm-populate-jail
  sConfigController:
    container:
      appArmorProfile: unconfined
      image: cr.nebius.cloud/soperator/sconfigcontroller:4.1.13
      imagePullPolicy: IfNotPresent
      resources:
        cpu: 250m
        ephemeral-storage: 500Mi
        memory: 256Mi
    node:
      k8sNodeFilterName: system
      priorityClass: soperator-slurm-sconfigcontroller
      size: 2
    reconfigurePollInterval: 20s
    reconfigureWaitTimeout: 5m
    runAsGid: 1001
    runAsUid: 1001
    serviceAccountName: soperator-sconfigcontroller
  secrets: {}
  slurmConfig:
    completeWait: 5
    defCpuPerGPU: 4
    defMemPerNode: 0
    epilog: /opt/slurm_scripts/epilog.sh
    maxJobCount: 20000
    messageTimeout: 60
    minJobAge: 28800
    prolog: /opt/slurm_scripts/prolog.sh
    resumeTimeout: 1800
    suspendTime: 1000000000
    taskPluginParam: ""
    topologyParam: SwitchAsNodeRank
    topologyPlugin: topology/tree
  slurmNodes:
    accounting:
      enabled: false
      k8sNodeFilterName: accounting
      priorityClass: soperator-slurm-accounting
      slurmConfig:
        accountingStorageTRES: CPU,Mem,Node,VMem,Gres/gpu
        jobAcctGatherFrequency: 0
        jobAcctGatherType: jobacct_gather/cgroup
        priorityWeightAge: 0
        priorityWeightFairshare: 0
        priorityWeightQOS: 0
      slurmdbd:
        appArmorProfile: unconfined
        image: cr.nebius.cloud/soperator/controller_slurmdbd:4.1.13-slurm25.11.8
        imagePullPolicy: IfNotPresent
      slurmdbdConfig:
        archiveEvents: "yes"
        archiveJobs: "yes"
        archiveResvs: "yes"
        archiveSteps: "no"
        archiveSuspend: "no"
        archiveTXN: "no"
        archiveUsage: "yes"
        debugLevel: info
        purgeEventAfter: 1month
        purgeJobAfter: 12month
        purgeResvAfter: 1month
        purgeStepAfter: 1month
        purgeSuspendAfter: 1month
        purgeTXNAfter: 12month
        purgeUsageAfter: 24month
        tcpTimeout: 2
    controller:
      customInitContainers:
      - command:
        - grep
        - ' /volume-mount virtiofs '
        - /proc/mounts
        image: cr.nebius.cloud/soperator/busybox
        name: ensure-jail-virtiofs
        volumeMounts:
        - mountPath: /volume-mount
          name: jail
      k8sNodeFilterName: controller
      munge:
        appArmorProfile: unconfined
        image: cr.nebius.cloud/soperator/munge:4.1.13-slurm25.11.8
        imagePullPolicy: IfNotPresent
        livenessProbe:
          exec:
            command:
            - /bin/sh
            - -c
            - /usr/bin/munge -n > /dev/null && exit 0 || exit 1
          failureThreshold: 3
          periodSeconds: 10
          successThreshold: 1
          timeoutSeconds: 1
        readinessProbe:
          exec:
            command:
            - /bin/sh
            - -c
            - test -S /run/munge/munge.socket.2
          failureThreshold: 3
          periodSeconds: 10
          successThreshold: 1
          timeoutSeconds: 1
        resources:
          cpu: 100m
          ephemeral-storage: 5Gi
          memory: 0.5Gi
      openMetrics:
        enabled: true
        serviceMonitor:
          interval: 30s
          scrapeTimeout: 28s
      priorityClass: soperator-slurm-controller
      serviceAccountName: soperator-slurm-controller
      slurmctld:
        appArmorProfile: unconfined
        image: cr.nebius.cloud/soperator/controller_slurmctld:4.1.13-slurm25.11.8
        imagePullPolicy: IfNotPresent
        livenessProbe:
          exec:
            command:
            - scontrol
            - ping
          failureThreshold: 3
          initialDelaySeconds: 25
          periodSeconds: 10
          successThreshold: 1
          timeoutSeconds: 1
        port: 6817
        resources:
          cpu: 2000m
          ephemeral-storage: 55Gi
          memory: 11Gi
      sssdDebugLevel: 0
      volumes:
        jail:
          volumeSourceName: jail
        spool:
          volumeClaimTemplateSpec:
            accessModes:
            - ReadWriteOnce
            resources:
              requests:
                storage: 50Gi
            storageClassName: compute-csi-network-ssd-ext4
    exporter:
      collectionInterval: 30s
      enabled: true
      exporterContainer:
        appArmorProfile: unconfined
        image: cr.nebius.cloud/soperator/soperator-exporter:4.1.13-slurm25.11.8
        imagePullPolicy: IfNotPresent
      k8sNodeFilterName: system
      podMonitorConfig:
        interval: 30s
        jobLabel: slurm-exporter
        scrapeTimeout: 28s
      priorityClass: soperator-slurm-exporter
      serviceAccountName: slurm-exporter-sa
      size: 1
    login:
      customInitContainers:
      - command:
        - grep
        - ' /volume-mount virtiofs '
```

```bash
kubectl -n soperator get pods -o wide

NAME                                                    READY   STATUS      RESTARTS   AGE     IP             NODE                                 NOMINATED NODE   READINESS GATES
all-reduce-perf-nccl-with-ib-29863485-w7vf4             0/2     Completed   0          3h36m   10.6.36.150    computeinstance-e00x7j626d1a3pm55f   <none>           <none>
all-reduce-perf-nccl-without-ib-29863405-hv6f2          0/2     Completed   0          4h56m   10.6.96.165    computeinstance-e00s52tt1ma5gsb7zf   <none>           <none>
controller-0                                            2/2     Running     0          7h32m   10.6.37.13     computeinstance-e00f0f6eqqzeg61nng   <none>           2/2
controller-placeholder-jmrts                            3/3     Running     0          7h32m   10.6.37.170    computeinstance-e00f0f6eqqzeg61nng   <none>           <none>
controller-spool-mount-vj5hs                            1/1     Running     0          7h41m   10.6.37.65     computeinstance-e00f0f6eqqzeg61nng   <none>           <none>
create-user-nebius-initial-run-d8zjc                    0/1     Completed   0          7h29m   10.6.36.194    computeinstance-e00x7j626d1a3pm55f   <none>           <none>
create-user-soperatorchecks-initial-run-hdcq5           0/1     Completed   0          7h30m   10.6.36.232    computeinstance-e00x7j626d1a3pm55f   <none>           <none>
cuda-samples-29863470-cgdcz                             0/2     Completed   0          3h51m   10.6.36.152    computeinstance-e00x7j626d1a3pm55f   <none>           <none>
ensure-dir-snccld-logs-initial-run-2vhds                0/1     Completed   0          7h30m   10.6.36.137    computeinstance-e00x7j626d1a3pm55f   <none>           <none>
ensure-healthy-nodes-initial-run-cfd58                  0/2     Completed   0          7h30m   10.6.96.135    computeinstance-e00s52tt1ma5gsb7zf   <none>           <none>
gpu-fryer-29863275-sq44d                                0/2     Completed   0          7h6m    10.6.96.31     computeinstance-e00s52tt1ma5gsb7zf   <none>           <none>
helm-soperator-dcgm-exporter-ds-kvx8x                   1/1     Running     0          7h43m   10.6.22.60     computeinstance-e00gp55x6krjw7dmd6   <none>           <none>
helm-soperator-dcgm-exporter-ds-nh6hp                   1/1     Running     0          7h43m   10.6.130.88    computeinstance-e00mv1d3sabb2nj8pe   <none>           <none>
ib-gpu-perf-29863315-r9z7p                              0/2     Completed   0          6h26m   10.6.96.185    computeinstance-e00s52tt1ma5gsb7zf   <none>           <none>
ib-gpu-perf-29863555-v489w                              0/2     Completed   0          146m    10.6.96.138    computeinstance-e00s52tt1ma5gsb7zf   <none>           <none>
jail-mount-9kk9n                                        1/1     Running     0          7h41m   10.6.96.227    computeinstance-e00s52tt1ma5gsb7zf   <none>           <none>
jail-mount-btlk5                                        1/1     Running     0          7h41m   10.6.22.136    computeinstance-e00gp55x6krjw7dmd6   <none>           <none>
jail-mount-hlz6m                                        1/1     Running     0          7h41m   10.6.130.6     computeinstance-e00mv1d3sabb2nj8pe   <none>           <none>
jail-mount-hncj5                                        1/1     Running     0          7h41m   10.6.37.94     computeinstance-e00f0f6eqqzeg61nng   <none>           <none>
jail-mount-nr98r                                        1/1     Running     0          7h41m   10.6.28.85     computeinstance-e00pmdsyqcadj9tp8g   <none>           <none>
jail-mount-shxqc                                        1/1     Running     0          7h41m   10.6.55.207    computeinstance-e00hjf3m4dg1k2ebnj   <none>           <none>
jail-mount-xfqgz                                        1/1     Running     0          7h41m   10.6.36.73     computeinstance-e00x7j626d1a3pm55f   <none>           <none>
jail-submount-data-mount-5shsv                          1/1     Running     0          7h41m   10.6.130.251   computeinstance-e00mv1d3sabb2nj8pe   <none>           <none>
jail-submount-data-mount-7d79k                          1/1     Running     0          7h41m   10.6.36.133    computeinstance-e00x7j626d1a3pm55f   <none>           <none>
jail-submount-data-mount-fs9gd                          1/1     Running     0          7h41m   10.6.28.244    computeinstance-e00pmdsyqcadj9tp8g   <none>           <none>
jail-submount-data-mount-ptn44                          1/1     Running     0          7h41m   10.6.37.219    computeinstance-e00f0f6eqqzeg61nng   <none>           <none>
jail-submount-data-mount-rx6cc                          1/1     Running     0          7h41m   10.6.22.38     computeinstance-e00gp55x6krjw7dmd6   <none>           <none>
jail-submount-data-mount-vhxrt                          1/1     Running     0          7h41m   10.6.96.110    computeinstance-e00s52tt1ma5gsb7zf   <none>           <none>
jail-submount-data-mount-w2d2k                          1/1     Running     0          7h41m   10.6.55.139    computeinstance-e00hjf3m4dg1k2ebnj   <none>           <none>
login-0                                                 2/2     Running     0          7h32m   10.6.28.71     computeinstance-e00pmdsyqcadj9tp8g   <none>           1/1
manage-jail-state-dry-run-29863380-vhldg                0/1     Completed   0          5h21m   10.6.36.246    computeinstance-e00x7j626d1a3pm55f   <none>           <none>
mem-perf-29863340-gsvzt                                 0/2     Completed   0          6h1m    10.6.96.138    computeinstance-e00s52tt1ma5gsb7zf   <none>           <none>
run-extensive-check-on-reservations-29863690-j6f8c      0/2     Completed   0          11m     10.6.36.120    computeinstance-e00x7j626d1a3pm55f   <none>           <none>
run-extensive-check-on-reservations-29863695-dbkmm      0/2     Completed   0          6m33s   10.6.36.76     computeinstance-e00x7j626d1a3pm55f   <none>           <none>
run-extensive-check-on-reservations-29863700-nqz5b      0/2     Completed   0          93s     10.6.36.247    computeinstance-e00x7j626d1a3pm55f   <none>           <none>
sconfigcontroller-7b868fdf86-9952j                      1/1     Running     0          7h32m   10.6.96.241    computeinstance-e00s52tt1ma5gsb7zf   <none>           <none>
sconfigcontroller-7b868fdf86-fk7pf                      1/1     Running     0          7h32m   10.6.28.110    computeinstance-e00pmdsyqcadj9tp8g   <none>           <none>
slurm-exporter-6cf785fbd7-8nqgf                         1/1     Running     0          7h32m   10.6.96.214    computeinstance-e00s52tt1ma5gsb7zf   <none>           <none>
soperator-outputs-logs-cleaner-29863540-gs8cf           0/1     Completed   0          161m    10.6.36.36     computeinstance-e00x7j626d1a3pm55f   <none>           <none>
soperator-outputs-logs-cleaner-29863600-6xjbv           0/1     Completed   0          101m    10.6.36.240    computeinstance-e00x7j626d1a3pm55f   <none>           <none>
soperator-outputs-logs-cleaner-29863660-6989p           0/1     Completed   0          41m     10.6.36.126    computeinstance-e00x7j626d1a3pm55f   <none>           <none>
soperator-populate-jail-nszw7                           0/1     Completed   0          7h41m   10.6.36.2      computeinstance-e00x7j626d1a3pm55f   <none>           <none>
ssh-check-initial-run-lc8cw                             0/1     Completed   0          7h28m   10.6.36.31     computeinstance-e00x7j626d1a3pm55f   <none>           <none>
wait-for-soperatorchecks-srun-ready-initial-run-d5p9n   0/2     Completed   0          7h29m   10.6.36.34     computeinstance-e00x7j626d1a3pm55f   <none>           <none>
wait-for-topology-initial-run-lr7tr                     0/1     Completed   0          7h30m   10.6.36.176    computeinstance-e00x7j626d1a3pm55f   <none>           <none>
worker-0                                                2/2     Running     0          7h32m   10.6.130.62    computeinstance-e00mv1d3sabb2nj8pe   <none>           2/2
worker-1                                                2/2     Running     0          6h55m   10.6.22.178    computeinstance-e00gp55x6krjw7dmd6   <none>           2/2
```

```bash
kubectl -n soperator get sts,svc,cm,pvc

Warning: short name "sts" could also match lower priority resource statefulsets.apps.kruise.io
NAME                                          TYPE           CLUSTER-IP     EXTERNAL-IP      PORT(S)        AGE
service/helm-soperator-dcgm-exporter-svc      ClusterIP      10.5.146.106   <none>           9400/TCP       7h44m
service/soperator-controller-svc              ClusterIP      10.5.24.18     <none>           6817/TCP       7h33m
service/soperator-login-headless-svc          ClusterIP      None           <none>           22/TCP         7h33m
service/soperator-login-svc                   LoadBalancer   10.5.39.38     195.242.29.216   22:31540/TCP   7h33m
service/soperator-nodeset-svc                 ClusterIP      None           <none>           6818/TCP       7h41m
service/soperator-nodeset-worker-svc          ClusterIP      None           <none>           6818/TCP       7h41m
service/soperator-sconfigcontroller-metrics   ClusterIP      10.5.222.220   <none>           8080/TCP       7h42m

NAME                                                      DATA   AGE
configmap/activecheck-prolog                              1      7h42m
configmap/custom-supervisord-config                       1      7h44m
configmap/helm-soperator-dcgm-exporter-metrics            1      7h44m
configmap/image-storage                                   2      7h44m
configmap/kube-root-ca.crt                                1      7h44m
configmap/motd-nebius-o11y                                1      7h44m
configmap/mount-scripts                                   2      7h42m
configmap/sbatch-script-all-reduce-perf-nccl-in-docker    1      7h28m
configmap/sbatch-script-all-reduce-perf-nccl-with-ib      1      7h28m
configmap/sbatch-script-all-reduce-perf-nccl-without-ib   1      7h28m
configmap/sbatch-script-cuda-samples                      1      7h28m
configmap/sbatch-script-dcgmi-diag-r2                     1      7h28m
configmap/sbatch-script-dcgmi-diag-r3                     1      7h28m
configmap/sbatch-script-enroot-cleanup                    1      7h28m
configmap/sbatch-script-ensure-healthy-nodes              1      7h31m
configmap/sbatch-script-extensive-check                   1      7h28m
configmap/sbatch-script-gpu-fryer                         1      7h28m
configmap/sbatch-script-ib-gpu-perf                       1      7h28m
configmap/sbatch-script-mem-perf                          1      7h28m
configmap/sbatch-script-prepull-container-image           1      7h28m
configmap/slurm-scripts                                   22     7h42m
configmap/soperator-controller-security-limits            1      7h33m
configmap/soperator-login-security-limits                 1      7h33m
configmap/soperator-nodeset-worker-security-limits        1      7h41m
configmap/soperator-slurm-configs                         7      7h33m
configmap/soperator-ssh-configs                           1      7h33m
configmap/soperator-ssh-configs-worker                    1      7h41m
configmap/soperator-ssh-root-keys                         1      7h33m
configmap/soperator-sysctl                                1      7h33m
configmap/topology-config                                 1      7h42m
configmap/topology-node-labels                            2      7h42m

NAME                                                  STATUS   VOLUME                                     CAPACITY   ACCESS MODES   STORAGECLASS                   VOLUMEATTRIBUTESCLASS   AGE
persistentvolumeclaim/controller-spool-controller-0   Bound    pvc-2ff97e5e-6c08-4124-aa40-35daca498fd9   50Gi       RWO            compute-csi-network-ssd-ext4   <unset>                 7h33m
persistentvolumeclaim/controller-spool-pvc            Bound    controller-spool-pv                        128Gi      RWX            slurm-local-pv                 <unset>                 7h42m
persistentvolumeclaim/home-dir                        Bound    pvc-e443914a-1412-48c9-892c-e3fed44b6866   42         RWX            nfs                            <unset>                 7h42m
persistentvolumeclaim/jail-pvc                        Bound    jail-pv                                    1Ti        RWX            slurm-local-pv                 <unset>                 7h42m
persistentvolumeclaim/jail-submount-data-pvc          Bound    jail-submount-data-pv                      1Ti        RWX            slurm-local-pv                 <unset>                 7h42m
```

```bash
kubectl -n soperator get activechecks
NAME                                  TYPE       INIT    SUSPEND   SCHEDULE            K8S STATUS   SLURM STATUS   SLURM SUBMIT TIME   SLURM ID   AGE
all-reduce-perf-nccl-in-docker        slurmJob   false   true      0 0 1 1 *                                                                      7h42m
all-reduce-perf-nccl-with-ib          slurmJob   false   false     45 0-18/6 * * *                                                                7h42m
all-reduce-perf-nccl-without-ib       slurmJob   false   false     25 5-23/6 * * *                                                                7h42m
create-user-nebius                    k8sJob     true    true      0 0 1 1 *           Complete                                                   7h42m
create-user-soperatorchecks           k8sJob     true    true      0 0 1 1 *           Complete                                                   7h42m
cuda-samples                          slurmJob   false   false     30 0-18/6 * * *                                                                7h42m
dcgmi-diag-r2                         slurmJob   false   true      5 12 * * *                                                                     7h42m
dcgmi-diag-r3                         slurmJob   false   true      0 0 1 1 *                                                                      7h42m
enroot-cleanup                        slurmJob   false   false     10 8-20/12 * * *                                                               7h42m
ensure-dir-snccld-logs                k8sJob     true    false     15 0 * * *          Complete                                                   7h42m
ensure-healthy-nodes                  slurmJob   true    true      0 0 1 1 *                        Complete                                      7h42m
extensive-check                       slurmJob   false   true      0 0 1 1 *                                                                      7h42m
gpu-fryer                             slurmJob   false   false     15 9-21/12 * * *                                                               7h42m
ib-gpu-perf                           slurmJob   false   false     55 1-21/4 * * *                                                                7h42m
manage-jail-state                     k8sJob     false   true      0 0 1 1 *                                                                      7h42m
manage-jail-state-dry-run             k8sJob     false   false     0 11 * * *          Complete                                                   7h42m
manage-jail-state-force               k8sJob     false   true      0 0 1 1 *                                                                      7h42m
mem-perf                              slurmJob   false   false     20 10-22/12 * * *                                                              7h42m
prepull-container-image               slurmJob   false   true      0 0 1 1 *                                                                      7h42m
retrigger-checks                      k8sJob     false   true      0 0 1 1 *                                                                      7h42m
soperator-outputs-logs-cleaner        k8sJob     false   false     40 */1 * * *        Complete                                                   7h42m
ssh-check                             k8sJob     true    true      0 0 1 1 *           Complete                                                   7h42m
upgrade-health-checker                k8sJob     false   true      0 0 1 1 *                                                                      7h42m
wait-for-soperatorchecks-srun-ready   k8sJob     true    true      0 0 1 1 *           Complete                                                   7h42m
wait-for-topology                     k8sJob     true    true      0 0 1 1 *           Complete                                                   7h42m
```

---

> Separator

## Operators and system namespaces: what runs the controllers.

```bash
kubectl -n soperator-system get all

NAME                                                READY   STATUS    RESTARTS   AGE
pod/soperator-checks-checks-b757c4cc9-jvkrc         2/2     Running   0          7h43m
pod/soperator-controller-manager-584b65dc7c-s9lmn   2/2     Running   0          7h44m
pod/soperator-node-configurator-ds-5p2h5            1/1     Running   0          7h43m
pod/soperator-node-configurator-ds-6hj2x            1/1     Running   0          7h43m
pod/soperator-node-configurator-ds-6tj7t            1/1     Running   0          7h43m
pod/soperator-node-configurator-ds-bd2dg            1/1     Running   0          7h43m
pod/soperator-node-configurator-ds-c8gv8            1/1     Running   0          7h43m
pod/soperator-node-configurator-ds-hwk8q            1/1     Running   0          7h43m
pod/soperator-node-configurator-ds-wrj69            1/1     Running   0          7h43m
pod/soperator-node-configurator-ds-xdhkc            1/1     Running   0          7h43m

NAME                                                   TYPE        CLUSTER-IP    EXTERNAL-IP   PORT(S)    AGE
service/soperator-checks-metrics                       ClusterIP   10.5.3.22     <none>        8443/TCP   7h43m
service/soperator-controller-metrics                   ClusterIP   10.5.16.110   <none>        8443/TCP   7h44m
service/soperator-controller-webhook-service           ClusterIP   10.5.169.97   <none>        443/TCP    7h44m
service/soperator-node-configurator-rebooter-metrics   ClusterIP   10.5.218.69   <none>        8080/TCP   7h43m

NAME                                            DESIRED   CURRENT   READY   UP-TO-DATE   AVAILABLE   NODE SELECTOR   AGE
daemonset.apps/soperator-node-configurator-ds   8         8         8       8            8           <none>          7h43m

NAME                                           READY   UP-TO-DATE   AVAILABLE   AGE
deployment.apps/soperator-checks-checks        1/1     1            1           7h43m
deployment.apps/soperator-controller-manager   1/1     1            1           7h44m

NAME                                                      DESIRED   CURRENT   READY   AGE
replicaset.apps/soperator-checks-checks-b757c4cc9         1         1         1       7h43m
replicaset.apps/soperator-controller-manager-584b65dc7c   1         1         1       7h44m
```

```bash
kubectl get pods -A | grep -i -E "kruise|cert-manager|operator|controller-manager|node-configurator"

cert-manager-system                 cert-manager-689dbf96cf-n8dd7                                  1/1     Running     0          7h45m
cert-manager-system                 cert-manager-cainjector-7c8d57866-fncbw                        1/1     Running     0          7h45m
cert-manager-system                 cert-manager-webhook-5b78b88bc6-9nz82                          1/1     Running     0          7h45m
kruise-system                       kruise-controller-manager-7c6f58d74-88r72                      1/1     Running     0          7h45m
kruise-system                       kruise-controller-manager-7c6f58d74-l5dcr                      1/1     Running     0          7h45m
kruise-system                       kruise-daemon-64qfl                                            1/1     Running     0          7h45m
kruise-system                       kruise-daemon-66mjj                                            1/1     Running     0          7h45m
kruise-system                       kruise-daemon-9xkwh                                            1/1     Running     0          7h45m
kruise-system                       kruise-daemon-d2rgg                                            1/1     Running     0          7h45m
kruise-system                       kruise-daemon-lb52x                                            1/1     Running     0          7h45m
kruise-system                       kruise-daemon-pqbmx                                            1/1     Running     0          7h45m
kruise-system                       kruise-daemon-pw69z                                            1/1     Running     0          7h45m
kruise-system                       kruise-daemon-wljqm                                            1/1     Running     0          7h45m
kube-system                         cilium-operator-7cf67ddb5b-gccfj                               1/1     Running     0          7h55m
kube-system                         cilium-operator-7cf67ddb5b-kdncx                               1/1     Running     0          7h55m
monitoring-system                   metrics-victoria-metrics-operator-6b488645c9-w7nqm             1/1     Running     0          7h45m
security-profiles-operator-system   security-profiles-operator-bf6c8455c-d975r                     1/1     Running     0          7h45m
security-profiles-operator-system   security-profiles-operator-bf6c8455c-trw29                     1/1     Running     0          7h45m
security-profiles-operator-system   security-profiles-operator-webhook-56b6f8df7f-4klmj            1/1     Running     0          7h45m
security-profiles-operator-system   security-profiles-operator-webhook-56b6f8df7f-jnxp7            1/1     Running     0          7h45m
security-profiles-operator-system   security-profiles-operator-webhook-56b6f8df7f-nwpw2            1/1     Running     0          7h45m
security-profiles-operator-system   spod-54xkz                                                     2/2     Running     0          7h45m
security-profiles-operator-system   spod-5gg6f                                                     2/2     Running     0          7h45m
security-profiles-operator-system   spod-5jr4k                                                     2/2     Running     0          7h45m
security-profiles-operator-system   spod-fxb82                                                     2/2     Running     0          7h45m
security-profiles-operator-system   spod-jknst                                                     2/2     Running     0          7h45m
security-profiles-operator-system   spod-sg7fd                                                     2/2     Running     0          7h45m
security-profiles-operator-system   spod-srdp2                                                     2/2     Running     0          7h45m
security-profiles-operator-system   spod-wfh54                                                     2/2     Running     0          7h45m
soperator-system                    soperator-checks-checks-b757c4cc9-jvkrc                        2/2     Running     0          7h44m
soperator-system                    soperator-controller-manager-584b65dc7c-s9lmn                  2/2     Running     0          7h44m
soperator-system                    soperator-node-configurator-ds-5p2h5                           1/1     Running     0          7h44m
soperator-system                    soperator-node-configurator-ds-6hj2x                           1/1     Running     0          7h44m
soperator-system                    soperator-node-configurator-ds-6tj7t                           1/1     Running     0          7h44m
soperator-system                    soperator-node-configurator-ds-bd2dg                           1/1     Running     0          7h44m
soperator-system                    soperator-node-configurator-ds-c8gv8                           1/1     Running     0          7h44m
soperator-system                    soperator-node-configurator-ds-hwk8q                           1/1     Running     0          7h44m
soperator-system                    soperator-node-configurator-ds-wrj69                           1/1     Running     0          7h44m
soperator-system                    soperator-node-configurator-ds-xdhkc                           1/1     Running     0          7h44m
soperator                           all-reduce-perf-nccl-with-ib-29863485-w7vf4                    0/2     Completed   0          3h39m
soperator                           all-reduce-perf-nccl-without-ib-29863405-hv6f2                 0/2     Completed   0          4h59m
soperator                           controller-0                                                   2/2     Running     0          7h35m
soperator                           controller-placeholder-jmrts                                   3/3     Running     0          7h35m
soperator                           controller-spool-mount-vj5hs                                   1/1     Running     0          7h44m
soperator                           create-user-nebius-initial-run-d8zjc                           0/1     Completed   0          7h31m
soperator                           create-user-soperatorchecks-initial-run-hdcq5                  0/1     Completed   0          7h32m
soperator                           cuda-samples-29863470-cgdcz                                    0/2     Completed   0          3h54m
soperator                           ensure-dir-snccld-logs-initial-run-2vhds                       0/1     Completed   0          7h32m
soperator                           ensure-healthy-nodes-initial-run-cfd58                         0/2     Completed   0          7h32m
soperator                           gpu-fryer-29863275-sq44d                                       0/2     Completed   0          7h9m
soperator                           helm-soperator-dcgm-exporter-ds-kvx8x                          1/1     Running     0          7h46m
soperator                           helm-soperator-dcgm-exporter-ds-nh6hp                          1/1     Running     0          7h46m
soperator                           ib-gpu-perf-29863315-r9z7p                                     0/2     Completed   0          6h29m
soperator                           ib-gpu-perf-29863555-v489w                                     0/2     Completed   0          149m
soperator                           jail-mount-9kk9n                                               1/1     Running     0          7h44m
soperator                           jail-mount-btlk5                                               1/1     Running     0          7h44m
soperator                           jail-mount-hlz6m                                               1/1     Running     0          7h44m
soperator                           jail-mount-hncj5                                               1/1     Running     0          7h44m
soperator                           jail-mount-nr98r                                               1/1     Running     0          7h44m
soperator                           jail-mount-shxqc                                               1/1     Running     0          7h44m
soperator                           jail-mount-xfqgz                                               1/1     Running     0          7h44m
soperator                           jail-submount-data-mount-5shsv                                 1/1     Running     0          7h44m
soperator                           jail-submount-data-mount-7d79k                                 1/1     Running     0          7h44m
soperator                           jail-submount-data-mount-fs9gd                                 1/1     Running     0          7h44m
soperator                           jail-submount-data-mount-ptn44                                 1/1     Running     0          7h44m
soperator                           jail-submount-data-mount-rx6cc                                 1/1     Running     0          7h44m
soperator                           jail-submount-data-mount-vhxrt                                 1/1     Running     0          7h44m
soperator                           jail-submount-data-mount-w2d2k                                 1/1     Running     0          7h44m
soperator                           login-0                                                        2/2     Running     0          7h35m
soperator                           manage-jail-state-dry-run-29863380-vhldg                       0/1     Completed   0          5h24m
soperator                           mem-perf-29863340-gsvzt                                        0/2     Completed   0          6h4m
soperator                           run-extensive-check-on-reservations-29863690-j6f8c             0/2     Completed   0          14m
soperator                           run-extensive-check-on-reservations-29863695-dbkmm             0/2     Completed   0          9m1s
soperator                           run-extensive-check-on-reservations-29863700-nqz5b             0/2     Completed   0          4m1s
soperator                           sconfigcontroller-7b868fdf86-9952j                             1/1     Running     0          7h35m
soperator                           sconfigcontroller-7b868fdf86-fk7pf                             1/1     Running     0          7h35m
soperator                           slurm-exporter-6cf785fbd7-8nqgf                                1/1     Running     0          7h35m
soperator                           soperator-outputs-logs-cleaner-29863540-gs8cf                  0/1     Completed   0          164m
soperator                           soperator-outputs-logs-cleaner-29863600-6xjbv                  0/1     Completed   0          104m
soperator                           soperator-outputs-logs-cleaner-29863660-6989p                  0/1     Completed   0          44m
soperator                           soperator-populate-jail-nszw7                                  0/1     Completed   0          7h44m
soperator                           ssh-check-initial-run-lc8cw                                    0/1     Completed   0          7h31m
soperator                           wait-for-soperatorchecks-srun-ready-initial-run-d5p9n          0/2     Completed   0          7h31m
soperator                           wait-for-topology-initial-run-lr7tr                            0/1     Completed   0          7h32m
soperator                           worker-0                                                       2/2     Running     0          7h35m
soperator                           worker-1                                                       2/2     Running     0          6h58m
```

```bash
kubectl get validatingwebhookconfigurations,mutatingwebhookconfigurations
NAME                                                                                                                WEBHOOKS   AGE
validatingwebhookconfiguration.admissionregistration.k8s.io/cert-manager-webhook                                    1          7h46m
validatingwebhookconfiguration.admissionregistration.k8s.io/kruise-validating-webhook-configuration                 22         7h45m
validatingwebhookconfiguration.admissionregistration.k8s.io/metrics-victoria-metrics-operator-admission             10         7h45m
validatingwebhookconfiguration.admissionregistration.k8s.io/soperator-controller-validating-webhook-configuration   3          7h45m

NAME                                                                                                            WEBHOOKS   AGE
mutatingwebhookconfiguration.admissionregistration.k8s.io/cert-manager-webhook                                  1          7h46m
mutatingwebhookconfiguration.admissionregistration.k8s.io/kruise-mutating-webhook-configuration                 12         7h45m
mutatingwebhookconfiguration.admissionregistration.k8s.io/soperator-controller-mutating-webhook-configuration   1          7h45m
mutatingwebhookconfiguration.admissionregistration.k8s.io/spo-mutating-webhook-configuration                    2          7h46m
```

---

> Separator

## Networking, part 1: services and addresses.

```bash
kubectl get svc -A -o wide

NAMESPACE                           NAME                                           TYPE           CLUSTER-IP     EXTERNAL-IP      PORT(S)                                                            AGE     SELECTOR
cert-manager-system                 cert-manager                                   ClusterIP      10.5.244.89    <none>           9402/TCP                                                           7h47m   app.kubernetes.io/component=controller,app.kubernetes.io/instance=cert-manager,app.kubernetes.io/name=cert-manager
cert-manager-system                 cert-manager-cainjector                        ClusterIP      10.5.195.140   <none>           9402/TCP                                                           7h47m   app.kubernetes.io/component=cainjector,app.kubernetes.io/instance=cert-manager,app.kubernetes.io/name=cainjector
cert-manager-system                 cert-manager-webhook                           ClusterIP      10.5.176.77    <none>           443/TCP,9402/TCP                                                   7h47m   app.kubernetes.io/component=webhook,app.kubernetes.io/instance=cert-manager,app.kubernetes.io/name=webhook
default                             kubernetes                                     ClusterIP      10.5.0.1       <none>           443/TCP                                                            7h56m   <none>
flux-system                         notification-controller                        ClusterIP      10.5.220.44    <none>           80/TCP                                                             7h48m   app=notification-controller
flux-system                         source-controller                              ClusterIP      10.5.161.240   <none>           80/TCP                                                             7h48m   app=source-controller
flux-system                         webhook-receiver                               ClusterIP      10.5.39.58     <none>           80/TCP                                                             7h48m   app=notification-controller
kruise-system                       kruise-webhook-service                         ClusterIP      10.5.23.123    <none>           443/TCP                                                            7h46m   control-plane=controller-manager
kube-system                         coredns                                        ClusterIP      10.5.0.10      <none>           53/UDP,53/TCP                                                      7h56m   app.kubernetes.io/instance=coredns,app.kubernetes.io/name=coredns,k8s-app=coredns
kube-system                         coredns-metrics                                ClusterIP      10.5.71.109    <none>           9153/TCP                                                           7h56m   app.kubernetes.io/instance=coredns,app.kubernetes.io/name=coredns,k8s-app=coredns
kube-system                         hubble-metrics                                 ClusterIP      None           <none>           9965/TCP                                                           7h56m   k8s-app=cilium
kube-system                         hubble-peer                                    ClusterIP      10.5.213.162   <none>           443/TCP                                                            7h56m   k8s-app=cilium
kube-system                         hubble-relay                                   ClusterIP      10.5.68.218    <none>           80/TCP                                                             7h56m   k8s-app=hubble-relay
kube-system                         hubble-ui                                      ClusterIP      10.5.1.113     <none>           80/TCP                                                             7h56m   k8s-app=hubble-ui
kube-system                         metrics-server                                 ClusterIP      10.5.107.207   <none>           443/TCP                                                            7h56m   app.kubernetes.io/instance=metrics-server,app.kubernetes.io/name=metrics-server
kube-system                         nebius-node-problem-detector                   ClusterIP      None           <none>           20257/TCP                                                          7h56m   app=nebius-node-problem-detector
logs-system                         opentelemetry-collector-events                 ClusterIP      10.5.109.89    <none>           6831/UDP,14250/TCP,14268/TCP,8888/TCP,4317/TCP,4318/TCP,9411/TCP   7h45m   app.kubernetes.io/instance=opentelemetry-collector-events,app.kubernetes.io/name=opentelemetry-collector,component=standalone-collector
logs-system                         vm-logs-victoria-logs-single-server            ClusterIP      None           <none>           9428/TCP                                                           7h47m   app.kubernetes.io/instance=vm-logs,app.kubernetes.io/name=victoria-logs-single,app=server
monitoring-system                   metrics-grafana                                ClusterIP      10.5.91.243    <none>           80/TCP                                                             7h46m   app.kubernetes.io/instance=metrics,app.kubernetes.io/name=grafana
monitoring-system                   metrics-kube-state-metrics                     ClusterIP      10.5.115.100   <none>           8080/TCP,8081/TCP                                                  7h46m   app.kubernetes.io/instance=metrics,app.kubernetes.io/name=kube-state-metrics
monitoring-system                   metrics-prometheus-node-exporter               ClusterIP      10.5.14.126    <none>           9100/TCP                                                           7h46m   app.kubernetes.io/instance=metrics,app.kubernetes.io/name=prometheus-node-exporter
monitoring-system                   metrics-victoria-metrics-operator              ClusterIP      10.5.161.224   <none>           8080/TCP,9443/TCP                                                  7h46m   app.kubernetes.io/instance=metrics,app.kubernetes.io/name=victoria-metrics-operator
monitoring-system                   vmagent-metrics-victoria-metrics-k8s-stack     ClusterIP      10.5.198.236   <none>           8429/TCP                                                           7h46m   app.kubernetes.io/component=monitoring,app.kubernetes.io/instance=metrics-victoria-metrics-k8s-stack,app.kubernetes.io/name=vmagent,managed-by=vm-operator
monitoring-system                   vmsingle-metrics-victoria-metrics-k8s-stack    ClusterIP      10.5.226.217   <none>           8429/TCP                                                           7h45m   app.kubernetes.io/component=monitoring,app.kubernetes.io/instance=metrics-victoria-metrics-k8s-stack,app.kubernetes.io/name=vmsingle,managed-by=vm-operator
nfs-system                          nfs-server                                     ClusterIP      10.5.253.90    <none>           2049/TCP,111/TCP,20048/TCP,9100/TCP                                7h46m   app.kubernetes.io/instance=nfs-server,app.kubernetes.io/name=nfs-server
security-profiles-operator-system   metrics                                        ClusterIP      10.5.140.128   <none>           443/TCP                                                            7h46m   app=security-profiles-operator,name=spod
security-profiles-operator-system   webhook-service                                ClusterIP      10.5.167.158   <none>           443/TCP                                                            7h46m   app=security-profiles-operator,name=security-profiles-operator-webhook
soperator-system                    soperator-checks-metrics                       ClusterIP      10.5.3.22      <none>           8443/TCP                                                           7h45m   app.kubernetes.io/instance=soperator-checks,app.kubernetes.io/name=soperator-checks
soperator-system                    soperator-controller-metrics                   ClusterIP      10.5.16.110    <none>           8443/TCP                                                           7h45m   app.kubernetes.io/instance=soperator-controller,app.kubernetes.io/name=helm-soperator
soperator-system                    soperator-controller-webhook-service           ClusterIP      10.5.169.97    <none>           443/TCP                                                            7h45m   app.kubernetes.io/instance=soperator-controller,app.kubernetes.io/name=helm-soperator,control-plane=controller-manager
soperator-system                    soperator-node-configurator-rebooter-metrics   ClusterIP      10.5.218.69    <none>           8080/TCP                                                           7h45m   app.kubernetes.io/component=node-configurator
soperator                           helm-soperator-dcgm-exporter-svc               ClusterIP      10.5.146.106   <none>           9400/TCP                                                           7h47m   app.kubernetes.io/instance=soperator-dcgm-exporter,app.kubernetes.io/name=helm-soperator-dcgm-exporter,app=nvidia-dcgm-exporter
soperator                           soperator-controller-svc                       ClusterIP      10.5.24.18     <none>           6817/TCP                                                           7h36m   app.kubernetes.io/component=controller,app.kubernetes.io/instance=soperator,app.kubernetes.io/name=slurmcluster,slurm.nebius.ai/controller-type=main
soperator                           soperator-login-headless-svc                   ClusterIP      None           <none>           22/TCP                                                             7h36m   app.kubernetes.io/component=login,app.kubernetes.io/instance=soperator,app.kubernetes.io/name=slurmcluster
soperator                           soperator-login-svc                            LoadBalancer   10.5.39.38     195.242.29.216   22:31540/TCP                                                       7h36m   app.kubernetes.io/component=login,app.kubernetes.io/instance=soperator,app.kubernetes.io/name=slurmcluster
soperator                           soperator-nodeset-svc                          ClusterIP      None           <none>           6818/TCP                                                           7h44m   app.kubernetes.io/component=nodeset,app.kubernetes.io/instance=soperator,app.kubernetes.io/name=slurmcluster
soperator                           soperator-nodeset-worker-svc                   ClusterIP      None           <none>           6818/TCP                                                           7h44m   app.kubernetes.io/component=nodeset,app.kubernetes.io/instance=soperator,app.kubernetes.io/name=slurmcluster,slurm.nebius.ai/nodeset=worker
soperator                           soperator-sconfigcontroller-metrics            ClusterIP      10.5.222.220   <none>           8080/TCP                                                           7h45m   app.kubernetes.io/name=sconfigcontroller
```

```bash
kubectl get svc -A | grep -i LoadBalancer

soperator                           soperator-login-svc                            LoadBalancer   10.5.39.38     195.242.29.216   22:31540/TCP                                                       7h36m
```

```bash
kubectl get endpoints -A                                                                                                                                                                                                        ─╯

Warning: v1 Endpoints is deprecated in v1.33+; use discovery.k8s.io/v1 EndpointSlice
NAMESPACE                           NAME                                           ENDPOINTS                                                         AGE
cert-manager-system                 cert-manager                                   10.6.28.32:9402                                                   7h48m
cert-manager-system                 cert-manager-cainjector                        10.6.36.112:9402                                                  7h48m
cert-manager-system                 cert-manager-webhook                           10.6.28.142:10250,10.6.28.142:9402                                7h48m
default                             kubernetes                                     10.6.0.1:443,10.6.0.7:443,10.6.0.93:443                           7h58m
flux-system                         notification-controller                        10.6.28.108:9090                                                  7h49m
flux-system                         source-controller                              10.6.96.50:9090                                                   7h49m
flux-system                         webhook-receiver                               10.6.28.108:9292                                                  7h49m
kruise-system                       kruise-webhook-service                         10.6.28.94:9876,10.6.36.205:9876                                  7h47m
kube-system                         coredns                                        10.6.55.131:53,10.6.96.246:53,10.6.55.131:53 + 1 more...          7h57m
kube-system                         coredns-metrics                                10.6.55.131:9153,10.6.96.246:9153                                 7h57m
kube-system                         hubble-metrics                                 10.6.0.0:9965,10.6.0.108:9965,10.6.0.3:9965 + 5 more...           7h57m
kube-system                         hubble-peer                                    10.6.0.0:4244,10.6.0.108:4244,10.6.0.3:4244 + 5 more...           7h57m
kube-system                         hubble-relay                                   10.6.55.145:4245                                                  7h57m
kube-system                         hubble-ui                                      10.6.55.98:8081                                                   7h57m
kube-system                         metrics-server                                 10.6.55.151:10250,10.6.55.163:10250                               7h57m
kube-system                         nebius-node-problem-detector                   10.6.0.0:20257,10.6.0.108:20257,10.6.0.3:20257 + 5 more...        7h57m
logs-system                         opentelemetry-collector-events                 10.6.96.20:14268,10.6.96.20:14250,10.6.96.20:8888 + 4 more...     7h47m
logs-system                         vm-logs-victoria-logs-single-server            10.6.96.77:9428                                                   7h48m
monitoring-system                   metrics-grafana                                10.6.55.56:3000                                                   7h47m
monitoring-system                   metrics-kube-state-metrics                     10.6.55.103:8081,10.6.55.103:8080                                 7h47m
monitoring-system                   metrics-prometheus-node-exporter               10.6.0.0:9100,10.6.0.108:9100,10.6.0.3:9100 + 5 more...           7h47m
monitoring-system                   metrics-victoria-metrics-operator              10.6.55.187:8080,10.6.55.187:9443                                 7h47m
monitoring-system                   vmagent-metrics-victoria-metrics-k8s-stack     10.6.55.83:8429                                                   7h47m
monitoring-system                   vmsingle-metrics-victoria-metrics-k8s-stack    10.6.96.112:8429                                                  7h46m
nfs-system                          nfs-server                                     10.6.95.94:9100,10.6.95.94:20048,10.6.95.94:2049 + 1 more...      7h48m
security-profiles-operator-system   metrics                                        10.6.130.242:9443,10.6.22.184:9443,10.6.28.154:9443 + 5 more...   7h47m
security-profiles-operator-system   webhook-service                                10.6.130.100:9443,10.6.22.103:9443,10.6.55.70:9443                7h47m
soperator-system                    soperator-checks-metrics                       10.6.28.1:8443                                                    7h46m
soperator-system                    soperator-controller-metrics                   10.6.36.193:8443                                                  7h46m
soperator-system                    soperator-controller-webhook-service           10.6.36.193:9443                                                  7h46m
soperator-system                    soperator-node-configurator-rebooter-metrics   10.6.0.0:8080,10.6.0.108:8080,10.6.0.3:8080 + 5 more...           7h46m
soperator                           helm-soperator-dcgm-exporter-svc               10.6.130.88:9400,10.6.22.60:9400                                  7h48m
soperator                           soperator-controller-svc                       10.6.37.13:6817                                                   7h37m
soperator                           soperator-login-headless-svc                   10.6.28.71:22                                                     7h37m
soperator                           soperator-login-svc                            10.6.28.71:22                                                     7h37m
soperator                           soperator-nodeset-svc                          10.6.130.62:6818,10.6.22.178:6818                                 7h45m
soperator                           soperator-nodeset-worker-svc                   10.6.130.62:6818,10.6.22.178:6818                                 7h45m
soperator                           soperator-sconfigcontroller-metrics            <none>                                                            7h46m
```

```bash
kubectl get ingress,networkpolicies -A

NAMESPACE     NAME                                             POD-SELECTOR                  AGE
flux-system   networkpolicy.networking.k8s.io/allow-egress     <none>                        7h49m
flux-system   networkpolicy.networking.k8s.io/allow-scraping   <none>                        7h49m
flux-system   networkpolicy.networking.k8s.io/allow-webhooks   app=notification-controller   7h49m
```

```bash
kubectl get nodes -o custom-columns='NAME:.metadata.name,INTERNAL:.status.addresses[?(@.type=="InternalIP")].address,PODCIDR:.spec.podCIDR'
NAME                                 INTERNAL     PODCIDR
computeinstance-e00dpf5e97eft6c4sg   10.6.0.3     10.6.95.0/24
computeinstance-e00f0f6eqqzeg61nng   10.6.0.108   10.6.37.0/24
computeinstance-e00gp55x6krjw7dmd6   10.6.38.15   10.6.22.0/24
computeinstance-e00hjf3m4dg1k2ebnj   10.6.0.47    10.6.55.0/24
computeinstance-e00mv1d3sabb2nj8pe   10.6.0.0     10.6.130.0/24
computeinstance-e00pmdsyqcadj9tp8g   10.6.38.4    10.6.28.0/24
computeinstance-e00s52tt1ma5gsb7zf   10.6.0.79    10.6.96.0/24
computeinstance-e00x7j626d1a3pm55f   10.6.38.3    10.6.36.0/24
```

---

> Separator

## Networking, part 2: CNI, DNS and the view from inside a pod.

```bash
kubectl -n kube-system get pods -o wide                                                                                                                                                                                         ─╯

NAME                                                      READY   STATUS    RESTARTS   AGE     IP             NODE                                 NOMINATED NODE   READINESS GATES
cilium-278rk                                              1/1     Running   0          7h51m   10.6.38.3      computeinstance-e00x7j626d1a3pm55f   <none>           <none>
cilium-76vqw                                              1/1     Running   0          7h51m   10.6.0.0       computeinstance-e00mv1d3sabb2nj8pe   <none>           <none>
cilium-cv9t4                                              1/1     Running   0          7h51m   10.6.38.4      computeinstance-e00pmdsyqcadj9tp8g   <none>           <none>
cilium-envoy-52fw4                                        1/1     Running   0          7h51m   10.6.0.3       computeinstance-e00dpf5e97eft6c4sg   <none>           <none>
cilium-envoy-98fw2                                        1/1     Running   0          7h51m   10.6.38.3      computeinstance-e00x7j626d1a3pm55f   <none>           <none>
cilium-envoy-9bhcr                                        1/1     Running   0          7h51m   10.6.38.15     computeinstance-e00gp55x6krjw7dmd6   <none>           <none>
cilium-envoy-9x2tl                                        1/1     Running   0          7h51m   10.6.0.0       computeinstance-e00mv1d3sabb2nj8pe   <none>           <none>
cilium-envoy-hfsgb                                        1/1     Running   0          7h51m   10.6.0.47      computeinstance-e00hjf3m4dg1k2ebnj   <none>           <none>
cilium-envoy-nlmn9                                        1/1     Running   0          7h51m   10.6.0.79      computeinstance-e00s52tt1ma5gsb7zf   <none>           <none>
cilium-envoy-qxxtz                                        1/1     Running   0          7h51m   10.6.0.108     computeinstance-e00f0f6eqqzeg61nng   <none>           <none>
cilium-envoy-zx2rn                                        1/1     Running   0          7h51m   10.6.38.4      computeinstance-e00pmdsyqcadj9tp8g   <none>           <none>
cilium-frmcf                                              1/1     Running   0          7h51m   10.6.0.47      computeinstance-e00hjf3m4dg1k2ebnj   <none>           <none>
cilium-l7rds                                              1/1     Running   0          7h51m   10.6.0.3       computeinstance-e00dpf5e97eft6c4sg   <none>           <none>
cilium-operator-7cf67ddb5b-gccfj                          1/1     Running   0          7h59m   10.6.38.3      computeinstance-e00x7j626d1a3pm55f   <none>           <none>
cilium-operator-7cf67ddb5b-kdncx                          1/1     Running   0          7h59m   10.6.38.4      computeinstance-e00pmdsyqcadj9tp8g   <none>           <none>
cilium-qlsft                                              1/1     Running   0          7h51m   10.6.38.15     computeinstance-e00gp55x6krjw7dmd6   <none>           <none>
cilium-th8ll                                              1/1     Running   0          7h51m   10.6.0.108     computeinstance-e00f0f6eqqzeg61nng   <none>           <none>
cilium-x6mc2                                              1/1     Running   0          7h51m   10.6.0.79      computeinstance-e00s52tt1ma5gsb7zf   <none>           <none>
compute-csi-node-6lp9k                                    2/2     Running   0          7h51m   10.6.38.3      computeinstance-e00x7j626d1a3pm55f   <none>           <none>
compute-csi-node-d5kkx                                    2/2     Running   0          7h51m   10.6.0.108     computeinstance-e00f0f6eqqzeg61nng   <none>           <none>
compute-csi-node-g95wg                                    2/2     Running   0          7h51m   10.6.0.47      computeinstance-e00hjf3m4dg1k2ebnj   <none>           <none>
compute-csi-node-ghzdf                                    2/2     Running   0          7h51m   10.6.0.79      computeinstance-e00s52tt1ma5gsb7zf   <none>           <none>
compute-csi-node-nk6d4                                    2/2     Running   0          7h51m   10.6.0.0       computeinstance-e00mv1d3sabb2nj8pe   <none>           <none>
compute-csi-node-rv4qq                                    2/2     Running   0          7h51m   10.6.38.4      computeinstance-e00pmdsyqcadj9tp8g   <none>           <none>
compute-csi-node-vfnh8                                    2/2     Running   0          7h51m   10.6.0.3       computeinstance-e00dpf5e97eft6c4sg   <none>           <none>
compute-csi-node-xd5l4                                    2/2     Running   0          7h51m   10.6.38.15     computeinstance-e00gp55x6krjw7dmd6   <none>           <none>
container-runtime-monitor-installer-42m48                 1/1     Running   0          7h51m   10.6.38.15     computeinstance-e00gp55x6krjw7dmd6   <none>           <none>
container-runtime-monitor-installer-k75sd                 1/1     Running   0          7h51m   10.6.0.47      computeinstance-e00hjf3m4dg1k2ebnj   <none>           <none>
container-runtime-monitor-installer-ln6kf                 1/1     Running   0          7h51m   10.6.0.108     computeinstance-e00f0f6eqqzeg61nng   <none>           <none>
container-runtime-monitor-installer-mnnkq                 1/1     Running   0          7h51m   10.6.0.3       computeinstance-e00dpf5e97eft6c4sg   <none>           <none>
container-runtime-monitor-installer-nkbnt                 1/1     Running   0          7h51m   10.6.38.3      computeinstance-e00x7j626d1a3pm55f   <none>           <none>
container-runtime-monitor-installer-rjvcb                 1/1     Running   0          7h51m   10.6.0.0       computeinstance-e00mv1d3sabb2nj8pe   <none>           <none>
container-runtime-monitor-installer-sshh5                 1/1     Running   0          7h51m   10.6.38.4      computeinstance-e00pmdsyqcadj9tp8g   <none>           <none>
container-runtime-monitor-installer-zfqjk                 1/1     Running   0          7h51m   10.6.0.79      computeinstance-e00s52tt1ma5gsb7zf   <none>           <none>
coredns-77c89844c-5jxjk                                   1/1     Running   0          7h51m   10.6.96.246    computeinstance-e00s52tt1ma5gsb7zf   <none>           <none>
coredns-77c89844c-9pb75                                   1/1     Running   0          7h59m   10.6.55.131    computeinstance-e00hjf3m4dg1k2ebnj   <none>           <none>
coredns-autoscaler-695db474c-m77lv                        1/1     Running   0          7h59m   10.6.55.32     computeinstance-e00hjf3m4dg1k2ebnj   <none>           <none>
coredns-autoscaler-695db474c-qjfg2                        1/1     Running   0          7h59m   10.6.55.19     computeinstance-e00hjf3m4dg1k2ebnj   <none>           <none>
hubble-relay-6868665797-clzxz                             1/1     Running   0          7h59m   10.6.55.145    computeinstance-e00hjf3m4dg1k2ebnj   <none>           <none>
hubble-ui-55c9496fb6-xmxf6                                2/2     Running   0          7h59m   10.6.55.98     computeinstance-e00hjf3m4dg1k2ebnj   <none>           <none>
metrics-server-8694976875-8s7ks                           1/1     Running   0          7h59m   10.6.55.163    computeinstance-e00hjf3m4dg1k2ebnj   <none>           <none>
metrics-server-8694976875-qd6ps                           1/1     Running   0          7h59m   10.6.55.151    computeinstance-e00hjf3m4dg1k2ebnj   <none>           <none>
nebius-node-problem-detector-cpu-7rtqv                    1/1     Running   0          7h51m   10.6.0.108     computeinstance-e00f0f6eqqzeg61nng   <none>           <none>
nebius-node-problem-detector-cpu-j5qht                    1/1     Running   0          7h51m   10.6.38.4      computeinstance-e00pmdsyqcadj9tp8g   <none>           <none>
nebius-node-problem-detector-cpu-khrdb                    1/1     Running   0          7h51m   10.6.0.47      computeinstance-e00hjf3m4dg1k2ebnj   <none>           <none>
nebius-node-problem-detector-cpu-tmnfn                    1/1     Running   0          7h51m   10.6.38.3      computeinstance-e00x7j626d1a3pm55f   <none>           <none>
nebius-node-problem-detector-cpu-v67sq                    1/1     Running   0          7h51m   10.6.0.3       computeinstance-e00dpf5e97eft6c4sg   <none>           <none>
nebius-node-problem-detector-cpu-v7b6f                    1/1     Running   0          7h51m   10.6.0.79      computeinstance-e00s52tt1ma5gsb7zf   <none>           <none>
nebius-node-problem-detector-gpu-954zv                    1/1     Running   0          7h51m   10.6.0.0       computeinstance-e00mv1d3sabb2nj8pe   <none>           <none>
nebius-node-problem-detector-gpu-qvdr8                    1/1     Running   0          7h51m   10.6.38.15     computeinstance-e00gp55x6krjw7dmd6   <none>           <none>
nvidia-device-plugin-computeinstance-e00gp55x6krjw7dmd6   1/1     Running   0          7h51m   10.6.22.73     computeinstance-e00gp55x6krjw7dmd6   <none>           <none>
nvidia-device-plugin-computeinstance-e00mv1d3sabb2nj8pe   1/1     Running   0          7h51m   10.6.130.222   computeinstance-e00mv1d3sabb2nj8pe   <none>           <none>
```

```bash
 kubectl -n kube-system get cm coredns -o yaml

apiVersion: v1
data:
  Corefile: |-
    # DO NOT UPDATE THIS CONFIG MANUALLY.
    # IT WILL BE OVERWRITTEN BY MK8S BACKEND EVENTUALLY.
    # PLEASE REFER TO THE OFFICIAL NEBIUS DOCUMENTATION ON HOW TO CUSTOMIZE COREDNS.
    import custom/*.server
    .:53 {
        errors
        health {
            lameduck 5s
        }
        ready
        kubernetes cluster.local in-addr.arpa ip6.arpa {
            pods insecure
            fallthrough in-addr.arpa ip6.arpa
            ttl 30
        }
        prometheus 0.0.0.0:9153
        cache 30
        loop
        reload
        loadbalance
        import custom/*.override
        forward . 8.8.8.8
    }
kind: ConfigMap
metadata:
  annotations:
    meta.helm.sh/release-name: coredns
    meta.helm.sh/release-namespace: kube-system
  creationTimestamp: "2026-10-12T08:28:41Z"
  labels:
    app.kubernetes.io/instance: coredns
    app.kubernetes.io/managed-by: Helm
    app.kubernetes.io/name: coredns
    helm.sh/chart: coredns-1.31.0-nebius.1
    k8s-app: coredns
    kubernetes.io/cluster-service: "true"
    kubernetes.io/name: CoreDNS
  name: coredns
  namespace: kube-system
  resourceVersion: "451"
  uid: e65e9b25-50bd-452b-9634-ce6795a7eca0
```

```bash
kubectl -n soperator exec worker-0 -c slurmd -- cat /etc/resolv.conf                                                                                                                                                            ─╯

search soperator.svc.cluster.local svc.cluster.local cluster.local vpcnetwork-e00p051cp2ddcp49c0.compute.internal soperator-nodeset-svc.soperator.svc.cluster.local soperator-login-headless-svc.soperator.svc.cluster.local
nameserver 10.5.0.10
options ndots:5
```

```bash
kubectl -n soperator exec worker-0 -c slurmd -- ip -br addr

lo               UNKNOWN        127.0.0.1/8 ::1/128
docker0          DOWN           172.17.0.1/16
eth0@if21        UP             10.6.130.62/32 fe80::dce5:a5ff:fed2:563e/64
```

```bash
kubectl -n soperator exec worker-0 -c slurmd -- ip route
default via 10.6.130.225 dev eth0 mtu 1400
10.6.130.225 dev eth0 scope link
172.17.0.0/16 dev docker0 proto kernel scope link src 172.17.0.1 linkdown
```

---

> Separator

## Storage, part 1: classes, volumes and claims.

```bash
kubectl get sc

NAME                                          PROVISIONER                    RECLAIMPOLICY   VOLUMEBINDINGMODE      ALLOWVOLUMEEXPANSION   AGE
compute-csi-default-sc (default)              compute.csi.nebius.com         Delete          WaitForFirstConsumer   true                   8h
compute-csi-network-ssd-ext4                  compute.csi.nebius.com         Delete          WaitForFirstConsumer   true                   7h52m
compute-csi-network-ssd-io-m3-ext4            compute.csi.nebius.com         Delete          WaitForFirstConsumer   true                   7h52m
compute-csi-network-ssd-io-m3-xfs             compute.csi.nebius.com         Delete          WaitForFirstConsumer   true                   7h52m
compute-csi-network-ssd-non-replicated-ext4   compute.csi.nebius.com         Delete          WaitForFirstConsumer   true                   7h52m
compute-csi-network-ssd-non-replicated-xfs    compute.csi.nebius.com         Delete          WaitForFirstConsumer   true                   7h52m
compute-csi-network-ssd-xfs                   compute.csi.nebius.com         Delete          WaitForFirstConsumer   true                   7h52m
nfs                                           nfs.csi.k8s.io                 Delete          Immediate              true                   7h51m
slurm-local-pv                                kubernetes.io/no-provisioner   Delete          WaitForFirstConsumer   true                   7h50m
```

```bash
kubectl get csidriver

NAME                     ATTACHREQUIRED   PODINFOONMOUNT   STORAGECAPACITY   TOKENREQUESTS   REQUIRESREPUBLISH   MODES        AGE
compute.csi.nebius.com   true             false            false             <unset>         false               Persistent   8h
nfs.csi.k8s.io           false            false            false             <unset>         false               Persistent   7h52m
```

```bash
kubectl get pv                                                                                                                                                                                                                  ─╯

NAME                                       CAPACITY   ACCESS MODES   RECLAIM POLICY   STATUS   CLAIM                                                             STORAGECLASS                   VOLUMEATTRIBUTESCLASS   REASON   AGE
controller-spool-pv                        128Gi      RWX            Retain           Bound    soperator/controller-spool-pvc                                    slurm-local-pv                 <unset>                          7h50m
jail-pv                                    1Ti        RWX            Retain           Bound    soperator/jail-pvc                                                slurm-local-pv                 <unset>                          7h50m
jail-submount-data-pv                      1Ti        RWX            Retain           Bound    soperator/jail-submount-data-pvc                                  slurm-local-pv                 <unset>                          7h50m
pvc-1dfe3def-0abd-4cc2-b45a-7fa1696b1ad9   64Gi       RWO            Delete           Bound    nfs-system/nfs-server-storage                                     compute-csi-network-ssd-ext4   <unset>                          7h52m
pvc-2ff97e5e-6c08-4124-aa40-35daca498fd9   50Gi       RWO            Delete           Bound    soperator/controller-spool-controller-0                           compute-csi-network-ssd-ext4   <unset>                          7h41m
pvc-b86df713-da8f-4719-81d5-07ad44f2b849   32Gi       RWO            Delete           Bound    logs-system/server-volume-vm-logs-victoria-logs-single-server-0   compute-csi-default-sc         <unset>                          7h52m
pvc-d0d942fe-810f-4177-84ad-4a276fb8aab2   32Gi       RWO            Delete           Bound    monitoring-system/vmsingle-metrics-victoria-metrics-k8s-stack     compute-csi-default-sc         <unset>                          7h51m
pvc-e443914a-1412-48c9-892c-e3fed44b6866   42         RWX            Delete           Bound    soperator/home-dir                                                nfs                            <unset>                          7h50m
```

```bash
kubectl get pvc -A

NAMESPACE           NAME                                                  STATUS   VOLUME                                     CAPACITY   ACCESS MODES   STORAGECLASS                   VOLUMEATTRIBUTESCLASS   AGE
logs-system         server-volume-vm-logs-victoria-logs-single-server-0   Bound    pvc-b86df713-da8f-4719-81d5-07ad44f2b849   32Gi       RWO            compute-csi-default-sc         <unset>                 7h54m
monitoring-system   vmsingle-metrics-victoria-metrics-k8s-stack           Bound    pvc-d0d942fe-810f-4177-84ad-4a276fb8aab2   32Gi       RWO            compute-csi-default-sc         <unset>                 7h52m
nfs-system          nfs-server-storage                                    Bound    pvc-1dfe3def-0abd-4cc2-b45a-7fa1696b1ad9   64Gi       RWO            compute-csi-network-ssd-ext4   <unset>                 7h53m
soperator           controller-spool-controller-0                         Bound    pvc-2ff97e5e-6c08-4124-aa40-35daca498fd9   50Gi       RWO            compute-csi-network-ssd-ext4   <unset>                 7h42m
soperator           controller-spool-pvc                                  Bound    controller-spool-pv                        128Gi      RWX            slurm-local-pv                 <unset>                 7h51m
soperator           home-dir                                              Bound    pvc-e443914a-1412-48c9-892c-e3fed44b6866   42         RWX            nfs                            <unset>                 7h51m
soperator           jail-pvc                                              Bound    jail-pv                                    1Ti        RWX            slurm-local-pv                 <unset>                 7h51m
soperator           jail-submount-data-pvc                                Bound    jail-submount-data-pv                      1Ti        RWX            slurm-local-pv                 <unset>                 7h51m
```

```bash
kubectl get volumeattachments
NAME                                                                   ATTACHER                 PV                                         NODE                                 ATTACHED   AGE
csi-35d6fc48a1cd87dbfea3062c90387abf76b8c77aec3e8d439d4f0c2cfd02b9b6   compute.csi.nebius.com   pvc-2ff97e5e-6c08-4124-aa40-35daca498fd9   computeinstance-e00f0f6eqqzeg61nng   true       7h43m
csi-46ea2cc2a51c74a36812c761ad17fa2b4c2c8abdebf5c7dd9e6156c839e54d09   compute.csi.nebius.com   pvc-b86df713-da8f-4719-81d5-07ad44f2b849   computeinstance-e00s52tt1ma5gsb7zf   true       7h54m
csi-e8ad56ae60bb213a01422c35e629c09fdf8f693f42cc3bf5215587f5dc47a000   compute.csi.nebius.com   pvc-d0d942fe-810f-4177-84ad-4a276fb8aab2   computeinstance-e00s52tt1ma5gsb7zf   true       7h52m
csi-f32bcd9200d6336fe0a36b8806f519e7a1efdec5365b240a78a40148b47a8aa4   compute.csi.nebius.com   pvc-1dfe3def-0abd-4cc2-b45a-7fa1696b1ad9   computeinstance-e00dpf5e97eft6c4sg   true       7h53m
```

---

> Separator

## Storage, part 2: what the Slurm pods mount.

```bash
kubectl -n soperator get pod worker-0 -o jsonpath='{range .spec.volumes[*]}{.name}{"\t"}{.persistentVolumeClaim.claimName}{.hostPath.path}{.configMap.name}{.secret.secretName}{"\n"}{end}'

munge-key	soperator-munge
munge-socket
security-limits	soperator-nodeset-worker-security-limits
sshd-keys	soperator-sshd-keys
ssh-root-keys	soperator-ssh-root-keys
in-memory
tmp-disk
boot	/boot
dev-shm
sysctl	soperator-sysctl
supervisord-config	custom-supervisord-config
ssh-configs-worker	soperator-ssh-configs-worker
nvidia	/run/nvidia
nvidia-imex-cli	/usr/bin/nvidia-imex-ctl
nvidia-imex-cli-jail	/usr/bin/nvidia-imex-ctl
nvidia-imex-config	/etc/nvidia-imex
nvidia-imex-config-jail	/etc/nvidia-imex
worker-spool
jail	jail-pvc
home-dir	home-dir
data	jail-submount-data-pvc
slurm-scripts	slurm-scripts
slurm-scripts-jail	slurm-scripts
sys-host	/sys
hpc-jobs-dir	/var/run/nebius/slurm
nvidia-driver-root	/
topology-node-labels	topology-node-labels
kube-api-access-c5x5q
```

```bash
kubectl -n soperator exec worker-0 -c slurmd -- df -h                                                                                                                                                                           ─╯

Filesystem                                                                         Size  Used Avail Use% Mounted on
overlay                                                                            495G   31G  465G   7% /
tmpfs                                                                               64M     0   64M   0% /dev
/dev/vda1                                                                          495G   31G  465G   7% /tmp
/dev/vda16                                                                         881M  258M  562M  32% /boot
/dev/vda15                                                                         105M  6.2M   99M   6% /boot/efi
jail                                                                               1.0T   13G 1012G   2% /mnt/jail
tmpfs                                                                               64G     0   64G   0% /dev/shm
tmpfs                                                                               20G  8.4M   20G   1% /run/nvidia
tmpfs                                                                              186G   24K  186G   1% /etc/ssh/sshd_keys
nfs-server.nfs-system.svc.cluster.local:/pvc-e443914a-1412-48c9-892c-e3fed44b6866   63G     0   63G   0% /mnt/jail/home
tmpfs                                                                               99G     0   99G   0% /run/nvidia/driver/dev/shm
tmpfs                                                                              5.0M     0  5.0M   0% /run/nvidia/driver/run/lock
shm                                                                                 64M     0   64M   0% /run/nvidia/driver/run/containerd/io.containerd.grpc.v1.cri/sandboxes/c26189153c6106029e276d9bd7e4ba27e206113df4dd099b589a5d48e8f30ce2/shm
overlay                                                                            495G   31G  465G   7% /run/nvidia/driver/run/containerd/io.containerd.runtime.v2.task/k8s.io/c26189153c6106029e276d9bd7e4ba27e206113df4dd099b589a5d48e8f30ce2/rootfs
shm                                                                                 64M  4.0K   64M   1% /run/nvidia/driver/run/containerd/io.containerd.grpc.v1.cri/sandboxes/940eb30114a38f948e3b6285d8bfdfaca32066c586339a65e92b6753d30759b1/shm
overlay                                                                            495G   31G  465G   7% /run/nvidia/driver/run/containerd/io.containerd.runtime.v2.task/k8s.io/940eb30114a38f948e3b6285d8bfdfaca32066c586339a65e92b6753d30759b1/rootfs
shm                                                                                 64M     0   64M   0% /run/nvidia/driver/run/containerd/io.containerd.grpc.v1.cri/sandboxes/cadff811070962e354fd517297d972c6f5f4075f40c7fb4383ebf2154b127d30/shm
shm                                                                                 64M     0   64M   0% /run/nvidia/driver/run/containerd/io.containerd.grpc.v1.cri/sandboxes/4cf78d96539f6aa91cf3f6dcb9b20ef13c5996b91a52d03be7f5942526c5afe5/shm
overlay                                                                            495G   31G  465G   7% /run/nvidia/driver/run/containerd/io.containerd.runtime.v2.task/k8s.io/cadff811070962e354fd517297d972c6f5f4075f40c7fb4383ebf2154b127d30/rootfs
overlay                                                                            495G   31G  465G   7% /run/nvidia/driver/run/containerd/io.containerd.runtime.v2.task/k8s.io/4cf78d96539f6aa91cf3f6dcb9b20ef13c5996b91a52d03be7f5942526c5afe5/rootfs
overlay                                                                            495G   31G  465G   7% /run/nvidia/driver/run/containerd/io.containerd.runtime.v2.task/k8s.io/d92bcd94c1725b4cef7cce9958472728091366fea92b0945d638e2cd8b2e839d/rootfs
overlay                                                                            495G   31G  465G   7% /run/nvidia/driver/run/containerd/io.containerd.runtime.v2.task/k8s.io/b154164917ef619de9f3598f9e78fe54ddd8dd391b7a85d9d6d92fd30d5b0da7/rootfs
overlay                                                                            495G   31G  465G   7% /run/nvidia/driver/run/containerd/io.containerd.runtime.v2.task/k8s.io/899e0439ff25943ac85b065bdc615f3e76a2d39e50428ae1dae1c16fe3f1c8f9/rootfs
overlay                                                                            495G   31G  465G   7% /run/nvidia/driver/run/containerd/io.containerd.runtime.v2.task/k8s.io/edb997495296001987b0f00d4ea3afb9fcb141343cd206be0743d4a4a41b26dc/rootfs
overlay                                                                            495G   31G  465G   7% /run/nvidia/driver/run/containerd/io.containerd.runtime.v2.task/k8s.io/ce8f13285d3201dd98da0a307231b5ec70d86d6ac92a5b2e55ff68b2fdd6b278/rootfs
shm                                                                                 64M     0   64M   0% /run/nvidia/driver/run/containerd/io.containerd.grpc.v1.cri/sandboxes/da6151271f83424eb15516932b085018f1f93dcd513e65f21ab3dea7d0921276/shm
overlay                                                                            495G   31G  465G   7% /run/nvidia/driver/run/containerd/io.containerd.runtime.v2.task/k8s.io/da6151271f83424eb15516932b085018f1f93dcd513e65f21ab3dea7d0921276/rootfs
shm                                                                                 64M     0   64M   0% /run/nvidia/driver/run/containerd/io.containerd.grpc.v1.cri/sandboxes/c9247f5ed2dd5323d7f989347ec69822f30b504a1229156987b72a13efd5bfac/shm
overlay                                                                            495G   31G  465G   7% /run/nvidia/driver/run/containerd/io.containerd.runtime.v2.task/k8s.io/c9247f5ed2dd5323d7f989347ec69822f30b504a1229156987b72a13efd5bfac/rootfs
overlay                                                                            495G   31G  465G   7% /run/nvidia/driver/run/containerd/io.containerd.runtime.v2.task/k8s.io/7a7b00d19c74ade52becd752c60ca6c83d04aa639958bd41eeab83b584dd819e/rootfs
overlay                                                                            495G   31G  465G   7% /run/nvidia/driver/run/containerd/io.containerd.runtime.v2.task/k8s.io/3974f623e51913f5bf885e4dac325383707421f2b6c3973f18871a02b37c0839/rootfs
shm                                                                                 64M     0   64M   0% /run/nvidia/driver/run/containerd/io.containerd.grpc.v1.cri/sandboxes/734866adf01568e27322c81165b70e7c50baaefe48ffa26c97f1c61d3163e768/shm
overlay                                                                            495G   31G  465G   7% /run/nvidia/driver/run/containerd/io.containerd.runtime.v2.task/k8s.io/734866adf01568e27322c81165b70e7c50baaefe48ffa26c97f1c61d3163e768/rootfs
overlay                                                                            495G   31G  465G   7% /run/nvidia/driver/run/containerd/io.containerd.runtime.v2.task/k8s.io/05ae6c3892af0eb668da8bb4dc15675507c0729f6c101601a25b211efc7a5d81/rootfs
shm                                                                                 64M     0   64M   0% /run/nvidia/driver/run/containerd/io.containerd.grpc.v1.cri/sandboxes/a92f84fb60ef28f7bc295ef75cbdf054d6c17f8f8c78ffec1382114b454473cd/shm
overlay                                                                            495G   31G  465G   7% /run/nvidia/driver/run/containerd/io.containerd.runtime.v2.task/k8s.io/a92f84fb60ef28f7bc295ef75cbdf054d6c17f8f8c78ffec1382114b454473cd/rootfs
overlay                                                                            495G   31G  465G   7% /run/nvidia/driver/run/containerd/io.containerd.runtime.v2.task/k8s.io/7fb8c3cd6ffd6c1be6189f0476bbbb3ec3da25a576be735a699381ed3907d3fd/rootfs
overlay                                                                            495G   31G  465G   7% /run/nvidia/driver/run/containerd/io.containerd.runtime.v2.task/k8s.io/133c1da376e6cc91aa55bf8fe504ed267e67d0810978a2abad450252c91e8c44/rootfs
overlay                                                                            495G   31G  465G   7% /run/nvidia/driver/run/containerd/io.containerd.runtime.v2.task/k8s.io/5dfe37592454ea13ab9de0395c5b0ed3758b388e61d7d56b1885f05fc431f325/rootfs
shm                                                                                 64M     0   64M   0% /run/nvidia/driver/run/containerd/io.containerd.grpc.v1.cri/sandboxes/b17ee65687dead12a2914516d1260b568da469087bfd64c994edce6593bff178/shm
overlay                                                                            495G   31G  465G   7% /run/nvidia/driver/run/containerd/io.containerd.runtime.v2.task/k8s.io/b17ee65687dead12a2914516d1260b568da469087bfd64c994edce6593bff178/rootfs
shm                                                                                 64M     0   64M   0% /run/nvidia/driver/run/containerd/io.containerd.grpc.v1.cri/sandboxes/f1af132015a6b9571f398098be73b49e5e85045c4378bf314e860f0e334988a3/shm
overlay                                                                            495G   31G  465G   7% /run/nvidia/driver/run/containerd/io.containerd.runtime.v2.task/k8s.io/f1af132015a6b9571f398098be73b49e5e85045c4378bf314e860f0e334988a3/rootfs
overlay                                                                            495G   31G  465G   7% /run/nvidia/driver/run/containerd/io.containerd.runtime.v2.task/k8s.io/0fa89ebc5002d661a1b089cc411ecf22a9066538c7358840657185005b93076b/rootfs
overlay                                                                            495G   31G  465G   7% /run/nvidia/driver/run/containerd/io.containerd.runtime.v2.task/k8s.io/b48048db86716eede3c6805d716c3ef1b1c730d158d83ba74e6895e857ce8794/rootfs
overlay                                                                            495G   31G  465G   7% /run/nvidia/driver/run/containerd/io.containerd.runtime.v2.task/k8s.io/166e8fd9e6defabeb11c5c6894405eaa19d038b401ab38d826e415aef9256d4f/rootfs
shm                                                                                 64M     0   64M   0% /run/nvidia/driver/run/containerd/io.containerd.grpc.v1.cri/sandboxes/45ccb213355b8b5ce98ebb8c116f9224a1843548c4a4e914d3c6ea2543d520be/shm
overlay                                                                            495G   31G  465G   7% /run/nvidia/driver/run/containerd/io.containerd.runtime.v2.task/k8s.io/45ccb213355b8b5ce98ebb8c116f9224a1843548c4a4e914d3c6ea2543d520be/rootfs
overlay                                                                            495G   31G  465G   7% /run/nvidia/driver/run/containerd/io.containerd.runtime.v2.task/k8s.io/619663e462ce5a6a316cace656c503c48462cbe6ebd1999990a357c991f3689a/rootfs
shm                                                                                 64M     0   64M   0% /run/nvidia/driver/run/containerd/io.containerd.grpc.v1.cri/sandboxes/bf1f692c1b9c8dad001401a8f550f0f0ffed8e751fafd906241a5d0b92657cf9/shm
overlay                                                                            495G   31G  465G   7% /run/nvidia/driver/run/containerd/io.containerd.runtime.v2.task/k8s.io/bf1f692c1b9c8dad001401a8f550f0f0ffed8e751fafd906241a5d0b92657cf9/rootfs
overlay                                                                            495G   31G  465G   7% /run/nvidia/driver/run/containerd/io.containerd.runtime.v2.task/k8s.io/3fe3cb357cef577b28485472b4621541cc01ebfff26d3bbaadcd2b842fb3baf9/rootfs
shm                                                                                 64M     0   64M   0% /run/nvidia/driver/run/containerd/io.containerd.grpc.v1.cri/sandboxes/065ca1a9dcffa33be40be7a0ac650d112e897f3d4267b050f5f68942c75181c7/shm
overlay                                                                            495G   31G  465G   7% /run/nvidia/driver/run/containerd/io.containerd.runtime.v2.task/k8s.io/065ca1a9dcffa33be40be7a0ac650d112e897f3d4267b050f5f68942c75181c7/rootfs
overlay                                                                            495G   31G  465G   7% /run/nvidia/driver/run/containerd/io.containerd.runtime.v2.task/k8s.io/20df9ee0208d841c3e402026c62f14b4a2eb0fb1f44324f11c5c75b554d27a3b/rootfs
shm                                                                                 64M     0   64M   0% /run/nvidia/driver/run/containerd/io.containerd.grpc.v1.cri/sandboxes/ccb9a8c0a2df0d75acd56602917148885661f7c5296074c2a1da0d6fe064322d/shm
overlay                                                                            495G   31G  465G   7% /run/nvidia/driver/run/containerd/io.containerd.runtime.v2.task/k8s.io/ccb9a8c0a2df0d75acd56602917148885661f7c5296074c2a1da0d6fe064322d/rootfs
shm                                                                                 64M     0   64M   0% /run/nvidia/driver/run/containerd/io.containerd.grpc.v1.cri/sandboxes/4f7339dc74ef287a814593db3461e9bc00f78c09fb0bafaf63ab423c44bffa29/shm
overlay                                                                            495G   31G  465G   7% /run/nvidia/driver/run/containerd/io.containerd.runtime.v2.task/k8s.io/4f7339dc74ef287a814593db3461e9bc00f78c09fb0bafaf63ab423c44bffa29/rootfs
overlay                                                                            495G   31G  465G   7% /run/nvidia/driver/run/containerd/io.containerd.runtime.v2.task/k8s.io/81bdf876f6494ab2bfae029a12c7f49e1f2524363581281d340f594a9b6806de/rootfs
overlay                                                                            495G   31G  465G   7% /run/nvidia/driver/run/containerd/io.containerd.runtime.v2.task/k8s.io/811b75d9c649fa1e0b0b039f73feae00a830088bf452a3ca2aced65db7b745ec/rootfs
shm                                                                                 64M     0   64M   0% /run/nvidia/driver/run/containerd/io.containerd.grpc.v1.cri/sandboxes/b47303f02640365c4e358cb0b3bc8c27b872d776a81c8e6481bdb5c7b5930625/shm
overlay                                                                            495G   31G  465G   7% /run/nvidia/driver/run/containerd/io.containerd.runtime.v2.task/k8s.io/b47303f02640365c4e358cb0b3bc8c27b872d776a81c8e6481bdb5c7b5930625/rootfs
overlay                                                                            495G   31G  465G   7% /run/nvidia/driver/run/containerd/io.containerd.runtime.v2.task/k8s.io/1c7266feb3d1eb049ee42ab46afeefa5a6144cbb9f26e3ee3075ba42f2402d07/rootfs
shm                                                                                 64M     0   64M   0% /run/nvidia/driver/run/containerd/io.containerd.grpc.v1.cri/sandboxes/20a5fc3813296a58f95d4a2f869670c66924a9f08e1c31f5842222bf76981a86/shm
overlay                                                                            495G   31G  465G   7% /run/nvidia/driver/run/containerd/io.containerd.runtime.v2.task/k8s.io/20a5fc3813296a58f95d4a2f869670c66924a9f08e1c31f5842222bf76981a86/rootfs
overlay                                                                            495G   31G  465G   7% /run/nvidia/driver/run/containerd/io.containerd.runtime.v2.task/k8s.io/258d6f3b7f3f1c4a4e6f93d65b49130c9e92a29201695455f039d32afc0b255e/rootfs
cloud-metadata                                                                    1008G   16K 1008G   1% /run/nvidia/driver/mnt/cloud-metadata
tmpfs                                                                              186G     0  186G   0% /run/nvidia/driver/var/lib/kubelet/pods/22360765-4cae-43b7-bcca-1aa5297d216a/volumes/kubernetes.io~projected/clustermesh-secrets
tmpfs                                                                              186G   12K  186G   1% /run/nvidia/driver/var/lib/kubelet/pods/22360765-4cae-43b7-bcca-1aa5297d216a/volumes/kubernetes.io~projected/hubble-tls
tmpfs                                                                              186G   12K  186G   1% /run/nvidia/driver/var/lib/kubelet/pods/0d186cf6-7f3f-486f-9bbd-489a1e4bfab5/volumes/kubernetes.io~projected/kube-api-access-ds6mf
tmpfs                                                                              186G   12K  186G   1% /run/nvidia/driver/var/lib/kubelet/pods/22360765-4cae-43b7-bcca-1aa5297d216a/volumes/kubernetes.io~projected/kube-api-access-bkd2g
tmpfs                                                                              186G   12K  186G   1% /run/nvidia/driver/var/lib/kubelet/pods/4bbfdb64-a21c-4d5e-9f2f-d2a56c54e67e/volumes/kubernetes.io~projected/kube-api-access-lrsmf
tmpfs                                                                              512M   12K  512M   1% /run/nvidia/driver/var/lib/kubelet/pods/336c81fc-ab6e-49de-aa31-20009310b731/volumes/kubernetes.io~projected/kube-api-access-7p9wf
tmpfs                                                                              400M   12K  400M   1% /run/nvidia/driver/var/lib/kubelet/pods/5874f57f-932e-491b-881f-76b7f62b1b82/volumes/kubernetes.io~projected/kube-api-access-ftwb7
tmpfs                                                                              186G   12K  186G   1% /run/nvidia/driver/var/lib/kubelet/pods/597f9684-d0dc-408a-bff1-ad095d32f029/volumes/kubernetes.io~projected/kube-api-access-jbqf4
tmpfs                                                                              500M   12K  500M   1% /run/nvidia/driver/var/lib/kubelet/pods/c991dbd4-38b0-4543-844f-98216b7128b8/volumes/kubernetes.io~projected/kube-api-access-mbf6s
tmpfs                                                                              256M   12K  256M   1% /run/nvidia/driver/var/lib/kubelet/pods/199db238-e10d-4565-940a-9deac6f728e2/volumes/kubernetes.io~secret/metrics-cert-volume
tmpfs                                                                              256M   12K  256M   1% /run/nvidia/driver/var/lib/kubelet/pods/199db238-e10d-4565-940a-9deac6f728e2/volumes/kubernetes.io~projected/kube-api-access-g7bbz
tmpfs                                                                               64M   12K   64M   1% /run/nvidia/driver/var/lib/kubelet/pods/a1703c86-faf7-47b1-809d-a1d50b2ade35/volumes/kubernetes.io~projected/kube-api-access-v95d4
tmpfs                                                                               64M   12K   64M   1% /run/nvidia/driver/var/lib/kubelet/pods/a1703c86-faf7-47b1-809d-a1d50b2ade35/volumes/kubernetes.io~secret/cert
tmpfs                                                                              128M   12K  128M   1% /run/nvidia/driver/var/lib/kubelet/pods/2134ae9b-04fe-4694-8613-2fe16964dd84/volumes/kubernetes.io~projected/kube-api-access-h86vw
tmpfs                                                                              186G   12K  186G   1% /run/nvidia/driver/var/lib/kubelet/pods/3f4dd1e1-6872-409c-a109-9f8290b5d11f/volumes/kubernetes.io~projected/kube-api-access-j4pxg
tmpfs                                                                              186G   12K  186G   1% /run/nvidia/driver/var/lib/kubelet/pods/00f55a2a-4311-4b4d-ae07-563800f9c2b8/volumes/kubernetes.io~projected/kube-api-access-gtqj7
tmpfs                                                                              186G   12K  186G   1% /run/nvidia/driver/var/lib/kubelet/pods/093285bb-0f56-4f96-a485-7c005112f190/volumes/kubernetes.io~projected/kube-api-access-cr5w5
jail-submount-data                                                                 1.0T     0  1.0T   0% /mnt/jail/mnt/data
tmpfs                                                                              186G   12K  186G   1% /run/nvidia/driver/var/lib/kubelet/pods/53c59bfc-0975-4f8f-b6ec-4a397f78110f/volumes/kubernetes.io~projected/kube-api-access-q9z9b
tmpfs                                                                              176G     0  176G   0% /mnt/jail/mnt/memory
tmpfs                                                                              186G  4.0K  186G   1% /run/nvidia/driver/var/lib/kubelet/pods/a4f803fd-925b-4096-b61d-dc8cc5591147/volumes/kubernetes.io~secret/munge-key
tmpfs                                                                              186G   12K  186G   1% /run/secrets/kubernetes.io/serviceaccount
tmpfs                                                                              4.0K  4.0K     0 100% /run/nvidia-ctk-hookb1d3970a-d525-4000-9fed-4fffc7af5541
tmpfs                                                                               99G   12K   99G   1% /mnt/jail/proc/driver/nvidia
tmpfs                                                                               99G  4.0K   99G   1% /mnt/jail/etc/nvidia/nvidia-application-profiles-rc.d
```

```bash
kubectl -n soperator exec controller-0 -c slurmctld -- df -h
Filesystem      Size  Used Avail Use% Mounted on
overlay         123G   16G  108G  13% /
tmpfs            64M     0   64M   0% /dev
jail            1.0T   13G 1012G   2% /mnt/jail
/dev/vda1       123G   16G  108G  13% /run/munge
tmpfs            16G  4.0K   16G   1% /mnt/rest-jwt-key
shm              64M     0   64M   0% /dev/shm
/dev/vdc         49G  368K   49G   1% /var/spool/slurmctld
tmpfs            16G   12K   16G   1% /run/secrets/kubernetes.io/serviceaccount
tmpfs           4.0K     0  4.0K   0% /proc/acpi
```

---

> Separator

## Scheduling and limits

```bash
kubectl get priorityclasses                                                                                                                                                                                                     ─╯

NAME                                VALUE        GLOBAL-DEFAULT   AGE     PREEMPTIONPOLICY
nfs-server-high                     10000        false            7h57m   PreemptLowerPriority
soperator-slurm-accounting          100003       false            7h56m   PreemptLowerPriority
soperator-slurm-controller          1000001      false            7h56m   PreemptLowerPriority
soperator-slurm-exporter            100004       false            7h56m   PreemptLowerPriority
soperator-slurm-login               100002       false            7h56m   PreemptLowerPriority
soperator-slurm-populate-jail       100007       false            7h56m   PreemptLowerPriority
soperator-slurm-rest                100005       false            7h56m   PreemptLowerPriority
soperator-slurm-sconfigcontroller   100006       false            7h56m   PreemptLowerPriority
soperator-slurm-worker              1000000      false            7h56m   PreemptLowerPriority
soperator-worker-high-priority      10000000     false            7h55m   PreemptLowerPriority
system-cluster-critical             2000000000   false            8h      PreemptLowerPriority
system-node-critical                2000001000   false            8h      PreemptLowerPriority
```

```bash
kubectl get resourcequota,limitrange,pdb -A

NAMESPACE     NAME                          REQUEST      LIMIT   AGE
flux-system   resourcequota/critical-pods   pods: 3/1k           7h59m

NAMESPACE     NAME                                            MIN AVAILABLE   MAX UNAVAILABLE   ALLOWED DISRUPTIONS   AGE
kube-system   poddisruptionbudget.policy/cilium-operator      N/A             1                 1                     8h
kube-system   poddisruptionbudget.policy/coredns              1               N/A               1                     8h
kube-system   poddisruptionbudget.policy/coredns-autoscaler   1               N/A               1                     8h
kube-system   poddisruptionbudget.policy/hubble-relay         N/A             1                 1                     8h
kube-system   poddisruptionbudget.policy/hubble-ui            N/A             1                 1                     8h
kube-system   poddisruptionbudget.policy/metrics-server       1               N/A               1                     8h
```

```bash
kubectl describe nodes | grep -A10 "Allocated resources"                                                                                                                                                                        ─╯

Allocated resources:
  (Total limits may be over 100 percent, i.e., overcommitted.)
  Resource           Requests       Limits
  --------           --------       ------
  cpu                3750m (96%)    1350m (34%)
  memory             13284Mi (86%)  15572Mi (101%)
  ephemeral-storage  60Mi (0%)      220Mi (0%)
  hugepages-1Gi      0 (0%)         0 (0%)
  hugepages-2Mi      0 (0%)         0 (0%)


--
Allocated resources:
  (Total limits may be over 100 percent, i.e., overcommitted.)
  Resource           Requests       Limits
  --------           --------       ------
  cpu                2800m (71%)    1250m (32%)
  memory             12740Mi (82%)  14996Mi (97%)
  ephemeral-storage  61500Mi (54%)  61660Mi (54%)
  hugepages-1Gi      0 (0%)         0 (0%)
  hugepages-2Mi      0 (0%)         0 (0%)


--
Allocated resources:
  (Total limits may be over 100 percent, i.e., overcommitted.)
  Resource           Requests        Limits
  --------           --------        ------
  cpu                15 (94%)        15200m (95%)
  memory             181732Mi (95%)  184020Mi (96%)
  ephemeral-storage  396348Mi (87%)  396508Mi (87%)
  hugepages-1Gi      0 (0%)          0 (0%)
  hugepages-2Mi      0 (0%)          0 (0%)
  nvidia.com/gpu     1               1

--
Allocated resources:
  (Total limits may be over 100 percent, i.e., overcommitted.)
  Resource           Requests       Limits
  --------           --------       ------
  cpu                6300m (79%)    2250m (28%)
  memory             11889Mi (37%)  14036Mi (44%)
  ephemeral-storage  60Mi (0%)      220Mi (0%)
  hugepages-1Gi      0 (0%)         0 (0%)
  hugepages-2Mi      0 (0%)         0 (0%)


--
Allocated resources:
  (Total limits may be over 100 percent, i.e., overcommitted.)
  Resource           Requests        Limits
  --------           --------        ------
  cpu                15 (94%)        15200m (95%)
  memory             181732Mi (95%)  184020Mi (96%)
  ephemeral-storage  396348Mi (87%)  396508Mi (87%)
  hugepages-1Gi      0 (0%)          0 (0%)
  hugepages-2Mi      0 (0%)          0 (0%)
  nvidia.com/gpu     1               1

--
Allocated resources:
  (Total limits may be over 100 percent, i.e., overcommitted.)
  Resource           Requests       Limits
  --------           --------       ------
  cpu                5850m (74%)    4750m (60%)
  memory             20456Mi (64%)  25896Mi (82%)
  ephemeral-storage  66096Mi (58%)  66256Mi (59%)
  hugepages-1Gi      0 (0%)         0 (0%)
  hugepages-2Mi      0 (0%)         0 (0%)


--
Allocated resources:
  (Total limits may be over 100 percent, i.e., overcommitted.)
  Resource           Requests       Limits
  --------           --------       ------
  cpu                4320m (54%)    3270m (41%)
  memory             11864Mi (37%)  15912Mi (50%)
  ephemeral-storage  560Mi (0%)     720Mi (0%)
  hugepages-1Gi      0 (0%)         0 (0%)
  hugepages-2Mi      0 (0%)         0 (0%)


--
Allocated resources:
  (Total limits may be over 100 percent, i.e., overcommitted.)
  Resource           Requests      Limits
  --------           --------      ------
  cpu                4450m (56%)   4750m (60%)
  memory             9348Mi (29%)  13588Mi (43%)
  ephemeral-storage  60Mi (0%)     220Mi (0%)
  hugepages-1Gi      0 (0%)        0 (0%)
  hugepages-2Mi      0 (0%)        0 (0%)
```

```bash
kubectl top pods -A --sort-by=memory | head -25                                                                                                                                                                                 ─╯

NAMESPACE                           NAME                                                           CPU(cores)   MEMORY(bytes)
kube-system                         cilium-76vqw                                                   15m          3448Mi
kube-system                         cilium-qlsft                                                   13m          3430Mi
kube-system                         cilium-frmcf                                                   44m          759Mi
kube-system                         cilium-x6mc2                                                   25m          757Mi
kube-system                         cilium-278rk                                                   33m          756Mi
kube-system                         cilium-cv9t4                                                   33m          754Mi
kube-system                         cilium-th8ll                                                   24m          495Mi
kube-system                         cilium-l7rds                                                   28m          464Mi
monitoring-system                   vmsingle-metrics-victoria-metrics-k8s-stack-649c5d79df-9gvv5   30m          360Mi
monitoring-system                   metrics-grafana-58795cdb5-f9xkt                                9m           330Mi
monitoring-system                   vmagent-metrics-victoria-metrics-k8s-stack-6586588b9c-md8tf    92m          171Mi
soperator                           helm-soperator-dcgm-exporter-ds-kvx8x                          6m           113Mi
soperator                           helm-soperator-dcgm-exporter-ds-nh6hp                          5m           112Mi
kruise-system                       kruise-controller-manager-7c6f58d74-l5dcr                      6m           111Mi
kruise-system                       kruise-controller-manager-7c6f58d74-88r72                      2m           83Mi
logs-system                         vm-logs-victoria-logs-single-server-0                          5m           81Mi
soperator                           worker-0                                                       2m           63Mi
soperator                           worker-1                                                       1m           62Mi
soperator-system                    soperator-controller-manager-584b65dc7c-s9lmn                  3m           60Mi
flux-system                         helm-controller-b654b75f8-j7hrk                                3m           57Mi
soperator-system                    soperator-checks-checks-b757c4cc9-jvkrc                        2m           56Mi
kube-system                         nebius-node-problem-detector-gpu-qvdr8                         1m           56Mi
kube-system                         nebius-node-problem-detector-gpu-954zv                         1m           56Mi
flux-system                         source-controller-c7c5b47d6-v8m7r                              2m           54Mi
```

```bash
kubectl top pods -A --sort-by=cpu | head -25                                                                                                                                                                                    ─╯
NAMESPACE                           NAME                                                           CPU(cores)   MEMORY(bytes)
monitoring-system                   vmagent-metrics-victoria-metrics-k8s-stack-6586588b9c-md8tf    92m          181Mi
kube-system                         cilium-frmcf                                                   47m          759Mi
logs-system                         opentelemetry-collector-logs-agent-9wh6z                       44m          41Mi
logs-system                         opentelemetry-collector-logs-agent-6rdnt                       36m          40Mi
logs-system                         opentelemetry-collector-logs-agent-pxtj8                       33m          42Mi
kube-system                         cilium-cv9t4                                                   33m          755Mi
kube-system                         cilium-278rk                                                   33m          756Mi
logs-system                         opentelemetry-collector-logs-agent-hfr9h                       32m          39Mi
kube-system                         cilium-th8ll                                                   30m          495Mi
kube-system                         cilium-l7rds                                                   29m          464Mi
kube-system                         cilium-x6mc2                                                   28m          757Mi
logs-system                         opentelemetry-collector-logs-agent-fzr79                       26m          40Mi
logs-system                         opentelemetry-collector-logs-agent-zdj65                       24m          50Mi
monitoring-system                   vmsingle-metrics-victoria-metrics-k8s-stack-649c5d79df-9gvv5   24m          370Mi
logs-system                         opentelemetry-collector-logs-agent-w2hdk                       20m          50Mi
logs-system                         opentelemetry-collector-logs-agent-pwh9h                       20m          51Mi
monitoring-system                   metrics-grafana-58795cdb5-f9xkt                                20m          332Mi
kube-system                         cilium-qlsft                                                   18m          3429Mi
kube-system                         cilium-76vqw                                                   15m          3448Mi
flux-system                         image-reflector-controller-684c57479b-7s4g2                    10m          15Mi
kruise-system                       kruise-controller-manager-7c6f58d74-l5dcr                      9m           111Mi
kube-system                         compute-csi-node-rv4qq                                         6m           16Mi
soperator                           helm-soperator-dcgm-exporter-ds-kvx8x                          6m           113Mi
logs-system                         vm-logs-victoria-logs-single-server-0                          6m           81Mi
```

---

> Separator

## GPU stack

```bash
kubectl get pods -A | grep -i -E "nvidia|gpu|dcgm|node-feature"                                                                                                                                                                 ─╯

kube-system                         nebius-node-problem-detector-gpu-954zv                         1/1     Running     0          8h
kube-system                         nebius-node-problem-detector-gpu-qvdr8                         1/1     Running     0          8h
kube-system                         nvidia-device-plugin-computeinstance-e00gp55x6krjw7dmd6        1/1     Running     0          8h
kube-system                         nvidia-device-plugin-computeinstance-e00mv1d3sabb2nj8pe        1/1     Running     0          8h
soperator                           gpu-fryer-29863275-sq44d                                       0/2     Completed   0          7h25m
soperator                           helm-soperator-dcgm-exporter-ds-kvx8x                          1/1     Running     0          8h
soperator                           helm-soperator-dcgm-exporter-ds-nh6hp                          1/1     Running     0          8h
soperator                           ib-gpu-perf-29863315-r9z7p                                     0/2     Completed   0          6h45m
soperator                           ib-gpu-perf-29863555-v489w                                     0/2     Completed   0          165m
```

```bash
kubectl describe $W | grep -i -E "nvidia|gpu"                                                                                                                                                                                   ─╯

                    beta.kubernetes.io/instance-type=gpu-h100-sxm
                    nebius.com/gpu=true
                    nebius.com/gpu-name=H100
                    nebius.com/nvidia_driver_version=580.173.02
                    nebius.com/resource-preset=1gpu-16vcpu-200gb
                    node.kubernetes.io/instance-type=gpu-h100-sxm
                    nvidia.com/gpu.deploy.operands=false
                    slurm.nebius.ai/workload=gpu
Taints:             nvidia.com/gpu=1:NoSchedule
  NebiusGPUError                False   Mon, 12 Oct 2026 20:37:15 +0400   Mon, 12 Oct 2026 12:36:25 +0400   NoGPUErrorMK8S                All checks have passed
  nvidia.com/gpu:     1
  nvidia.com/gpu:     1
  Kernel Version:                    6.11.0-1016-nvidia
  kube-system                        nebius-node-problem-detector-gpu-qvdr8                     100m (0%)     200m (1%)     200Mi (0%)       400Mi (0%)      8h
  kube-system                        nvidia-device-plugin-computeinstance-e00gp55x6krjw7dmd6    0 (0%)        0 (0%)        0 (0%)           0 (0%)          8h
  nvidia.com/gpu     1               1
```

```bash
kubectl -n soperator exec worker-0 -c slurmd -- nvidia-smi                                                                                                                                                                      ─╯

Mon Oct 12 16:42:02 2026
+-----------------------------------------------------------------------------------------+
| NVIDIA-SMI 580.173.02             Driver Version: 580.173.02     CUDA Version: 13.0     |
+-----------------------------------------+------------------------+----------------------+
| GPU  Name                 Persistence-M | Bus-Id          Disp.A | Volatile Uncorr. ECC |
| Fan  Temp   Perf          Pwr:Usage/Cap |           Memory-Usage | GPU-Util  Compute M. |
|                                         |                        |               MIG M. |
|=========================================+========================+======================|
|   0  NVIDIA H100 80GB HBM3          On  |   00000000:8D:00.0 Off |                    0 |
| N/A   24C    P0             72W /  700W |       0MiB /  81559MiB |      0%      Default |
|                                         |                        |             Disabled |
+-----------------------------------------+------------------------+----------------------+

+-----------------------------------------------------------------------------------------+
| Processes:                                                                              |
|  GPU   GI   CI              PID   Type   Process name                        GPU Memory |
|        ID   ID                                                               Usage      |
|=========================================================================================|
|  No running processes found                                                             |
+-----------------------------------------------------------------------------------------+
```

```bash
kubectl -n soperator exec worker-0 -c slurmd -- nvidia-smi topo -m                                                                                                                                                              ─╯
	GPU0	CPU Affinity	NUMA Affinity	GPU NUMA ID
GPU0	 X 	0-15	0		N/A

Legend:

  X    = Self
  SYS  = Connection traversing PCIe as well as the SMP interconnect between NUMA nodes (e.g., QPI/UPI)
  NODE = Connection traversing PCIe as well as the interconnect between PCIe Host Bridges within a NUMA node
  PHB  = Connection traversing PCIe as well as a PCIe Host Bridge (typically the CPU)
  PXB  = Connection traversing multiple PCIe bridges (without traversing the PCIe Host Bridge)
  PIX  = Connection traversing at most a single PCIe bridge
  NV#  = Connection traversing a bonded set of # NVLinks
```

---

> Separator

## Slurm itself

```bash
kubectl -n soperator exec controller-0 -c slurmctld -- sinfo -N -l                                                                                                                                                              ─╯

Mon Oct 12 16:43:11 2026
NODELIST   NODES PARTITION       STATE CPUS    S:C:T MEMORY TMP_DISK WEIGHT AVAIL_FE REASON
worker-0       1     main*        idle 16      1:8:2 180224        0      1 gpu_h100 none
worker-0       1    hidden        idle 16      1:8:2 180224        0      1 gpu_h100 none
worker-1       1     main*        idle 16      1:8:2 180224        0      1 gpu_h100 none
worker-1       1    hidden        idle 16      1:8:2 180224        0      1 gpu_h100 none
```

```bash
kubectl -n soperator exec controller-0 -c slurmctld -- scontrol show partition                                                                                                                                                  ─╯

PartitionName=main
   AllowGroups=ALL AllowAccounts=ALL AllowQos=ALL
   AllocNodes=ALL Default=YES QoS=N/A
   DefaultTime=NONE DisableRootJobs=NO ExclusiveUser=NO ExclusiveTopo=NO GraceTime=0 Hidden=NO
   MaxNodes=UNLIMITED MaxTime=UNLIMITED MinNodes=0 LLN=NO MaxCPUsPerNode=UNLIMITED MaxCPUsPerSocket=UNLIMITED
   NodeSets=ALL
   Nodes=worker-[0-1]
   PriorityJobFactor=1 PriorityTier=10 RootOnly=NO ReqResv=NO OverSubscribe=YES:4
   OverTimeLimit=NONE PreemptMode=OFF
   State=UP TotalCPUs=32 TotalNodes=2 SelectTypeParameters=NONE
   JobDefaults=(null)
   DefMemPerNode=UNLIMITED MaxMemPerNode=UNLIMITED
   TRES=cpu=32,mem=352G,node=2,billing=32
   ResumeTimeout=GLOBAL SuspendTimeout=GLOBAL SuspendTime=GLOBAL PowerDownOnIdle=NO

PartitionName=hidden
   AllowGroups=ALL AllowAccounts=ALL AllowQos=ALL
   AllocNodes=ALL Default=NO QoS=N/A
   DefaultTime=NONE DisableRootJobs=NO ExclusiveUser=NO ExclusiveTopo=NO GraceTime=0 Hidden=YES
   MaxNodes=UNLIMITED MaxTime=UNLIMITED MinNodes=0 LLN=NO MaxCPUsPerNode=UNLIMITED MaxCPUsPerSocket=UNLIMITED
   NodeSets=ALL
   Nodes=worker-[0-1]
   PriorityJobFactor=1 PriorityTier=10 RootOnly=NO ReqResv=NO OverSubscribe=YES:4
   OverTimeLimit=NONE PreemptMode=OFF
   State=UP TotalCPUs=32 TotalNodes=2 SelectTypeParameters=NONE
   JobDefaults=(null)
   DefMemPerNode=UNLIMITED MaxMemPerNode=UNLIMITED
   TRES=cpu=32,mem=352G,node=2,billing=32
   ResumeTimeout=GLOBAL SuspendTimeout=GLOBAL SuspendTime=GLOBAL PowerDownOnIdle=NO
```

```bash
kubectl -n soperator exec controller-0 -c slurmctld -- scontrol show node                                                                                                                                                       ─╯

NodeName=worker-0 Arch=x86_64 CoresPerSocket=8
   CPUAlloc=0 CPUEfctv=16 CPUTot=16 CPULoad=0.05
   AvailableFeatures=gpu_h100_sxm,network_ssd
   ActiveFeatures=gpu_h100_sxm,network_ssd
   Gres=gpu:nvidia_h100_80gb_hbm3:1
   NodeAddr=10.6.130.62 NodeHostName=worker-0 Version=25.11.8
   OS=Linux 6.11.0-1016-nvidia #16-Ubuntu SMP PREEMPT_DYNAMIC Sun Sep 21 17:06:33 UTC 2025
   RealMemory=180224 AllocMem=0 FreeMem=194711 Sockets=1 Boards=1
   State=IDLE+CLOUD ThreadsPerCore=2 TmpDisk=0 Weight=1 Owner=N/A MCS_label=N/A
   Partitions=main,hidden
   BootTime=2026-10-12T08:50:52 SlurmdStartTime=2026-10-12T08:50:52
   LastBusyTime=2026-10-12T09:15:03 ResumeAfterTime=None
   CfgTRES=cpu=16,mem=176G,billing=16
   AllocTRES=
   CurrentWatts=0 AveWatts=0
   Extra={ "ib_pod": "demo-tier2", "ib_su": "demo-tier1" }
   InstanceId=computeinstance-e00mv1d3sabb2nj8pe
   Topology=default:root:demo-tier2:demo-tier1

NodeName=worker-1 Arch=x86_64 CoresPerSocket=8
   CPUAlloc=0 CPUEfctv=16 CPUTot=16 CPULoad=0.04
   AvailableFeatures=gpu_h100_sxm,network_ssd
   ActiveFeatures=gpu_h100_sxm,network_ssd
   Gres=gpu:nvidia_h100_80gb_hbm3:1
   NodeAddr=10.6.22.178 NodeHostName=worker-1 Version=25.11.8
   OS=Linux 6.11.0-1016-nvidia #16-Ubuntu SMP PREEMPT_DYNAMIC Sun Sep 21 17:06:33 UTC 2025
   RealMemory=180224 AllocMem=0 FreeMem=194776 Sockets=1 Boards=1
   State=IDLE+CLOUD ThreadsPerCore=2 TmpDisk=0 Weight=1 Owner=N/A MCS_label=N/A
   Partitions=main,hidden
   BootTime=2026-10-12T09:25:59 SlurmdStartTime=2026-10-12T09:25:59
   LastBusyTime=2026-10-12T09:55:05 ResumeAfterTime=None
   CfgTRES=cpu=16,mem=176G,billing=16
   AllocTRES=
   CurrentWatts=0 AveWatts=0
   Extra={ "ib_pod": "demo-tier2", "ib_su": "demo-tier1" }
   InstanceId=computeinstance-e00gp55x6krjw7dmd6
   Topology=default:root:demo-tier2:demo-tier1
```

```bash
kubectl -n soperator exec controller-0 -c slurmctld -- scontrol show config | grep -i -E "topology|gres|schedulertype|selecttype|accounting|taskplugin|proctrack|prolog|epilog|clustername"                                     ─╯

AccountingStorageBackupHost = (null)
AccountingStorageEnforce = none
AccountingStorageHost   = localhost
AccountingStorageExternalHost = (null)
AccountingStorageParameters = (null)
AccountingStoragePort   = 0
AccountingStorageTRES   = cpu,mem,energy,node,billing,fs/disk,vmem,pages
AccountingStorageType   = (null)
AccountingStoreFlags    = (null)
ClusterName             = soperator
Epilog[0]               = /opt/slurm_scripts/epilog.sh
EpilogMsgTime           = 2000 usec
GresTypes               = gpu
ProctrackType           = proctrack/cgroup
Prolog[0]               = /opt/slurm_scripts/prolog.sh
PrologEpilogTimeout     = 65534
PrologFlags             = (null)
ResvEpilog              = (null)
ResvProlog              = (null)
SchedulerParameters     = nohold_on_prolog_fail,extra_constraints,pack_serial_at_end,salloc_wait_nodes,sbatch_wait_nodes
SchedulerType           = sched/backfill
SelectType              = select/cons_tres
SelectTypeParameters    = CR_CORE_MEMORY,CR_CORE_DEFAULT_DIST_BLOCK
SrunEpilog              = (null)
SrunProlog              = (null)
TaskEpilog              = (null)
TaskPlugin              = task/cgroup,task/affinity
TaskPluginParam         = (null type)
TaskProlog              = (null)
TopologyParam           = SwitchAsNodeRank
TopologyPlugin          = topology/tree
PMIxShareServerTopology = no
```

```bash
kubectl -n soperator exec controller-0 -c slurmctld -- squeue                                                                                                                                                                   ─╯
             JOBID PARTITION     NAME     USER ST       TIME  NODES NODELIST(REASON)
                15    hidden ib-gpu-p soperato PD       0:00      1 (Priority)
                14    hidden ib-gpu-p soperato PD       0:00      1 (Nodes required for job are DOWN, DRAINED or reserved for jobs in higher priority partitions)
                 7    hidden mem-perf soperato PD       0:00      1 (Resources)
                 6    hidden mem-perf soperato PD       0:00      1 (Resources)
```





