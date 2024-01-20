
using MixedStructTypes

@sum_struct_type A{X} begin
    mutable struct B{X}
        a::Tuple{X, X}
        b::Tuple{Float64, Float64}
        const c::Symbol
    end
    mutable struct C
        a::Tuple{Int, Int}
        d::Int32
        e::Bool
        const c::Symbol
    end
    mutable struct D
        a::Tuple{Int, Int}
        f::Float32
        g::Tuple{Complex, Complex}
        const c::Symbol
    end
end

