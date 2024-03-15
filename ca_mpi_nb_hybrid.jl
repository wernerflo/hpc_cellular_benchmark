include("ca_mpi.jl")

using .CaMpi
using MPI

@enum ExecutionMode begin
    nb_parallel
    nb_sequential
end
# check if Arguments are set correct
if length(ARGS) != 3
    println("Need 3 Arguments: number of lines, number of iterations, one of the following options: [", string(nb_parallel),", ", string(nb_sequential),"]")
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
    else
        println("Argument 3 must be one of the following options: [", string(nb_parallel),", ", string(nb_sequential),"]")
        exit(1)
    end
end

calculate_handler! = get_calculate_handler(execution_mode)



MPI.Init()
cellularAutomaton, recv_buffer_lower_bound, recv_buffer_upper_bound = init(num_total_lines, iterations)

start_time, stop_time = calculate_handler!(cellularAutomaton, recv_buffer_lower_bound, recv_buffer_upper_bound, iterations)

MPI.Barrier(cellularAutomaton.comm)

full_matrix = construct_full_matrix(cellularAutomaton, num_total_lines)
if cellularAutomaton.rank == 0
    computation_time, hash_value = hash_and_report(start_time, stop_time, cellularAutomaton, full_matrix, num_total_lines)
    println("nb_hybrid:")
    println("lines: ", num_total_lines, ", iterations: ", iterations)
    println("Computation time: ", computation_time, "s")
    println("Hash-value: ", hash_value)
    print("\n")  
end


MPI.Finalize()
    