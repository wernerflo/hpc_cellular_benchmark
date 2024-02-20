#!/bin/bash
#SBATCH --output=out.%j
#SBATCH --error=err.%j
#SBATCH --nodes=1 # number of nodes
#SBATCH --ntasks=1 # number of processor cores
#SBATCH --exclusive
#SBATCH --time=00:03:00 # walltime
# Good Idea to stop operation on first error.
set -e
module load gcc

gcc -fPIC -c time_measurement.c -o time_measurement.o 
gcc -fPIC -c random.c -o random.o
gcc -shared -o libutility.so ca_common.o random.o

rm time_measurement.o random.o