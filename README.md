# MixedStructTypes.jl

[![CI](https://github.com/JuliaDynamics/MixedStructTypes.jl/workflows/CI/badge.svg)](https://github.com/JuliaDynamics/MixedStructTypes.jl/actions?query=workflow%3ACI)
[![](https://img.shields.io/badge/docs-stable-blue.svg)](https://juliadynamics.github.io/MixedStructTypes.jl/stable/)
[![codecov](https://codecov.io/gh/JuliaDynamics/MixedStructTypes.jl/graph/badge.svg?token=rz9b1WTqCa)](https://codecov.io/gh/JuliaDynamics/MixedStructTypes.jl)
[![Aqua QA](https://raw.githubusercontent.com/JuliaTesting/Aqua.jl/master/badge.svg)](https://github.com/JuliaTesting/Aqua.jl)

This package allows to combine multiple heterogeneous types in a single one. This helps to write type-stable code
by avoiding Union-splitting, which has big performance drawbacks when many types are unionized. A second aim
of this library is to provide a syntax as similar as possible to standard Julia structs to help integration within
other libraries. 

Two macros implement different strategies to create a compact representation of the types: `@compact_structs` and
`@sum_structs`.

Both work very similarly, but there are some differences:

- `@compact_structs` is faster;

- `@sum_structs` is more memory efficient and allows to mix mutable and immutable structs where fields belonging to different structs can also have different types, it uses [SumTypes.jl](https://github.com/MasonProtter/SumTypes.jl) under the hood. 

Even if there is only a unique type defined by these macros, you can access a symbol containing the conceptual type
of an instance with the function `kindof`.

## Example

```julia
julia> using MixedStructTypes

julia> abstract type AbstractA{X} end

julia> @sum_structs A{X} <: AbstractA{X} begin
           @kwdef mutable struct B{X}
               a::X = 1
               b::Float64 = 1.0
           end
           @kwdef mutable struct C
               a::Int = 2
               c::Bool = true
           end
           @kwdef mutable struct D
               a::Int = 3
               const d::Symbol = :s
           end
           @kwdef struct E{X}
               a::X = 4
           end
       end

julia> b = B(1, 1.5)
B{Int64}(1, 1.5)::A

julia> b.a
1

julia> b.a = 3
3

julia> kindof(b)
:B

julia> abstract type AbstractF{X} end

julia> # as you can see, here, all structs are mutable
       # and all shared fields in different structs have
       # the same type
       @compact_structs F{X} <: AbstractF{X} begin
           @kwdef mutable struct G{X}
               a::X = 1
               b::Float64 = 1.0
           end
           @kwdef mutable struct H{X}
               a::X = 2
               c::Bool = true
           end
           @kwdef mutable struct I{X}
               a::X = 3
               const d::Symbol = :s
           end
           @kwdef mutable struct L{X}
               a::X = 4
           end
       end

julia> g = G(1, 1.5)
G{Int64}(1, 1.5)::F

julia> g.a
1

julia> g.a = 3
3

julia> kindof(g)
:G
```

Consult the [API page](https://juliadynamics.github.io/MixedStructTypes.jl/stable/) for more information on the available functionalities.

## Benchmark

Let's see briefly how the two macros compare performance-wise in respect to a `Union` of types:

```julia
julia> @kwdef mutable struct M{X}
           a::X = 1
           b::Float64 = 1.0
       end

julia> @kwdef mutable struct N{X}
           a::X = 2
           c::Bool = true
       end

julia> @kwdef mutable struct O{X}
           a::X = 3
           const d::Symbol = :s
       end

julia> @kwdef mutable struct P{X}
           a::X = 4
       end

julia> vec_union = Union{M{Int},N{Int},O{Int},P{Int}}[rand((M,N,O,P))() for _ in 1:10^6];

julia> vec_sum = A{Int}[rand((B,C,D,E))() for _ in 1:10^6];

julia> vec_compact = F{Int}[rand((G,H,I,L))() for _ in 1:10^6];

julia> Base.summarysize(vec_union)
21997856

julia> Base.summarysize(vec_sum)
28868832

julia> Base.summarysize(vec_compact)
49924817

julia> using BenchmarkTools

julia> @btime sum(x.a for x in $vec_union);
  26.762 ms (999788 allocations: 15.26 MiB)

julia> @btime sum(x.a for x in $vec_sum);
  6.595 ms (0 allocations: 0 bytes)

julia> @btime sum(x.a for x in $vec_compact);
  1.936 ms (0 allocations: 0 bytes)
```

In this case, `@compact_structs` types are almost 15 times faster than `Union` ones, even if they require more than
double the memory. Whereas, as expected, `@sum_structs` types are less time efficient than `@compact_structs` ones, 
but the memory usage increase in respect to `Union` types is smaller.

## Contributing

Contributions are welcome! If you encounter any issues, have suggestions for improvements, or would like to add new 
features, feel free to open an issue or submit a pull request.
