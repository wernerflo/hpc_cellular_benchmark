#!/bin/bash
#SBATCH --job-name=julia_mpi_bench
#SBATCH --output=./benchmarks/%x.%j
#SBATCH --error=./errors/err.%x.%j
#SBATCH --nodes=4 # number of nodes
#SBATCH --ntasks-per-node=1
#SBATCH --cpus-per-task=4
#SBATCH --exclusive
#SBATCH --time=00:10:00 # walltime

set -e
module purge
module load openmpi

JULIA_PATH=~/julia-1.5.3/bin
export JULIA_NUM_THREADS=$SLURM_CPUS_PER_TASK

for iterations in 128 256 512; do
    for lines in 1000 10000 50000; do
        mpiexec -n $SLURM_NPROCS $JULIA_PATH/julia ./ca_mpi_blocking.jl $lines $iterations
    done
done