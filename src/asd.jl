
julia> using Revise

julia> using DynamicSumTypes

julia> abstract type AbstractA{X} end

julia>  # default version is :on_fields
        @sum_structs A{X} <: AbstractA{X} begin
           @kwdef mutable struct B{X}
               a::X = 1
               b::Float64 = 1.0
           end
           @kwdef mutable struct C{X}
               a::X = 2
               c::Bool = true
           end
           @kwdef mutable struct D{X}
               a::X = 3
               const d::Symbol = :s
           end
           @kwdef mutable struct E{X}
               a::X = 4
           end
       end

julia> @export_variants(A)

julia> b = B(1, 1.5)
B{Int64}(1, 1.5)::A

julia> b.a
1

julia> b.a = 3
3

julia> kindof(b)
:B

julia> function sum2(v) # with @pattern macro
           s = 0
           for x in v
               s += value(1, x)
           end
           return s
       end
sum2 (generic function with 1 method)

julia> @pattern value(k::Int, ::A'.B) = k + 1;

