#!/bin/bash

#SBATCH --nodes=1 # number of nodes
#SBATCH --ntasks-per-node=1
#SBATCH --exclusive

set -e
module purge
module load openmpi

JULIA_PATH=~/julia-1.5.3/bin

CPUS_PER_TASK=$1
export JULIA_NUM_THREADS=$CPUS_PER_TASK

 
for iterations in 128 256 512; do
    for lines in 1000 10000 50000; do
        echo "Benchmarking for $lines lines and $iterations iterations"
        srun -n $SLURM_NPROCS --ntasks-per-node 1 --cpus-per-task $CPUS_PER_TASK $JULIA_PATH/julia ./ca_nb_hybrid_benchmarking.jl $lines $iterations
    done
done
