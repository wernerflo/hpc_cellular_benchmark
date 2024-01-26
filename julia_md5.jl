using MD5
using Random

const XSIZE = 10
const LINES = 10
const utility_lib = "./libutility.so" 


function nextRandomLEcuyer()::Float64
    return ccall(("nextRandomLEcuyer", utility_lib), Float64, ())
end


function randInt(n)
    return UInt8(trunc(nextRandomLEcuyer() * n))
end


function ca_init_config(buf::Matrix{UInt8}, lines::Int)
    ccall(("initRandomLEcuyer", utility_lib), Cvoid, (Cint,), 424243)

    # Initialize the matrix with random values
    for x in 1:lines
        for y in 1:XSIZE
            buf[x, y] = randInt(Cint(100)) >= 50
        end
    end
end


function calculate_md5_hash(matrix::AbstractMatrix)
    # traverse matrix because of column major order in julia, row major order in c
    transposed_matrix = transpose(matrix)
    # Flatten the matrix into a one-dimensional array
    flattened_matrix = vec(transposed_matrix)

    # Convert the flattened array to a byte array
    byte_array = reinterpret(UInt8, flattened_matrix)
    print("byte array", byte_array)
    # Calculate the MD5 hash
    hash_object = md5(byte_array)
    
    hash_string = join([string(i, base=16, pad=2) for i in hash_object])

    return hash_string
end


# initialize the matrix
my_matrix=zeros(UInt8, LINES, XSIZE)
ca_init_config(my_matrix, LINES)

# calculate the hash
hash = calculate_md5_hash(my_matrix)

# print the output
println("julia-matrix:")
print(my_matrix)

println("Julia-hash:")
println(hash)