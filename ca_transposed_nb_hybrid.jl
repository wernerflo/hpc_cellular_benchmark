include("common_functions.jl")

using .Common_Functions
using MPI
using Base.Threads
using MD5

# check if Arguments are set correct
if length(ARGS) != 2
    println("Need 2 Arguments: number of lines, number of iterations")
    exit(1)
end


const TAG_SEND_UPPER_BOUND = 1
const TAG_SEND_LOWER_BOUND = 2

const TAG_RECV_UPPER_BOUND = TAG_SEND_LOWER_BOUND
const TAG_RECV_LOWER_BOUND = TAG_SEND_UPPER_BOUND

const TAG_RESULT = 0xCAFE

const XSIZE = 1024
const LINESIZE = XSIZE + 2

num_total_lines = parse(Int, ARGS[1])
iterations = parse(Int, ARGS[2])


function prev_proc(n::Int, num_procs::Int)
    return (n - 1 + num_procs) % num_procs
end

function succ_proc(n::Int, num_procs::Int)
    return (n + 1) % num_procs
end

function boundary!(matrix::AbstractMatrix)

    # buffer left and right
    matrix[1,:] = matrix[end-1,:]
    matrix[end,:] = matrix[2,:]

end

function apply_transition_line!(from_matrix::AbstractMatrix, to_matrix::AbstractMatrix, column::Int)

    for i in 2:(size(from_matrix, 1)-1)
        to_matrix[i, column] = transition(from_matrix, column, i)
    end

end

function apply_transition_parallel!(from_matrix::AbstractMatrix, to_matrix::AbstractMatrix, start_line::Int, end_line::Int)

    @threads for j in start_line:end_line
        for i in 2:(size(from_matrix, 1)-1)
            to_matrix[i, j] = transition(from_matrix, j, i)
        end
    end

end

function calculate_md5_hash(matrix::AbstractMatrix)

    # simulate the clean ghost zones function of baseline
    matrix[1,:] = zeros(UInt8, size(matrix,2))
    matrix[end,:] = zeros(UInt8, size(matrix,2))

    # Flatten the matrix into a one-dimensional array
    flattened_matrix = vec(matrix)

    # Convert the flattened array to a byte array
    byte_array = reinterpret(UInt8, flattened_matrix)
    
    # Calculate the MD5 hash
    hash_object = md5(byte_array)
    
    hash_string = join([string(i, base=16, pad=2) for i in hash_object])

    return hash_string
end
#=---------- main ------------=#
MPI.Init()

comm = MPI.COMM_WORLD
local_rank = MPI.Comm_rank(comm)
num_procs = MPI.Comm_size(comm)

num_local_lines, num_skip_lines = ca_mpi_init(num_procs, local_rank, num_total_lines)

from = zeros(UInt8,num_local_lines + 2, LINESIZE)
to = zeros(UInt8, LINESIZE, num_local_lines + 2)

# Initialize from matrix 
ca_init_config!(from, num_local_lines, num_skip_lines)
from = transpose(from)
#print(size(from))
#print(size(to))

# fill send buffer
send_buffer_upper_bound = MPI.Buffer(from[:,2])
send_buffer_lower_bound = MPI.Buffer(from[:,num_local_lines + 1])

# Initialize receive buffers
recv_buffer_upper_bound = MPI.Buffer(zeros(UInt8, LINESIZE))
recv_buffer_lower_bound = MPI.Buffer(zeros(UInt8, LINESIZE))

# initial data exchange
MPI.Sendrecv!(
    send_buffer_upper_bound,
    prev_proc(local_rank, num_procs), TAG_SEND_UPPER_BOUND,
    recv_buffer_lower_bound,
    succ_proc(local_rank, num_procs), TAG_RECV_LOWER_BOUND,
    comm
)

MPI.Sendrecv!(
    send_buffer_lower_bound,
    succ_proc(local_rank, num_procs), TAG_SEND_LOWER_BOUND,
    recv_buffer_upper_bound,
    prev_proc(local_rank, num_procs), TAG_RECV_UPPER_BOUND,
    comm
)

# Update ghost zones with received data
from[:, 1] .= recv_buffer_upper_bound.data
from[:, num_local_lines + 2] .= recv_buffer_lower_bound.data


# actual computation starting here
start_time = get_time()
for iteration in 1:iterations
    requests = Vector{MPI.Request}()
    boundary!(from)

    # Prepost matching receive operation
    push!(requests, MPI.Irecv!(recv_buffer_upper_bound, prev_proc(local_rank, num_procs), TAG_RECV_UPPER_BOUND, comm))
    push!(requests, MPI.Irecv!(recv_buffer_lower_bound, succ_proc(local_rank, num_procs), TAG_RECV_LOWER_BOUND, comm))

    # Compute boundaries
    apply_transition_line!(from, to, 2)
    apply_transition_line!(from, to, num_local_lines + 1)

    # fill send buffer
    global send_buffer_upper_bound = MPI.Buffer(to[:,2])
    global send_buffer_lower_bound = MPI.Buffer(to[:,num_local_lines + 1,])

    # Isend operations
    push!(requests, MPI.Isend(send_buffer_upper_bound, prev_proc(local_rank, num_procs), TAG_SEND_UPPER_BOUND, comm))
    push!(requests, MPI.Isend(send_buffer_lower_bound, succ_proc(local_rank, num_procs), TAG_SEND_LOWER_BOUND, comm))
    
    apply_transition_parallel!(from, to, 3, num_local_lines)

    # setting pointers to new locations instead of updating values
    temp = from
    global from = to
    global to = temp

    # Wait for the completion of receive and send operations
    MPI.Waitall!(requests)

    # Update ghost zones with received data
    from[:,1] .= recv_buffer_upper_bound.data
    from[:, num_local_lines + 2] .= recv_buffer_lower_bound.data

end
stop_time = get_time()

MPI.Barrier(comm)

if local_rank == 0
    
    full_matrix = from[:,2:end-1]
    
    num_remainder_procs = num_total_lines % num_procs

    # collecting all local buffers and concatenating with already received data
    for i in 1:(num_procs-1)
        num_lines = div(num_total_lines, num_procs)
        if i < num_remainder_procs
            num_lines += 1
        end

        
        recv_buf = MPI.Buffer(zeros(UInt8, LINESIZE, num_lines))
        status = MPI.Recv!(recv_buf, i, TAG_RESULT, comm)
        
        # Concatenate new data to already received matrix
        global full_matrix = hcat(full_matrix, recv_buf.data)
        
    end
    
    hash_value = calculate_md5_hash(full_matrix)
    computation_time = measure_time_diff(start_time,stop_time)
    println("transposed_nb_hybrid:")
    println("lines: ", num_total_lines, ", iterations: ", iterations)
    println("Computation time: ", computation_time, "s")
    println("Hash-value: ", hash_value)
    print("\n")

else
    #send local buffer without upper and lower ghost zone
    send_buffer_local_matrix = MPI.Buffer(from[:,2:num_local_lines+1])
    MPI.Send(send_buffer_local_matrix, 0, TAG_RESULT, comm)

end

MPI.Finalize()
