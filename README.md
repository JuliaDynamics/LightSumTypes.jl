# MixedStructTypes.jl

This package allows to pack multiple heterogeneous types in a single type. 

Two macros implements different strategies to create a compact representation of the types:

- `@sum_struct_type`  which uses as a backend [SumTypes.jl](https://github.com/MasonProtter/SumTypes.jl);

- `@compact_struct_type` which uses as a backend [LazilyInitializedFields.jl](https://github.com/KristofferC/LazilyInitializedFields.jl);

While `@compact_struct_type` is a bit faster, `@sum_struct_type` is more memory efficient and allows to mix
mutable and immutable structs where fields belonging to different structs can also have different types, 
while the first macro does not.

## Example

```julia
julia> using MixedStructTypes

julia> @sum_struct_type A{X,Y} begin
           mutable struct B{X}
               a::Tuple{X, X}
               b::Tuple{Float64, Float64}
               const c::Symbol
           end
           mutable struct C
               a::Tuple{Int, Int}
               const c::Symbol
               d::Int32
               e::Bool
           end
           struct D{Y}
               a::Tuple{Int, Int}
               c::Symbol
               f::Y
               g::Tuple{Complex, Complex}
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

julia> # as you can see, here, all structs are mutable
       # and all shared fields in different structs have
       # the same type
       @compact_struct_type E{X,Y} begin
           mutable struct F{X}
               a::Tuple{X, X}
               b::Tuple{Float64, Float64}
               const c::Symbol
           end
           mutable struct G{X}
               a::Tuple{X, X}
               const c::Symbol
               d::Int32
               e::Bool
           end
           mutable struct H{X,Y}
               a::Tuple{X, X}
               const c::Symbol
               f::Y
               g::Tuple{Complex, Complex}
           end
       end

julia> f = F((1,1), (1.0, 1.0), :s)
F{Int64}((1, 1), (1.0, 1.0), :s)::E

julia> f.a
(1, 1)

julia> f.c
:s

julia> f.a = (3, 3)
(3, 3)

julia> kindof(f)
:F
```

