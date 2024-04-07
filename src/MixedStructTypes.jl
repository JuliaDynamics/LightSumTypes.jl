
module MixedStructTypes

using ExprTools
using MacroTools
using SumTypes

export @sum_structs
export @compact_structs
export kindof
export allkinds
export kindconstructor

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
include("precompile.jl")

end
