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

The `@sumtype` macro takes inspiration from [SumTypes.jl](https://github.com/MasonProtter/SumTypes.jl),
but it offers a much more simple interface. Working with it is almost like working with `Union` types.

## Construction

```julia
julia> using DynamicSumTypes

julia> abstract type AbstractAT end

julia> struct A
           x::Int
       end

julia> struct B
           y::Float64
       end

julia> @sumtype AT(A,B) <: AbstractAT

julia> a = AT(A(1))

julia> b = AT(B(1.0))
```

## Dispatch

For this, you can simply destructure the sum type with
`variant` and then dispatch on it. For example:

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
module UnionTypeTest

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
    xs = [rand(rng, (A(), B(), C(), D())) for _ in 1:n]
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
display(@benchmark foo!($rng, 10^5);)

end;
```
</details>

```julia
Array size: 399962 bytes

BenchmarkTools.Trial: 319 samples with 1 evaluation.
 Range (min … max):  13.048 ms … 26.947 ms  ┊ GC (min … max):  0.00% … 33.93%
 Time  (median):     15.571 ms              ┊ GC (median):    16.47%
 Time  (mean ± σ):   15.702 ms ±  1.921 ms  ┊ GC (mean ± σ):  13.26% ± 11.37%

      ▂██▇▂                ▁                                   
  ▃▁▁▅█████▇▄▆▄▄▄▄▅▄█▆▇█████▄▆▆▄▄▅█▄▃▄▃▃▅▃▃▁▃▃▁▃▃▃▃▃▃▃▃▄▃▁▃▁▃ ▄
  13 ms           Histogram: frequency by time          21 ms <

 Memory estimate: 29.34 MiB, allocs estimate: 474209.
```

### Using `@sumtype`
<details>
 <summary>Benchmark code</summary>

```julia
module SumTypeTest

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
display(@benchmark foo!($rng, 10^5);)

end;
```
</details>

```julia
Array size: 120754 bytes

BenchmarkTools.Trial: 1010 samples with 1 evaluation.
 Range (min … max):  3.730 ms … 11.622 ms  ┊ GC (min … max):  0.00% … 34.82%
 Time  (median):     4.174 ms              ┊ GC (median):     0.00%
 Time  (mean ± σ):   4.925 ms ±  1.680 ms  ┊ GC (mean ± σ):  13.83% ± 16.99%

  ▂▂▅█▆▆▅▁                                                ▁   
  ████████▆▄▄▁▄▁▅▁▁▁▁▁▁▁▄▇▆▆▇▆▇▇▇▆▆▆▆▅▇▅▆▆▅▆▅▄▁▆▅▅▁▅▇▇▇▇████ █
  3.73 ms      Histogram: log(frequency) by time     9.66 ms <

 Memory estimate: 8.77 MiB, allocs estimate: 224600.
```

In this micro-benchmark, using `@sum_structs :on_fields` is 1.5 times faster than `Union` types, 
even if it requires 4 times the memory to store the array. Whereas, using `@sum_structs :on_types` is a bit 
less time efficient than `:on_fields`, but the memory required to store elements in respect to `Union` types 
is less than 1/3!

<sub>*These benchmarks have been run on Julia 1.11*</sub>

## Contributing

Contributions are welcome! If you encounter any issues, have suggestions for improvements, or would like to add new 
features, feel free to open an issue or submit a pull request.
