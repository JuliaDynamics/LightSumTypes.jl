
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

@dispatch f(x::X, q::Int, a::A1) = 0
@dispatch f(x::X, q::Int, b::B1) = 1
@dispatch f(x::X, q::Int, c::C1) = 2
@dispatch f(a::A1, q::Int, c::B1; s = 1) = 3
@dispatch f(a::A1, q::Int, c::B1{Q}; s = 1) where Q = 4
@dispatch f(a::A1, q::Float64, c::B1) = 5
@dispatch f(a::A1, q::Complex, c::B1{Int}; s = 1) = 6
@dispatch f(z::C1, q::Complex, c::B1{Int, Int}; s = 1) = 7
@dispatch f(a::A1, q::Int, c::B1{Q, Int} where Q; s = 1) = 8
@dispatch f(a::A1, q::Int, c::B1{Q, Q} where Q; s = 1) = 9

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

@dispatch f(a::Y, b::Int, c::D1) = 0
@dispatch f(a::Y, b::Int, c::E1) = 1
@dispatch f(a::Y, b::Int, c::F1) = 2
@dispatch f(a::D1, b::Int, c::E1; s = 1) = 3
@dispatch f(a::D1, b::Int, c::E1{Q}; s = 1) where Q = 4
@dispatch f(a::D1, b::Float64, c::E1) = 5
@dispatch f(a::D1, b::Complex, c::E1{Int}; s = 1) = 6
@dispatch f(a::F1, b::Complex, c::E1{Int, Int}; s = 1) = 7
@dispatch f(a::D1, b::Int, c::E1{Q, Int} where Q; s = 1) = 8
@dispatch f(a::D1, b::Int, c::E1{Q, Q} where Q; s = 1) = 9

