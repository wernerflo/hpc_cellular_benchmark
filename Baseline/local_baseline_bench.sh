#!/bin/bash

#SBATCH --nodes=1 # number of nodes
#SBATCH --ntasks-per-node=1
#SBATCH --exclusive

set -e
module purge
module load openmpi

CPUS_PER_TASK=$1
export OMP_NUM_THREADS=$CPUS_PER_TASK


num_runs=5

for ((run=1; run<=num_runs; run++))
do
    
    for iterations in 128 256 512; do
        for lines in 1000 10000 50000; do
            echo  "Lines: $lines, Iterations: $iterations"
            echo -n "Run $run:"
            srun -n $SLURM_NPROCS --ntasks-per-node 1 --cpus-per-task $CPUS_PER_TASK ./ca_mpi_p2p_nb_hybrid $lines $iterations
        done
    done
done