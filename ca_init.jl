module CaInit

include("ca_common.jl")

using .CaCommon
using MPI

export nextRandomLEcuyer, randInt, ca_init_config!, ca_mpi_init, initialize_ca


function nextRandomLEcuyer()
    return ccall(("nextRandomLEcuyer", CaCommon.utility_lib), Float64, ())
end


function randInt(n)
    return UInt8(trunc(nextRandomLEcuyer() * n))
end


function ca_init_config!(buf::AbstractMatrix, lines::Int, skip_lines::Int)
    ccall(("initRandomLEcuyer", CaCommon.utility_lib), Cvoid, (Cint,), 424243)

    scratch = 0

    #= let the RNG spin for some rounds (used for distributed initialization) =#
    # matrix has dimension (lines+2,XSIZE)
	for y in 2:(skip_lines+1)
		for x in 2:(CaCommon.XSIZE+1)
			scratch = scratch + randInt(100) >= 50;
        end
    end

    # Initialize the matrix with random values
    for x in 2:(lines+1)
        for y in 2:(CaCommon.XSIZE+1)
            buf[x, y] = randInt(Cint(100)) >= 50
        end
    end

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


#=------- actual initialization of CA and preparing for calculation ---------=#
function initialize_ca(num_total_lines::Int, iterations::Int)

    comm = MPI.COMM_WORLD
    rank = MPI.Comm_rank(comm)
    num_procs = MPI.Comm_size(comm)

    num_local_lines, num_skip_lines = ca_mpi_init(num_procs, rank, num_total_lines)

    global from = zeros(UInt8,num_local_lines + 2, CaCommon.LINESIZE)
    global to = zeros(UInt8,num_local_lines + 2, CaCommon.LINESIZE)

    # Initialize from matrix 
    ca_init_config!(from, num_local_lines, num_skip_lines)

    # fill send buffer
    send_buffer_upper_bound = MPI.Buffer(from[2,:])
    send_buffer_lower_bound = MPI.Buffer(from[num_local_lines + 1,:])

    # Initialize receive buffers
    recv_buffer_upper_bound = MPI.Buffer(zeros(UInt8, CaCommon.LINESIZE))
    recv_buffer_lower_bound = MPI.Buffer(zeros(UInt8, CaCommon.LINESIZE))

    # initial data exchange
    MPI.Sendrecv!(
        send_buffer_upper_bound,
        prev_proc(rank, num_procs), CaCommon.TAG_SEND_UPPER_BOUND,
        recv_buffer_lower_bound,
        succ_proc(rank, num_procs), CaCommon.TAG_RECV_LOWER_BOUND,
        comm
    )

    MPI.Sendrecv!(
        send_buffer_lower_bound,
        succ_proc(rank, num_procs), CaCommon.TAG_SEND_LOWER_BOUND,
        recv_buffer_upper_bound,
        prev_proc(rank, num_procs), CaCommon.TAG_RECV_UPPER_BOUND,
        comm
    )

    # Update ghost zones with received data
    from[1, :] .= recv_buffer_upper_bound.data
    from[num_local_lines + 2, :] .= recv_buffer_lower_bound.data

    cellularAutomaton = CellularAutomaton(from, to, num_local_lines, rank, num_procs, comm)
    return cellularAutomaton, recv_buffer_lower_bound, recv_buffer_upper_bound
end


end