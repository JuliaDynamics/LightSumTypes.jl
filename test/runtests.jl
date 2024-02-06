
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

@sum_struct_type @kwdef Animal{T,N,J} begin
    mutable struct Wolf{T,N}
        energy::T = 0.5
        ground_speed::N
        const fur_color::Symbol
    end
    mutable struct Hawk{T,N,J}
        energy::T = 0.1
        ground_speed::N
        flight_speed::J
    end
end

abstract type AbstractSimple end
@sum_struct_type Simple <: AbstractSimple begin
    struct SimpleA
        x::Int
    end
    struct SimpleB
        y::Int
    end
end

@testset "@sum_struct_type" begin

    b = B((1,1), (1.0, 1.0), :s)
    c = C((1,1), 1, 1, :c)
    
    @test b.a == (1,1)
    @test b.b == (1.0, 1.0)
    @test b.c == :s
    @test c.d === Int32(1)
    @test c.e === true

    b.a = (3, 3)
    @test b.a == (3, 3)

    @test kindof(b) == :B
    @test MixedStructTypes.constructor(b) == B
    @test propertynames(b) == (:a, :b, :c)
    
    hawk_1 = Hawk(1.0, 2.0, 3)
    hawk_2 = Hawk(; ground_speed = 2.3, flight_speed = 2)
    wolf_1 = Wolf{Float64, Float64}(2.0, 3.0, :black)
    wolf_2 = Wolf(; ground_speed = 2.0, fur_color = :white)

    @test hawk_1.energy == 1.0
    @test hawk_2.energy == 0.1
    @test wolf_1.energy == 2.0
    @test wolf_2.energy == 0.5
    @test hawk_1.flight_speed == 3
    @test hawk_2.flight_speed == 2
    @test wolf_1.fur_color == :black
    @test wolf_2.fur_color == :white
    @test_throws "" hawk_1.fur_color
    @test_throws "" wolf_1.flight_speed
    @test kindof(hawk_1) == kindof(hawk_2) == :Hawk
    @test kindof(wolf_1) == kindof(wolf_2) == :Wolf 

    b = SimpleA(1)
    c = SimpleB(2)

    @test b.x == 1
    @test c.y == 2
    @test_throws "" b.y
    @test_throws "" c.x
    @test kindof(b) == :SimpleA
    @test kindof(c) == :SimpleB
    @test Simple <: AbstractSimple
    @test b isa Simple && c isa Simple  
end

@static if VERSION >= v"1.10"
    @testset "copy tests @struct_sum_type" begin
        b = B((1,1), (1.0, 1.0), :s)
        copy_b = copy(b)
        @test copy_b.a == b.a
        @test kindof(copy_b) == kindof(b)
    end
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

@compact_struct_type @kwdef Animal2{T,N,J} begin
    mutable struct Wolf2{T,N}
        energy::T = 0.5
        ground_speed::N
        const fur_color::Symbol
    end
    mutable struct Hawk2{T,N,J}
        energy::T = 0.1
        ground_speed::N
        flight_speed::J
    end
end

abstract type AbstractSimple2 end
@compact_struct_type Simple2 <: AbstractSimple2 begin
    struct SimpleA2
        x::Int
    end
    struct SimpleB2
        y::Int
    end
end

@testset "@compact_struct_type" begin

    f = F((1,1), (1.0, 1.0), :s)
    g = G((1,1), 1, 1, :c)

    @test f.a == (1,1)
    @test f.b == (1.0, 1.0)
    @test f.c == :s
    @test g.d === Int32(1)
    @test g.e === true
    
    f.a = (3, 3)
    @test f.a == (3, 3)

    @test kindof(f) == :F
    @test MixedStructTypes.constructor(f) == F
    @test propertynames(f) == (:a, :b, :c)

    copy_f = copy(f)
    @test copy_f.a == f.a
    @test kindof(copy_f) == kindof(f)

    hawk_1 = Hawk2(1.0, 2.0, 3)
    hawk_2 = Hawk2(; ground_speed = 2.3, flight_speed = 2)
    wolf_1 = Wolf2(2.0, 3.0, :black)
    wolf_2 = Wolf2(; ground_speed = 2.0, fur_color = :white)

    @test hawk_1.energy == 1.0
    @test hawk_2.energy == 0.1
    @test wolf_1.energy == 2.0
    @test wolf_2.energy == 0.5
    @test hawk_1.flight_speed == 3
    @test hawk_2.flight_speed == 2
    @test wolf_1.fur_color == :black
    @test wolf_2.fur_color == :white
    @test_throws "" hawk_1.fur_color
    @test_throws "" wolf_1.flight_speed
    @test kindof(hawk_1) == kindof(hawk_2) == :Hawk2
    @test kindof(wolf_1) == kindof(wolf_2) == :Wolf2 


    b = SimpleA2(1)
    c = SimpleB2(2)

    @test b.x == 1
    @test c.y == 2
    @test_throws "" b.y
    @test_throws "" c.x
    @test kindof(b) == :SimpleA2
    @test kindof(c) == :SimpleB2
    @test Simple2 <: AbstractSimple2
    @test b isa Simple2 && c isa Simple2   
end
