#!/bin/bash
#SBATCH --job-name=julia_mpi_bench
#SBATCH --output=./benchmarks/%x.%j
#SBATCH --error=./errors/err.%x.%j
#SBATCH --nodes=1 # number of nodes
#SBATCH --ntasks-per-node=1
#SBATCH --cpus-per-task=1
#SBATCH --exclusive
#SBATCH --time=00:10:00 # walltime

set -e
module purge
module load openmpi

JULIA_PATH=~/julia-1.5.3/bin
export JULIA_NUM_THREADS=$SLURM_CPUS_PER_TASK

srun -n $SLURM_NPROCS $JULIA_PATH/julia ./julia/julia_ca_mpi_benchmark_memory.jl 50000 512 nb_parallel