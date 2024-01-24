
macro sum_struct_type(type, struct_defs = nothing)

    if struct_defs === nothing
        is_kwdef = true
        type, struct_defs = type.args[end-1:end]
    else
        is_kwdef = false
    end
    
    struct_defs = [x for x in struct_defs.args if !(x isa LineNumberNode)]

    isnotmutable = all(!(d.args[1]) for d in struct_defs)
    
    variants_types = []
    hidden_struct_types = []
    for (i, d) in enumerate(struct_defs)
        t = d.args[2]
        c = @capture(t, t_n_{t_p__})
        c == false && ((t_n, t_p) = (t, []))
        push!(variants_types, t)
        h_t = gensym(t_n)
        if t_p != []
            h_t = :($h_t{$(t_p...)})
        end
        push!(hidden_struct_types, h_t)
        d_new = MacroTools.postwalk(s -> s == t ? h_t : s, d)
        for p in t_p
            p_u = gensym(p)
            d_new = MacroTools.postwalk(s -> s == p ? p_u : s, d_new)
        end
        struct_defs[i] = d_new
    end

    fields_each, default_each = [], []
    for a_spec in struct_defs
        a_comps = decompose_struct_no_base(a_spec)
        push!(fields_each, a_comps[2][1])
        push!(default_each, a_comps[2][2])
    end

    struct_defs = [:($Base.@kwdef $d) for d in struct_defs]

    variants_defs = [:($t(ht::$ht)) for (t, ht) in zip(variants_types, hidden_struct_types)]

    expr_sum_type = :(MixedStructTypes.SumTypes.@sum_type $type begin
                        $(variants_defs...)
                      end)
    expr_sum_type = macroexpand(__module__, expr_sum_type)

    variants_types_names = namify.(variants_types)
    branching_getprop = generate_branching_variants(variants_types_names, :(return getfield(data_a.data[1], s)))

    expr_getprop = :(function Base.getproperty(a::$(namify(type)), s::Symbol)
                        type_a = (typeof)(a)
                        MixedStructTypes.SumTypes.check_sum_type(type_a)
                        MixedStructTypes.SumTypes.assert_exhaustive(Val{(MixedStructTypes.SumTypes.tags)(type_a)}, 
                                                   Val{$(Tuple(variants_types_names))})

                        data_a = (MixedStructTypes.SumTypes.unwrap)(a)

                        $(branching_getprop...)
                     end)

    branching_setprop = generate_branching_variants(variants_types_names, :(return setfield!(data_a.data[1], s, v)))

    if !isnotmutable
        expr_setprop = :(function Base.setproperty!(a::$(namify(type)), s::Symbol, v)
                            type_a = (typeof)(a)

                            MixedStructTypes.SumTypes.check_sum_type(type_a)
                            MixedStructTypes.SumTypes.assert_exhaustive(Val{(MixedStructTypes.SumTypes.tags)(type_a)}, 
                                                       Val{$(Tuple(variants_types_names))})

                            data_a = (MixedStructTypes.SumTypes.unwrap)(a)

                            $(branching_setprop...)
                         end)
    else
        expr_setprop = :()
    end

    branching_kindof = generate_branching_variants(variants_types_names, :(return MixedStructTypes.retrieve_type(data_a)))

    expr_kindof = :(function MixedStructTypes.kindof(a::$(namify(type)))
                        type_a = (typeof)(a)
                        MixedStructTypes.SumTypes.check_sum_type(type_a)
                        MixedStructTypes.SumTypes.assert_exhaustive(Val{(MixedStructTypes.SumTypes.tags)(type_a)}, 
                                                   Val{$(Tuple(variants_types_names))})

                        data_a = (MixedStructTypes.SumTypes.unwrap)(a)

                        $(branching_kindof...)
                     end)

    fields_each_symbol = [:(return $(Tuple(f))) for f in retrieve_fields_names.(fields_each, false)]
    branching_propnames = generate_branching_variants(variants_types_names, fields_each_symbol)

    expr_propnames = :(function Base.propertynames(a::$(namify(type)))
                           type_a = (typeof)(a)
                           MixedStructTypes.SumTypes.check_sum_type(type_a)
                           MixedStructTypes.SumTypes.assert_exhaustive(Val{(MixedStructTypes.SumTypes.tags)(type_a)}, 
                                                                       Val{$(Tuple(variants_types_names))})

                           data_a = (MixedStructTypes.SumTypes.unwrap)(a)
                           $(branching_propnames...)
                       end)

    return_copy = [:(
        begin
            data_a_t = typeof(data_a)
            data_ins = data_a.data[1]
            data_ins_t = typeof(data_ins)
            return $v((getfield(data_ins, x) for x in fieldnames(data_ins_t))...)
        end
        ) for v in variants_types_names]
    branching_copy = generate_branching_variants(variants_types_names, return_copy)
    expr_copy = :(function Base.copy(a::$(namify(type)))::typeof(a)
                      type_a = (typeof)(a)
                      MixedStructTypes.SumTypes.check_sum_type(type_a)
                      MixedStructTypes.SumTypes.assert_exhaustive(Val{(MixedStructTypes.SumTypes.tags)(type_a)}, 
                                                                       Val{$(Tuple(variants_types_names))})

                      data_a = (MixedStructTypes.SumTypes.unwrap)(a)
                      $(branching_copy...)
                  end)

    expr_show = :(function Base.show(io::IO, a::$(namify(type)))
                      h_a = (MixedStructTypes.SumTypes.unwrap)(a).data[1]
                      f_vals = [getfield(h_a, x) for x in fieldnames(typeof(h_a))]
                      vals = join([MixedStructTypes.print_transform(x) for x in f_vals], ", ")
                      params = typeof(h_a).parameters
                      if isempty(params)
                          print(io, string(kindof(a)), "($vals)", "::", $(namify(type)))
                      else
                          print(io, string(kindof(a), "{", join(params, ", "), "}"), "($vals)", 
                                           "::", $(namify(type)))
                      end
                  end
                  )

    expr_show_mime = :(Base.show(io::IO, ::MIME"text/plain", a::$(namify(type))) = show(io, a))

    expr_constructors = []

    for (fs, fd, t, h_t) in zip(fields_each, default_each, variants_types, hidden_struct_types)
        f_d_n = retrieve_fields_names(fs, false)
        f_d_n_t = retrieve_fields_names(fs, true)
        c = @capture(t, t_n_{t_p__})
        a_spec_n_d = [d != "#328723329" ? Expr(:kw, n, d) : (:($n)) 
                          for (n, d) in zip(f_d_n, fd)]
        f_params_kwargs = Expr(:parameters, a_spec_n_d...)
        if t_p !== nothing
            c1 = :(function $t($(f_d_n...)) where {$(t_p...)}
                       return $t($(namify(h_t))($(f_d_n...)))
                   end
                  )
            c4 = :()
            if is_kwdef
                c4 = :(function $t($(f_params_kwargs)) where {$(t_p...)}
                           return $t($(namify(h_t))($(f_d_n...)))
                       end
                      )
            end
        else
            c1 = :()
            c4 = :()
        end
        c2 = :(function $(namify(t))($(f_d_n...))
                   return $(namify(t))($(namify(h_t))($(f_d_n...)))
               end
              )
        c3 = :()
        if is_kwdef
            c3 = :(function $(namify(t))($(f_params_kwargs))
                       return $(namify(t))($(namify(h_t))($(f_d_n...)))
                   end
                  )
        end
        push!(expr_constructors, c1)
        push!(expr_constructors, c2)
        push!(expr_constructors, c3)
        push!(expr_constructors, c4)
    end

    expr_sum_type = MacroTools.postwalk(e -> e isa Expr ? 
                                        remove_redefinitions(e, namify(type), variants_types_names, fields_each) : e, 
                                        expr_sum_type)

    expr = quote 
               $(struct_defs...)
               $(expr_sum_type)
               $(expr_getprop)
               $(expr_setprop)
               $(expr_kindof)
               $(expr_propnames)
               $(expr_copy)
               $(expr_show)
               $(expr_show_mime)
               $(expr_constructors...)
               nothing
           end

    return esc(expr)
end

function generate_branching_variants(variants_types, res)
    if !(res isa Vector)
        res = repeat([res], length(variants_types))
    end
    branchs = [Expr(:if, :(data_a isa (MixedStructTypes.SumTypes.Variant){$(Expr(:quote, variants_types[1]))}), res[1])]
    for i in 2:length(variants_types)
        push!(branchs, Expr(:elseif, :(data_a isa (MixedStructTypes.SumTypes.Variant){$(Expr(:quote, variants_types[i]))}), res[i]))
    end
    return branchs
end

function print_transform(x)
    x isa String && return "\"$x\""
    x isa Symbol && return QuoteNode(x)
    return x
end

function remove_redefinitions(e, t, vs, fs)

    redef = [:($(Base).show), :(($Base).getproperty)]
    f = ExprTools.splitdef(e, throw=false)
    f === nothing && return e

    if :name in keys(f) && f[:name] in redef
        if any(x -> x isa Expr && x.head == :(::) && x.args[2] == t, f[:args])
            return :()
        end
    elseif :name in keys(f)&& f[:name] in vs
        idx = findfirst(v -> f[:name] == v, vs)
        if length(f[:args]) == 1 && length(fs[idx]) == 1
            arg = f[:args][1]
            if arg isa Symbol
                return :()
            end
        end
    end
    return e
end

retrieve_type(::MixedStructTypes.SumTypes.Variant{T}) where T = T
retrieve_hidden_type(::MixedStructTypes.SumTypes.Variant{T,F,HT} where {T,F}) where HT = eltype(HT)


