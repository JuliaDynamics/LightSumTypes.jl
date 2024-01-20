# StructSumTypes.jl

This package implements an interface based on [SumTypes.jl](https://github.com/MasonProtter/SumTypes.jl) which allows to work with sum types with a structs-like syntax:

```julia
julia> using StructSumTypes

julia> @struct_sum_type A{X} begin
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
           mutable struct D
               a::Tuple{Int, Int}
               f::Float32
               g::Tuple{Complex, Complex}
               const c::Symbol
           end
       end
A

julia> b = B((1,1), (1.0, 1.0), :s)
B{Int64}((1, 1), (1.0, 1.0), :s)

julia> b.a
(1, 1)

julia> b.c
:s

julia> b.a = (3, 3)
(3, 3)

julia> kindof(b)
:B
```
