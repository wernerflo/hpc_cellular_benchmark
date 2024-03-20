#!/bin/bash
#SBATCH --time=01:00:00

set -e
module purge
module load openmpi

CPUS_PER_TASK=$1
export OMP_NUM_THREADS=$CPUS_PER_TASK

for iterations in 128 256 512; do
    for lines in 1000 10000 50000; do
            srun -n $SLURM_NPROCS --ntasks-per-node 1 --cpus-per-task $CPUS_PER_TASK valgrind --tool=massif --massif-out-file="${CPUS_PER_TASK}_massiv_${lines}_${iterations}.out.%p" ./Baseline/ca_mpi_p2p_nb_hybrid $lines $iterations
    done
done