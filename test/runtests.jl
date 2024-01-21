
using Test
using MixedStructTypes

@sum_struct_type A{X,Y} begin
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
    struct D{Y}
        a::Tuple{Int, Int}
        f::Y
        g::Tuple{Complex, Complex}
        c::Symbol
    end
end

@testset "@sum_struct_type" begin

    b = B((1,1), (1.0, 1.0), :s)

    @test b.a == (1,1)
    @test b.b == (1.0, 1.0)
    @test b.c == :s

    b.a = (3, 3)
    @test b.a == (3, 3)

    @test kindof(b) == :B
end

@compact_struct_type E{X,Y} begin
    mutable struct F{X}
        a::Tuple{X, X}
        b::Tuple{Float64, Float64}
        const c::Symbol
    end
    mutable struct G{X}
        a::Tuple{X, X}
        d::Int32
        e::Bool
        const c::Symbol
    end
    mutable struct H{X,Y}
        a::Tuple{X, X}
        f::Y
        g::Tuple{Complex, Complex}
        const c::Symbol
    end
end

@testset "@compact_struct_type" begin

    f = F((1,1), (1.0, 1.0), :s)

    @test f.a == (1,1)
    @test f.b == (1.0, 1.0)
    @test f.c == :s

    f.a = (3, 3)
    @test f.a == (3, 3)

    @test kindof(f) == :F
end
