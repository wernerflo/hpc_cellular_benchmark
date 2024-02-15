module Common_Functions

using MD5
using MPI

export get_time, measure_time_diff, nextRandomLEcuyer, randInt, ca_init_config!, calculate_md5_hash, transition, apply_transition_seq, apply_transition!, ca_mpi_init, mpi_calculate_md5_hash, boundary, boundary_seq

const utility_lib = "./libutility.so" 
const XSIZE = 1024
const LINESIZE = XSIZE + 2
const anneal = [0, 0, 0, 0, 1, 0, 1, 1, 1, 1]

#=---------- time measurement ------------=#
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


#=---------- initialization of ca ------------=#
function nextRandomLEcuyer()::Float64
    return ccall(("nextRandomLEcuyer", utility_lib), Float64, ())
end


function randInt(n)
    return UInt8(trunc(nextRandomLEcuyer() * n))
end


function ca_init_config!(buf::Matrix{UInt8}, lines::Int, skip_lines::Int)
    ccall(("initRandomLEcuyer", utility_lib), Cvoid, (Cint,), 424243)

    scratch = 0

    #= let the RNG spin for some rounds (used for distributed initialization) =#
    # matrix has dimension (lines+2,XSIZE)
	for y in 2:(skip_lines+1)
		for x in 2:(XSIZE+1)
			scratch = scratch + randInt(100) >= 50;
        end
    end

    # Initialize the matrix with random values
    for x in 2:(lines+1)
        for y in 2:(XSIZE+1)
            buf[x, y] = randInt(Cint(100)) >= 50
        end
    end

    return buf
end


#=---------- calculate local lines and get first global line for MPI ------------=#
function ca_mpi_init(num_procs::Int, rank::Int, num_total_lines::Int)
    num_local_lines = div(num_total_lines, num_procs)
    global_first_line = rank * num_local_lines

    # if work cannot be distributed equally, distribute the remaining lines equally
    num_remainder_procs = num_total_lines % num_procs
    if rank < num_remainder_procs
        num_local_lines += 1
        global_first_line += rank
    else
        global_first_line += num_remainder_procs
    end

    return num_local_lines, global_first_line
end


#=---------- compute md5-hash for ca ------------=#
function calculate_md5_hash(matrix::AbstractMatrix)

    # simulate the clean ghost zones function of baseline
    matrix[:,1] = zeros(UInt8, size(matrix,1))
    matrix[:,end] = zeros(UInt8, size(matrix,1))

    # traverse matrix because of column major order in julia, row major order in c
    transposed_matrix = transpose(matrix)

    # Flatten the matrix into a one-dimensional array
    flattened_matrix = vec(transposed_matrix)

    # Convert the flattened array to a byte array
    byte_array = reinterpret(UInt8, flattened_matrix)
    
    # Calculate the MD5 hash
    hash_object = md5(byte_array)
    
    hash_string = join([string(i, base=16, pad=2) for i in hash_object])

    return hash_string
end

const TAG_RESULT = 0xCAFE

function mpi_calculate_md5_hash(local_buf::AbstractMatrix, num_procs::Int)
    comm = MPI.COMM_WORLD
    rank = MPI.Comm_rank

    if rank == 0
        # building full matrix from all local buffers --> no issues with column major order
        result_matrix = local_buf
        print(local_buf)
        # collecting all local buffers and concatenating with already received data
        for i in 1:(num_procs-1)
            sent_buf = MPI.Recv(comm, i, TAG_RESULT)

            # Overwrite lower ghost zone with the first row of sent buffer
            result_matrix[end, :] .= matrix2[1, :]

            # Concatenate the rest
            result_matrix = vcat(result_matrix, sent_buf[2:end, :])
        end
        
        print(result_matrix)
        hash = calculate_md5_hash(result_matrix)
        return hash

        

    else
        #send local buffer
        MPI.Send(local_buf, 0, TAG_RESULT, comm)

    end


end


#=---------- computation step for each iteration ------------=#
function transition(a::AbstractMatrix, x::Int, y::Int)
    return anneal[a[y-1, x-1] + a[y, x-1] + a[y+1, x-1] +
                  a[y-1, x]   + a[y, x  ] + a[y+1, x  ] +
                  a[y-1, x+1] + a[y, x+1] + a[y+1, x+1] + 1]
end


function boundary(matrix::AbstractMatrix)

    # buffer left and right
    matrix[:,1] = matrix[:,end-1]
    matrix[:,end] = matrix[:,2]

end

function boundary_seq(matrix::AbstractMatrix)

    # buffer left and right
    matrix[:,1] = matrix[:,end-1]
    matrix[:,end] = matrix[:,2]

    # buffer up and down
    matrix[1,:] = matrix[end-1,:]
    matrix[end,:] = matrix[2,:]

end


function apply_transition_seq(from_matrix::AbstractMatrix,to_matrix::AbstractMatrix)

    m, n = size(from_matrix)
    for i in 2:m-1
        for j in 2:n-1
            to_matrix[i, j] = transition(from_matrix, j, i)
        end
    end

end


function apply_transition!(from_matrix::AbstractMatrix, to_matrix::AbstractMatrix, start_line::Int, end_line::Int)

    for i in start_line:end_line
        for j in 2:(size(from_matrix, 2)-1)
            to_matrix[i, j] = transition(from_matrix, j, i)
        end
    end

end

function apply_transition!(from_matrix::AbstractMatrix, to_matrix::AbstractMatrix, start_line::Int)

    for j in 2:(size(from_matrix, 2)-1)
        to_matrix[start_line, j] = transition(from_matrix, j, start_line)
    end

end

end