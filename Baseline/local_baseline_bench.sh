#!/bin/bash
#SBATCH --output=./outputs/test.%j
#SBATCH --nodes=1 # number of nodes
#SBATCH --ntasks-per-node=1
#SBATCH --cpus-per-task=12
#SBATCH --exclusive

set -e
module purge
module load openmpi

export OMP_NUM_THREADS=$SLURM_CPUS_PER_TASK

num_runs=5

for iterations in 128 256 512; do
    for lines in 1000 10000 50000; do
        echo  "Lines: $lines, Iterations: $iterations"
        for ((run=1; run<=num_runs; run++))
        do
            echo -n "Run $run: "
            srun -n $SLURM_NPROCS --ntasks-per-node 1 --cpus-per-task $SLURM_CPUS_PER_TASK ./Baseline/ca_mpi_p2p_nb_hybrid $lines $iterations
        done
        echo " "
    done
done