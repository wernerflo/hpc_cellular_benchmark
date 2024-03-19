#!/bin/bash
#SBATCH --walltime=02:00:00

set -e
module purge
module load openmpi

JULIA_PATH=~/julia-1.5.3/bin
export JULIA_NUM_THREADS=$SLURM_CPUS_PER_TASK

 
for iterations in 128 256 512; do
    for lines in 1000 10000 50000; do
        srun -n $SLURM_NPROCS --ntasks-per-node 1 --cpus-per-task $SLURM_CPUS_PER_TASK $JULIA_PATH/julia ./julia/julia_ca_mpi_benchmarking.jl $lines $iterations nb_parallel
    done
done
