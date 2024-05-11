
module MixedStructTypes

using ExprTools
using MacroTools
using SumTypes
using Suppressor

export @sum_structs
export @compact_structs
export @branch
export kindof
export allkinds
export kindconstructor

const __variants_types_cache__ = Dict{Symbol, Symbol}()
const __variants_types_with_params_cache__ = Dict{Symbol, Vector{Any}}()
const __dispatch_cache__ = Dict{Tuple{Symbol, Vector{Tuple{Int, Symbol}}}, Expr}()

"""
    kindof(instance)

Return a symbol representing the conceptual type of an instance:

```julia
julia> @compact_structs AB begin
           struct A x::Int end
           struct B y::Int end
       end

julia> a = A(1);

julia> kindof(a)
:A
```
"""
function kindof end

"""
    allkinds(type)

Return a `Tuple` containing all kinds associated with the overarching 
type defined with `@compact_structs` or `@sum_structs`:

```julia
julia> @compact_structs AB begin
           struct A x::Int end
           struct B y::Int end
       end

julia> allkinds(AB)
(:A, :B)
```
"""
function allkinds end

"""
    kindconstructor(instance)

Return the constructor of an instance:

```julia
julia> @compact_structs AB begin
           struct A x::Int end
           struct B y::Int end
       end

julia> a = A(1);

julia> kindconstructor(a)
A
```
"""
function kindconstructor end

include("SumStructs.jl")
include("CompactStructs.jl")
include("Branch.jl")
include("precompile.jl")

end
