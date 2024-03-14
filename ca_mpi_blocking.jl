include("ca_mpi.jl")

using .CaMpi
using MPI

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


function prev_proc(n, num_procs)
    return (n - 1 + num_procs) % num_procs
end

function succ_proc(n, num_procs)
    return (n + 1) % num_procs
end


#=---------- main ------------=#
MPI.Init()

comm = MPI.COMM_WORLD
local_rank = MPI.Comm_rank(comm)
num_procs = MPI.Comm_size(comm)

num_local_lines, num_skip_lines = ca_mpi_init(num_procs, local_rank, num_total_lines)

from = zeros(UInt8, num_local_lines + 2, LINESIZE)
to = zeros(UInt8, num_local_lines + 2, LINESIZE)

# Initialize from matrix (replace with your actual initialization logic)
ca_init_config!(from, num_local_lines, num_skip_lines)

# fill send buffer
send_buffer_upper_bound = MPI.Buffer(from[2,:])
send_buffer_lower_bound = MPI.Buffer(from[num_local_lines + 1,:])

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
from[1, :] .= recv_buffer_upper_bound.data
from[num_local_lines + 2, :] .= recv_buffer_lower_bound.data


# actual computation starting here
start_time = get_time()
for iteration in 1:iterations

    boundary!(from)

    # Compute boundaries
    apply_transition!(from, to, 2)
    apply_transition!(from, to, num_local_lines + 1)

    # fill send buffer
    global send_buffer_upper_bound = MPI.Buffer(to[2,:])
    global send_buffer_lower_bound = MPI.Buffer(to[num_local_lines + 1,:])

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
    
    apply_transition!(from, to, 3, num_local_lines)
    
    # Update ghost zones with received data
    to[1, :] .= recv_buffer_upper_bound.data
    to[num_local_lines + 2, :] .= recv_buffer_lower_bound.data

    temp = from
    global from = to
    global to = temp

end
stop_time = get_time()

MPI.Barrier(comm)

if local_rank == 0
    
    full_matrix = from[2:num_local_lines+1,:]
    
    num_remainder_procs = num_total_lines % num_procs

    # collecting all local buffers and concatenating with already received data
    for i in 1:(num_procs-1)
        num_lines = div(num_total_lines, num_procs)
        if i < num_remainder_procs
            num_lines += 1
        end

        
        recv_buf = MPI.Buffer(zeros(UInt8, num_lines, LINESIZE))
        status = MPI.Recv!(recv_buf, i, TAG_RESULT, comm)
        
        # Concatenate new data to already received matrix
        global full_matrix = vcat(full_matrix, recv_buf.data)
        
    end
    
    hash_value = calculate_md5_hash(full_matrix)
    computation_time = measure_time_diff(start_time,stop_time)

    println("blocking")
    println("lines: ", num_total_lines, ", iterations: ", iterations)
    println("Computation time: ", computation_time, "s")
    println("Hash-value: ", hash_value)
    print("\n")
    
    
else
    #send local buffer without upper and lower ghost zone
    send_buffer_local_matrix = MPI.Buffer(from[2:num_local_lines+1,:])
    MPI.Send(send_buffer_local_matrix, 0, TAG_RESULT, comm)

end


MPI.Finalize()
