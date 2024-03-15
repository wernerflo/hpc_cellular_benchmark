using Statistics
include("ca_mpi_nb_hybrid.jl")

# check if Arguments are set correct
if length(ARGS) != 2
    println("Need 2 Arguments: number of lines, number of iterations")
    exit(1)
end

num_total_lines = parse(Int, ARGS[1])
iterations = parse(Int, ARGS[2])


num_runs = 5
computation_times = []

MPI.Init()
for i in 1:(5+1)
    if i == 1
        println("warm-up\n")
    else
        println("running benchmark nr: ", i-1)
    end
    cellularAutomata, recv_buffer_lower_bound, recv_buffer_upper_bound = init(num_total_lines, iterations)
    start_time, stop_time = calculate!(cellularAutomata, recv_buffer_lower_bound, recv_buffer_upper_bound)
    MPI.Barrier(cellularAutomata.comm)
    full_matrix = construct_full_matrix(cellularAutomata, num_total_lines)
    if cellularAutomata.rank == 0
        computation_time, hash_value = hash_and_report(start_time, stop_time, cellularAutomata, full_matrix, num_total_lines)
        append!(computation_times,computation_time)
    end
end
MPI.Finalize()

for t in 1:length(computation_times)
    if t == 1
        println("warm-up:  ", computation_times[t])
    else
        println("benchmark ", t-1, ":  ", computation_times[t])
    end
end

println("Mean: ", Statistics.mean(computation_times[2:end]))
println("Varianz: ", Statistics.var(computation_times[2:end]))
