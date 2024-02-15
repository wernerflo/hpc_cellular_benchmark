include("common_functions.jl")

using .Common_Functions

# check if Arguments are set correct
if length(ARGS) != 2
    println("Need 2 Arguments: number of lines, number of iterations")
    exit(1)
end

const XSIZE = 1024

lines = parse(Int, ARGS[1])
iterations = parse(Int, ARGS[2])

#=---------- main ------------=#
# initialize matrix

from_matrix = zeros(UInt8, lines+2, XSIZE+2)
to_matrix = zeros(UInt8, lines+2, XSIZE+2)
from_matrix = ca_init_config!(from_matrix, lines, 0)

# actual computation starting here
start_time = get_time()
for iteration in 1:iterations
    boundary_seq(from_matrix)
    apply_transition_seq_parallel(from_matrix, to_matrix)
    global from_matrix .= to_matrix
end
stop_time = get_time()


# get computation time and calculate hash value
computation_time = measure_time_diff(start_time,stop_time)
hash = calculate_md5_hash(from_matrix[2:end-1,:])

# create output
println("Computation time: ", computation_time, "s")
println("Hash-value: ", hash)
println("Hash-value of baseline: 4604B369CB251400EF4CFB91E9151C7E")
