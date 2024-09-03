# DynamicSumTypes.jl

[![CI](https://github.com/JuliaDynamics/DynamicSumTypes.jl/workflows/CI/badge.svg)](https://github.com/JuliaDynamics/DynamicSumTypes.jl/actions?query=workflow%3ACI)
[![](https://img.shields.io/badge/docs-stable-blue.svg)](https://juliadynamics.github.io/DynamicSumTypes.jl/stable/)
[![codecov](https://codecov.io/gh/JuliaDynamics/DynamicSumTypes.jl/graph/badge.svg?token=rz9b1WTqCa)](https://codecov.io/gh/JuliaDynamics/DynamicSumTypes.jl)
[![Aqua QA](https://raw.githubusercontent.com/JuliaTesting/Aqua.jl/master/badge.svg)](https://github.com/JuliaTesting/Aqua.jl)
[![DOI](https://zenodo.org/badge/745234998.svg)](https://zenodo.org/doi/10.5281/zenodo.12826686)


This package allows to combine multiple heterogeneous types in a single one. This helps to write 
type-stable code by avoiding `Union` performance drawbacks when many types are unionized. Another 
aim of this library is to provide a syntax as similar as possible to standard Julia 
structs to facilitate its integration within other libraries. 

The `@sumtype` macro takes inspiration from [SumTypes.jl](https://github.com/MasonProtter/SumTypes.jl),
but it offers a much more simple and idiomatic interface. Working with it is almost like working with `Union` types.

## Definition

To define a sum type you can just take an arbitrary number of types and enclose them in it
like so:

```julia
julia> using DynamicSumTypes

julia> abstract type AbstractS end

julia> struct A{X}
           x::X
       end

julia> mutable struct B{Y}
           y::Y
       end

julia> struct C
           z::Int
       end

julia> @sumtype S{X}(A{X},B{Int},C) <: AbstractS
```

## Construction

Then constructing instances is just a matter of enclosing the type constructed in the
predefined sum type:

```julia
julia> a = S(A(1))
S{Int64}(A{Int64}(1))

julia> b = S{Int}(B(1))
S{Int64}(B{Int64}(1))

julia> c = S{Int}(C(1))
S{Int64}(C(1))
```

a different syntax is also provided for convenience:

```julia
julia> a = S'.A(1)
S{Int64}(A{Int64}(1))

julia> b = S{Int}'.B(1)
S{Int64}(B{Int64}(1))

julia> c = S{Int}'.C(1)
S{Int64}(C(1))
```

## Access and Mutation

This works like if they were normal Julia types:

```julia
julia> a.x
1

julia> b.y = 3
3
```

## Dispatch

For this, you can simply access the variant 
inside the sum type and then dispatch on it:

```julia
julia> f(x::S) = f(variant(x))

julia> f(x::A) = 1

julia> f(x::B) = 2

julia> f(x::C) = 3

julia> f(a)
1

julia> f(b)
2

julia> f(c)
3
```

## Micro-benchmarks

<details>
 <summary>Benchmark code</summary>

```julia
using BenchmarkTools
using DynamicSumTypes
       
struct A end
struct B end
struct C end
struct D end
struct E end
struct F end

@sumtype S(A, B, C, D, E, F)
       
f(s::S) = f(variant(s));
f(::A) = 1;
f(::B) = 2;
f(::C) = 3;
f(::D) = 4;
f(::E) = 5;
f(::F) = 6;

vals = rand((A(), B(), C(), D(), E(), F()), 1000);

tuple_manytypes = Tuple(vals);
vec_manytypes = collect(Union{A, B, C, D, E, F}, vals);

tuple_sumtype = Tuple(S.(vals));
vec_sumtype = S.(vals);

@benchmark sum($f, $tuple_manytypes)
@benchmark sum($f, $tuple_sumtype)
@benchmark sum($f, $vec_manytypes)
@benchmark sum($f, $vec_sumtype)
```
</details>

```julia
julia> @benchmark sum($f, $tuple_manytypes)
BenchmarkTools.Trial: 10000 samples with 1 evaluation.
 Range (min … max):  75.092 μs …  1.176 ms  ┊ GC (min … max): 0.00% … 91.00%
 Time  (median):     77.736 μs              ┊ GC (median):    0.00%
 Time  (mean ± σ):   78.613 μs ± 16.373 μs  ┊ GC (mean ± σ):  0.34% ±  1.67%

                ▅█▇▆▁                                          
  ▂▂▁▂▂▂▂▂▂▂▂▃▄██████▆▃▂▂▂▂▂▂▂▂▃▃▄▄▅▄▄▃▃▂▂▂▂▂▂▂▂▂▂▂▂▂▂▂▂▂▂▂▂▂ ▃
  75.1 μs         Histogram: frequency by time        84.3 μs <

 Memory estimate: 13.34 KiB, allocs estimate: 854.

julia> @benchmark sum($f, $tuple_sumtype)
BenchmarkTools.Trial: 10000 samples with 116 evaluations.
 Range (min … max):  758.672 ns … 990.836 ns  ┊ GC (min … max): 0.00% … 0.00%
 Time  (median):     767.828 ns               ┊ GC (median):    0.00%
 Time  (mean ± σ):   772.407 ns ±  13.168 ns  ┊ GC (mean ± σ):  0.00% ± 0.00%

  ▄   █    █    ▆          ▄    ▄   ▄▂   ▆    ▁                 ▂
  █▄▁▁█▇██▇█▇▆▇▇█▃▅▅▄▅▆▇▄▇██▇▆▇██▆▆▇██▆▆▆█▄▄▅▄█▄▄▁▁▄▄▁▃▁▃▆▆▁▄▆▅ █
  759 ns        Histogram: log(frequency) by time        817 ns <

 Memory estimate: 0 bytes, allocs estimate: 0.

julia> @benchmark sum($f, $vec_manytypes)
BenchmarkTools.Trial: 10000 samples with 211 evaluations.
 Range (min … max):  355.455 ns … 504.645 ns  ┊ GC (min … max): 0.00% … 0.00%
 Time  (median):     360.536 ns               ┊ GC (median):    0.00%
 Time  (mean ± σ):   362.472 ns ±   6.510 ns  ┊ GC (mean ± σ):  0.00% ± 0.00%

            ▁█                                                   
  ▂▅▆▂▂▃▇▆▂▃██▇▂▂▃▅▃▂▁▂▂▂▂▂▂▂▂▂▂▂▂▂▃▃▃▃▂▂▂▃▄▃▂▂▂▂▂▂▂▂▁▁▁▁▂▂▂▂▂▂ ▃
  355 ns           Histogram: frequency by time          383 ns <

 Memory estimate: 0 bytes, allocs estimate: 0.

julia> @benchmark sum($f, $vec_sumtype)
BenchmarkTools.Trial: 10000 samples with 276 evaluations.
 Range (min … max):  286.880 ns … 372.297 ns  ┊ GC (min … max): 0.00% … 0.00%
 Time  (median):     291.453 ns               ┊ GC (median):    0.00%
 Time  (mean ± σ):   292.996 ns ±   4.673 ns  ┊ GC (mean ± σ):  0.00% ± 0.00%

        ▁█   ▅▇   █▄                                             
  ▂▃▅▄▂▃██▅▃▃██▄▃▅██▃▂▂▂▂▂▂▂▂▂▂▂▃▃▂▂▂▃▃▂▂▃▄▆▅▃▂▂▂▂▂▂▁▂▂▂▂▁▂▂▁▂▂ ▃
  287 ns           Histogram: frequency by time          309 ns <

 Memory estimate: 0 bytes, allocs estimate: 0.
```

<sub>*These benchmarks have been run on Julia 1.11*</sub>

------

See the [Discourse announcement post](https://discourse.julialang.org/t/ann-dynamicsumtypes-jl-v3/116741)
for more information about the performance advantages of the approach in respect to a `Union`. In summary,
it is shown that for Julia<1.11, `@sumtype` has a huge performance advantage in realistic programs (often
around 10x), while for Julia>=1.11, given the improvements in dynamic dispatch issues related to a `Union`,
the advantage of `@sumtype` is much less, around 1.5-2x faster.

## Contributing

Contributions are welcome! If you encounter any issues, have suggestions for improvements, or would like to add new 
features, feel free to open an issue or submit a pull request.
