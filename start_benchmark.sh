#!/bin/bash

# Define an array of CPU allocations (number of threads)
cpu_allocations=(1 2 4 6 8 10 12 14 16 18 20 22 24) 

# Loop through each CPU allocation and submit a job
for cpus_per_task in "${cpu_allocations[@]}"; do
    sbatch --cpus-per-task=$cpus_per_task --job-name=local_hybrid_$cpus_per_task --output=./benchmarks/local_$cpus_per_task.%j --error=./errors/err.local_$cpus_per_task.%j --exclusive local_hybrid_bench.sh $cpus_per_task # Submit the job script
done