
module DynamicSumTypes

using ExprTools
using MacroTools
using SumTypes

export @sum_structs
export @pattern
export @finalize_patterns
export export_variants
export kindof
export allkinds
export variant_constructor

const __modules_cache__ = Set{Module}()
const __variants_types_cache__ = Dict{Module, Dict{Any, Any}}()
const __variants_types_with_params_cache__ = Dict{Module, Dict{Any, Vector{Any}}}()

"""
    kindof(instance)

Return a symbol representing the conceptual type of an instance:

```julia
julia> @sum_structs AB begin
           struct A x::Int end
           struct B y::Int end
       end

julia> a = AB'.A(1);

julia> kindof(a)
:A
```
"""
function kindof end

"""
    allkinds(type)

Return a `Tuple` containing all kinds associated with the overarching 
type defined with `@sum_structs`

```julia
julia> @sum_structs AB begin
           struct A x::Int end
           struct B y::Int end
       end

julia> allkinds(AB)
(:A, :B)
```
"""
function allkinds end

"""
    variant_constructor(instance)

Return the constructor of an instance in a more
efficient way than doing `typeof(inst)'[kindof(inst)]`:

```julia
julia> @sum_structs AB begin
           struct A x::Int end
           struct B y::Int end
       end

julia> a = AB'.A(1)
AB'.A(1)

julia> typeof(a)'[kindof(a)]
AB'.A

julia> variant_constructor(a)
AB'.A
```
"""
function variant_constructor end

"""
    export_variants(T)

Export all variants types into the module the
function it is called into.

## Example

```julia
julia> @sum_structs AB begin
           struct A x::Int end
           struct B y::Int end
       end

julia> AB'.A(1)
AB'.A(1)

julia> export_variants(AB)

julia> A(1) # now this also works
AB'.A(1)
```
"""
function export_variants end

include("SumStructsOnFields.jl")
include("SumStructsOnTypes.jl")
include("Pattern.jl")
include("precompile.jl")

end
