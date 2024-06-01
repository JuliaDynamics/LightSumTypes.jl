
@sum_structs SingleT1 begin
    struct ST1 end
end

abstract type AbstractE{X, Y} end
@sum_structs E{X<:Real,Y<:Real} <: AbstractE{X, Y} begin
    @kwdef mutable struct F{X<:Int}
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
    @kwdef mutable struct H{X,Y<:Real}
        a::Tuple{X, X}
        f::Y
        g::Tuple{Complex, Complex}
        const c::Symbol
    end
end

@sum_structs Animal2{T,N,J} begin
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
@sum_structs Simple2 <: AbstractSimple2 begin
    struct SimpleA2
        x
        z::Int
    end
    struct SimpleB2
        y
        q::String
    end
end

@sum_structs TestOrder2 begin
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

@sum_structs AA{T} begin
    @kwdef mutable struct BB{T}
        id::Int
        a::T = 1
        b::Int
        c::Symbol
    end
    @kwdef mutable struct CC
        id::Int
        b::Int = 2
        c::Symbol
        d::Vector{Int}
    end
    @kwdef mutable struct DD{T}
        id::Int
        c::Symbol = :k
        d::Vector{Int}
        a::T
    end
end

@testset "@sum_structs :opt_speed" begin
    
    st = ST1()
    @test propertynames(st) == ()

    f = F((1,1), (1.0, 1.0), :s)
    g1 = G((1,1), 1, 1, :c)
    g2 = G(; a = (1,1), d = 1, e = 1, c = :c)
    h = H((1,1), 1, (im, im), :j)

    @test_throws "" F((1.0,1.0), (1.0, 1.0), :s)
    @test_throws "" G((1,1), im, (im, im), :d)
    @test_throws "" G((im,im), 1, (im, im), :d)

    @test f.a == (1,1)
    @test f.b == (1.0, 1.0)
    @test f.c == :s
    @test g1.d === g2.d === Int32(1)
    @test g1.e === g2.e === true
    
    f.a = (3, 3)
    @test f.a == (3, 3)

    @test kindof(f) == :F
    @test propertynames(f) == (:a, :b, :c)

    copy_f = copy(f)
    @test copy_f.a == f.a
    @test kindof(copy_f) == kindof(f)
    @test allkinds(E) == (:F, :G, :H)
    @test allkinds(typeof(f)) == (:F, :G, :H)
    @test kindconstructor(f) == F
    @test kindconstructor(h) == H

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
    @test allkinds(Animal2) == (:Wolf2, :Hawk2)
    @test allkinds(typeof(wolf_3)) == (:Wolf2, :Hawk2)

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
    @test allkinds(Simple2) == (:SimpleA2, :SimpleB2)
    @test allkinds(typeof(b)) == (:SimpleA2, :SimpleB2)

    o1 = TestOrder21("a", 2.0)
    o2 = TestOrder22(3.0, [1], "b")  

    @test propertynames(o1) == (:x, :y)
    @test propertynames(o2) == (:y, :z, :x)
    @test o1.x == "a" && o2.x == "b"
    @test o1.y == 2.0 && o2.y == 3.0
    @test o2.z == [1]
    @test_throws "" o1.z
    @test allkinds(TestOrder2) == (:TestOrder21, :TestOrder22)

    b1 = BB(1, 2, 1, :s)
    c1 = CC(1, 1, :s, Int[])
    d1 = DD(1, :s, [1], 1.0)
    b2 = BB(; id = 1, b = 1, c = :s)
    c2 = CC(; id = 1, c = :s, d = [1,2])
    d2 = DD(; id = 1, d = [1], a = true)
    b3 = BB{Float64}(1, 2, 1, :s)
    d3 = DD{Float64}(1, :s, [1], 1.0)
    b4 = BB{Int}(; id = 1, b = 1, c = :s)
    d4 = DD{Int}(; id = 1, d = [1], a = true)

    @test b3.a === 2.0 && d3.a === 1.0
    @test b4.a === 1 && d4.a === 1
end
