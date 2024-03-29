include("ca_init.jl")
include("ca_calculations.jl")
include("ca_report.jl")

using .CaInit
using .CaCalculations
using .CaReport

using MPI
using Profile


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


function main(lines, iterations, calculate_handler!)
    MPI.Init()
    cellularAutomata, recv_buffer_lower_bound, recv_buffer_upper_bound = initialize_ca(num_total_lines, iterations)
    start_time, stop_time = calculate_handler!(cellularAutomata, recv_buffer_lower_bound, recv_buffer_upper_bound, iterations)
    MPI.Barrier(cellularAutomata.comm)
    full_matrix = construct_full_matrix(cellularAutomata, num_total_lines)
    if cellularAutomata.rank == 0
        computation_time, hash_value = hash_and_report(start_time, stop_time, full_matrix)
    end
    MPI.Finalize()
end

calculate_handler! = get_calculate_handler(execution_mode)


@profile main(num_total_lines, iterations, calculate_handler!)
main(num_total_lines, iterations, calculate_handler!)
Profile.print()
