

module TypeWrappers

export @sumtype

struct Variant{T}
    data::T
end

unwrap(sumt) = getfield(sumt, :variants)

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
    variants_names = type_with_variants.args[2:end]
    variants = [:(TypeWrappers.Variant{$T}) for T in variants_names]

    #fake_names = [:($(Symbol("###", namify(type), "#", namify(v))){$(p...)}) for (v, p) in zip(variants_types_names, variants_params_unconstr)]
    #fake_structs = [:(struct $fn 1+1 end) for fn in fake_names]

    esc(quote
            struct $type <: $(abstract_type)
                variants::Union{$(variants...)}
                function $type(v)
                    $(branchs(variants_names, [:(return new($vw(v))) for vw in variants])...)
                end
            end
            function variant(sumt::$type)
                v = TypeWrappers.unwrap(sumt)
                $(branchs(variants, :(return v.data))...)
            end
            function Base.getproperty(sumt::$type, s::Symbol)
                v = TypeWrappers.unwrap(sumt)
                $(branchs(variants, :(return getproperty(v.data, s)))...)
            end
            function Base.setproperty!(sumt::$type, s::Symbol, value)
                v = TypeWrappers.unwrap(sumt)
                $(branchs(variants, :(return setproperty!(v.data, s, value)))...)
            end
            function Base.propertynames(sumt::$type)
                v = TypeWrappers.unwrap(sumt)
                $(branchs(variants, :(return propertynames(v.data)))...)
            end
            function Base.adjoint(ST::Type{<:$(type)})
            	$NamedTuple{$(Expr(:tuple, QuoteNode.(variants_names)...))}($(Expr(:tuple, variants_names...)))
            end
    end)
end 

function branchs(variants, outputs)
    if !(outputs isa Vector)
        outputs = repeat([outputs], length(variants))
    end
    branchs = [Expr(:if, :(v isa $(variants[1])), outputs[1])]
    for i in 2:length(variants)
        push!(branchs, Expr(:elseif, :(v isa $(variants[i])), outputs[i]))
    end
    push!(branchs, :(error("THIS_SHOULD_BE_UNREACHABLE")))
    return branchs
end

end

