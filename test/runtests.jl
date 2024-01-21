
using MixedStructTypes

@sum_struct_type A{X,Y} begin
    mutable struct B{X}
        a::Tuple{X, X}
        b::Tuple{Float64, Float64}
        const c::Symbol
    end
    mutable struct C
        a::Tuple{Int, Int}
        const c::Symbol
        d::Int32
        e::Bool
    end
    struct D{Y}
        a::Tuple{Int, Int}
        c::Symbol
        f::Y
        g::Tuple{Complex, Complex}
    end
end

b = B((1,1), (1.0, 1.0), :s)

b.a

b.c

b.a = (3, 3)

kindof(b)

# as you can see, here, all structs are mutable
# and all shared fields in different structs have
# the same type
@compact_struct_type E{X,Y} begin
    mutable struct F{X}
        a::Tuple{X, X}
        b::Tuple{Float64, Float64}
        const c::Symbol
    end
    mutable struct G{X}
        a::Tuple{X, X}
        const c::Symbol
        d::Int32
        e::Bool
    end
    mutable struct H{X,Y}
        a::Tuple{X, X}
        const c::Symbol
        f::Y
        g::Tuple{Complex, Complex}
    end
end

f = F((1,1), (1.0, 1.0), :s)

f.a

f.c

f.a = (3, 3)

kindof(f)

