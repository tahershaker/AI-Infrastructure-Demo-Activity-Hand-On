# List Of Available Values In terraform.tfvars

## What it is

`terraform.tfvars` is the file where you give values to the variables that `variables.tf` declares. Terraform reads it automatically. It holds every choice that is specific to a cluster: names, node sizes, disk sizes, storage, and which features are on. A few other values (region, tenant, project, subnet, token) do not live here: `.envrc` exports them as `TF_VAR_*` environment variables.

`variables.tf` also checks the values. For example, it rejects boot disks below a minimum size per node type, and it requires `iam_merge_request_url` when `production = true`. If a value is wrong, `terraform plan` stops with the name of the rule.

## All available options

### Identity and release

| Option | What it does |
|---|---|
| `company_name` | Name used for the Mk8s cluster, the Slurm cluster and the `kubectl` context. Required. |
| `production` | Marks the cluster as production. If `true`, `iam_merge_request_url` must be set. |
| `iam_merge_request_url` | Link to the IAM merge request that production Soperator Pro clusters need. Leave empty when `production = false`. |
| `slurm_operator_version` | Soperator version (charts and images). Do not change it without a reason. |
| `slurm_operator_stable` | `true` pulls charts and images from the stable registry, `false` from the unstable one. |

### Storage

| Option | What it does |
|---|---|
| `filestore_jail` | The jail: the shared root filesystem used by controller, login and workers. Either `spec` (Terraform creates it: size, block size, `forbid_deletion`) or `existing` (a filesystem ID; the cluster overwrites its data). |
| `filestore_jail_submounts` | Extra shared filesystems mounted inside the jail (name, `mount_path`, and `spec` or `existing`). Good for datasets and checkpoints. |
| `allow_empty_jail_submounts` | Turns off the check that a submount is not empty. |
| `filestore_controller_spool` | Shared filesystem for the controller. Deprecated since 1.22; controller state is on a network SSD disk. Kept for compatibility. |
| `filestore_accounting` | Shared filesystem for the accounting database. Needed only if accounting is on. |
| `controller_state_on_filestore` | `true` keeps controller state on a Filestore, `false` on a disk (PVC). |
| `nfs_in_k8s` | NFS server running inside Kubernetes, mounted at `/home` (`enabled`, `version`, `size_gibibytes`, `disk_type`, `filesystem_type`, `threads`). For code and configs, not for datasets or checkpoints. |
| `nfs` | The older NFS server on its own VM. Off by default. Do not use together with `nfs_in_k8s`. |

### Kubernetes and nodes

| Option | What it does |
|---|---|
| `k8s_version` | Kubernetes version (`<major>.<minor>`). `null` uses the Nebius default. |
| `etcd_cluster_size` | Size of the control plane etcd cluster. Default 3. |
| `slurm_nodeset_system` | System node group: hosts Soperator, observability and other services. `min_size`, `max_size` (autoscaled), `resource`, `boot_disk`. |
| `slurm_nodeset_controller` | Controller node group (`size`, `resource`, `boot_disk`). Only one controller is supported. |
| `slurm_nodeset_login` | Login: `size` is the number of login pods; `node_group_enabled` creates a dedicated login node group; `resource`, `boot_disk`. |
| `slurm_nodeset_accounting` | Node group for MariaDB and the accounting daemon. Required if accounting is on. |
| `slurm_nodeset_nfs` | Node group for the NFS server (`size`, `resource`, `boot_disk`). |
| `slurm_nodeset_workers` | The list of worker NodeSets. Fields are in the next table. |
| `k8s_cluster_node_ssh_access_users` | Users and public keys for SSH to the Kubernetes nodes themselves. |
| `nvidia_config_lines` | Lines written to `/etc/modprobe.d/nvidia_config.conf` on GPU workers by cloud-init. |
| `use_preinstalled_gpu_drivers` | `true`: the node image brings the drivers ("driverfull"). `false`: the NVIDIA operators install them. |
| `platform_cuda_versions` | CUDA version per platform used by Soperator. |
| `platform_driver_presets` | GPU driver preset per platform. |
| `maintenance_ignore_node_groups` | Node groups that Soperator ignores for maintenance events (Mk8s handles them). |
| `maintenance` | Maintenance mode (`none` by default). Used to repopulate the jail or recreate all pods. |
| `use_default_apparmor_profile` | Loads the default AppArmor profile on Soperator nodes and selects it for login and worker containers. |

### Fields of a worker NodeSet (`slurm_nodeset_workers`)

| Field | What it does |
|---|---|
| `name` | Name prefix; `worker` gives Slurm nodes `worker-0`, `worker-1`. |
| `size` | Number of worker nodes. |
| `autoscaling.enabled`, `autoscaling.min_size` | Autoscaling of the node group. `min_size = null` means min = max: no scale-down. |
| `resource.platform`, `resource.preset` | VM type, for example `gpu-h100-sxm` and `1gpu-16vcpu-200gb`. |
| `boot_disk` | Boot disk type and size. Workers need at least 512 GiB. |
| `gpu_cluster` | InfiniBand fabric: `id` of an existing GPU cluster, or `infiniband_fabric` to create one. `null` for presets without InfiniBand. |
| `preemptible` | `{}` uses preemptible VMs, `null` normal VMs. |
| `reservation_policy` | Use of compute reservations (`AUTO`, `FORBID`, `STRICT`) and optional reservation IDs. |
| `nvlink` | NVLink instance groups. Required for GB300 only. |
| `placement_policy_nodes` | Optional list of hosts where VMs can run (non-production only). |
| `features` | List of strings that become Slurm node features. |
| `create_partition` | Creates a Slurm partition for this NodeSet. |
| `ephemeral_nodes`, `initial_number_ephemeral_nodes` | Ephemeral behavior: dynamic topology and Slurm power management. Off by default. |
| `persistent_volume_claim_retention_policy` | Whether PVCs are kept (`Retain`) or deleted (`Delete`) when the NodeSet is deleted or scaled. |
| `local_nvme` | Local NVMe disks as a RAID0 mount on the node. |
| `node_local_jail_submounts` | Extra network SSD disks per worker, mounted into the jail. Each one uses disk quota. |
| `node_local_image_disk` | Extra disk per worker for Docker and Enroot images. Each one uses disk quota. |

### Slurm, login and features

| Option | What it does |
|---|---|
| `slurm_nodesets_partitions` | Slurm partitions: `name`, `is_all` or `slurm_nodeset_refs`, `config` string. Keep `hidden`. Exactly one partition has `Default=YES`. |
| `slurm_partition_config_type` | `default` (built from the list above) or `custom` (raw lines). |
| `slurm_partition_raw_config` | Raw `PartitionName=...` lines for `custom`. |
| `slurm_health_check_config` | Slurm `HealthCheckProgram` settings. |
| `slurm_topology_block_size` | Block size for the `topology/block` plugin. GB300 only. |
| `slurm_shared_memory_size_gibibytes` | Shared memory size for controller and worker pods. |
| `slurm_exporter_enabled` | Slurm metrics exporter. |
| `slurm_rest_enabled` | Slurm REST API. |
| `slurm_login_public_ip` | Public IP for the login load balancer (`false` = private). |
| `slurm_login_ssh_root_public_keys` | SSH public keys accepted for `root` on the login pod. |
| `slurm_login_sshd_config_map_ref_name`, `slurm_worker_sshd_config_map_ref_name` | Custom sshd configuration from a ConfigMap. |
| `tailscale_enabled` | Tailscale init container on the login pod. |
| `slurm_sssd_enabled`, `slurm_sssd_conf_secret_ref_name`, `slurm_sssd_ldap_ca_config_map_ref_name` | SSSD sidecar for IAM and LDAP integration. |
| `gb300_login_pod_worker_reserve` | Resources reserved on GB300 workers for login pods. GB300 only. |
| `active_checks_scope` | Which health checks run after the cluster is created: `prod_acceptance`, `prod_quick`, `testing`, `dev`, `essential`. Terraform waits for them. |
| `accounting_enabled` | Slurm accounting (`sacct`, job history) with MariaDB. |
| `slurmdbd_config`, `slurm_accounting_config` | `slurmdbd.conf` and accounting settings in `slurm.conf`. |
| `soperator_notifier` | Slack notifications for job events (needs a webhook URL). |

### Observability and backups

| Option | What it does |
|---|---|
| `telemetry_enabled` | In-cluster monitoring stack (VictoriaMetrics, Grafana, logs). |
| `dcgm_job_mapping_enabled` | Separate DCGM exporter that adds the Slurm job to GPU metrics. |
| `public_o11y_enabled` | Sends system logs to Nebius observability. Needs `o11y_profile`. |
| `allow_o11y_region_migration` | Allows moving an existing o11y logs project to the cluster region. |
| `backups_enabled` | `auto` (on if the jail is under 12 TiB), `force_enable`, `force_disable`. |
| `backups_password`, `backups_schedule`, `backups_prune_schedule`, `backups_retention` | Backup encryption, schedules and how many backups to keep. |
| `cleanup_bucket_on_destroy` | Delete all backup data when the cluster is destroyed. |

---
