
module DynamicSumTypes

export @sumtype, variant, variantof, allvariants, is_sumtype

unwrap(sumt) = getfield(sumt, :variants)

"""
    @sumtype SumTypeName(Types) [<: AbstractType]

The macro creates a sumtypes composed by the given types.
It optionally accept also an abstract supertype.

## Example
```julia
julia> using DynamicSumTypes

julia> struct A x::Int end;

julia> struct B end;

julia> @sumtype AB(A, B)
```
"""
macro sumtype(typedef)

    if typedef.head === :call
        abstract_type = :Any
        type_with_variants = typedef
    elseif typedef.head === :(<:)
        abstract_type = typedef.args[2]
        type_with_variants = typedef.args[1]
    else
        error("Invalid syntax")
    end

    type = type_with_variants.args[1]
    variants = type_with_variants.args[2:end]

    esc(quote
            struct $type <: $(abstract_type)
                variants::Union{$(variants...)}
                $type(v) = $(branchs(variants, :(return new(v)), "The enclosed type is not a variant of the sum type")...)
            end
            @inline function $DynamicSumTypes.variant(sumt::$type)
                v = $DynamicSumTypes.unwrap(sumt)
                $(branchs(variants, :(return v))...)
            end
            @inline function $Base.getproperty(sumt::$type, s::Symbol)
                v = $DynamicSumTypes.unwrap(sumt)
                $(branchs(variants, :(return $Base.getproperty(v, s)))...)
            end
            @inline function $Base.setproperty!(sumt::$type, s::Symbol, value)
                v = $DynamicSumTypes.unwrap(sumt)
                $(branchs(variants, :(return $Base.setproperty!(v, s, value)))...)
            end
            function $Base.propertynames(sumt::$type)
                v = $DynamicSumTypes.unwrap(sumt)
                $(branchs(variants, :(return $Base.propertynames(v)))...)
            end
            function $Base.hasproperty(sumt::$type, s::Symbol)
                v = $DynamicSumTypes.unwrap(sumt)
                $(branchs(variants, :(return $Base.hasproperty(v, s)))...)
            end
            function $Base.copy(sumt::$type)
                v = $DynamicSumTypes.unwrap(sumt)
                $(branchs(variants, :(return $type(Base.copy(v))))...)
            end
            $DynamicSumTypes.variantof(sumt::$type) = typeof($DynamicSumTypes.variant(sumt))
            $DynamicSumTypes.allvariants(sumt::Type{$type}) = tuple($(variants...))
            $DynamicSumTypes.is_sumtype(sumt::Type{$type}) = true
            $type
    end)
end 

function branchs(variants, outputs, err_str = "THIS_SHOULD_BE_UNREACHABLE")
    !(outputs isa Vector) && (outputs = repeat([outputs], length(variants)))
    branchs = [Expr(:if, :(v isa $(variants[1])), outputs[1])]
    for i in 2:length(variants)
        push!(branchs, Expr(:elseif, :(v isa $(variants[i])), outputs[i]))
    end
    push!(branchs, :(error($err_str)))
    return branchs
end

"""
    variant(inst)

Returns the variant enclosed in the sum type.

## Example
```julia
julia> using DynamicSumTypes

julia> struct A x::Int end;

julia> struct B end;

julia> @sumtype AB(A, B)

julia> a = AB(A(0))
AB'.A(0)

julia> variant(a)
A(0)
```
"""
function variant end

"""
    allvariants(SumType)

Returns all the enclosed variants types in the sum type
in a tuple.
  
## Example
```julia
julia> using DynamicSumTypes

julia> struct A x::Int end;

julia> struct B end;

julia> @sumtype AB(A, B)

julia> allvariants(AB)
(A, B)
```
"""
function allvariants end

"""
    variantof(inst)

Returns the type of the variant enclosed in
the sum type.
"""
function variantof end

"""
    is_sumtype(T)

Returns true if the type is a sum type otherwise
returns false.
"""
is_sumtype(T::Type) = false

include("deprecations.jl")

end
