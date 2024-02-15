#!/bin/bash
#SBATCH --job-name=julia_mpi_non_blocking
#SBATCH --output=./outputs/%x.%j
#SBATCH --error=./outputs/err.%x.%j
#SBATCH --nodes=4 # number of nodes
#SBATCH --ntasks-per-node=1 
#SBATCH --exclusive
#SBATCH --time=00:10:00 # walltime

set -e
module purge
module load openmpi

JULIA_PATH=~/julia-1.5.3/bin

mpiexec -n $SLURM_NPROCS $JULIA_PATH/julia ./ca_mpi_non_blocking.jl 33 10