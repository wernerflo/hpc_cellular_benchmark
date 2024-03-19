#!/bin/bash
#SBATCH --walltime=02:00:00

set -e
module purge
module load openmpi

export OMP_NUM_THREADS=$SLURM_CPUS_PER_TASK

num_runs=5

for ((run=1; run<=num_runs; run++))
do
    
    for iterations in 128 256 512; do
        for lines in 1000 10000 50000; do
            echo  "Lines: $lines, Iterations: $iterations"
            echo -n "Run $run: "
            srun -n $SLURM_NPROCS ./Baseline/ca_mpi_p2p_nb $lines $iterations
        done
    done
done