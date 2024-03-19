module CaReport

include("ca_common.jl")

using .CaCommon
using MPI
using MD5

export send_local_matrix, construct_full_matrix, calculate_md5_hash, hash_and_report


function send_local_matrix(from, num_local_lines, comm)
    #send local buffer without upper and lower ghost zone
    send_buffer_local_matrix = MPI.Buffer(from[2:num_local_lines+1,:])
    MPI.Send(send_buffer_local_matrix, 0, CaCommon.TAG_RESULT, comm)

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

            
            recv_buf = MPI.Buffer(zeros(UInt8, num_lines, CaCommon.LINESIZE))
            status = MPI.Recv!(recv_buf, i, CaCommon.TAG_RESULT, cellularAutomaton.comm)
            
            # Concatenate new data to already received matrix
            full_matrix = vcat(full_matrix, recv_buf.data)
            
        end
        return full_matrix
        
    else
        send_local_matrix(cellularAutomaton.from, cellularAutomaton.num_local_lines, cellularAutomaton.comm)
    end
end


function calculate_md5_hash(matrix::AbstractMatrix)

    # simulate the clean ghost zones function of baseline
    matrix[:,1] = zeros(UInt8, size(matrix,1))
    matrix[:,end] = zeros(UInt8, size(matrix,1))

    # transpose matrix because of column major order in julia
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


function convert_timespec(start_time::Main.CaCalculations.CaCommon.timespec, stop_time::Main.CaCalculations.CaCommon.timespec)
end

function hash_and_report(start_time::Main.CaCalculations.CaCommon.timespec, stop_time::Main.CaCalculations.CaCommon.timespec, full_matrix)
    hash_value = calculate_md5_hash(full_matrix)
    computation_time = measure_time_diff(timespec(start_time.sec, start_time.nsec),timespec(stop_time.sec,stop_time.nsec))  
    return computation_time, hash_value
end 


end
