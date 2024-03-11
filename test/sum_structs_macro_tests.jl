
@sum_structs SingleT2 begin
    struct ST2 end
end

abstract type AbstractA{X, Y} end
@sum_structs A{X<:Real,Y<:Real} <: AbstractA{X, Y} begin
    @kwdef mutable struct B{X<:Int}
        a::Tuple{X, X}
        b::Tuple{Float64, Float64}
        const c::Symbol
    end
    @kwdef mutable struct C
        a::Tuple{Int, Int}
        d::Int32
        e::Bool
        const c::Symbol
    end
    @kwdef struct D{Y<:Real}
        a::Tuple{Int, Int}
        f::Y
        g::Tuple{Complex, Complex}
        c::Symbol
    end
end

@sum_structs Animal{T,N,J} begin
    @kwdef mutable struct Wolf{T,N}
        energy::T = 0.5
        ground_speed::N
        const fur_color::Symbol
    end
    @kwdef mutable struct Hawk{T,N,J}
        energy::T = 0.1
        ground_speed::N
        flight_speed::J
    end
end

abstract type AbstractSimple end
@sum_structs Simple <: AbstractSimple begin
    struct SimpleA
        x
        z::Int
    end
    struct SimpleB
        y
        q::String
    end
end

@sum_structs TestOrder1 begin
    struct TestOrder11
        x::String
        y::Float64
    end
    struct TestOrder12
        y::Float64
        z::Vector{Int}
        x::String
    end
end

@testset "@sum_structs" begin

    st = ST2()
    @test propertynames(st) == ()

    b = B((1,1), (1.0, 1.0), :s)
    c1 = C((1,1), 1, 1, :c)
    c2 = C(; a = (1,1), d = 1, e = 1, c = :c)
    d = D((1,1), 1, (im, im), :d)

    @test_throws "" B((1.0,1.0), (1.0, 1.0), :s)
    @test_throws "" D((1,1), im, (im, im), :d)

    @test b.a == (1,1)
    @test b.b == (1.0, 1.0)
    @test b.c == :s
    @test c1.d === c2.d === Int32(1)
    @test c1.e === c2.e === true

    b = B((1,1), (1.0, 1.0), :s)
    copy_b = copy(b)
    @test copy_b.a == b.a
    @test kindof(copy_b) == kindof(b)

    b.a = (3, 3)
    @test b.a == (3, 3)

    @test kindof(b) == :B
    @test propertynames(b) == (:a, :b, :c)
    @test allkinds(A) == (:B, :C, :D)
    @test allkinds(typeof(b)) == (:B, :C, :D)
    @test kindconstr(b) == B
    
    hawk_1 = Hawk(1.0, 2.0, 3)
    hawk_2 = Hawk(; ground_speed = 2.3, flight_speed = 2)
    wolf_1 = Wolf(2.0, 3.0, :black)
    wolf_2 = Wolf(; ground_speed = 2.0, fur_color = :white)
    wolf_3 = Wolf{Int, Float64}(2.0, 3.0, :black)
    wolf_4 = Wolf{Float64, Float64}(; ground_speed = 2.0, fur_color = :white)

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
    @test kindof(hawk_1) == kindof(hawk_2) == :Hawk
    @test kindof(wolf_1) == kindof(wolf_2) == :Wolf 
    @test allkinds(Animal) == (:Wolf, :Hawk)
    @test allkinds(typeof(wolf_2)) == (:Wolf, :Hawk)

    b = SimpleA(1, 3)
    c = SimpleB(2, "a")

    @test b.x == 1 && b.z == 3
    @test c.y == 2 && c.q == "a"
    @test_throws "" b.y
    @test_throws "" b.q
    @test_throws "" c.x
    @test_throws "" c.z
    @test kindof(b) == :SimpleA
    @test kindof(c) == :SimpleB
    @test Simple <: AbstractSimple
    @test b isa Simple && c isa Simple 
    @test allkinds(Simple) == (:SimpleA, :SimpleB)
    @test allkinds(typeof(b)) == (:SimpleA, :SimpleB)

    o1 = TestOrder11("a", 2.0)
    o2 = TestOrder12(3.0, [1], "b") 

    @test propertynames(o1) == (:x, :y)
    @test propertynames(o2) == (:y, :z, :x)
    @test o1.x == "a" && o2.x == "b"
    @test o1.y == 2.0 && o2.y == 3.0
    @test o2.z == [1]
    @test_throws "" o1.z
    @test allkinds(TestOrder1) == (:TestOrder11, :TestOrder12)
end
