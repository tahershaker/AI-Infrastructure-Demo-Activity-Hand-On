#!/bin/bash

#SBATCH --job-name=nccl
#SBATCH --output=results/nccl.out
#SBATCH --error=results/nccl.out
#SBATCH --nodes=2
#SBATCH --ntasks-per-node=1
#SBATCH --gpus-per-node=1
#SBATCH --cpus-per-task=8
#SBATCH --mem=64G

# Show which network transport NCCL picks (expect NET/Socket, as there is no InfiniBand)
export NCCL_DEBUG=INFO
export NCCL_DEBUG_SUBSYS=INIT,NET

# Use more parallel TCP connections, as one connection rarely fills a fast link
export NCCL_SOCKET_NTHREADS=4
export NCCL_NSOCKS_PERTHREAD=4

# Run a multi-node MPI NCCL test, one rank per node
srun --mpi=pmix \
    bash -c 'echo "Run a multi-node all_reduce_perf_mpi on $(hostname) (rank $SLURM_PROCID):" && all_reduce_perf_mpi -b 512M -e 8G -f 2 -g 1'
