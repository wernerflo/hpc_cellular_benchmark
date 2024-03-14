include("ca_mpi.jl")

using .CaMpi
using MPI


const TAG_SEND_UPPER_BOUND = 1
const TAG_SEND_LOWER_BOUND = 2

const TAG_RECV_UPPER_BOUND = TAG_SEND_LOWER_BOUND
const TAG_RECV_LOWER_BOUND = TAG_SEND_UPPER_BOUND

const TAG_RESULT = 0xCAFE

const XSIZE = 1024
const LINESIZE = XSIZE + 2


function prev_proc(n::Int, num_procs::Int)
    return (n - 1 + num_procs) % num_procs
end


function succ_proc(n::Int, num_procs::Int)
    return (n + 1) % num_procs
end


mutable struct CellularAutomata
    from
    to
    num_local_lines
    rank
    num_procs
    comm
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

    cellularAutomata = CellularAutomata(from, to, num_local_lines, rank, num_procs, comm)
    return cellularAutomata, recv_buffer_lower_bound, recv_buffer_upper_bound
end


function calculate!(cellularAutomata, recv_buffer_lower_bound, recv_buffer_upper_bound)
    start_time = get_time()
    for iteration in 1:iterations
        requests = Vector{MPI.Request}()
        
        boundary!(cellularAutomata.from)

        # Prepost matching receive operation
        push!(requests, MPI.Irecv!(recv_buffer_upper_bound, prev_proc(cellularAutomata.rank, cellularAutomata.num_procs), TAG_RECV_UPPER_BOUND, cellularAutomata.comm))
        push!(requests, MPI.Irecv!(recv_buffer_lower_bound, succ_proc(cellularAutomata.rank, cellularAutomata.num_procs), TAG_RECV_LOWER_BOUND, cellularAutomata.comm))

        # Compute boundaries
        apply_transition!(cellularAutomata.from, cellularAutomata.to, 2)
        apply_transition!(cellularAutomata.from, cellularAutomata.to, cellularAutomata.num_local_lines + 1)

        # fill send buffer
        send_buffer_upper_bound = MPI.Buffer(cellularAutomata.to[2,:])
        send_buffer_lower_bound = MPI.Buffer(cellularAutomata.to[cellularAutomata.num_local_lines + 1,:])

        # Isend operations
        push!(requests, MPI.Isend(send_buffer_upper_bound, prev_proc(cellularAutomata.rank, cellularAutomata.num_procs), TAG_SEND_UPPER_BOUND, cellularAutomata.comm))
        push!(requests, MPI.Isend(send_buffer_lower_bound, succ_proc(cellularAutomata.rank, cellularAutomata.num_procs), TAG_SEND_LOWER_BOUND, cellularAutomata.comm))
        
        apply_transition_parallel!(cellularAutomata.from, cellularAutomata.to, 3, cellularAutomata.num_local_lines)

        # setting pointers to new locations instead of updating values
        temp = cellularAutomata.from
        cellularAutomata.from = to
        cellularAutomata.to = temp

        # Wait for the completion of receive and send operations
        MPI.Waitall!(requests)

        # Update ghost zones with received data
        cellularAutomata.from[1, :] .= recv_buffer_upper_bound.data
        cellularAutomata.from[cellularAutomata.num_local_lines + 2, :] .= recv_buffer_lower_bound.data

    end
    stop_time = get_time()
    return start_time, stop_time
end


function construct_full_matrix(cellularAutomata, num_total_lines)
    if cellularAutomata.rank == 0
        full_matrix = from[2:end-1,:]
        
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
        return full_matrix
    else
        send_local_matrix(cellularAutomata.from, cellularAutomata.num_local_lines, cellularAutomata.comm)
    end
end


function send_local_matrix(from, num_local_lines, comm)
    #send local buffer without upper and lower ghost zone
    send_buffer_local_matrix = MPI.Buffer(from[2:num_local_lines+1,:])
    MPI.Send(send_buffer_local_matrix, 0, TAG_RESULT, comm)

end


function get_hash_value(cellularAutomata, num_total_lines)
    hash_value = ""
    if cellularAutomata.rank == 0
        
        return hash_value
    end
end


function hash_and_report(start_time, stop_time, cellularAutomata, full_matrix, num_total_lines)
        hash_value = calculate_md5_hash(full_matrix)

        computation_time = measure_time_diff(start_time,stop_time)
        hash_value = get_hash_value(cellularAutomata, num_total_lines)

        println("nb_hybrid:")
        println("lines: ", num_total_lines, ", iterations: ", iterations)
        println("Computation time: ", computation_time, "s")
        println("Hash-value: ", hash_value)
        print("\n")
    
end 


# check if Arguments are set correct
if length(ARGS) != 2
    println("Need 2 Arguments: number of lines, number of iterations")
    exit(1)
end

num_total_lines = parse(Int, ARGS[1])
iterations = parse(Int, ARGS[2])

MPI.Init()
cellularAutomata, recv_buffer_lower_bound, recv_buffer_upper_bound = init(num_total_lines, iterations)

start_time, stop_time = calculate!(cellularAutomata, recv_buffer_lower_bound, recv_buffer_upper_bound)

MPI.Barrier(cellularAutomata.comm)

full_matrix = construct_full_matrix(cellularAutomata, num_total_lines)
if cellularAutomata.rank == 0        
    hash_and_report(start_time, stop_time, cellularAutomata, full_matrix, num_total_lines)
end

MPI.Finalize()
    