#!/bin/bash
#SBATCH --job-name=baseline_ca
#SBATCH --output=./benchmarks/%x.%j
#SBATCH --error=./errors/err.%x.%j
#SBATCH --nodes=1
#SBATCH --ntasks-per-node=1
#SBATCH --cpus-per-task=4
#SBATCH --exclusive
#SBATCH --time=00:10:00   # Adjust the time as needed

set -e

source /etc/profile.d/modules.sh
module purge

module load openmpi

export OMP_NUM_THREADS=$SLURM_CPUS_PER_TASK
for iterations in 128 256 512; do
    for lines in 1000 10000 50000; do
        srun -n $SLURM_NPROCS --ntasks-per-node 1 --cpus-per-task $SLURM_CPUS_PER_TASK ./ca_mpi_p2p_nb_hybrid $lines $iterations
    done
done
#make bench