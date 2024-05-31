
using MixedStructTypes, Test

@compact_structs X{T1, T2, T3} begin
    struct A1 end
    struct B1{T3, T1}
        a::T1 
        c::T3
    end
    struct C1{T2} 
        b::T2
    end
end

@sum_structs Y{T1, T2, T3} begin
    struct D1 end
    struct E1{T1, T3}
        a::T1 
        c::T3
    end
    struct F1{T2} 
        b::T2
    end
end

@dispatch g(x::B1, q, a::A1) = -1
@dispatch g(x::B1, q::Int, a::A1) = 0
@dispatch g(x::B1, q::Int, b::B1) = 1
@dispatch g(x::B1, q::Int, c::C1) = 2
@dispatch g(a::A1, q::Int, c::B1; s = 1) = 3

@dispatch g(a::A1, q::Int, c::B1{Int}; s = 1) = 10 + s
@dispatch g(a::A1, q::Int, c::C1{Int}; s = 1) = 11 + s

@dispatch g(a::E1, b::Int, c::D1) = 0
@dispatch g(a::E1, b::Int, c::E1) = 1
@dispatch g(a::E1, b::Int, c::F1) = 2
@dispatch g(a::D1, b::Int, c::E1; s = 1) = 3
@dispatch g(a::E1, b::Int, c::F1) = 4

Methods_Dispatch_Module_219428042303.define_all()

@testset "@dispatch" begin
    
    a, b1, b2, c = A1(), B1(0.0, 0.0), B1(1.0, 1.0), C1(1.0)

    @test g(b1, true, a) == -1
    @test g(b1, 1, a) == 0
    @test g(b1, 1, b2) == 1
    @test g(b1, 1, c) == 2
    @test g(a, 1, b1) == 3

    b3, c3 = B1(1, 1), C1(1)
    @test g(a, 1, c3) == 12
    @test g(a, 1, b3) == 11

    d, e1, e2, f = D1(), E1(1, 1), E1(1.0, 1.0), F1(1)

    @test g(e1, 1, d) == 0
    @test g(e1, 1, e2) == 1
    @test g(e1, 1, f) == 4
    @test g(d, 1, e1) == 3
end
