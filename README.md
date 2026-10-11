# AI-Infrastructure-Demo-Activity-Hand-On

*A hands-on log of one assignment on Nebius AI Cloud: build a Slurm cluster on Kubernetes, fine-tune a language model on it, serve the model, and compare it with the original. Every step is recorded and explained in simple words.*

---

## Description

This repo records, step by step, how I completed a hands-on AI infrastructure assignment on **Nebius AI Cloud**. The assignment asks for a Slurm cluster that runs on Kubernetes, built with **Soperator** (Nebius' open-source Kubernetes operator for Slurm). On that cluster, I fine-tune a language model, serve the fine-tuned model, compare it with the original model, and ensure the GPU utilization is above 80%.

The repo has two goals:

1. **A clear record.** It shows what was built and what was done, in the order it happened, so you can follow every step.
2. **A simple explanation.** It explains the ideas behind each step, for example what the architecture is, how the cluster is set up, and why LoRA is used.

The work is split into folders. Each folder covers one part and has its own README. The README explains the topic first, then lists the step-by-step actions that were taken. The repo also records the problems met on the way, and how each one was solved.

---

## The Tasks

The assignment has four tasks. **Task 1 is required.** Completing it is enough to pass. Tasks 2 to 4 are bonus objectives.

| # | Task | Type | Covered in |
|:---|:---|:---|:---|
| 1 | Run a distributed training or fine-tuning job using Soperator, with the latest release tag of `Soperator` | Required | [03-Provision](03-Provision/README.md), [04-Fine-Tuning](04-Fine-Tuning/README.md) |
| 2 | Serve the trained model for inference on the same Kubernetes cluster | Bonus | [05-Serve](05-Serve/README.md) |
| 3 | Run the original model before fine-tuning, and compare its results with the fine-tuned model | Bonus | [06-Benchmarking](06-Benchmarking/README.md) |
| 4 | Reach GPU utilization above 80% (the Nebius console dashboards can be used to track it) | Bonus | N/A |

Task 1 needs a working cluster, so the cluster is built first. Any model and any dataset are allowed.

> **Assumption for Task 4.** The assignment does not say which workload the 80% target applies to. I assume it applies to the **fine-tuning job, on both GPUs, during its steady training phase.** 

---

## Important Notes from the Assignment

These points shape the whole design, so they are listed here before anything else.

| Topic | What the assignment says | What it means in this repo |
|:---|:---|:---|
| GPU capacity | 2 x H100 GPUs in total for training and inference, with 1 x H100 per node | Two GPU nodes. Training uses both. Training and serving share the same GPUs, so they are planned to run one after the other |
| Clusters | One Managed Kubernetes cluster at a time | Any test cluster is deleted before the real deployment |
| **No InfiniBand** | The single-H100 node preset does not support InfiniBand. The standard Soperator Terraform recipe assumes an InfiniBand fabric and a GPU Cluster resource, so it will not work as it is | The recipe is adapted for single-GPU nodes. GPU-to-GPU traffic runs over normal Ethernet, so I use **LoRA** fine-tuning to keep that traffic small. See [02-Strategy](02-Strategy/README.md) and [03-Provision](03-Provision/README.md) |
| Release tag | Use the latest release tag, not `main` | I use release `4.1.13-2` of the Soperator Terraform recipe (tag `soperator-v4.1.13-2`), which was the latest tag when the work started |
| Separate filesystems | Do not use the same shared filesystem for two different jails | Each jail gets its own filesystem |
| Observability setting | Set `public_o11y_enabled = false` in the `.tfvars` file, to work around an open issue in the recipe | Set in my `tfvars`. See [03-Provision](03-Provision/README.md) |
| Model and dataset | Any model and any dataset | A small text-only LLM, explained in [02-Strategy](02-Strategy/README.md) |
| AI tools | AI-assisted tools are allowed, but I must be able to explain everything I submit | Every file and step in this repo is explained in simple words |
| Environment | Keep the lab running and intact for the Demo Day review. Decommission the cluster afterwards | The cluster stays up until the review |

### vCPU guidelines for the Soperator cluster

The assignment gives this sizing guide for the cluster's non-GPU nodes. It does not say how many vCPUs the two GPU nodes add.

| Nodeset | Platform | Preset | vCPU per node | Node count | Baseline vCPU |
|:---|:---|:---|:---|:---|:---|
| System | `cpu-d3` | `8vcpu-32gb` | 8 | 4 to 5, autoscaled | 32 |
| Login | `cpu-d3` | `16vcpu-64gb` | 16 | 1 | 16 |
| Accounting | `cpu-d3` | `8vcpu-32gb` | 8 | 1 | 8 |
| Controller | `cpu-d3` | `4vcpu-16gb` | 4 | 1 | 4 |
| NFS | `cpu-d3` | `4vcpu-16gb` | 4 | 1 | 4 |
| **Baseline total** | | | | **8 nodes** | **64** |

---

## Repository Structure

Here is everything in the repo, and what each part is for:

```
AI-Infrastructure-Demo-Activity-Hand-On/
├── 01-Infra-Arch/                 # Architecture of the cluster
│   ├── Images/
│   └── README.md
├── 02-Strategy/                   # The plan and the reasons behind it
│   ├── Images/
│   └── README.md
├── 03-Provision/                  # Building the cluster with the Soperator Terraform recipe
│   ├── Images/
│   ├── soperator-tf-4.1.13-2/     # Copy of the recipe release used
│   └── README.md
├── 04-Fine-Tuning/                # LoRA fine-tuning job on Slurm
│   ├── Images/
│   └── README.md
├── 05-Serve/                      # Serving the fine-tuned model
│   ├── Images/
│   └── README.md
├── 06-Benchmarking/               # Original model against fine-tuned model
│   ├── Images/
│   └── README.md
├── 07-Finding-&-Troubleshootings/ # Problems met and how they were solved
│   ├── <one sub-folder per issue>/
│   └── README.md
├── .gitignore
└── README.md                      # This file
```

Every numbered folder has its own `README.md`. The folders follow the order of the assignment, so the structure matches the tasks.

---

## What Each Folder Covers

| Folder | What it covers | Task |
|:---|:---|:---|
| [01-Infra-Arch](01-Infra-Arch/README.md) | The architecture of the cluster built with Soperator: the Slurm login, controller, accounting and worker nodes, the shared jail filesystem, the networking, and how the parts fit together. Includes diagrams | 1 |
| [02-Strategy](02-Strategy/README.md) | The plan and the reasons behind each choice: why a LoRA fine-tune, how LoRA keeps GPU-to-GPU traffic small without InfiniBand, how training and serving share two GPUs, and the assumptions made | 1 to 4 |
| [03-Provision](03-Provision/README.md) | Everything about building the cluster with the Soperator Terraform recipe: the changes needed for single-GPU nodes without InfiniBand, the settings used, the apply, and the checks that prove the cluster works | 1 |
| [04-Fine-Tuning](04-Fine-Tuning/README.md) | The model and dataset choice, the LoRA fine-tuning job run across both GPU nodes with Slurm, the results, and how GPU utilization was measured | 1, 4 |
| [05-Serve](05-Serve/README.md) | How the fine-tuned model is served for inference on the same Kubernetes cluster | 2 |
| [06-Benchmarking](06-Benchmarking/README.md) | The comparison of the original model with the fine-tuned model, using the same prompts and the same test data | 3 |
| [07-Finding-&-Troubleshootings](07-Finding-&-Troubleshootings/README.md) | Every problem met during the task and how it was solved. Each issue has its own sub-folder | All |

---

## How to Go Through This Repo

You can read the repo in two ways, depending on what you need.

**To understand the whole task**, read it in order:

1. Start with this README, to see the tasks and the limits.
2. Read [01-Infra-Arch](01-Infra-Arch/README.md) to see what is being built, and to learn the main terms: Slurm, Soperator and the jail.
3. Read [02-Strategy](02-Strategy/README.md) to see why the design looks the way it does.
4. Follow [03-Provision](03-Provision/README.md), [04-Fine-Tuning](04-Fine-Tuning/README.md), [05-Serve](05-Serve/README.md) and [06-Benchmarking](06-Benchmarking/README.md) in that order. Each one builds on the one before it: the cluster comes first, then the fine-tuning, then serving, then the comparison.
5. Use [07-Finding-&-Troubleshootings](07-Finding-&-Troubleshootings/README.md) at any time. Where a step hit a problem, the folder README points to the related issue.

---
