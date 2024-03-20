#!/bin/bash
#SBATCH --output=./outputs/%x.%j
#SBATCH --error=./outputs/err.%x.%j

cpu_allocations=(1 12 24) 

for cpus_per_task in "${cpu_allocations[@]}"; do
    sbatch --nodes=1 --ntasks-per-node=1 --cpus-per-task=$cpus_per_task --job-name=experiment1_$cpus_per_task --output=./benchmarks/experiment_5/Julia/local_$cpus_per_task.%j --error=./errors/experiment_1/julia_err.local_$cpus_per_task.%j --exclusive experiment_5_julia.sh $cpus_per_task
    sbatch --nodes=1 --ntasks-per-node=1 --cpus-per-task=$cpus_per_task --job-name=experiment1_$cpus_per_task --output=./benchmarks/experiment_1/Baseline/local_$cpus_per_task.%j --error=./errors/experiment_1/baseline_err.local_$cpus_per_task.%j --exclusive experiment_5_baseline.sh $cpus_per_task

done