# DynamicSumTypes.jl

[![CI](https://github.com/JuliaDynamics/DynamicSumTypes.jl/workflows/CI/badge.svg)](https://github.com/JuliaDynamics/DynamicSumTypes.jl/actions?query=workflow%3ACI)
[![](https://img.shields.io/badge/docs-stable-blue.svg)](https://juliadynamics.github.io/DynamicSumTypes.jl/stable/)
[![codecov](https://codecov.io/gh/JuliaDynamics/DynamicSumTypes.jl/graph/badge.svg?token=rz9b1WTqCa)](https://codecov.io/gh/JuliaDynamics/DynamicSumTypes.jl)
[![Aqua QA](https://raw.githubusercontent.com/JuliaTesting/Aqua.jl/master/badge.svg)](https://github.com/JuliaTesting/Aqua.jl)

This package allows to combine multiple heterogeneous types in a single one. This helps to write 
type-stable code by avoiding Union-splitting, which has big performance drawbacks when many types are 
unionized. 

Another aim of this library is to provide a syntax as similar as possible to standard Julia 
structs to facilitate its integration within other libraries. 

The `@sum_structs` macro implements two strategies to create a compact representation of the types: 
the default one merges all fields of each struct in a unique type which is faster in many cases, 
while the second uses [SumTypes.jl](https://github.com/MasonProtter/SumTypes.jl) under the hood, 
which is more memory efficient and allows to mix mutable and immutable structs.

Even if there is only a unique type defined by this macro, you can access a symbol containing the conceptual 
type of an instance with the function `kindof` and use the `@pattern` macro to define functions which 
can operate differently on each kind.

## Construct sum types

```julia
julia> using DynamicSumTypes

julia> abstract type AbstractA{X} end

julia> # default version is :on_fields
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

julia> b = A'.B(1, 1.5)
A'.B{Int64}(1, 1.5)

julia> export_variants(A)

julia> b = B(1, 1.5)
A'.B{Int64}(1, 1.5)

julia> b.a
1

julia> b.a = 3
3

julia> kindof(b)
:B

julia> abstract type AbstractF{X} end

julia> @sum_structs :on_types F{X} <: AbstractF{X} begin
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

julia> g = F'.G(1, 1.5)
F'.G{Int64}(1, 1.5)

julia> export_variants(F)

julia> g = G(1, 1.5)
F'.G{Int64}(1, 1.5)

julia> g.a
1

julia> g.a = 3
3

julia> kindof(g)
:G
```

## Define functions on sum types

There are currently two ways to define function on the types created 
with this package:

- Use manual branching;
- Use the `@pattern` macro.

For example, let's say we want to create a sum function where different values are added
depending on the kind of each element in a vector:

```julia
julia> function sum1(v) # with manual branching
           s = 0
           for x in v
               if kindof(x) === :B
                   s += value_B(1)
               elseif kindof(x) === :C
                   s += value_C(1)
               elseif kindof(x) === :D
                   s += value_D(1)
               elseif kindof(x) === :E
                   s += value_E(1)
               else
                   error()
               end
           end
           return s
       end
sum1 (generic function with 1 method)

julia> value_B(k::Int) = k + 1;

julia> value_C(k::Int) = k + 2;

julia> value_D(k::Int) = k + 3;

julia> value_E(k::Int) = k + 4;

julia> function sum2(v) # with @pattern macro
           s = 0
           for x in v
               s += value(1, x)
           end
           return s
       end
sum2 (generic function with 1 method)

julia> @pattern value(k::Int, ::B) = k + 1;

julia> @pattern value(k::Int, ::C) = k + 2;

julia> @pattern value(k::Int, ::D) = k + 3;

julia> @pattern value(k::Int, ::E) = k + 4;

julia> v = A{Int}[rand((B,C,D,E))() for _ in 1:10^6];

julia> sum1(v)
2499517

julia> sum2(v)
2499517
```

As you can see the version using the `@pattern` macro is much less verbose and more intuitive. In some more
advanced cases the verbosity of the first approach could be even stronger.

Since the macro essentially reconstruct the branching version described above, to ensure that everything will 
work correctly when using it, do not define functions operating on the main type of some variants without 
using the `@pattern` macro. 

Also, if you use it in a module or in a script run from the command line, you will need to use `@finalize_patterns` 
at some point to make sure that the functions using the macro are defined, usually you will only need one 
invocation after all the rest of the code.

Consult the [API page](https://juliadynamics.github.io/DynamicSumTypes.jl/stable/) for more information on 
the available functionalities.

## Micro-benchmarks

### Using `Union` types
<details>
 <summary>Benchmark code</summary>
       
```julia
module UnionTypeTest

@kwdef struct A
    common_field::Int = 1
    a::Bool = true
    b::Int = 10
end
@kwdef struct B
    common_field::Int = 1
    c::Int = 1
    d::Float64 = 1.0
    e::Complex{Float64} = 1.0 + 1.0im
end
@kwdef struct C
    common_field::Int = 1
    f::Float64 = 2.0
    g::Bool = false
    h::Float64 = 3.0
    i::Complex{Float64} = 1.0 + 2.0im
end
@kwdef struct D
    common_field::Int = 1
    l::String = "hi"
end

function foo!(xs)
    for i in eachindex(xs)
        @inbounds xs[i] = foo_each(xs[i])
    end
end

foo_each(x::A) = B(x.common_field+1, x.a, x.b, x.b)
foo_each(x::B) = C(x.common_field-1, x.d, isodd(x.c), x.d, x.e)
foo_each(x::C) = D(x.common_field+1, isodd(x.common_field) ? "hi" : "bye")
foo_each(x::D) = A(x.common_field-1, x.l=="hi", x.common_field)


using Random

rng = MersenneTwister(42)
xs = [rand(rng, (A(), B(), C(), D())) for _ in 1:10000];

using BenchmarkTools

println("Array size: $(Base.summarysize(xs)) bytes\n")

display(@benchmark foo!($xs);)

end;
```
</details>

```julia
Array size: 399962 bytes

BenchmarkTools.Trial: 10000 samples with 1 evaluation.
 Range (min … max):  237.918 μs …   3.585 ms  ┊ GC (min … max):  0.00% … 88.41%
 Time  (median):     250.622 μs               ┊ GC (median):     0.00%
 Time  (mean ± σ):   282.875 μs ± 265.652 μs  ┊ GC (mean ± σ):  10.82% ± 10.27%

  █                                                             ▁
  █▇▄▁▆▇▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▃▇ █
  238 μs        Histogram: log(frequency) by time       2.49 ms <

 Memory estimate: 428.33 KiB, allocs estimate: 10000.
```

### Using `@sum_structs :on_fields`
<details>
 <summary>Benchmark code</summary>

```julia
module SumStructsOnFieldsTest

using DynamicSumTypes

@sum_structs :on_fields AT begin
    @kwdef struct A
        common_field::Int = 1
        a::Bool = true
        b::Int = 10
    end
    @kwdef struct B
        common_field::Int = 1
        c::Int = 1
        d::Float64 = 1.0
        e::Complex{Float64} = 1.0 + 1.0im
    end
    @kwdef struct C
        common_field::Int = 1
        f::Float64 = 2.0
        g::Bool = false
        h::Float64 = 3.0
        i::Complex{Float64} = 1.0 + 2.0im
    end
    @kwdef struct D
        common_field::Int = 1
        l::String = "hi"
    end
end

export_variants(AT)

function foo!(xs)
    for i in eachindex(xs)
        @inbounds xs[i] = foo_each(xs[i])
    end
end

@pattern foo_each(x::A) = B(x.common_field+1, x.a, x.b, x.b)
@pattern foo_each(x::B) = C(x.common_field-1, x.d, isodd(x.c), x.d, x.e)
@pattern foo_each(x::C) = D(x.common_field+1, isodd(x.common_field) ? "hi" : "bye")
@pattern foo_each(x::D) = A(x.common_field-1, x.l=="hi", x.common_field)
@finalize_patterns

using Random

rng = MersenneTwister(42)
xs = [rand(rng, (A(), B(), C(), D())) for _ in 1:10000];

using BenchmarkTools

println("Array size: $(Base.summarysize(xs)) bytes\n")

display(@benchmark foo!($xs);)

end;
```
</details>

```julia
Array size: 1600050 bytes

BenchmarkTools.Trial: 10000 samples with 1 evaluation.
 Range (min … max):  114.265 μs … 164.790 μs  ┊ GC (min … max): 0.00% … 0.00%
 Time  (median):     121.559 μs               ┊ GC (median):    0.00%
 Time  (mean ± σ):   119.503 μs ±   4.064 μs  ┊ GC (mean ± σ):  0.00% ± 0.00%

    ▃▆██▇▄        ▁▁▂▂▃▂        ▂▄▆▇▇▇▆▄▁        ▁▂▂▂▂▁▁        ▃
  ▄████████▅▆▆▄▃▆▆███████▆▆▆▂▃▅███████████▅▆▆▆██████████▇▅▆▄▃▆▅ █
  114 μs        Histogram: log(frequency) by time        129 μs <

 Memory estimate: 0 bytes, allocs estimate: 0.
```

### Using `@sum_structs :on_types`

<details>
 <summary>Benchmark code</summary>

```julia
module SumStructsOnTypesTest

using DynamicSumTypes

@sum_structs :on_types AT begin
    @kwdef struct A
        common_field::Int = 1
        a::Bool = true
        b::Int = 10
    end
    @kwdef struct B
        common_field::Int = 1
        c::Int = 1
        d::Float64 = 1.0
        e::Complex{Float64} = 1.0 + 1.0im
    end
    @kwdef struct C
        common_field::Int = 1
        f::Float64 = 2.0
        g::Bool = false
        h::Float64 = 3.0
        i::Complex{Float64} = 1.0 + 2.0im
    end
    @kwdef struct D
        common_field::Int = 1
        l::String = "hi"
    end
end

export_variants(AT)

function foo!(xs)
    for i in eachindex(xs)
        @inbounds xs[i] = foo_each(xs[i])
    end
end

@pattern foo_each(x::A) = B(x.common_field+1, x.a, x.b, x.b)
@pattern foo_each(x::B) = C(x.common_field-1, x.d, isodd(x.c), x.d, x.e)
@pattern foo_each(x::C) = D(x.common_field+1, isodd(x.common_field) ? "hi" : "bye")
@pattern foo_each(x::D) = A(x.common_field-1, x.l=="hi", x.common_field)
@finalize_patterns

using Random

rng = MersenneTwister(42)
xs = [rand(rng, (A(), B(), C(), D())) for _ in 1:10000];

using BenchmarkTools

println("Array size: $(Base.summarysize(xs)) bytes\n")

display(@benchmark foo!($xs);)

end;
```
</details>

```julia
Array size: 120754 bytes

BenchmarkTools.Trial: 10000 samples with 1 evaluation.
 Range (min … max):  138.210 μs …   3.678 ms  ┊ GC (min … max):  0.00% … 91.71%
 Time  (median):     148.831 μs               ┊ GC (median):     0.00%
 Time  (mean ± σ):   179.962 μs ± 283.349 μs  ┊ GC (mean ± σ):  16.78% ±  9.99%

  █                                                              
  █▂▂▂▂▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▂ ▂
  138 μs           Histogram: frequency by time         2.73 ms <

 Memory estimate: 428.33 KiB, allocs estimate: 10000.
```

In this micro-benchmark, using `@sum_structs :on_fields` is more than 2 times faster than `Union` types, 
even if it requires 4 times the memory to store the array. Whereas, using `@sum_structs :on_types` is a bit 
less time efficient than `:on_fields`, but the memory required to store elements in respect to `Union` types 
is less than 1/3!

## Macro-benchmarks

Micro-benchmarks are very difficult to design to be robust, so usually it is better to have some evidences on more realistic
programs. You can find two of them at [https://github.com/JuliaDynamics/Agents.jl/blob/main/test/performance/branching_faster_than_dispatch.jl](https://github.com/JuliaDynamics/Agents.jl/blob/main/test/performance/branching_faster_than_dispatch.jl#L173)
and https://juliadynamics.github.io/Agents.jl/stable/performance_tips/#multi_vs_union (consider that `@multiagent` is actually `@sum_structs` under the hood). Speed-up in those cases are sometimes over 10x in respect to `Union` types.

## Contributing

Contributions are welcome! If you encounter any issues, have suggestions for improvements, or would like to add new 
features, feel free to open an issue or submit a pull request.
