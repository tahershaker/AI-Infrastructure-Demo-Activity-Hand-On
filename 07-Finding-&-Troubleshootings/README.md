# 07-Finding-&-Troubleshootings

*A log of every problem met during the assignment: what broke, how I found the cause, and how I got past it.*

---

## Description

This folder records the problems I met whilst building the cluster and running the workload. Each problem has its own sub-folder with its own README. The README follows one pattern: what happened, the troubleshooting steps in the order I ran them, the cause, and the workaround.

I kept this log for two reasons. It shows how I found each cause, step by step, not only the final fix. It also gives the Nebius team the actions I took to fix each issue, so they can review them.

You can use this folder in two ways. To see everything that went wrong, go through the issues one by one, in the order shown in the Issues Log below. To look at one specific problem, use the table to jump straight to that issue.

The README of each phase folder explains in detail what was done in that phase. If an issue was met during that phase, the README has a link to the matching issue in this folder. So you can follow the main story in the phase folders, and open this folder only when you want the full detail of a problem and its fix.

---

## Issues Log

| # | Issue | Phase | Short description |
|:---|:---|:---|:---|
| 01 | [Permission denied for the provided tfstate service account](/07-Finding-&-Troubleshootings/01-Permission-Denied-SA-Bucket/README.md) | 03-Provision | The provided service account cannot access the provided state bucket (HTTP 403), so `terraform init` fails |
| 02 | [Permission denied reading the tenant data source](/07-Finding-&-Troubleshootings/02-Permission-Denied-Reading-Tenant-Data-Source/README.md) | 03-Provision | My user cannot read the tenant, and the recipe reads it in an unused lookup, so `terraform plan` stops |
| 03 | [Disk quota limit](/07-Finding-&-Troubleshootings/03-Qouta-Limitation-On-Disk/README.md) | 03-Provision | The project allows only 2048 GiB of Network SSD, so the NFS disk could not be created and `terraform apply` stalled |
| 04 | [GRES data written for 8-GPU nodes](/07-Finding-&-Troubleshootings/04-Gres-Data-8-GPU/README.md) | 03-Provision | The recipe describes an 8-GPU node, but mine have 1 GPU, so the Slurm controller crashes in a loop |

---
