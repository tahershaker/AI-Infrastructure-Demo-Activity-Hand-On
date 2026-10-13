#!/bin/bash

#SBATCH --job-name=hello
#SBATCH --output=results/hello.out
#SBATCH --error=results/hello.out
#SBATCH --nodes=2
#SBATCH --ntasks-per-node=1
#SBATCH --cpus-per-task=4
#SBATCH --mem=16G

# Print hello from each node
srun bash -c 'echo "Hello from $(hostname)"'

# Run a job step with redefined resource allocations
srun --cpus-per-task=2 \
    bash -c 'echo "Number of CPUs available for the job step on $(hostname):" && nproc'
