#!/bin/bash
#SBATCH --job-name=compare_md5
#SBATCH --output=%x.%j
#SBATCH --error=err.%x.%j
#SBATCH --nodes=1
#SBATCH --tasks-per-node=1
#SBATCH --cpus-per-task=4
#SBATCH --time=1:00:00

# Load necessary modules (if needed)
set -e
module load gcc

JULIA_PATH=~/julia-1.5.3/bin

# Run the compiled C program
srun ./c_test

# Run the Julia file
srun $JULIA_PATH/julia ./julia_test.jl