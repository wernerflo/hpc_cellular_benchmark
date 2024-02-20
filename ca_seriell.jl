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
ca_init_config!(from_matrix, lines, 0)

# actual computation starting here
start_time = get_time()
for iteration in 1:iterations
    boundary_seq!(from_matrix)
    apply_transition_seq_parallel!(from_matrix, to_matrix)
    temp = from_matrix
    global from_matrix = to_matrix
    global to_matrix = temp
end
stop_time = get_time()


# get computation time and calculate hash value
computation_time = measure_time_diff(start_time,stop_time)
hash = calculate_md5_hash(from_matrix[2:end-1,:])

# create output
println("lines: ", lines, ", iterations: ", iterations)
println("Computation time: ", computation_time, "s")
println("Hash-value: ", hash)
print("\n")

