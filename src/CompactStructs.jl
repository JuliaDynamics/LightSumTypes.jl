

struct Uninitialized end
const uninit = Uninitialized()

"""
    @compact_structs(type_definition, structs_definitions)

This macro allows to combine multiple types in a single one. 
This version has been built to yield a performance almost 
identical to having just one type.

## Example

```julia
julia> @compact_structs AB begin
           struct A x::Int end
           struct B y::Int end
       end

julia> a = A(1)
A(1)::AB

julia> a.x
1
```

"""
macro compact_structs(new_type, struct_defs)
    return esc(_compact_structs(new_type, struct_defs))
end

function _compact_structs(new_type, struct_defs)
    if new_type isa Expr && new_type.head == :(<:)
        new_type, abstract_type = new_type.args
    else
        new_type, abstract_type = new_type, :(Any)
    end
    structs_specs = decompose_struct_base(struct_defs)

    structs_specs_new = []
    is_kws = []
    for x in structs_specs
        v1 = @capture(x, @kwdef d_)
        v1 == false && (v2 = @capture(x, Base.@kwdef d_))
        if d == nothing 
            push!(structs_specs_new, x)
            push!(is_kws, false)
        else
            push!(structs_specs_new, d)
            push!(is_kws, true)
        end
    end
    structs_specs = structs_specs_new

    is_mutable = []
    for x in structs_specs
        push!(is_mutable, x.args[1])
    end
    if !allequal(is_mutable)
        return error("`@compact_structs` does not accept mixing mutable and immutable structs.")
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
    all_fields_transf = [transform_field(x, noncommon_fields) for x in all_fields]

    gensym_type = gensym(:(_kind))
    field_type = is_mutable ? Expr(:const, :($(gensym_type)::Symbol)) : (:($(gensym_type)::Symbol))

    expr_comp_types = [Expr(:struct, false, t, :(begin sdfnsdfsdfak() = 1 end)) for t in types_each]
    type_name = new_type isa Symbol ? new_type : new_type.args[1]

    type_no_constr = MacroTools.postwalk(s -> s isa Expr && s.head == :(<:) ? s.args[1] : s, new_type)
    type_params = new_type isa Symbol ? [] : [x isa Expr && x.head == :(<:) ? x.args[1] : x for x in new_type.args[2:end]]
    uninit_val = :(MixedStructTypes.Uninitialized)
    compact_t = MacroTools.postwalk(s -> s isa Expr && s.head == :(<:) ? make_union_uninit(s, type_name, uninit_val) : s, new_type)
    
    abstract_type_inner = Symbol("##$(namify(compact_t))#563487")
    if abstract_type isa Expr
        abstract_type_inner = :($abstract_type_inner{$(abstract_type.args[2:end]...)})
    end
    expr_subt = :(abstract type $abstract_type_inner <: $abstract_type end)
    expr_new_type = Expr(:struct, is_mutable, :($compact_t <: $abstract_type_inner),
                         :(begin 
                            $(all_fields_transf...)
                            $field_type
                          end))


    expr_new_type = quote
            $expr_subt
            $expr_new_type
        end

    expr_params_each = []
    expr_functions = []
    for (struct_t, struct_f, struct_d, is_kw) in zip(types_each, fields_each, default_each, is_kws)
        struct_spec_n = retrieve_fields_names(struct_f)
        struct_spec_n_d = [d != "#32872248308323039203329" ? Expr(:kw, n, d) : (:($n)) 
                      for (n, d) in zip(struct_spec_n, struct_d)]
        f_params_kwargs = struct_spec_n_d
        f_params_kwargs = Expr(:parameters, f_params_kwargs...)        
        f_params_args = struct_spec_n
        f_params_args_with_T = retrieve_fields_names(struct_f, true)
        @capture(new_type, new_type_n_{new_type_p__})
        if new_type_p === nothing 
            new_type_n, new_type_p = new_type, []
        end
        new_type_p = [t isa Expr && t.head == :(<:) ? t.args[1] : t for t in new_type_p]
        f_params_args_with_T = [!any(p -> inexpr(x, p), new_type_p) ? (x isa Symbol ? x : x.args[1]) : x 
                                for x in f_params_args_with_T]
        struct_spec_n2_d = [d != "#32872248308323039203329" ? Expr(:kw, n, d) : (:($n)) 
                      for (n, d) in zip(f_params_args_with_T, struct_d)]
        f_params_kwargs_with_T = struct_spec_n2_d
        f_params_kwargs_with_T = Expr(:parameters, f_params_kwargs_with_T...)
        type = Symbol(string(namify(struct_t)))
        f_inside_args = all_fields_n

        conv_maybe = [x isa Symbol ? :() : x.args[2] for x in retrieve_fields_names(all_fields, true)]
        f_inside_args_no_t = maybe_convert_fields(conv_maybe, f_inside_args, new_type_p, struct_spec_n)
        f_inside_args2_no_t = maybe_convert_fields(conv_maybe, f_inside_args, new_type_p, struct_spec_n; with_params=true)
        f_inside_args = [f_inside_args_no_t..., Expr(:quote, type)]
        f_inside_args2 = [f_inside_args2_no_t..., Expr(:quote, type)]

        @capture(struct_t, struct_t_n_{struct_t_p__})
        struct_t_p === nothing && (struct_t_p = [])
        struct_t_p_no_sup = [p isa Expr && p.head == :(<:) ? p.args[1] : p for p in struct_t_p]
        struct_t_arg = struct_t_p_no_sup != [] ? :($struct_t_n{$(struct_t_p_no_sup...)}) : struct_t
        new_type_p = [t in struct_t_p_no_sup ? t : (:(MixedStructTypes.Uninitialized)) 
                      for t in new_type_p]

        expr_function_kwargs = :()
        expr_function_kwargs2 = :()
        expr_function_args = :()
        expr_function_args2 = :()

        push!(expr_params_each, :($new_type_n{$(new_type_p...)}))

        if isempty(new_type_p)
            expr_function_args = :(
                function $(namify(struct_t))($(f_params_args...))
                    return $(namify(new_type))($(f_inside_args...))
                end)
            if is_kw
                expr_function_kwargs = :(
                    function $(namify(struct_t))($f_params_kwargs)
                        return $(namify(new_type))($(f_inside_args...))
                    end)
            end
        else
            expr_function_args = :(
                    function $(namify(struct_t))($(f_params_args_with_T...)) where {$(struct_t_p...)}
                        return $new_type_n{$(new_type_p...)}($(f_inside_args...))
                    end)
            if !isempty(struct_t_p)
                expr_function_args2 = :(function $(struct_t_arg)($(f_params_args...)) where {$(struct_t_p...)}
                                            return $new_type_n{$(new_type_p...)}($(f_inside_args2...))
                                        end)
            end
            if is_kw
                expr_function_kwargs = :(
                    function $(namify(struct_t))($f_params_kwargs_with_T) where {$(struct_t_p...)}
                        return $new_type_n{$(new_type_p...)}($(f_inside_args...))
                    end)
                if !isempty(struct_t_p)
                    expr_function_kwargs2 = :(
                        function $(struct_t_arg)($f_params_kwargs) where {$(struct_t_p...)}
                            return $new_type_n{$(new_type_p...)}($(f_inside_args2...))
                        end)
                end
            end
        end

        push!(expr_functions, expr_function_kwargs)
        push!(expr_functions, expr_function_args)
        push!(expr_functions, expr_function_kwargs2)
        push!(expr_functions, expr_function_args2)
    end

    add_types_to_cache(type_name, types_each)
    add_types_params_to_cache(expr_params_each, types_each)

    expr_kindof = :(MixedStructTypes.kindof(a::$(namify(new_type))) = getfield(a, $(Expr(:quote, gensym_type))))

    expr_allkinds = []
    expr_allkinds1 = :(MixedStructTypes.allkinds(a::Type{$(namify(new_type))}) = $(Tuple(namify.(types_each))))
    push!(expr_allkinds, expr_allkinds1)
    if namify(type_no_constr) !== type_no_constr
        expr_allkinds2 = :(MixedStructTypes.allkinds(a::Type{$type_no_constr} where {$(type_params...)}) = $(Tuple(namify.(types_each))))
        push!(expr_allkinds, expr_allkinds2)
    end

    branching_constructor = generate_branching_types(namify.(types_each), [:(return $v) for v in namify.(types_each)])

    expr_constructor = :(function MixedStructTypes.kindconstructor(a::$(namify(new_type)))
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
                            return error(lazy"type $(kindof(a)) has no field $s")
                        end
                        return f
                     end)

    if is_mutable
        expr_setprop = :(function Base.setproperty!(a::$(namify(new_type)), s::Symbol, v)
                            f = getfield(a, s)
                            if f isa MixedStructTypes.Uninitialized
                                return error(lazy"type $(kindof(a)) has no field $s")
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
            $(expr_allkinds...)
            $(expr_getprop)
            $(expr_setprop)
            $(expr_propnames)
            $(expr_copy)
            $(expr_constructor)
            $(expr_show)
            nothing
           end
    return expr
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
                    k = "#32872248308323039203329"
                end
            end
            push!(new_fields_with_defs[1], t)
            push!(new_fields_with_defs[2], k)
        end
        new_fields = new_fields_with_defs
    end
    return new_type, new_fields
end

function maybe_convert_fields(conv_maybe, f_inside_args, new_type_p, struct_spec_n; with_params=false)
    f_inside_args_new = []
    i = 1

    for f in f_inside_args
        if f in struct_spec_n
            t = conv_maybe[i]
            if (with_params || !any(p -> inexpr(t, p), new_type_p)) && t != :()
                new_f = :(Base.convert($t, $f))
            else
                new_f = f
            end
        else
            new_f = :(MixedStructTypes.uninit)
        end
        i += 1
        push!(f_inside_args_new, new_f)
    end
    return f_inside_args_new
end

function retrieve_fields_names(fields, only_consts = false)
    field_names = []
    for f in fields
        if f isa Symbol
            push!(field_names, f)
        else
            f.head == :const && (f = f.args[1])
            !only_consts && (f = namify(f))
            push!(field_names, f)
        end
    end
    return field_names
end

function generate_branching_types(variants_types, res)
    if !(res isa Vector)
        res = repeat([res], length(variants_types))
    end
    branchs = [Expr(:if, :(kind === $(Expr(:quote, variants_types[1]))), res[1])]
    for i in 2:length(variants_types)
        push!(branchs, Expr(:elseif, :(kind === $(Expr(:quote, variants_types[i]))), res[i]))
    end
    push!(branchs, :(error("unreacheable")))
    return branchs
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

function add_types_to_cache(type, variants)
    type = namify(type)
    variants = namify.(variants)
    for v in variants
        __variants_types_cache__[v] = type
    end
end

function add_types_params_to_cache(params, variants)
    variants_n = namify.(variants)
    for (v1, v2, p) in zip(variants, variants_n, params)
        __variants_types_with_params_cache__[v2] = [v1, p]
    end
end
