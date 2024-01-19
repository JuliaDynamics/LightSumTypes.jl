b = [B((1,1), (1.0, 2.0), :b) for i in 1:1000]
c1 = C((1,1), Int32(3), true, :c)
c2 = c = C((1,1), 3, true, :c)
c1.d == c2.d
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