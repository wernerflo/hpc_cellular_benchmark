include("ca_mpi_nb_hybrid.jl")

# check if Arguments are set correct
if length(ARGS) != 2
    println("Need 2 Arguments: number of lines, number of iterations")
    exit(1)
end

num_total_lines = parse(Int, ARGS[1])
iterations = parse(Int, ARGS[2])

num_runs = 5

for i in 1:(5+1)
    if i == 1
        println("warm-up\n")
    end
    if i == 2
        println("benchmark")
    end
    MPI.Init()
    init()
end