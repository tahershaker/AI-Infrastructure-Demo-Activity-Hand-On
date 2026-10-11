# 02-Provision

> Provisioning a Slurm cluster on top a Nebius Managed Kubernetes using `Soperator` latest release that is based on Terraform

---

# Description

This section is focused on provisioning the required infrastrcutre that will be used to fulfil the requested tasks - Model Fine-Tuning & Model Inferenceing - using the `Soperator` based on the provided tasks.

This section will cover everything related to this phase starting by how the `Soperator` terraform works, what gets provisioned, how, and most importantly the workarounds added to overcome several limitations due to the limited resources available that do not allign well with the `Soparator` if we use it as-is.

As explained in the [Main_ReadMe_File](/README.md) - we are looking at a task to run a fin-tuning job usgin Slurm running on top of Kubernetes. We are also tasks to use `Soperator` which is (Slurm-on-Kubernetes Operator) is an open-source Kubernetes operator developed by Nebius that runs and manages Slurm clusters on top of Kubernetes. It is designed for artificial intelligence (AI) training and high-performance computing (HPC) workloads on GPU infrastructure. You can read more about it [here - Introducing Soperator: a Kubernetes Operator for Slurm](https://nebius.com/blog/posts/introducing-soperator) or [here - Explaining Soperator, Nebius’ open-source Kubernetes operator for Slurm](https://nebius.com/blog/posts/soperator-in-open-source-explained) and you can check its [GitHub](https://github.com/nebius/nebius-solutions-library/tree/main/soperator)

