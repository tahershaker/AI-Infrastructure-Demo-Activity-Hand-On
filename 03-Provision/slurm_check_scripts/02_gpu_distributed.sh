#!/bin/bash

#SBATCH --job-name=gpu
#SBATCH --output=results/gpu.out
#SBATCH --error=results/gpu.out
#SBATCH --nodes=2
#SBATCH --ntasks-per-node=1
#SBATCH --gpus-per-node=1
#SBATCH --cpus-per-task=4
#SBATCH --mem=16G

# Show the GPU model, GPU memory and driver version on each node
srun bash -c 'echo "GPU on $(hostname):" && nvidia-smi --query-gpu=name,memory.total,driver_version --format=csv,noheader
