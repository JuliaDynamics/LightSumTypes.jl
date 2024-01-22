# MixedStructTypes.jl

This package allows to pack multiple heterogeneous types in a single type. 

Two macros implements different strategies to create a compact representation of the types: `@sum_struct_type`
and `@compact_struct_type`.

Both works very similarly but there are some differences:

- `@compact_struct_type` is a bit faster;

- `@sum_struct_type` is more memory efficient and allows to mix mutable and immutable structs where fields belonging to different structs can also have different types, it uses [SumTypes.jl](https://github.com/MasonProtter/SumTypes.jl) under the hood. 

## Example

```julia
julia> using MixedStructTypes

julia> @sum_struct_type @kwdef A{X} begin
           mutable struct B{X}
               a::Tuple{X, X} = (1,1)
               b::Tuple{Float64, Float64} = (1.0, 1.0)
               const c::Symbol = :s
           end
           mutable struct C
               a::Tuple{Int, Int} = (1,1)
               const c::Symbol = :q
               d::Int32 = Int32(2)
               e::Bool = false
           end
           struct D
               a::Tuple{Int, Int} = (1,1)
               c::Symbol = :s
               f::Char = 'p'
               g::Tuple{Complex, Complex} = (im, im)
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
       @compact_struct_type @kwdef E{X} begin
           mutable struct F{X}
               a::Tuple{X, X} = (1,1)
               b::Tuple{Float64, Float64} = (1.0, 1.0)
               const c::Symbol = :s
           end
           mutable struct G{X}
               a::Tuple{X, X} = (1,1)
               const c::Symbol = :q
               d::Int32 = Int32(2)
               e::Bool = false
           end
           mutable struct H{X}
               a::Tuple{X, X} = (1,1)
               const c::Symbol = :s
               f::Char = 'p'
               g::Tuple{Complex, Complex} = (im, im)
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

