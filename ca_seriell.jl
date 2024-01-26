using MD5

# check if Arguments are set correct
if length(ARGS) != 2
    println("Need 2 Arguments: number of lines, number of iterations")
    exit(1)
end

const XSIZE = 1024
const anneal = [0, 0, 0, 0, 1, 0, 1, 1, 1, 1]
const utility_lib = "./libutility.so" 

lines = parse(Int, ARGS[1])
iterations = parse(Int, ARGS[2])

# Define timespec struct in Julia
struct timespec
    sec::Int64
    nsec::Int64
end

# Get all necessary c_functions
function get_time()::timespec
    return ccall(("get_time", utility_lib), timespec, ())
end


function measure_time_diff(timer1::timespec, timer2::timespec)::Cdouble
    return ccall(("measure_time_diff", utility_lib), Cdouble, (Ptr{timespec}, Ptr{timespec}), Ref(timer1), Ref(timer2))
end

# compute MD5-Hash
function calculate_md5_hash(matrix::AbstractMatrix)
    # Flatten the matrix into a one-dimensional array
    flattened_matrix = vec(matrix)

    # Convert the flattened array to a byte array
    byte_array = reinterpret(UInt8, flattened_matrix)

    # Calculate the MD5 hash
    hash_object = md5(byte_array)
    hash_string = join([string(i, base=16, pad=2) for i in hash_object])

    return hash_string
end


# functions for actual ca-computation
function transition(a, x, y)
    return anneal[a[y-1, x-1] + a[y, x-1] + a[y+1, x-1] +
                  a[y-1, x]   + a[y, x]   + a[y+1, x] +
                  a[y-1, x+1] + a[y, x+1] + a[y+1, x+1] + 1]
end


function apply_transition(from_matrix, transition)
    # buffer left and right
    first_col = from_matrix[:,1]
    last_col = from_matrix[:, end]
    from_matrix = hcat(last_col, from_matrix)
    from_matrix = hcat(from_matrix, first_col)

    # buffer top and bottom, only for serial computation
    last_row = from_matrix[end,:]
    first_row = from_matrix[2,:]
    from_matrix = vcat(last_row', from_matrix)
    from_matrix = vcat(from_matrix, first_row')

    # creating the "to"-matrix
    m, n = size(from_matrix)
    to_matrix = zeros(Int, m, n)

    for i in 2:m-1
        for j in 2:n-1
            to_matrix[i, j] = transition(from_matrix, j, i)
        end
    end

    return to_matrix[2:end-1,2:end-1]
end


# create random matrix
matrix = rand([0, 1], lines, XSIZE)

# compute multiple iterations
start_time = get_time()
for iteration in 1:iterations
    global matrix = apply_transition(matrix, transition)
end
stop_time = get_time()
hash = calculate_md5_hash(matrix)
println(hash)
println("fertig")
