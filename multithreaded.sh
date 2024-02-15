#!/bin/bash
#SBATCH --job-name=julia_multithreaded
#SBATCH --output=./outputs/%x.%j
#SBATCH --error=./outputs/err.%x.%j
#SBATCH --nodes=1 # number of nodes
#SBATCH --ntasks=1 # number of processor cores
#SBATCH --tasks-per-node=1 
#SBATCH --exclusive
#SBATCH --time=00:10:00 # walltime


set -e
JULIA_PATH=~/julia-1.5.3/bin

srun $JULIA_PATH/julia ./ca_multithreaded.jl 33 10