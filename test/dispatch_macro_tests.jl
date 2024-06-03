
using DynamicSumTypes, Test

@sum_structs X{T1, T2, T3} begin
    struct A1 end
    struct B1{T3, T1}
        a::T1 
        c::T3
    end
    struct C1{T2} 
        b::T2
    end
end

@sum_structs :opt_memory Y{T1, T2, T3} begin
    struct D1 end
    struct E1{T1, T3}
        a::T1 
        c::T3
    end
    struct F1{T2} 
        b::T2
    end
end

@sum_structs :opt_speed Z{T1, T2, T3} begin
    struct G1{T1, T2, T3} end
    struct H1{T1, T2, T3}
        a::T1 
        c::T3
    end
    struct I1{T1, T2, T3}
        b::T2
    end
end

@dispatch g(x::X, q, a::X) = -10
@dispatch g(x::B1, q, a::A1) = -1
@dispatch g(x::B1, q::Int, a::A1) = 0
@dispatch g(x::B1, q::Int, b::B1) = 1
@dispatch g(x::B1, q::Int, c::C1) = 2
@dispatch g(a::A1, q::Int, c::B1) = 3

@dispatch g(a::A1, q::Int, c::B1{Int}; s = 1) = 10 + s
@dispatch g(a::A1, q::Int, c::C1{Int}; s = 1) = 11 + s
@dispatch g(a::X, q::Int, c::X{DynamicSumTypes.Uninitialized, Int}; s = 1) = 12 + s

@dispatch g(x::X, q::Vararg{Int, 2}) = 1000
@dispatch g(x::A1, q::Vararg{Int, 2}) = 1001

@dispatch g(a::E1, b::Int, c::D1) = 0
@dispatch g(a::E1, b::Int, c::E1) = 1
@dispatch g(a::E1, b::Int, c::F1) = 2
@dispatch g(a::D1, b::Int, c::E1) = 3
@dispatch g(a::E1, b::Int, c::F1) = 4

@dispatch g(a::B1, b::Int, c::Vector{<:X}) = c

@dispatch g(a::H1{Int}, b::G1{Int}, c::I1{Int}) = a.a + c.b
@dispatch g(a::G1{Int}, b::G1{Int}, c::I1{Int}) = c.b
@dispatch g(a::H1{Float64}, b::G1{Float64}, c::I1{Float64}) = a.a
@dispatch g(a::X, q::Int, c::X{Int}; s = 1) = 12 + s

@dispatch t(::A1) = 100

Methods_Dispatch_Module_219428042303.define_all()

@testset "@dispatch" begin
    
    a, b1, b2, c = A1(), B1(0.0, 0.0), B1(1.0, 1.0), C1(1.0)

    @test g(a, true, c) == -10
    @test g(a, 1, c) == -10
    @test g(b1, true, a) == -1
    @test g(b1, 1, a) == 0
    @test g(b1, 1, b2) == 1
    @test g(b1, 1, c) == 2
    @test g(a, 1, b1) == 3

    b3, c3 = B1(1, 1), C1(1)
    @test g(c3, 1, c3) == 13
    @test g(a, 1, c3) == 12
    @test g(a, 1, b3) == 11

    @test g(a, 1, 1) == 1001
    @test g(b1, 1, 1) == 1000
    @test g(c, 1, 1) == 1000

    d, e1, e2, f = D1(), E1(1, 1), E1(1.0, 1.0), F1(1)

    @test g(e1, 1, d) == 0
    @test g(e1, 1, e2) == 1
    @test g(e1, 1, f) == 4
    @test g(d, 1, e1) == 3

    @test g(B1(1,1), 1, [A1()]) == [A1()]

    g1, h1, i1 = G1{Int, Int, Int}(), H1{Int, Int, Int}(1, 1), I1{Int, Int, Int}(5)
    g2, h2, i2 = G1{Float64, Float64, Float64}(), H1{Float64, Float64, Float64}(1, 1), I1{Float64, Float64, Float64}(1)

    @test g(h1, g1, i1) == 6
    @test g(g1, g1, i1) == 5
    @test g(h2, g2, i2) == 1.0
    @test t(A1()) == 100
end
