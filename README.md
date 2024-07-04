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

julia> abstract type AbstractAT{X} end

julia> # default version is :on_fields
       @sum_structs AT{X} <: AbstractAT{X} begin
           @kwdef mutable struct A{X}
               a::X = 1
               b::Float64 = 1.0
           end
           @kwdef mutable struct B{X}
               a::X = 2
               c::Bool = true
           end
           @kwdef mutable struct C{X}
               a::X = 3
               const d::Symbol = :s
           end
           @kwdef mutable struct D{X}
               a::X = 4
           end
       end

julia> a = AT'.A(1, 1.5)
AT'.A{Int64}(1, 1.5)

julia> export_variants(AT)

julia> a = A(1, 1.5)
AT'.A{Int64}(1, 1.5)

julia> a.b
1.5

julia> a.b = 3.0
3.0

julia> kindof(a)
:A
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
               if kindof(x) === :A
                   s += value_A(1)
               elseif kindof(x) === :B
                   s += value_B(1)
               elseif kindof(x) === :C
                   s += value_C(1)
               elseif kindof(x) === :D
                   s += value_D(1)
               else
                   error()
               end
           end
           return s
       end
sum1 (generic function with 1 method)

julia> value_A(k::Int) = k + 1;

julia> value_B(k::Int) = k + 2;

julia> value_C(k::Int) = k + 3;

julia> value_D(k::Int) = k + 4;

julia> function sum2(v) # with @pattern macro
           s = 0
           for x in v
               s += value(1, x)
           end
           return s
       end
sum2 (generic function with 1 method)

julia> @pattern value(k::Int, ::A) = k + 1;

julia> @pattern value(k::Int, ::B) = k + 2;

julia> @pattern value(k::Int, ::C) = k + 3;

julia> @pattern value(k::Int, ::D) = k + 4;

julia> v = AT{Int}[rand((A,B,C,D))() for _ in 1:10^6];

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

function foo!(rng, xs)
    s = length(xs)
    while s != 0
        r = rand(rng, 1:length(xs))
        @inbounds xs[r] = foo_each(xs[r])
    	s -= 1
    end
end

foo_each(x::A) = B(x.common_field+1, x.a, x.b, x.b)
foo_each(x::B) = C(x.common_field-1, x.d, isodd(x.c), x.d, x.e)
foo_each(x::C) = D(x.common_field+1, isodd(x.common_field) ? "hi" : "bye")
foo_each(x::D) = A(x.common_field-1, x.l=="hi", x.common_field)

using Random

rng = MersenneTwister(42)
xs = Union{A,B,C,D}[rand(rng, (A(), B(), C(), D())) for _ in 1:10000];

using BenchmarkTools

println("Array size: $(Base.summarysize(xs)) bytes\n")

display(@benchmark foo!($rng, $xs);)

end;
```
</details>

```julia
Array size: 399962 bytes

BenchmarkTools.Trial: 10000 samples with 1 evaluation.
 Range (min … max):  316.656 μs …   4.165 ms  ┊ GC (min … max): 0.00% … 85.80%
 Time  (median):     413.999 μs               ┊ GC (median):    0.00%
 Time  (mean ± σ):   432.672 μs ± 297.266 μs  ┊ GC (mean ± σ):  7.13% ±  9.08%

    █                                                            
  ▇██▃▂▂▂▂▂▂▂▂▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▂▂ ▂
  317 μs           Histogram: frequency by time         3.05 ms <

 Memory estimate: 425.50 KiB, allocs estimate: 10000.
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

function foo!(rng, xs)
    s = length(xs)
    while s != 0
        r = rand(rng, 1:length(xs))
        @inbounds xs[r] = foo_each(xs[r])
    	s -= 1
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

display(@benchmark foo!($rng, $xs);)

end;
```
</details>

```julia
Array size: 1600050 bytes

BenchmarkTools.Trial: 10000 samples with 1 evaluation.
 Range (min … max):  281.450 μs … 712.240 μs  ┊ GC (min … max): 0.00% … 0.00%
 Time  (median):     288.493 μs               ┊ GC (median):    0.00%
 Time  (mean ± σ):   289.516 μs ±   7.968 μs  ┊ GC (mean ± σ):  0.00% ± 0.00%

               ▁▆█▇                                              
  ▁▁▁▁▁▂▂▃▃▄▄▅▆█████▄▂▂▂▂▂▂▂▁▁▁▁▁▁▁▂▂▂▂▂▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁ ▂
  281 μs           Histogram: frequency by time          309 μs <

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

function foo!(rng, xs)
    s = length(xs)
    while s != 0
        r = rand(rng, 1:length(xs))
        @inbounds xs[r] = foo_each(xs[r])
    	s -= 1
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

display(@benchmark foo!($rng, $xs);)

end;
```
</details>

```julia
Array size: 120754 bytes

BenchmarkTools.Trial: 10000 samples with 1 evaluation.
 Range (min … max):  277.863 μs …   4.212 ms  ┊ GC (min … max):  0.00% … 86.77%
 Time  (median):     289.539 μs               ┊ GC (median):     0.00%
 Time  (mean ± σ):   328.873 μs ± 317.800 μs  ┊ GC (mean ± σ):  10.20% ±  9.50%

  █▂▂                                                           ▁
  ███▅▄▃▄▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▇ █
  278 μs        Histogram: log(frequency) by time       3.16 ms <

 Memory estimate: 425.50 KiB, allocs estimate: 10000.
```

In this micro-benchmark, using `@sum_structs :on_fields` is 1.5 times faster than `Union` types, 
even if it requires 4 times the memory to store the array. Whereas, using `@sum_structs :on_types` is a bit 
less time efficient than `:on_fields`, but the memory required to store elements in respect to `Union` types 
is less than 1/3!

<sub>*Benchmaks have been run on Julia 1.11*</sub>

## Macro-benchmarks

Micro-benchmarks are very difficult to design to be robust, so usually it is better to have some evidence on more realistic
programs. You can find two of them at [https://github.com/JuliaDynamics/Agents.jl/blob/main/test/performance/branching_faster_than_dispatch.jl](https://github.com/JuliaDynamics/Agents.jl/blob/main/test/performance/branching_faster_than_dispatch.jl#L173)
and https://juliadynamics.github.io/Agents.jl/stable/performance_tips/#multi_vs_union (consider that `@multiagent` is actually `@sum_structs` under the hood). Speed-ups in those cases are sometimes over 10x in respect to `Union` types.

## Contributing

Contributions are welcome! If you encounter any issues, have suggestions for improvements, or would like to add new 
features, feel free to open an issue or submit a pull request.
