using MD5

const XSIZE = 10  # Assuming XSIZE is defined

function hash_and_print(matrix::Array{UInt8, 2})
    # Convert the line to bytes
    flattened = vec(matrix)
    byte_array = reinterpret(UInt8, flattened)

    # Calculate the MD5 hash
    hash_object = md5(byte_array)
    hash_string = join([string(i, base=16, pad=2) for i in hash_object])
    println("$hash_object")
    println("hash: $hash_string")
end

# Example usage
line1 = UInt8[0, 1, 0, 1, 0, 1, 0, 1, 0, 1]

# Create a 2-dimensional matrix with the first line
my_matrix = hcat(line1, ones(UInt8, length(line1)))

hash_and_print(my_matrix)