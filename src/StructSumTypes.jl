
module StructSumTypes

using MacroTools
using SumTypes
export SumTypes

export @struct_sum_type

macro struct_sum_type(type, struct_defs)
    
    struct_defs = [x for x in struct_defs.args if !(x isa LineNumberNode)]

    isnotmutable = all(!(d.args[1]) for d in struct_defs)
    
    variants_types = []
    for (i, d) in enumerate(struct_defs)
        t = d.args[2]
        push!(variants_types, t)
        d_new = MacroTools.postwalk(s -> s == t ? Symbol(:_, s) : s, d)
        struct_defs[i] = d_new
    end

    hidden_struct_types = [Symbol(:_, t) for t in variants_types]
    variants_defs = [:($t(ht::$ht)) for (t, ht) in zip(variants_types, hidden_struct_types)]

    expr_sum_type = :(SumTypes.@sum_type $type begin
                        $(variants_defs...)
                      end)

    branching_getprop = generate_branching_variants(variants_types, :(return getfield(data_a.data[1], s)))

    expr_getprop = :(function Base.getproperty(a::$type, s::Symbol)
                        type_a = (typeof)(a)
                        SumTypes.check_sum_type(type_a)
                        SumTypes.assert_exhaustive(Val{(SumTypes.tags)(type_a)}, 
                                                   Val{$(Tuple(variants_types))})

                        data_a = (SumTypes.unwrap)(a)

                        $(branching_getprop...)
                     end)

    branching_setprop = generate_branching_variants(variants_types, :(return setfield!(data_a.data[1], s, v)))

    if !isnotmutable
        expr_setprop = :(function Base.setproperty!(a::$type, s::Symbol, v)
                            type_a = (typeof)(a)

                            SumTypes.check_sum_type(type_a)
                            SumTypes.assert_exhaustive(Val{(SumTypes.tags)(type_a)}, 
                                                       Val{$(Tuple(variants_types))})

                            data_a = (SumTypes.unwrap)(a)

                            $(branching_setprop...)
                         end)
    else
        expr_setprop = :()
    end

    expr_constructors = []

    for (d, t) in zip(struct_defs, variants_types)
        f_d = [x for x in d.args[3].args if !(x isa LineNumberNode)]
        f_d_n = retrieve_fields_names(f_d, false)
        f_d_n_t = retrieve_fields_names(f_d, true)
        c = :(function $t($(f_d_n_t...))
                  return $t($(Symbol(:_, t))($(f_d_n...)))
              end
            )
        push!(expr_constructors, c)
    end

    expr = quote 
               $(struct_defs...)
               $(expr_sum_type)
               $(expr_getprop)
               $(expr_setprop)
               $(expr_constructors...)
           end

    return esc(expr)
end

function generate_branching_variants(variants_types, res)
    branchs = [Expr(:if, :(data_a isa (SumTypes.Variant){$(Expr(:quote, variants_types[1]))}), res)]
    for i in 2:length(variants_types)
        push!(branchs, Expr(:elseif, :(data_a isa (SumTypes.Variant){$(Expr(:quote, variants_types[i]))}), res))
    end
    return branchs
end

function retrieve_fields_names(fields, remove_only_consts = false)
    field_names = []
    for f in fields
        f.head == :const && (f = f.args[1])
        !remove_only_consts && f.head == :(::) && (f = f.args[1])
        push!(field_names, f)
    end
    return field_names
end

end
