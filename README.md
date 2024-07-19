# DynamicSumTypes.jl

[![CI](https://github.com/JuliaDynamics/DynamicSumTypes.jl/workflows/CI/badge.svg)](https://github.com/JuliaDynamics/DynamicSumTypes.jl/actions?query=workflow%3ACI)
[![](https://img.shields.io/badge/docs-stable-blue.svg)](https://juliadynamics.github.io/DynamicSumTypes.jl/stable/)
[![codecov](https://codecov.io/gh/JuliaDynamics/DynamicSumTypes.jl/graph/badge.svg?token=rz9b1WTqCa)](https://codecov.io/gh/JuliaDynamics/DynamicSumTypes.jl)
[![Aqua QA](https://raw.githubusercontent.com/JuliaTesting/Aqua.jl/master/badge.svg)](https://github.com/JuliaTesting/Aqua.jl)

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

julia> abstract type AbstractAT end

julia> struct A{X}
           x::X
       end

julia> mutable struct B
           y::Float64
       end

julia> @sumtype AT(A{Int},B) <: AbstractAT
AT
```

## Construction

Then constructing instances is just a matter of enclosing the type constructed in the
predefined sum type:

```julia
julia> a = AT(A(1))
AT(A{Int64}(1))

julia> b = AT(B(1.0))
AT(B(1.0))
```

## Access and Mutation

This works like if they were normal Julia types:

```julia
julia> a.x
1

julia> b.y = 3.0
3.0
```

## Dispatch

For this, you can simply access the variant 
inside the sum type and then dispatch on it:

```julia
julia> f(x::AT) = f(variant(x))

julia> f(x::A) = 1

julia> f(x::B) = 2

julia> f(a)
1

julia> f(b)
2
```

## Micro-benchmarks

### Using `Union` types
<details>
 <summary>Benchmark code</summary>
       
```julia
using Random, BenchmarkTools

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

function foo!(rng, n)
    xs = Union{A,B,C,D}[rand(rng, (A(), B(), C(), D())) for _ in 1:n]
    while n != 0
        r = rand(rng, 1:length(xs))
        @inbounds xs[r] = foo_each(xs[r])
    	n -= 1
    end
end

foo_each(x::A) = B(x.common_field+1, x.a, x.b, x.b)
foo_each(x::B) = C(x.common_field-1, x.d, isodd(x.c), x.d, x.e)
foo_each(x::C) = D(x.common_field+1, isodd(x.common_field) ? "hi" : "bye")
foo_each(x::D) = A(x.common_field-1, x.l=="hi", x.common_field)

rng = MersenneTwister(42)
xs = Union{A,B,C,D}[rand(rng, (A(), B(), C(), D())) for _ in 1:10000];
println("Array size: $(Base.summarysize(xs)) bytes\n")
@benchmark foo!($rng, 10^5)
```
</details>

```julia
Array size: 399962 bytes

BenchmarkTools.Trial: 490 samples with 1 evaluation.
 Range (min … max):   8.325 ms … 20.104 ms  ┊ GC (min … max):  0.00% … 14.68%
 Time  (median):      9.834 ms              ┊ GC (median):    14.50%
 Time  (mean ± σ):   10.209 ms ±  1.309 ms  ┊ GC (mean ± σ):  11.74% ± 10.98%

          ▄▄  █▅▂▃█   ▂                                        
  ▂▂▂▁▃▃▄▆███▇███████▇█▅▄▅▃▁▃▃▄▃▃▂▂▂▁▃▃▃▃▁▃▃▃▃▃▂▃▃▃▃▂▃▃▃▄▃▂▂▃ ▃
  8.32 ms         Histogram: frequency by time          14 ms <

 Memory estimate: 22.88 MiB, allocs estimate: 300002.
```

### Using `@sumtype`
<details>
 <summary>Benchmark code</summary>

```julia
using DynamicSumTypes, Random, BenchmarkTools

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

@sumtype AT(A,B,C,D)

function foo!(rng, n)
    xs = [rand(rng, (AT(A()), AT(B()), AT(C()), AT(D()))) for _ in 1:n]
    while n != 0
        r = rand(rng, 1:length(xs))
        @inbounds xs[r] = foo_each(variant(xs[r]))
    	n -= 1
    end
end

foo_each(x::A) = AT(B(x.common_field+1, x.a, x.b, x.b))
foo_each(x::B) = AT(C(x.common_field-1, x.d, isodd(x.c), x.d, x.e))
foo_each(x::C) = AT(D(x.common_field+1, isodd(x.common_field) ? "hi" : "bye"))
foo_each(x::D) = AT(A(x.common_field-1, x.l=="hi", x.common_field))

rng = MersenneTwister(42)
xs = [rand(rng, (AT(A()), AT(B()), AT(C()), AT(D()))) for _ in 1:10000]
println("Array size: $(Base.summarysize(xs)) bytes\n")
@benchmark foo!($rng, 10^5)
```
</details>

```julia
Array size: 120754 bytes

BenchmarkTools.Trial: 1115 samples with 1 evaluation.
 Range (min … max):  3.440 ms … 12.625 ms  ┊ GC (min … max):  0.00% … 53.09%
 Time  (median):     3.729 ms              ┊ GC (median):     0.00%
 Time  (mean ± σ):   4.462 ms ±  1.640 ms  ┊ GC (mean ± σ):  13.81% ± 17.13%

  ▂▆█▅▅▄▁                                                  ▁  
  ███████▆▁▁▁▁▁▁▁▁▁▁▄▅▄▁▁▁▄▆▆▇██▇▆▅▅▅▇▆▄▆▅▇▄▁▆▄▅▆▅▅▄▄▇▇█████ █
  3.44 ms      Histogram: log(frequency) by time      9.1 ms <

 Memory estimate: 8.00 MiB, allocs estimate: 200003.
```

In this micro-benchmark, using `@sumtype` is more than 2 times faster and 3 times
memory efficient than `Union` types!

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
