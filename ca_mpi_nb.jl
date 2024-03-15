include("ca_mpi.jl")

using .CaMpi
using MPI


# check if Arguments are set correct
if length(ARGS) != 2
    println("Need 2 Arguments: number of lines, number of iterations")
    exit(1)
end

num_total_lines = parse(Int, ARGS[1])
iterations = parse(Int, ARGS[2])

MPI.Init()
cellularAutomata, recv_buffer_lower_bound, recv_buffer_upper_bound = init(num_total_lines, iterations)

start_time, stop_time = calculate_non_blocking_sequential!(cellularAutomata, recv_buffer_lower_bound, recv_buffer_upper_bound)

MPI.Barrier(cellularAutomata.comm)

full_matrix = construct_full_matrix(cellularAutomata, num_total_lines)
if cellularAutomata.rank == 0
    computation_time, hash_value = hash_and_report(start_time, stop_time, cellularAutomata, full_matrix, num_total_lines)
    println("nb_hybrid:")
    println("lines: ", num_total_lines, ", iterations: ", iterations)
    println("Computation time: ", computation_time, "s")
    println("Hash-value: ", hash_value)
    print("\n")  
end


MPI.Finalize()
    