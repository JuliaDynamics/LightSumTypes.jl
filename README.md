# MixedStructTypes.jl

[![CI](https://github.com/JuliaDynamics/MixedStructTypes.jl/workflows/CI/badge.svg)](https://github.com/JuliaDynamics/MixedStructTypes.jl/actions?query=workflow%3ACI)
[![codecov](https://codecov.io/gh/JuliaDynamics/MixedStructTypes.jl/graph/badge.svg?token=rz9b1WTqCa)](https://codecov.io/gh/JuliaDynamics/MixedStructTypes.jl)

This package allows to pack multiple heterogeneous types in a single type. 

Two macros implement different strategies to create a compact representation of 
the types: `@struct_compact_type` and `@struct_sum_type`.

Both work very similarly but there are some differences:

- `@struct_compact_type` is a bit faster;

- `@struct_sum_type` is more memory efficient and allows to mix mutable and immutable structs where fields belonging to different structs can also have different types, it uses [SumTypes.jl](https://github.com/MasonProtter/SumTypes.jl) under the hood. 

Even if there is only a unique type defined by these macros, you can access a symbol containing the 
conceptual type of an instance with the function `kindof`.

## Example

```julia
julia> using MixedStructTypes

julia> abstract type AbstractA{X} end

julia> @struct_sum_type A{X} <: AbstractA{X} begin
           @kwdef mutable struct B{X}
               a::Tuple{X, X} = (1,1)
               b::Tuple{Float64, Float64} = (1.0, 1.0)
               const c::Symbol = :s
           end
           @kwdef mutable struct C
               a::Tuple{Int, Int} = (2,2)
               const c::Symbol = :q
               d::Int32 = Int32(2)
               e::Bool = false
           end
           @kwdef struct D
               a::Tuple{Int, Int} = (3,3)
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

julia> abstract type AbstractE{X} end 

julia> # as you can see, here, all structs are mutable
       # and all shared fields in different structs have
       # the same type

julia> @struct_compact_type E{X} <: AbstractE{X} begin
           @kwdef mutable struct F{X}
               a::Tuple{X, X} = (1,1)
               b::Tuple{Float64, Float64} = (1.0, 1.0)
               const c::Symbol = :s
           end
           @kwdef mutable struct G{X}
               a::Tuple{X, X} = (2,2)
               const c::Symbol = :q
               d::Int32 = Int32(2)
               e::Bool = false
           end
           @kwdef mutable struct H{X}
               a::Tuple{X, X} = (3,3)
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

Let's see briefly how the two macros compare performance-wise:

```julia
julia> vec_a = A{Int}[rand((B,C,D))() for _ in 1:10^6];

julia> vec_e = E{Int}[rand((F,G,H))() for _ in 1:10^6];

julia> Base.summarysize(vec_a)
41463268

julia> Base.summarysize(vec_e)
93289413

julia> using BenchmarkTools

julia> @btime sum(x.a[1] for x in $vec_a);
  5.585 ms (0 allocations: 0 bytes)

julia> @btime sum(x.a[1] for x in $vec_e);
  2.938 ms (0 allocations: 0 bytes)
```

