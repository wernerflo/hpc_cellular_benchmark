module CaMpi

using MD5
using MPI
using Base.Threads

export get_time, measure_time_diff, nextRandomLEcuyer, randInt, ca_init_config!,
        calculate_md5_hash, transition, apply_transition_seq!, apply_transition!,
        ca_mpi_init, mpi_calculate_md5_hash, boundary!, boundary_seq!,
        apply_transition_seq_parallel!, apply_transition_parallel!,
        apply_transition_parallel_by_element!, init, calculate_non_blocking_parallel!,
        calculate_non_blocking_sequential!, hash_and_report, construct_full_matrix,
        send_local_matrix, prev_proc, succ_proc

const utility_lib = "./libutility.so" 
const XSIZE = 1024
const LINESIZE = XSIZE + 2

const TAG_SEND_UPPER_BOUND = 1
const TAG_SEND_LOWER_BOUND = 2

const TAG_RECV_UPPER_BOUND = TAG_SEND_LOWER_BOUND
const TAG_RECV_LOWER_BOUND = TAG_SEND_UPPER_BOUND

const TAG_RESULT = 0xCAFE

const anneal = [0, 0, 0, 0, 1, 0, 1, 1, 1, 1]


#=---------- time measurement ------------=#
# Define timespec struct in Julia
struct timespec
    sec::Int64
    nsec::Int64
end

# Get all necessary c_functions
function get_time()
    return ccall(("get_time", utility_lib), timespec, ())
end


function measure_time_diff(timer1::timespec, timer2::timespec)
    return ccall(("measure_time_diff", utility_lib), Cdouble, (Ptr{timespec}, Ptr{timespec}), Ref(timer1), Ref(timer2))
end



#=---------- initialization of ca ------------=#
mutable struct CellularAutomaton
    from
    to
    num_local_lines
    rank
    num_procs
    comm
end


function nextRandomLEcuyer()
    return ccall(("nextRandomLEcuyer", utility_lib), Float64, ())
end


function randInt(n)
    return UInt8(trunc(nextRandomLEcuyer() * n))
end


function ca_init_config!(buf::AbstractMatrix, lines::Int, skip_lines::Int)
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

end


function init(num_total_lines::Int, iterations::Int)

    comm = MPI.COMM_WORLD
    rank = MPI.Comm_rank(comm)
    num_procs = MPI.Comm_size(comm)

    num_local_lines, num_skip_lines = ca_mpi_init(num_procs, rank, num_total_lines)

    global from = zeros(UInt8,num_local_lines + 2, LINESIZE)
    global to = zeros(UInt8,num_local_lines + 2, LINESIZE)

    # Initialize from matrix 
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
        prev_proc(rank, num_procs), TAG_SEND_UPPER_BOUND,
        recv_buffer_lower_bound,
        succ_proc(rank, num_procs), TAG_RECV_LOWER_BOUND,
        comm
    )

    MPI.Sendrecv!(
        send_buffer_lower_bound,
        succ_proc(rank, num_procs), TAG_SEND_LOWER_BOUND,
        recv_buffer_upper_bound,
        prev_proc(rank, num_procs), TAG_RECV_UPPER_BOUND,
        comm
    )

    # Update ghost zones with received data
    from[1, :] .= recv_buffer_upper_bound.data
    from[num_local_lines + 2, :] .= recv_buffer_lower_bound.data

    cellularAutomaton = CellularAutomaton(from, to, num_local_lines, rank, num_procs, comm)
    return cellularAutomaton, recv_buffer_lower_bound, recv_buffer_upper_bound
end


function construct_full_matrix(cellularAutomaton, num_total_lines)
    if cellularAutomaton.rank == 0
        global full_matrix = cellularAutomaton.from[2:end-1,:]
        
        num_remainder_procs = num_total_lines % cellularAutomaton.num_procs

        # collecting all local buffers and concatenating with already received data
        for i in 1:(cellularAutomaton.num_procs-1)
            num_lines = div(num_total_lines, cellularAutomaton.num_procs)
            if i < num_remainder_procs
                num_lines += 1
            end

            
            recv_buf = MPI.Buffer(zeros(UInt8, num_lines, LINESIZE))
            status = MPI.Recv!(recv_buf, i, TAG_RESULT, cellularAutomaton.comm)
            
            # Concatenate new data to already received matrix
            full_matrix = vcat(full_matrix, recv_buf.data)
            
        end
        return full_matrix
        
    else
        send_local_matrix(cellularAutomaton.from, cellularAutomaton.num_local_lines, cellularAutomaton.comm)
    end
end


function send_local_matrix(from, num_local_lines, comm)
    #send local buffer without upper and lower ghost zone
    send_buffer_local_matrix = MPI.Buffer(from[2:num_local_lines+1,:])
    MPI.Send(send_buffer_local_matrix, 0, TAG_RESULT, comm)

end


function hash_and_report(start_time, stop_time, cellularAutomaton, full_matrix, num_total_lines)
    hash_value = calculate_md5_hash(full_matrix)
    computation_time = measure_time_diff(start_time,stop_time)  
    return computation_time, hash_value
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



#=---------- computation of local ghost zones ------------=#
function boundary!(matrix::AbstractMatrix)

    # buffer left and right
    matrix[:,1] = matrix[:,end-1]
    matrix[:,end] = matrix[:,2]

end


# only for serial computation
function boundary_seq!(matrix::AbstractMatrix)

    # buffer left and right
    matrix[:,1] = matrix[:,end-1]
    matrix[:,end] = matrix[:,2]

    # buffer up and down
    matrix[1,:] = matrix[end-1,:]
    matrix[end,:] = matrix[2,:]

end



#=---------- computation step for each iteration ------------=#
function transition(a::AbstractMatrix, x::Int, y::Int)
    return anneal[a[y-1, x-1] + a[y, x-1] + a[y+1, x-1] +
                  a[y-1, x  ] + a[y, x  ] + a[y+1, x  ] +
                  a[y-1, x+1] + a[y, x+1] + a[y+1, x+1] + 1]
end


# only for serial computation
function apply_transition_seq!(from_matrix::AbstractMatrix, to_matrix::AbstractMatrix)

    m, n = size(from_matrix)
    for j in 2:n-1
        for i in 2:m-1
            to_matrix[i, j] = transition(from_matrix, j, i)
        end
    end

end


# only for multithreaded serial computation
function apply_transition_seq_parallel!(from_matrix::AbstractMatrix, to_matrix::AbstractMatrix)

    m, n = size(from_matrix)
    @threads for j in 2:n-1
        for i in 2:m-1
            to_matrix[i, j] = transition(from_matrix, j, i)
        end
    end

end


# compute multiple lines
function apply_transition!(from_matrix::AbstractMatrix, to_matrix::AbstractMatrix, start_line::Int, end_line::Int)

    for j in 2:(size(from_matrix, 2)-1)
        for i in start_line:end_line
            to_matrix[i, j] = transition(from_matrix, j, i)
        end
    end

end


# compute a single line
function apply_transition!(from_matrix::AbstractMatrix, to_matrix::AbstractMatrix, start_line::Int)

    for j in 2:(size(from_matrix, 2)-1)
        to_matrix[start_line, j] = transition(from_matrix, j, start_line)
    end

end


# multithreaded version
function apply_transition_parallel!(from_matrix::AbstractMatrix, to_matrix::AbstractMatrix, start_line::Int, end_line::Int)

    @threads for j in 2:(size(from_matrix, 2)-1)
        for i in start_line:end_line
            to_matrix[i, j] = transition(from_matrix, j, i)
        end
    end

end

function calculate_non_blocking!(cellularAutomaton, recv_buffer_lower_bound, recv_buffer_upper_bound, transition_handler, iterations)
    start_time = get_time()
    for iteration in 1:iterations
        requests = Vector{MPI.Request}()
        
        boundary!(cellularAutomaton.from)

        # Prepost matching receive operation
        push!(requests, MPI.Irecv!(recv_buffer_upper_bound, prev_proc(cellularAutomaton.rank, cellularAutomaton.num_procs), TAG_RECV_UPPER_BOUND, cellularAutomaton.comm))
        push!(requests, MPI.Irecv!(recv_buffer_lower_bound, succ_proc(cellularAutomaton.rank, cellularAutomaton.num_procs), TAG_RECV_LOWER_BOUND, cellularAutomaton.comm))

        # Compute boundaries
        apply_transition!(cellularAutomaton.from, cellularAutomaton.to, 2)
        apply_transition!(cellularAutomaton.from, cellularAutomaton.to, cellularAutomaton.num_local_lines + 1)

        # fill send buffer
        send_buffer_upper_bound = MPI.Buffer(cellularAutomaton.to[2,:])
        send_buffer_lower_bound = MPI.Buffer(cellularAutomaton.to[cellularAutomaton.num_local_lines + 1,:])

        # Isend operations
        push!(requests, MPI.Isend(send_buffer_upper_bound, prev_proc(cellularAutomaton.rank, cellularAutomaton.num_procs), TAG_SEND_UPPER_BOUND, cellularAutomaton.comm))
        push!(requests, MPI.Isend(send_buffer_lower_bound, succ_proc(cellularAutomaton.rank, cellularAutomaton.num_procs), TAG_SEND_LOWER_BOUND, cellularAutomaton.comm))
        
        transition_handler(cellularAutomaton.from, cellularAutomaton.to, 3, cellularAutomaton.num_local_lines)

        # setting pointers to new locations instead of updating values
        temp = cellularAutomaton.from
        cellularAutomaton.from = cellularAutomaton.to
        cellularAutomaton.to = temp

        # Wait for the completion of receive and send operations
        MPI.Waitall!(requests)

        # Update ghost zones with received data
        cellularAutomaton.from[1, :] .= recv_buffer_upper_bound.data
        cellularAutomaton.from[cellularAutomaton.num_local_lines + 2, :] .= recv_buffer_lower_bound.data

    end
    stop_time = get_time()
    return start_time, stop_time
end

function calculate_non_blocking_parallel!(cellularAutomaton, recv_buffer_lower_bound, recv_buffer_upper_bound, iterations)
    calculate_non_blocking!(cellularAutomaton, recv_buffer_lower_bound, recv_buffer_upper_bound, apply_transition_parallel!, iterations)
end


function calculate_non_blocking_sequential!(cellularAutomaton, recv_buffer_lower_bound, recv_buffer_upper_bound, iterations)
    calculate_non_blocking!(cellularAutomaton, recv_buffer_lower_bound, recv_buffer_upper_bound, apply_transition!, iterations)
end

function prev_proc(n::Int, num_procs::Int)
    return (n - 1 + num_procs) % num_procs
end


function succ_proc(n::Int, num_procs::Int)
    return (n + 1) % num_procs
end


end