
module LightSumTypes

using MacroTools: namify

export @sumtype, sumtype_expr, variant, variantof, allvariants, is_sumtype

unwrap(sumt) = getfield(sumt, :variants)

"""
    @sumtype SumTypeName(Types) [<: AbstractType]

Creates a sumtype composed by the given types.
It optionally accept also an abstract supertype.

## Example
```julia
julia> using LightSumTypes

julia> struct A x::Int end;

julia> struct B end;

julia> @sumtype AB(A, B)
```
"""
macro sumtype(typedef)
    return esc(sumtype_expr(typedef))
end

"""
    sumtype_expr(:(SumTypeName(Types) [<: AbstractType]))

Returns the expression evaluated by the @sumtype macro.
"""
function sumtype_expr(typedef)
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
    typename = namify(type)
    typeparams = type isa Symbol ? [] : type.args[2:end]
    variants = type_with_variants.args[2:end]
    !allunique(variants) && error("Duplicated variants in sumtype")
    variants_with_P = [v for v in variants if v isa Expr && !isempty(intersect(typeparams, v.args[2:end]))]
    variants_bounded = [v in variants_with_P ? namify(v) : v for v in variants]

    check_if_typeof(v) = v isa Expr && v.head == :call && v.args[1] == :typeof
    variants_names = namify.([check_if_typeof(v) ? v.args[2] : v for v in variants])
    for vname in unique(variants_names)
        inds = findall(==(vname), variants_names)
        length(inds) == 1 && continue
        for (k, i) in enumerate(inds)
            variant_args = check_if_typeof(variants[i]) ? variants[i].args[2] : variants[i].args
            variants_names[i] = Symbol([i == length(variant_args) ? a : Symbol(a, :_) for (i, a) in enumerate(variant_args)]...)
        end
    end

    constructors = [:(@inline $(namify(type))(v::Union{$(variants...)}) where {$(typeparams...)} =
        $(branchs(variants, variants_with_P, :(return new{$(typeparams...)}(v)))))]

    if type isa Expr
        push!(
            constructors,
            :(@inline $type(v::Union{$(variants...)}) where {$(typeparams...)} =
                $(branchs(variants, variants_with_P, :(return new{$(typeparams...)}(v)))))
        )
    end

    quote
        struct $type <: $(abstract_type)
            variants::Union{$(variants...)}
            $(constructors...)
        end
        @inline function $Base.getproperty(sumt::$typename, s::Symbol)
            v = $LightSumTypes.unwrap(sumt)
            $(branchs(variants, variants_with_P, :(return $Base.getproperty(v, s))))
        end
        if any(ismutabletype(v) for v in [$((variants_bounded)...)])
            @inline function $Base.setproperty!(sumt::$typename, s::Symbol, value)
                v = $LightSumTypes.unwrap(sumt)
                $(branchs(variants, variants_with_P, :(return $Base.setproperty!(v, s, value))))
            end
        end
        function $Base.propertynames(sumt::$typename)
            v = $LightSumTypes.unwrap(sumt)
            $(branchs(variants, variants_with_P, :(return $Base.propertynames(v))))
        end
        function $Base.hasproperty(sumt::$typename, s::Symbol)
            v = $LightSumTypes.unwrap(sumt)
            $(branchs(variants, variants_with_P, :(return $Base.hasproperty(v, s))))
        end
        function $Base.copy(sumt::$typename)
            v = $LightSumTypes.unwrap(sumt)
            $(branchs(variants, variants_with_P, :(return $type(Base.copy(v)))))
        end
        @inline $LightSumTypes.variant(sumt::$typename) = $LightSumTypes.unwrap(sumt)
        @inline function $LightSumTypes.variant_idx(sumt::$typename)
            v = $LightSumTypes.unwrap(sumt)
            $(branchs(variants, variants_with_P, [:(return $i) for i in 1:length(variants)]))
        end
        $LightSumTypes.variantof(sumt::$typename) = typeof($LightSumTypes.variant(sumt))
        $LightSumTypes.allvariants(sumt::Type{$typename}) = $(Expr(:tuple, (:($nv = $(v in variants_with_P ? namify(v) : v))
                                                                            for (nv, v) in zip(variants_names, variants))...))
        $LightSumTypes.is_sumtype(sumt::Type{$typename}) = true
        nothing
    end
end

function branchs(variants, variants_with_P, outputs)
    !(outputs isa Vector) && (outputs = repeat([outputs], length(variants)))
    expr = :(error("THIS_SHOULD_BE_UNREACHABLE"))
    for (variant, output) in zip(reverse(variants), reverse(outputs))
        condition = :(v isa $(variant in variants_with_P ? namify(variant) : variant))
        expr = Expr(:elseif, condition, output, expr)
    end
    expr = Expr(:if, expr.args...) # correct first :elseif to :if
    return expr
end

"""
    variant(inst)

Returns the variant enclosed in the sum type.

## Example
```julia
julia> using LightSumTypes

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
in a namedtuple.
  
## Example
```julia
julia> using LightSumTypes

julia> struct A x::Int end;

julia> struct B end;

julia> @sumtype AB(A, B)

julia> allvariants(AB)
(A = A, B = B)
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

function variant_idx end

include("precompile.jl")

end
