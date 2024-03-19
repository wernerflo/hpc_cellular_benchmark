include("ca_init.jl")
include("ca_calculations.jl")
include("ca_report.jl")

using .CaInit
using .CaCalculations
using .CaReport

using MPI
@enum ExecutionMode begin
    nb_parallel
    nb_sequential
    blocking
end

# check if Arguments are set correct
if length(ARGS) != 3
    println("Need 3 Arguments: number of lines, number of iterations, one of the following options: [", string(nb_parallel),", ", string(nb_sequential),", ", string(blocking),"]")
    exit(1)
end

num_total_lines = parse(Int, ARGS[1])
iterations = parse(Int, ARGS[2])
execution_mode = ARGS[3]


function get_calculate_handler(execution_mode)
    if execution_mode == string(nb_parallel)
        return calculate_non_blocking_parallel!
    elseif execution_mode == string(nb_sequential)
        return calculate_non_blocking_sequential!
    elseif execution_mode == string(blocking)
        return calculate_blocking!
    else
        println("Argument 3 must be one of the following options: [", string(nb_parallel),", ", string(nb_sequential),", ", string(blocking),"]")
        exit(1)
    end
end


calculate_handler! = get_calculate_handler(execution_mode)


num_runs = 5
computation_times = []

MPI.Init()
for i in 1:(5+1)
    cellularAutomata, recv_buffer_lower_bound, recv_buffer_upper_bound = initialize_ca(num_total_lines, iterations)
    start_time, stop_time = calculate_handler!(cellularAutomata, recv_buffer_lower_bound, recv_buffer_upper_bound, iterations)
    MPI.Barrier(cellularAutomata.comm)
    full_matrix = construct_full_matrix(cellularAutomata, num_total_lines)
    if cellularAutomata.rank == 0
        computation_time, hash_value = hash_and_report(start_time, stop_time, full_matrix)
        append!(computation_times,computation_time)
    end
end
MPI.Finalize()

println("Lines: ", num_total_lines, ", Iterations: ", iterations)
for t in 1:length(computation_times)
    if t == 1
        println("Warm-up:  ", computation_times[t])
    else
        println("Run ", t-1,":  ", computation_times[t])
    end
end

