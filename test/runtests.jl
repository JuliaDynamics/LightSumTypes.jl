
using StructSumTypes

@struct_sum_type A begin
    mutable struct B
        a::Tuple{Int, Int}
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

b = [B(1, 1.0, :b) for i in 1:1000]
c = C(1, Int32(3), true, :c)
d = D((1,1), Float32(3.2), (1 + 2im, 1+3im), :c)

f(v) = sum(a.x for a in v)


8 + 8 + 8 + 8 + 4 + 1 + 4 + 16

mutable struct E
    a::Tuple{Int, Int}
    b::Tuple{Float64, Float64}
    const c::Symbol
    d::Int32
    e::Bool
    f::Float32
    g::Tuple{Complex, Complex}
end

e = E((1,1), (1.0, 1.0), :b, Int32(3), true, Float32(3.2), (1 + 2im, 1 + 3im))