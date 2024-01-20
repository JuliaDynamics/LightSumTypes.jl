# MixedStructTypes.jl

This package allows to pack heterogeneous types in a single type. Two macros implements different
strategies to create a compact representation of the types:

- `@sum_struct_type`  which uses as a backend [SumTypes.jl](https://github.com/MasonProtter/SumTypes.jl);

- `@compact_struct_type` which uses as a backend [LazilyInitializedFields.jl](https://github.com/KristofferC/LazilyInitializedFields.jl);

While `@compact_struct_type` is a bit faster, `@sum_struct_type` is more memory efficient and it allows to mix
mutable and immutable structs, while the first macro does not.


```julia
julia> using MixedStructTypes

julia> @sum_struct_type A{X} begin
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

julia> b = B((1,1), (1.0, 1.0), :s)
B{Int64}((1, 1), (1.0, 1.0), :s)::A

julia> b.a
(1, 1)

julia> b.c
:s

julia> b.a = (3, 3)
(3, 3)

julia> kindof(b)
:B
```
