
@compact_structs E{X,Y} begin
    @kwdef mutable struct F{X}
        a::Tuple{X, X}
        b::Tuple{Float64, Float64}
        const c::Symbol
    end
    @kwdef mutable struct G{X}
        a::Tuple{X, X}
        d::Int32
        e::Bool
        const c::Symbol
    end
    @kwdef mutable struct H{X,Y}
        a::Tuple{X, X}
        f::Y
        g::Tuple{Complex, Complex}
        const c::Symbol
    end
end

@compact_structs Animal2{T,N,J} begin
    @kwdef mutable struct Wolf2{T,N}
        energy::T = 0.5
        ground_speed::N
        const fur_color::Symbol
    end
    @kwdef mutable struct Hawk2{T,N,J}
        energy::T = 0.1
        ground_speed::N
        flight_speed::J
    end
end

abstract type AbstractSimple2 end
@compact_structs Simple2 <: AbstractSimple2 begin
    struct SimpleA2
        x
        z::Int
    end
    struct SimpleB2
        y
        q::String
    end
end

@compact_structs TestOrder2 begin
    struct TestOrder21
        x::String
        y::Float64
    end
    struct TestOrder22
        y::Float64
        z::Vector{Int}
        x::String
    end
end

@testset "@compact_structs" begin

    f = F((1,1), (1.0, 1.0), :s)
    g1 = G((1,1), 1, 1, :c)
    g2 = G(; a = (1,1), d = 1, e = 1, c = :c)

    @test f.a == (1,1)
    @test f.b == (1.0, 1.0)
    @test f.c == :s
    @test g1.d === g2.d === Int32(1)
    @test g1.e === g2.e === true
    
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
    wolf_3 = Wolf2{Int, Float64}(2.0, 3.0, :black)
    wolf_4 = Wolf2{Float64, Float64}(; ground_speed = 2.0, fur_color = :white)

    @test hawk_1.energy == 1.0
    @test hawk_2.energy == 0.1
    @test wolf_1.energy == 2.0
    @test wolf_2.energy == 0.5
    @test wolf_3.energy === 2 && wolf_4.energy === 0.5
    @test hawk_1.flight_speed == 3
    @test hawk_2.flight_speed == 2
    @test wolf_1.fur_color == :black
    @test wolf_2.fur_color == :white
    @test_throws "" hawk_1.fur_color
    @test_throws "" wolf_1.flight_speed
    @test kindof(hawk_1) == kindof(hawk_2) == :Hawk2
    @test kindof(wolf_1) == kindof(wolf_2) == :Wolf2 


    b = SimpleA2(1, 3)
    c = SimpleB2(2, "a")

    @test b.x == 1 && b.z == 3
    @test c.y == 2 && c.q == "a"
    @test_throws "" b.y
    @test_throws "" b.q
    @test_throws "" c.x
    @test_throws "" c.z
    @test kindof(b) == :SimpleA2
    @test kindof(c) == :SimpleB2
    @test Simple2 <: AbstractSimple2
    @test b isa Simple2 && c isa Simple2 

    o1 = TestOrder21("a", 2.0)
    o2 = TestOrder22(3.0, [1], "b")  

    @test propertynames(o1) == (:x, :y)
    @test propertynames(o2) == (:y, :z, :x)
    @test o1.x == "a" && o2.x == "b"
    @test o1.y == 2.0 && o2.y == 3.0
    @test o2.z == [1]
    @test_throws "" o1.z
end
