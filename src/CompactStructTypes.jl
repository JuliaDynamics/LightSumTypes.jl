
struct Uninitialized end
const uninit = Uninitialized()

macro compact_struct_type(new_type, struct_defs = nothing)

    if struct_defs === nothing
        is_kwdef = true
        new_type, struct_defs = new_type.args[end-1:end]
    else
        is_kwdef = false
    end

    if new_type isa Expr && new_type.head == :(<:)
        new_type, abstract_type = new_type.args
    else
        new_type, abstract_type = new_type, :(Any)
    end
    structs_specs = decompose_struct_base(struct_defs)

    is_mutable = []
    for x in structs_specs
        push!(is_mutable, x.args[1])
    end
    if !allequal(is_mutable)
        return error("the compact_struct_type macro does not accept mixing mutable and immutable structs.")
    end
    is_mutable = all(x -> x == true, is_mutable)
    types_each, fields_each, default_each = [], [], []
    for struct_spec in structs_specs
        a_comps = decompose_struct_no_base(struct_spec)
        push!(types_each, a_comps[1])
        push!(fields_each, a_comps[2][1])
        push!(default_each, a_comps[2][2])
    end
    common_fields = intersect(fields_each...)
    all_fields = union(fields_each...)
    all_fields_n = retrieve_fields_names(all_fields)
    noncommon_fields = setdiff(all_fields, common_fields)
    if !isempty(noncommon_fields)
        all_fields = [transform_field(x, noncommon_fields) for x in all_fields]
    end

    gensym_type = gensym(:(type))

    field_type = is_mutable ? Expr(:const, :($(gensym_type)::Symbol)) : (:($(gensym_type)::Symbol))

    expr_comp_types = [Expr(:struct, is_mutable, t, :(begin end)) for t in types_each]
    expr_new_type = Expr(:struct, is_mutable, :($new_type <: $abstract_type),
                         :(begin 
                            $(all_fields...)
                            $field_type
                          end))

    expr_functions = []
    for (struct_t, struct_f, struct_d) in zip(types_each, fields_each, default_each)
        struct_spec_n = retrieve_fields_names(struct_f)
        struct_spec_n_d = [d != "#328723329" ? Expr(:kw, n, d) : (:($n)) 
                      for (n, d) in zip(struct_spec_n, struct_d)]
        f_params_kwargs = struct_spec_n_d
        f_params_kwargs = Expr(:parameters, f_params_kwargs...)        
        f_params_args = struct_spec_n
        f_params_args_with_T = retrieve_fields_names(struct_f, true)
        struct_spec_n2_d = [d != "#328723329" ? Expr(:kw, n, d) : (:($n)) 
                      for (n, d) in zip(retrieve_fields_names(struct_f, true), struct_d)]
        f_params_kwargs_with_T = struct_spec_n2_d
        f_params_kwargs_with_T = Expr(:parameters, f_params_kwargs_with_T...)
        type = Symbol(string(namify(struct_t)))
        f_inside_args = all_fields_n
        f_inside_args = [f in struct_spec_n ? f : (:(MixedStructTypes.uninit)) for f in f_inside_args]
        f_inside_args = [f_inside_args..., Expr(:quote, type)]
        @capture(struct_t, struct_t_n_{struct_t_p__})
        struct_t_p === nothing && (struct_t_p = [])
        @capture(new_type, new_type_n_{new_type_p__})
        if new_type_p === nothing 
            new_type_n, new_type_p = new_type, []
        end
        new_type_p = [t in struct_t_p ? t : (:(MixedStructTypes.Uninitialized)) 
                      for t in new_type_p]
        if isempty(new_type_p)
            expr_function_args = :(
                function $(namify(struct_t))($(f_params_args...))
                    return $(namify(new_type))($(f_inside_args...))
                end
                )
            if is_kwdef
                expr_function_kwargs = :(
                    function $(namify(struct_t))($f_params_kwargs)
                        return $(namify(new_type))($(f_inside_args...))
                    end
                    )
            else
                expr_function_kwargs = :()
            end
        else
            expr_function_args = :(
                function $(namify(struct_t))($(f_params_args_with_T...)) where {$(struct_t_p...)}
                    return $new_type_n{$(new_type_p...)}($(f_inside_args...))
                end
                )
            if is_kwdef
                expr_function_kwargs = :(
                    function $(namify(struct_t))($f_params_kwargs_with_T) where {$(struct_t_p...)}
                        return $new_type_n{$(new_type_p...)}($(f_inside_args...))
                    end
                    )
            else
                expr_function_kwargs = :()
            end
        end

        remove_prev_functions = remove_prev_methods(struct_t)
        push!(expr_functions, remove_prev_functions)
        push!(expr_functions, expr_function_kwargs)
        push!(expr_functions, expr_function_args)
    end

    expr_kindof = :(MixedStructTypes.kindof(a::$(namify(new_type))) = getfield(a, $(Expr(:quote, gensym_type))))

    branching_constructor = generate_branching_types(namify.(types_each), [:(return $v) for v in namify.(types_each)])

    expr_constructor = :(function MixedStructTypes.constructor(a::$(namify(new_type)))
                        kind = kindof(a)

                        $(branching_constructor...)
                     end)

    expr_show = :(function Base.show(io::IO, a::$(namify(new_type)))
                      f_vals = [getfield(a, x) for x in fieldnames(typeof(a))[1:end-1] if getfield(a, x) != MixedStructTypes.uninit]
                      vals = join([MixedStructTypes.print_transform(x) for x in f_vals], ", ")
                      params = [x for x in typeof(a).parameters if x != MixedStructTypes.Uninitialized] 
                      if isempty(params)
                          print(io, string(kindof(a)), "($vals)", "::", $(namify(new_type)))
                      else
                          print(io, string(kindof(a), "{", join(params, ", "), "}"), "($vals)", 
                                           "::", $(namify(new_type)))
                      end
                  end
                  )

    expr_getprop = :(function Base.getproperty(a::$(namify(new_type)), s::Symbol)
                        f = getfield(a, s)
                        if f isa MixedStructTypes.Uninitialized
                            return error("type $(kindof(a)) has no field $s")
                        end
                        return f
                     end)

    if is_mutable
        expr_setprop = :(function Base.setproperty!(a::$(namify(new_type)), s::Symbol, v)
                            f = getfield(a, s)
                            if f isa MixedStructTypes.Uninitialized
                                return error("type $(kindof(a)) has no field $s")
                            end
                            setfield!(a, s, v)
                         end)
    else
        expr_setprop = :()
    end

    fields_each_symbol = [:(return $(Tuple(f))) for f in retrieve_fields_names.(fields_each)]
    branching_propnames = generate_branching_types(namify.(types_each), fields_each_symbol)
    expr_propnames = :(function Base.propertynames(a::$(namify(new_type)))
                           kind = kindof(a)
                           $(branching_propnames...)
                           $(fields_each_symbol[end])
                       end)

    expr_copy = :(function Base.copy(a::$(namify(new_type)))
                      A = typeof(a)
                      return A((getfield(a, x) for x in fieldnames(A))...)
                  end)

        
    expr = quote 
            $(expr_comp_types...)
            $(Base.@__doc__ expr_new_type)
            $(expr_functions...)
            $(expr_kindof)
            $(expr_getprop)
            $(expr_setprop)
            $(expr_propnames)
            $(expr_copy)
            $(expr_constructor)
            $(expr_show)
            nothing
           end
    return esc(expr)
end

function decompose_struct_base(struct_repr)
    @capture(struct_repr, begin new_fields__ end)
    return new_fields
end

function decompose_struct_no_base(struct_repr, split_default=true)
    @capture(struct_repr, struct new_type_ new_fields__ end)
    new_fields == nothing && @capture(struct_repr, mutable struct new_type_ new_fields__ end)
    if split_default
        new_fields_with_defs = [[], []]
        for f in new_fields
            if !@capture(f, const t_ = k_)
                if !@capture(f, t_ = k_)
                    @capture(f, t_)
                    k = "#328723329"
                end
            end
            push!(new_fields_with_defs[1], t)
            push!(new_fields_with_defs[2], k)
        end
        new_fields = new_fields_with_defs
    end
    return new_type, new_fields
end

function retrieve_fields_names(fields, only_consts = false)
    field_names = []
    for f in fields
        f.head == :const && (f = f.args[1])
        !only_consts && f.head == :(::) && (f = f.args[1])
        push!(field_names, f)
    end
    return field_names
end

function generate_branching_types(variants_types, res)
    if !(res isa Vector)
        res = repeat([res], length(variants_types))
    end
    branchs = [Expr(:if, :(kind === $(Expr(:quote, variants_types[1]))), res[1])]
    for i in 2:length(variants_types)-1
        push!(branchs, Expr(:elseif, :(kind === $(Expr(:quote, variants_types[i]))), res[i]))
    end
    return branchs
end

function remove_prev_methods(struct_t)
    return :(if @isdefined $(namify(struct_t))
                for m in methods($(namify(struct_t)))
                    Base.delete_method(m)
                end
            end)
end

function transform_field(x, noncommon_fields)
    x isa Symbol && return x
    const_x = x.head == :const
    if const_x
        x_args = x.args[1]
    else
        x_args = x
    end
    if x_args isa Symbol
        return x
    else
        if x in noncommon_fields
            name, T = x_args.args
            f = :($name::Union{MixedStructTypes.Uninitialized, $T})
            if const_x
                f = Expr(:const, f)
            end
            return f
        else
            return x
        end
    end
end

