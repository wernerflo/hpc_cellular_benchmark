module CaCommon

export CellularAutomaton, timespec, get_time, measure_time_diff, prev_proc, succ_proc

const utility_lib = "./julia/libutility.so" 

const XSIZE = 1024
const LINESIZE = XSIZE + 2

const TAG_SEND_UPPER_BOUND = 1
const TAG_SEND_LOWER_BOUND = 2

const TAG_RECV_UPPER_BOUND = TAG_SEND_LOWER_BOUND
const TAG_RECV_LOWER_BOUND = TAG_SEND_UPPER_BOUND

const TAG_RESULT = 0xCAFE


struct timespec
    sec::Int64
    nsec::Int64
end


mutable struct CellularAutomaton
    from
    to
    num_local_lines
    rank
    num_procs
    comm
end


function get_time()
    return ccall(("get_time", utility_lib), timespec, ())
end


function measure_time_diff(timer1::timespec, timer2::timespec)
    return ccall(("measure_time_diff", utility_lib), Cdouble, (Ptr{timespec}, Ptr{timespec}), Ref(timer1), Ref(timer2))
end


function prev_proc(n::Int, num_procs::Int)
    return (n - 1 + num_procs) % num_procs
end


function succ_proc(n::Int, num_procs::Int)
    return (n + 1) % num_procs
end


end