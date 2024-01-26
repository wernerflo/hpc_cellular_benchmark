#!/bin/bash
# Do not forget to select a proper partition if the default # one is no fit for the job!
#SBATCH --output=out.%j
#SBATCH --error=err.%j
#SBATCH --nodes=1 # number of nodes
#SBATCH --ntasks=1 # number of processor cores
#SBATCH --exclusive
#SBATCH --time=00:03:00 # walltime
# Good Idea to stop operation on first error.
set -e
module load gcc

#gcc -I/usr/include -L/usr/lib/x86_64-linux-gnu -lssl -lcrypto -fPIC -c ca_common.c -o ca_common.o 
#gcc -fPIC -c random.c -o random.o
gcc -shared -o libutility.so ca_common.o random.o
