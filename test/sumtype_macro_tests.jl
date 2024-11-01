
struct ST1 end

@sumtype SingleT1(ST1)

Base.copy(x::ST1) = ST1()

@kwdef mutable struct F{X<:Integer}
    a::Tuple{X, X}
    b::Tuple{Float64, Float64}
    const c::Symbol
end

@kwdef mutable struct G{X}
    a::Tuple{X, X}
    d::Int
    e::Int
    const c::Symbol
end

@kwdef mutable struct H{X,Y<:Real}
    a::Tuple{X, X}
    f::Y
    g::Tuple{Complex, Complex}
    const c::Symbol
end

abstract type AbstractE end
@sumtype E(F,G,H) <: AbstractE
@sumtype FF(F{Int32}, F{Int64})

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

@sumtype Animal(Wolf, Hawk)

abstract type AbstractSimple end

struct SimpleA
    x
    z::Int
end

struct SimpleB
    y
    q::String
end

@sumtype Simple(SimpleA, SimpleB) <: AbstractSimple

struct Some{T}
   val::T
end

struct None end

@sumtype Option{T}(None, Some{T})

@testset "@sumtype" begin
    
    st = SingleT1(ST1())
    @test propertynames(st) == ()
    @test copy(st) == st

    f = E(F((1,1), (1.0, 1.0), :s))
    g1 = E(G((1,1), 1, 1, :c))
    g2 = E(G(; a = (1,1), d = 1, e = 1, c = :c))
    g3 = (E∘G)((1,1), 1, 1, :c)
    g4 = (E∘G)(; a = (1,1), d = 1, e = 1, c = :c)
    h = E(H((1,1), 1, (im, im), :j))

    @test_throws "" eval(:(@sumtype Z.E))
    @test_throws "" E(F((1.0,1.0), (1.0, 1.0), :s))
    @test_throws "" E(G((1,1), im, (im, im), :d))
    @test_throws "" E(G((im,im), 1, (im, im), :d))

    @test f.a == (1,1)
    @test f.b == (1.0, 1.0)
    @test f.c == :s
    @test g1.d === g2.d === 1
    @test g1.e === g2.e === 1
    @test hasproperty(g1, :e) == true
    @test hasproperty(g1, :w) == false
    @test is_sumtype(typeof(g1)) == true
    @test is_sumtype(G) == false
    @test variantof(g1) == G{Int}
    
    f.a = (3, 3)
    @test f.a == (3, 3)

    @test variant(f) isa F
    @test propertynames(f) == (:a, :b, :c)

    @test allvariants(E) == allvariants(typeof(f)) == (F = F, G = G, H = H)

    ff1 = FF(F((1,1), (1.0, 1.0), :s))
    ff2 = FF(F((Int32(1),Int32(1)), (1.0, 1.0), :s))
    @test allvariants(FF) == (F_Int32 = F{Int32}, F_Int64 = F{Int64})

    hawk_1 = Animal(Hawk(1.0, 2.0, 3))
    hawk_2 = Animal(Hawk(; ground_speed = 2.3, flight_speed = 2))
    wolf_1 = Animal(Wolf(2.0, 3.0, :black))
    wolf_2 = Animal(Wolf(; ground_speed = 2.0, fur_color = :white))
    wolf_3 = Animal(Wolf{Int, Float64}(2.0, 3.0, :black))
    wolf_4 = Animal(Wolf{Float64, Float64}(; ground_speed = 2.0, fur_color = :white))

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
    @test variant(hawk_1) isa Hawk
    @test variant(wolf_1) isa Wolf
    @test allvariants(Animal) == allvariants(typeof(wolf_3)) == (Wolf = Wolf, Hawk = Hawk)

    b = Simple(SimpleA(1, 3))
    c = Simple(SimpleB(2, "a"))

    @test b.x == 1 && b.z == 3
    @test c.y == 2 && c.q == "a"
    @test_throws "" b.y
    @test_throws "" b.q
    @test_throws "" c.x
    @test_throws "" c.z
    @test variant(b) isa SimpleA
    @test variant(c) isa SimpleB
    @test Simple <: AbstractSimple
    @test b isa Simple && c isa Simple
    @test allvariants(Simple) == allvariants(typeof(b)) == (SimpleA = SimpleA, SimpleB = SimpleB)

    option_none = Option{Int}(None())
    option_none2 = (Option{Int}∘None)()
    option_some = Option(Some(1))
    option_some2 = Option{Int}(Some(1))
    option_some3 = (Option{Int}∘Some)(1)
    option_some4 = (Option∘Some)(1)
    @test variant(option_none) isa None
    @test variant(option_some) isa Some{Int}
    @test variant(option_some2) isa Some{Int}
    @test variant(option_some3) isa Some{Int}
    @test variant(option_some4) isa Some{Int}
    @test allvariants(Option) == (None = None, Some = Some)
    @test option_some.val == 1
end
