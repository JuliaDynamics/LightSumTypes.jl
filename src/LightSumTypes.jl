
module LightSumTypes

using MacroTools: namify

export @sumtype, sumtype_expr, variant, variantof, allvariants, is_sumtype, apply

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
    variants_with_P = filter(has_typevars(typeparams), variants)
    variants_bounded = unique([v in variants_with_P ? namify(v) : v for v in variants])

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
        $(branchs(variants, :(return new{$(typeparams...)}(v)))))]

    if type isa Expr
        push!(
            constructors,
            :(@inline $type(v::Union{$(variants...)}) where {$(typeparams...)} =
                $(branchs(variants, :(return new{$(typeparams...)}(v)))))
        )
    end

    quote
        struct $type <: $(abstract_type)
            variants::Union{$(variants...)}
            $(constructors...)
        end
        $Core.@__doc__ $typename
        @inline function $Base.getproperty(sumt::$type, s::Symbol) where {$(typeparams...)}
            v = $LightSumTypes.unwrap(sumt)
            $(branchs(variants, :(return $Base.getproperty(v, s))))
        end
        @inline function $Base.setproperty!(sumt::$type, s::Symbol, value) where {$(typeparams...)}
            v = $LightSumTypes.unwrap(sumt)
            $(branchs(variants, :(return $Base.setproperty!(v, s, value))))
        end
        function $Base.propertynames(sumt::$type) where {$(typeparams...)}
            v = $LightSumTypes.unwrap(sumt)
            $(branchs(variants, :(return $Base.propertynames(v))))
        end
        function $Base.hasproperty(sumt::$type, s::Symbol) where {$(typeparams...)}
            v = $LightSumTypes.unwrap(sumt)
            $(branchs(variants, :(return $Base.hasproperty(v, s))))
        end
        function $Base.copy(sumt::$type) where {$(typeparams...)}
            v = $LightSumTypes.unwrap(sumt)
            $(branchs(variants, :(return $type(Base.copy(v)))))
        end
        @inline $LightSumTypes.variant(sumt::$typename) = $LightSumTypes.unwrap(sumt)
        @inline function $LightSumTypes.variant_idx(sumt::$type) where {$(typeparams...)}
            v = $LightSumTypes.unwrap(sumt)
            $(branchs(variants, [:(return $i) for i in 1:length(variants)]))
        end
        $LightSumTypes.variantof(sumt::$typename) = typeof($LightSumTypes.variant(sumt))
        $LightSumTypes.allvariants(sumt::Type{$typename}) = $(Expr(:tuple, (:($nv = $(v in variants_with_P ? namify(v) : v))
                                                                            for (nv, v) in zip(variants_names, variants))...))
        $LightSumTypes.is_sumtype(sumt::Type{$typename}) = true
        nothing
    end
end

function branchs(variants, outputs)
    !(outputs isa Vector) && (outputs = repeat([outputs], length(variants)))
    @assert length(variants) == length(outputs)
    expr = :(error("THIS_SHOULD_BE_UNREACHABLE"))
    for (variant, output) in zip(reverse(variants), reverse(outputs))
        condition = :(v isa $variant)
        expr = Expr(:elseif, condition, output, expr)
    end
    expr = Expr(:if, expr.args...) # correct first :elseif to :if
    return expr
end

has_typevars(expr::Symbol, typevars) = expr in typevars
has_typevars(expr, typevars) = Meta.isexpr(expr, :curly) && any(e -> has_typevars(e, typevars), expr.args)
has_typevars(typevars) = Base.Fix2(has_typevars, typevars)

check_if_typeof(v) = v isa Expr && v.head == :call && v.args[1] == :typeof

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

function _is_sumtype_structurally(T)
    return T isa DataType && fieldcount(T) == 1 && fieldname(T, 1) === :variants && fieldtype(T, 1) isa Union
end

function _get_variant_types(T_sum)
    field_T = fieldtype(T_sum, 1)
        
    !(field_T isa Union) && return [field_T]

    types = []
    curr = field_T
    while curr isa Union
        push!(types, curr.a)
        curr = curr.b
    end
    push!(types, curr)
    return types
end

@generated function apply(f::F, args::Tuple) where {F}
    

    args = fieldtypes(args)
    sumtype_args = [(i, T) for (i, T) in enumerate(args) if _is_sumtype_structurally(T)]

    if isempty(sumtype_args)
        return :(f(args...))
    end

    final_args = Any[:(args[$i]) for i in 1:length(args)]
    for (idx, T) in sumtype_args
        final_args[idx] = Symbol("v_", idx)
    end
    
    body = :(f($(final_args...)))
    
    for (idx, T) in reverse(sumtype_args)
        unwrapped_var = Symbol("v_", idx)
        
        variant_types = _get_variant_types(T)
        
        branch_expr = :(error("THIS_SHOULD_BE_UNREACHABLE"))
        for V_type in reverse(variant_types)
            condition = :($unwrapped_var isa $V_type)
            branch_expr = Expr(:elseif, condition, body, branch_expr)
        end
        branch_expr = Expr(:if, branch_expr.args...)
        
        body = quote
            let $(unwrapped_var) = $LightSumTypes.unwrap(args[$idx])
                $branch_expr
            end
        end
    end
    return body
end

include("precompile.jl")

end
