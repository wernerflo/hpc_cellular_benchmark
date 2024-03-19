module CaCalculations

include("ca_common.jl")

using .CaCommon
using MPI
using Base.Threads

export get_calculate_handler, calculate_blocking!, calculate_non_blocking_parallel!, calculate_non_blocking_sequential!

const anneal = [0, 0, 0, 0, 1, 0, 1, 1, 1, 1]


# calculate local ghost zones
function boundary!(matrix::AbstractMatrix)
    # buffer left and right
    matrix[:,1] = matrix[:,end-1]
    matrix[:,end] = matrix[:,2]
end


#=---------- computation step for each iteration ------------=#
function transition(a::AbstractMatrix, x::Int, y::Int)
    return anneal[a[y-1, x-1] + a[y, x-1] + a[y+1, x-1] +
                  a[y-1, x  ] + a[y, x  ] + a[y+1, x  ] +
                  a[y-1, x+1] + a[y, x+1] + a[y+1, x+1] + 1]
end

#=

this part can be deleted if not using ca_seriell.jl

# only for serial computation
function boundary_seq!(matrix::AbstractMatrix)

    # buffer left and right
    matrix[:,1] = matrix[:,end-1]
    matrix[:,end] = matrix[:,2]

    # buffer up and down
    matrix[1,:] = matrix[end-1,:]
    matrix[end,:] = matrix[2,:]

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
=#

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


function calculate_blocking!(cellularAutomaton, recv_buffer_lower_bound, recv_buffer_upper_bound, iterations)
    start_time = get_time()
    for iteration in 1:iterations

        boundary!(cellularAutomaton.from)

        # Compute boundaries
        apply_transition!(cellularAutomaton.from, cellularAutomaton.to, 2)
        apply_transition!(cellularAutomaton.from, cellularAutomaton.to, cellularAutomaton.num_local_lines + 1)

        # fill send buffer
        global send_buffer_upper_bound = MPI.Buffer(cellularAutomaton.to[2,:])
        global send_buffer_lower_bound = MPI.Buffer(cellularAutomaton.to[cellularAutomaton.num_local_lines + 1,:])

        MPI.Sendrecv!(
            send_buffer_upper_bound,
            prev_proc(cellularAutomaton.rank, cellularAutomaton.num_procs), CaCommon.TAG_SEND_UPPER_BOUND,
            recv_buffer_lower_bound,
            succ_proc(cellularAutomaton.rank, cellularAutomaton.num_procs), CaCommon.TAG_RECV_LOWER_BOUND,
            cellularAutomaton.comm
        )

        MPI.Sendrecv!(
            send_buffer_lower_bound,
            succ_proc(cellularAutomaton.rank, cellularAutomaton.num_procs), CaCommon.TAG_SEND_LOWER_BOUND,
            recv_buffer_upper_bound,
            prev_proc(cellularAutomaton.rank, cellularAutomaton.num_procs), CaCommon.TAG_RECV_UPPER_BOUND,
            cellularAutomaton.comm
        )
        
        apply_transition!(cellularAutomaton.from, cellularAutomaton.to, 3, cellularAutomaton.num_local_lines)
        
        # Update ghost zones with received data
        cellularAutomaton.to[1, :] .= recv_buffer_upper_bound.data
        cellularAutomaton.to[cellularAutomaton.num_local_lines + 2, :] .= recv_buffer_lower_bound.data

        temp = cellularAutomaton.from
        cellularAutomaton.from = cellularAutomaton.to
        cellularAutomaton.to = temp

    end
    stop_time = get_time()
    return start_time, stop_time
end


function calculate_non_blocking!(cellularAutomaton, recv_buffer_lower_bound, recv_buffer_upper_bound, transition_handler, iterations)
    start_time = get_time()
    for iteration in 1:iterations
        requests = Vector{MPI.Request}()
        
        boundary!(cellularAutomaton.from)

        # Prepost matching receive operation
        push!(requests, MPI.Irecv!(recv_buffer_upper_bound, prev_proc(cellularAutomaton.rank, cellularAutomaton.num_procs), CaCommon.TAG_RECV_UPPER_BOUND, cellularAutomaton.comm))
        push!(requests, MPI.Irecv!(recv_buffer_lower_bound, succ_proc(cellularAutomaton.rank, cellularAutomaton.num_procs), CaCommon.TAG_RECV_LOWER_BOUND, cellularAutomaton.comm))

        # Compute boundaries
        apply_transition!(cellularAutomaton.from, cellularAutomaton.to, 2)
        apply_transition!(cellularAutomaton.from, cellularAutomaton.to, cellularAutomaton.num_local_lines + 1)

        # fill send buffer
        send_buffer_upper_bound = MPI.Buffer(cellularAutomaton.to[2,:])
        send_buffer_lower_bound = MPI.Buffer(cellularAutomaton.to[cellularAutomaton.num_local_lines + 1,:])

        # Isend operations
        push!(requests, MPI.Isend(send_buffer_upper_bound, prev_proc(cellularAutomaton.rank, cellularAutomaton.num_procs), CaCommon.TAG_SEND_UPPER_BOUND, cellularAutomaton.comm))
        push!(requests, MPI.Isend(send_buffer_lower_bound, succ_proc(cellularAutomaton.rank, cellularAutomaton.num_procs), CaCommon.TAG_SEND_LOWER_BOUND, cellularAutomaton.comm))
        
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


end