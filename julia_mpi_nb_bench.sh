#!/bin/bash
#SBATCH --job-name=julia_non_blocking_bench
#SBATCH --output=./outputs/%x.%j
#SBATCH --error=./outputs/err.%x.%j
#SBATCH --nodes=4 # number of nodes
#SBATCH --ntasks-per-node=1
#SBATCH --cpus-per-task=4 
#SBATCH --exclusive
#SBATCH --time=00:10:00 # walltime

set -e
module purge
module load openmpi

JULIA_PATH=~/julia-1.5.3/bin

for iterations in 128 256 512; do
    for lines in 1000 10000 50000; do
        mpiexec -n $SLURM_NPROCS $JULIA_PATH/julia ./ca_mpi_nb.jl $lines $iterations
        mpiexec -n $SLURM_NPROCS $JULIA_PATH/julia ./ca_mpi_nb_hybrid.jl $lines $iterations
    done
done