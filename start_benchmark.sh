#!/bin/bash
#SBATCH --output=./outputs/%x.%j
#SBATCH --error=./outputs/err.%x.%j


# experiment 1
cpu_allocations=(1 2 4 6 8 10 12 14 16 18 20 22 24) 

for cpus_per_task in "${cpu_allocations[@]}"; do
    sbatch --nodes=1 --ntasks-per-node=1 --cpus-per-task=$cpus_per_task --job-name=experiment1_$cpus_per_task --output=./benchmarks/experiment_1/Julia/local_$cpus_per_task.%j --error=./errors/experiment_1/julia_err.local_$cpus_per_task.%j --exclusive experiment_1_julia.sh $cpus_per_task
    sbatch --nodes=1 --ntasks-per-node=1 --cpus-per-task=$cpus_per_task --job-name=experiment1_$cpus_per_task --output=./benchmarks/experiment_1/Baseline/local_$cpus_per_task.%j --error=./errors/experiment_1/baseline_err.local_$cpus_per_task.%j --exclusive experiment_1_baseline.sh $cpus_per_task

done


# experiment 2
node_allocations=(1 2 3 4)

for nodes in "${node_allocations[@]}"; do
    sbatch --nodes=$nodes --ntasks-per-node=1 --cpus-per-task=24 --job-name=experiment2_$nodes --output=./benchmarks/experiment_2/Julia/nodes_$nodes.%j --error=./errors/experiment_2/julia_err.nodes_$nodes.%j --exclusive experiment_2_julia.sh
    sbatch --nodes=$nodes --ntasks-per-node=1 --cpus-per-task=24 --job-name=experiment2_$nodes --output=./benchmarks/experiment_2/Baseline/nodes_$nodes.%j --error=./errors/experiment_2/baseline_err.nodes_$nodes.%j --exclusive experiment_2_baseline.sh
done


# experiment 3
node_allocations=(1 2 3 4)

for nodes in "${node_allocations[@]}"; do
    sbatch --nodes=$nodes --ntasks-per-node=1 --cpus-per-task=1 --job-name=experiment3_$nodes --output=./benchmarks/experiment_3/Julia/1_Task/nodes_$nodes.%j --error=./errors/experiment_3/julia_err.1TaskNodes_$nodes.%j --exclusive experiment_3_julia.sh $nodes
    sbatch --nodes=$nodes --ntasks-per-node=1 --cpus-per-task=1 --job-name=experiment3_$nodes --output=./benchmarks/experiment_3/Baseline/1_Task/nodes_$nodes.%j --error=./errors/experiment_3/baseline_err.1TaskNodes_$nodes.%j --exclusive experiment_3_baseline.sh $nodes


    sbatch --nodes=$nodes --ntasks-per-node=24 --cpus-per-task=1 --job-name=experiment3_$nodes --output=./benchmarks/experiment_3/Julia/24_Tasks/nodes_$nodes.%j --error=./errors/experiment_3/julia_err.24TasksNodes_$nodes.%j --exclusive experiment_3.sh $nodes
    sbatch --nodes=$nodes --ntasks-per-node=24 --cpus-per-task=1 --job-name=experiment3_$nodes --output=./benchmarks/experiment_3/Baseline/24_Tasks/nodes_$nodes.%j --error=./errors/experiment_3/baseline_err.24TasksNodes_$nodes.%j --exclusive experiment_3.sh $nodes

done


# experiment 4
node_allocations=(1 2 3 4)

for nodes in "${node_allocations[@]}"; do
    sbatch --nodes=$nodes --ntasks-per-node=1 --cpus-per-task=1 --job-name=experiment4_$nodes --output=./benchmarks/experiment_4/Julia/1_Task/nodes_$nodes.%j --error=./errors/experiment_3/julia_err.1TaskNodes_$nodes.%j --exclusive experiment_3.sh $nodes
    sbatch --nodes=$nodes --ntasks-per-node=1 --cpus-per-task=1 --job-name=experiment4_$nodes --output=./benchmarks/experiment_4/Baseline/1_Task/nodes_$nodes.%j --error=./errors/experiment_3/baseline_err.1TaskNodes_$nodes.%j --exclusive experiment_3.sh $nodes


    sbatch --nodes=$nodes --ntasks-per-node=24 --cpus-per-task=1 --job-name=experiment4_$nodes --output=./benchmarks/experiment_4/Julia/24_Tasks/nodes_$nodes.%j --error=./errors/experiment_3/julia_err.24TasksNodes_$nodes.%j --exclusive experiment_3.sh $nodes
    sbatch --nodes=$nodes --ntasks-per-node=24 --cpus-per-task=1 --job-name=experiment4_$nodes --output=./benchmarks/experiment_4/Baseline/24_Tasks/nodes_$nodes.%j --error=./errors/experiment_3/baseline_err.24TasksNodes_$nodes.%j --exclusive experiment_3.sh $nodes

done
