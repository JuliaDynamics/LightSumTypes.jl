
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
    agent_specs = decompose_struct_base(struct_defs)
    types_each, fields_each, default_each = [], [], []
    for a_spec in agent_specs
        a_comps = decompose_struct_no_base(a_spec)
        push!(types_each, a_comps[1])
        push!(fields_each, a_comps[2][1])
        push!(default_each, a_comps[2][2])
    end
    common_fields = intersect(fields_each...)
    all_fields = union(fields_each...)
    all_fields_n = retrieve_fields_names(all_fields)
    noncommon_fields = setdiff(all_fields, common_fields)
    if isempty(noncommon_fields)
        islazy = false
    else
        islazy = true
        all_fields = [transform_field(x, noncommon_fields) for x in all_fields]
    end

    gensym_type = gensym(:(type))
    expr_new_type = :(mutable struct $new_type <: $abstract_type
                        $(all_fields...)
                        $(gensym_type)::Symbol
                      end)

    expr_new_type = islazy ? :(@lazy $expr_new_type) : expr_new_type
    expr_functions = []
    for (a_t, a_f, a_d) in zip(types_each, fields_each, default_each)
        a_spec_n = retrieve_fields_names(a_f)
        a_spec_n_d = [d != "#328723329" ? Expr(:kw, n, d) : (:($n)) 
                      for (n, d) in zip(a_spec_n, a_d)]
        f_params_kwargs = a_spec_n_d
        f_params_kwargs = Expr(:parameters, f_params_kwargs...)        
        f_params_args = a_spec_n
        f_params_args_with_T = retrieve_fields_names(a_f, true)
        a_spec_n2_d = [d != "#328723329" ? Expr(:kw, n, d) : (:($n)) 
                      for (n, d) in zip(retrieve_fields_names(a_f, true), a_d)]
        f_params_kwargs_with_T = a_spec_n2_d
        f_params_kwargs_with_T = Expr(:parameters, f_params_kwargs_with_T...)
        type = Symbol(string(namify(a_t)))
        f_inside_args = all_fields_n
        f_inside_args = [f in a_spec_n ? f : (:(MixedStructTypes.uninit)) for f in f_inside_args]
        f_inside_args = [f_inside_args..., Expr(:quote, type)]
        @capture(a_t, a_t_n_{a_t_p__})
        a_t_p === nothing && (a_t_p = [])
        @capture(new_type, new_type_n_{new_type_p__})
        if new_type_p === nothing 
            new_type_n, new_type_p = new_type, []
        end
        new_type_p = [t in a_t_p ? t : (:(MixedStructTypes.LazilyInitializedFields.Uninitialized)) 
                      for t in new_type_p]
        if is_kwdef
            expr_function_kwargs = :(
                function $(namify(a_t))($f_params_kwargs)
                    return $(namify(new_type))($(f_inside_args...))
                end
                )
        else
            expr_function_kwargs = :()
        end
        expr_function_args = :(
            function $(namify(a_t))($(f_params_args...))
                return $(namify(new_type))($(f_inside_args...))
            end
            )
        if !isempty(new_type_p)
            expr_function_args_with_T = :(
                function $(namify(a_t))($(f_params_args_with_T...)) where {$(a_t_p...)}
                    return $new_type_n{$(new_type_p...)}($(f_inside_args...))
                end
                )
            if is_kwdef
                expr_function_kwargs_with_T = :(
                    function $(namify(a_t))($f_params_kwargs_with_T) where {$(a_t_p...)}
                        return $new_type_n{$(new_type_p...)}($(f_inside_args...))
                    end
                    )
            else
                expr_function_kwargs_with_T = :()
            end
        else
            expr_function_args_with_T = :()
            expr_function_kwargs_with_T = :()
        end
        remove_prev_functions = remove_prev_methods(a_t)
        push!(expr_functions, remove_prev_functions)
        push!(expr_functions, expr_function_kwargs)
        push!(expr_functions, expr_function_args)
        push!(expr_functions, expr_function_args_with_T)
        push!(expr_functions, expr_function_kwargs_with_T)
    end

    expr_kindof = :(kindof(a::$(namify(new_type))) = getfield(a, $(Expr(:quote, gensym_type))))

    expr_show = :(function Base.show(io::IO, a::$(namify(new_type)))
                      f_vals = [getfield(a, x) for x in fieldnames(typeof(a))[1:end-1] if getfield(a, x) != MixedStructTypes.uninit]
                      vals = join([MixedStructTypes.print_transform(x) for x in f_vals], ", ")
                      params = [x for x in typeof(a).parameters if x != MixedStructTypes.LazilyInitializedFields.Uninitialized] 
                      if isempty(params)
                          print(io, string(kindof(a)), "($vals)", "::", $(namify(new_type)))
                      else
                          print(io, string(kindof(a), "{", join(params, ", "), "}"), "($vals)", 
                                           "::", $(namify(new_type)))
                      end
                  end
                  )

    expr = quote 
            $(Base.@__doc__ expr_new_type)
            $(expr_functions...)
            $(expr_kindof)
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
    
function remove_prev_methods(a_t)
    return :(if @isdefined $(namify(a_t))
                for m in methods($(namify(a_t)))
                    Base.delete_method(m)
                end
            end)
end

function transform_field(x, noncommon_fields)
    if x in noncommon_fields
        return x.head == :const ? :(@lazy $(x.args[1])) : (:(@lazy $x)) 
    else
        return x
    end
end
