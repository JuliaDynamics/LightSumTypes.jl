# LightSumTypes.jl

[![CI](https://github.com/JuliaDynamics/LightSumTypes.jl/workflows/CI/badge.svg)](https://github.com/JuliaDynamics/LightSumTypes.jl/actions?query=workflow%3ACI)
[![](https://img.shields.io/badge/docs-stable-blue.svg)](https://juliadynamics.github.io/LightSumTypes.jl/stable/)
[![codecov](https://codecov.io/gh/JuliaDynamics/LightSumTypes.jl/graph/badge.svg?token=rz9b1WTqCa)](https://codecov.io/gh/JuliaDynamics/LightSumTypes.jl)
[![Aqua QA](https://raw.githubusercontent.com/JuliaTesting/Aqua.jl/master/badge.svg)](https://github.com/JuliaTesting/Aqua.jl)
[![DOI](https://zenodo.org/badge/745234998.svg)](https://zenodo.org/doi/10.5281/zenodo.12826686)


This package allows to combine multiple heterogeneous types in a single one. This helps to write 
type-stable code by avoiding `Union` performance drawbacks when many types are unionized. Another 
aim of this library is to provide a syntax as similar as possible to standard Julia 
structs to facilitate its integration within other libraries. 

The `@sumtype` macro takes inspiration from [SumTypes.jl](https://github.com/MasonProtter/SumTypes.jl),
but it offers a more idiomatic interface. Working with it is almost like working with `Union` types.

## Definition

To define a sum type you can just take an arbitrary number of types and enclose them in it
like so:

```julia
julia> using LightSumTypes

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

If you need to decouple the arguments of the sumtype to its
constructor you can use the composition operator:

```julia
julia> a = (S∘A)(1)
S{Int64}(A{Int64}(1))

julia> b = (S{Int}∘B)(1)
S{Int64}(B{Int64}(1))

julia> c = (S{Int}∘C)(1)
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
using LightSumTypes
       
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
iter_manytypes = (x for x in vec_manytypes);

tuple_sumtype = Tuple(S.(vals));
vec_sumtype = S.(vals);
iter_sumtype = (x for x in vec_sumtype)

@benchmark sum($f, $tuple_manytypes)
@benchmark sum($f, $tuple_sumtype)
@benchmark sum($f, $vec_manytypes)
@benchmark sum($f, $vec_sumtype)
@benchmark sum($f, $iter_manytypes)
@benchmark sum($f, $iter_sumtype)
```
</details>

```julia
julia> @benchmark sum($f, $tuple_manytypes)
BenchmarkTools.Trial: 10000 samples with 1 evaluation.
 Range (min … max):  81.092 μs …  1.267 ms  ┊ GC (min … max): 0.00% … 90.49%
 Time  (median):     85.791 μs              ┊ GC (median):    0.00%
 Time  (mean ± σ):   87.779 μs ± 18.802 μs  ┊ GC (mean ± σ):  0.35% ±  1.67%

   ▂ ▃▇█▆▆▅▃▂▂▂▁▁                                             ▂
  █████████████████▇▇▇▅▆▅▄▅▅▅▄▄▄▄▄▄▅▄▄▄▄▄▄▄▃▄▅▅▄▃▅▄▅▅▅▄▅▅▄▅▅▅ █
  81.1 μs      Histogram: log(frequency) by time       130 μs <

 Memory estimate: 13.42 KiB, allocs estimate: 859.

julia> @benchmark sum($f, $tuple_sumtype)
BenchmarkTools.Trial: 10000 samples with 107 evaluations.
 Range (min … max):  770.514 ns …  4.624 μs  ┊ GC (min … max): 0.00% … 0.00%
 Time  (median):     823.514 ns              ┊ GC (median):    0.00%
 Time  (mean ± σ):   826.188 ns ± 42.968 ns  ┊ GC (mean ± σ):  0.00% ± 0.00%

                    █ ▁    ▂  ▂                                 
  ▂▁▂▂▂▂▂▂▂▂▂▂▂▂▂▂▇▂█▃██▃█▅█▄▂██▂█▅▃▃▂▂▃▂▃▂▂▂▂▂▂▂▂▂▂▂▂▂▂▂▂▂▂▂▂ ▃
  771 ns          Histogram: frequency by time          900 ns <

 Memory estimate: 0 bytes, allocs estimate: 0.

julia> @benchmark sum($f, $vec_manytypes)
BenchmarkTools.Trial: 10000 samples with 207 evaluations.
 Range (min … max):  367.164 ns … 566.816 ns  ┊ GC (min … max): 0.00% … 0.00%
 Time  (median):     389.280 ns               ┊ GC (median):    0.00%
 Time  (mean ± σ):   390.919 ns ±   9.984 ns  ┊ GC (mean ± σ):  0.00% ± 0.00%

                 ▁ ▇▁ ▃  ▁    █  ▂                               
  ▂▂▃▂▁▁▂▁▁▂▂▁▂▂▄█▃██▃█▃▄█▂█▇▃█▅▃█▃▃▃▂▃▂▂▃▂▃▃▂▂▂▂▂▂▂▂▂▂▂▂▂▂▂▂▂▂ ▃
  367 ns           Histogram: frequency by time          424 ns <

 Memory estimate: 0 bytes, allocs estimate: 0.

julia> @benchmark sum($f, $vec_sumtype)
BenchmarkTools.Trial: 10000 samples with 254 evaluations.
 Range (min … max):  297.016 ns … 464.575 ns  ┊ GC (min … max): 0.00% … 0.00%
 Time  (median):     308.811 ns               ┊ GC (median):    0.00%
 Time  (mean ± σ):   306.702 ns ±   7.518 ns  ┊ GC (mean ± σ):  0.00% ± 0.00%

   ▁  ▆█▅                 ▅█▆▁▁▅▄  ▂▂   ▁  ▁▄▄▁ ▂▁              ▂
  ▇██████▇▅▅▄▅▅▄▄▄▃▄▄▅▅▅▆████████▇▆██▆▅▇██▅███████▇██▇▃▄▅▆▅▅▄▃▅ █
  297 ns        Histogram: log(frequency) by time        326 ns <

 Memory estimate: 0 bytes, allocs estimate: 0.

julia> @benchmark sum($f, $iter_manytypes)
BenchmarkTools.Trial: 10000 samples with 10 evaluations.
 Range (min … max):  1.323 μs …  3.407 μs  ┊ GC (min … max): 0.00% … 0.00%
 Time  (median):     1.390 μs              ┊ GC (median):    0.00%
 Time  (mean ± σ):   1.389 μs ± 54.987 ns  ┊ GC (mean ± σ):  0.00% ± 0.00%

     ▅▄▁▂   ▃█▇▇                                              
  ▃▄▆████▅▄▇████▆▇▆▅▄▄▃▃▂▂▂▂▂▂▂▂▂▂▂▂▂▂▁▁▂▁▂▂▂▂▁▁▂▂▁▂▂▂▂▂▂▂▂▂ ▃
  1.32 μs        Histogram: frequency by time        1.67 μs <

 Memory estimate: 0 bytes, allocs estimate: 0.

julia> @benchmark sum($f, $iter_sumtype)
BenchmarkTools.Trial: 10000 samples with 258 evaluations.
 Range (min … max):  310.236 ns … 370.112 ns  ┊ GC (min … max): 0.00% … 0.00%
 Time  (median):     318.971 ns               ┊ GC (median):    0.00%
 Time  (mean ± σ):   319.347 ns ±   5.859 ns  ┊ GC (mean ± σ):  0.00% ± 0.00%

   ▁  ▄▇▆▁▃▆█▃ ▃▆▅  ▄▆▄ ▃▆▇▃▁▄▇▇▃▁▂▅▄▁ ▁▂▁   ▁   ▁▁    ▁        ▃
  ▅█▂▆████████▇███▅███████████████████▇██████████████████▇▅█▆▇▅ █
  310 ns        Histogram: log(frequency) by time        338 ns <

 Memory estimate: 0 bytes, allocs estimate: 0.
```

<sub>*These benchmarks have been run on Julia 1.11*</sub>

## Contributing

Contributions are welcome! If you encounter any issues, have suggestions for improvements, or would like to add new 
features, feel free to open an issue or submit a pull request.
