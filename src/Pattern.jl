
"""
    @pattern(function_definition)

This macro allows to pattern on types created by [`@sum_structs`](@ref). 

Notice that this only works when the kinds in the macro are not wrapped 
by any type containing them.

## Example

```julia
julia> @sum_structs AB begin
           struct A x::Int end
           struct B y::Int end
       end

julia> @pattern f(::A) = 1;

julia> @pattern f(::B) = 2;

julia> @pattern f(::Vector{AB}) = 3; # this works 

julia> @pattern f(::Vector{B}) = 3; # this doesn't work
ERROR: LoadError: It is not possible to dispatch on a variant wrapped in another type
...

julia> f(A(0))
1

julia> f(B(0))
2

julia> f([A(0), B(0)])
3
```
"""
macro pattern(f_def)
    vtc = __variants_types_cache__[__module__]
    vtwpc = __variants_types_with_params_cache__[__module__]
    f_sub, f_super_dict, f_cache = _pattern(f_def, vtc, vtwpc)

    if f_super_dict == nothing
        return Expr(:toplevel, esc(f_sub))
    end

    if __module__ in __modules_cache__
        is_first = false
    else
        is_first = true
        push!(__modules_cache__, __module__)
    end

    if is_first 
        expr_m = :(module Methods_Pattern_Module_219428042303
                        const __pattern_cache__ = Dict{Any, Any}()
                        function __init__()
                            define_all()
                        end
                        function define_all()
                            mod = parentmodule(@__MODULE__)
                            defs = mod.DynamicSumTypes.generate_defs(mod)
                            for (d, f_default) in defs
                                !isdefined(mod, f_default) && Base.eval(mod, :(function $f_default end))
                                Base.eval(mod, d)
                            end
                            return defs
                        end
                    end)
    else
        expr_m = :()
    end
    expr_d = :(DynamicSumTypes.define_f_super($(__module__), $(QuoteNode(f_super_dict)), $(QuoteNode(f_cache))))
    expr_fire = quote 
                    if isinteractive() && (@__MODULE__) == Main
                        Methods_Pattern_Module_219428042303.define_all()
                        $(f_super_dict[:name])
                    end
                end

    return Expr(:toplevel, esc(f_sub), esc(expr_m), esc(expr_d), esc(expr_fire))
end

function _pattern(f_def, vtc, vtwpc)
    macros = []
    while f_def.head == :macrocall
        f_def_comps = rmlines(f_def.args)
        push!(macros, f_def.args[1])
        f_def = f_def.args[end]
    end

    is_arg_no_name(s) = s isa Expr && s.head == :(::) && length(s.args) == 1 

    f_comps = ExprTools.splitdef(f_def; throw=true)
    f_args = f_comps[:args]
    f_args = [x isa Symbol ? :($x::Any) : x for x in f_args]
    
    f_args_t = [is_arg_no_name(a) ? a.args[1] : a.args[2] for a in f_args]
    f_args_n = [a isa Symbol ? a : namify(a) for a in f_args_t]

    idxs_mctc = findall(a -> a in values(vtc), f_args_n)
    idxs_mvtc = findall(a -> a in keys(vtc), f_args_n)

    for k in keys(vtc)
        if any(a -> inexpr(a[2], k) && !(a[1] in idxs_mvtc), enumerate(f_args_t)) 
            error("It is not possible to dispatch on a variant wrapped in another type")
        end
    end

    if !isempty(idxs_mctc) && !isempty(idxs_mvtc) 
        error("Using `@pattern` with signatures containing sum types and variants at the same time is not supported")
    end

    if !any(a -> a in keys(vtc) || a in values(vtc), f_args_n)
        return f_def, nothing, nothing
    end

    new_arg_types = [vtc[f_args_n[i]] for i in idxs_mvtc]

    is_variant_symbol(s, variant) = s isa Symbol && s == variant
    whereparams = []
    if :whereparams in keys(f_comps)
        whereparams = f_comps[:whereparams]
    end
    f_args_name = Symbol[]
    for i in idxs_mvtc
        variant = f_args_n[i]
        type = vtc[variant]
        if f_args_t[i] isa Symbol
            f_args[i] = MacroTools.postwalk(s -> is_variant_symbol(s, variant) ? type : s, f_args[i])
        else
            y, y_w = f_args_t[i], [] 
            arg_abstract, type_abstract = vtwpc[f_args_n[i]]
            type_abstract = deepcopy(type_abstract)
            type_abstract_args = type_abstract.args[2:end]
            arg_abstract = arg_abstract.args[2:end]
            arg_abstract = [x isa Expr && x.head == :(<:) ? x.args[1] : x for x in arg_abstract]
            pos_args = []

            if y.head == :where 
                y_w = y.args[2:end]
                y = y.args[1]
            end
            arg_concrete = y.args[2:end]

            for x in arg_abstract[1:length(arg_concrete)]
                j = findfirst(t -> t == x, type_abstract_args)
                push!(pos_args, j)
            end
            pos_no_args = [i for i in 1:length(type_abstract_args) 
                           if !(i in pos_args) && (
                                type_abstract_args[i] != :(DynamicSumTypes.Uninitialized) &&
                                type_abstract_args[i] != :(DynamicSumTypes.SumTypes.Uninit))]

            @capture(y, _{t_params__})
            for (p, q) in enumerate(pos_args)
                type_abstract_args[q] = MacroTools.postwalk(s -> s isa Symbol && s == arg_abstract[p] ? arg_concrete[p] : s, 
                                                       type_abstract_args[q])
            end
            idx = is_arg_no_name(f_args[i]) ? 1 : 2
            
            ps = [y_w..., type_abstract_args[pos_no_args]...]
            
            if !(isempty(ps))
                f_args[i].args[idx] = :($(type_abstract.args[1]){$(type_abstract_args...)} where {$(ps...)})
            else
                f_args[i].args[idx] = :($(type_abstract.args[1]){$(type_abstract_args...)})
            end
        end
        a = gensym(:argv)
        f_args[i] = MacroTools.postwalk(s -> is_arg_no_name(s) ? (pushfirst!(s.args, a); s) : s, f_args[i])
        push!(f_args_name, f_args[i].args[1])
    end

    for i in 1:length(f_args)
        if f_args[i] isa Expr && f_args[i].head == :(::) && length(f_args[i].args) == 1
            push!(f_args[i].args, gensym(:a))
            f_args[i].args[1], f_args[i].args[2] = f_args[i].args[2], f_args[i].args[1]
        end
    end
    g_args = deepcopy(f_args)

    for i in 1:length(f_args)
        a = Symbol("##argv#563487$i")
        if !(g_args[i] isa Symbol)
            g_args[i].args[1] = a
        else
            g_args[i] = a
        end
    end

    g_args_names = Any[namify(a) for a in g_args]
    if g_args[end] isa Expr && namify(g_args[end].args[2]) == :(Vararg)
        g_args_names[end] = :($(g_args_names[end])...)
    end

    idx_and_variant0 = collect(zip(idxs_mvtc, map(i -> f_args_n[i], idxs_mvtc)))
    idx_and_type = collect(zip(idxs_mctc, map(i -> f_args_n[i], idxs_mctc)))

    all_types_args0 = idx_and_variant0 != [] ? sort(idx_and_variant0) : sort(idx_and_type)
    all_types_args1 = sort(collect(zip(idxs_mvtc, map(i -> vtc[f_args_n[i]], idxs_mvtc))))

    f_args_cache = deepcopy(f_args)
    for i in eachindex(f_args_cache)
        for p in whereparams
            p_n = p isa Symbol ? p : p.args[1]
            p_t = p isa Symbol ? :Any : (p.head == :(<:) ? p.args[2] : error())
            if f_args_cache[i] isa Symbol
                f_args_cache[i] = MacroTools.postwalk(s -> s isa Symbol && s == p_n ? p_t : s, f_args_cache[i])
            else
                f_args_cache[i] = MacroTools.postwalk(s -> s isa Symbol && s == p_n ? :(<:($p_t)) : s, f_args_cache[i])
            end
            i == length(f_args_cache) && (f_args_cache[i] = MacroTools.postwalk(s -> sub_vararg_any(s), f_args_cache[i]))
        end
    end
    f_args_cache = map(MacroTools.splitarg, f_args_cache)
    f_args_cache = [(x[2], x[3]) for x in f_args_cache]

    f_cache = f_args_cache

    f_sub_dict = define_f_sub(whereparams, f_comps, all_types_args0, f_args)
    f_sub = ExprTools.combinedef(f_sub_dict)

    f_super_dict = Dict{Symbol, Any}()
    f_super_dict[:name] = f_comps[:name]
    f_super_dict[:args] = g_args

    a_cond = [:(DynamicSumTypes.kindof($(g_args[i].args[1])) === $(Expr(:quote, x))) for (i, x) in idx_and_variant0]
    new_cond = nothing
    if length(a_cond) == 1
        new_cond = a_cond[1]
    elseif length(a_cond) > 1
        new_cond = Expr(:&&, a_cond[1], a_cond[2])
        for x in a_cond[3:end]
            new_cond = Expr(:&&, x, new_cond)
        end
    end

    f_super_dict[:whereparams] = whereparams
    f_super_dict[:kwargs] = :kwargs in keys(f_comps) ? f_comps[:kwargs] : []
    f_super_dict[:macros] = macros
    f_super_dict[:condition] = new_cond
    f_super_dict[:subcall] = :(return $(f_sub_dict[:name])($(g_args_names...)))
    f_sub_name_default = Symbol(Symbol("##"), f_comps[:name], :_, collect(Iterators.flatten(all_types_args1))...)
    f_super_dict[:subcall_default] = :(return $(f_sub_name_default)($(g_args_names...)))

    return f_sub, f_super_dict, f_cache
end

function sub_vararg_any(s)
    s isa Symbol && return s
    length(s.args) != 3 && return s
    return s.args[1] == :(Vararg) && s.args[3] == :(<:Any) ? :Any : s
end

function define_f_sub(whereparams, f_comps, all_types_args0, f_args)
    f_sub_dict = Dict{Symbol, Any}()
    f_sub_name = Symbol(Symbol("##"), f_comps[:name], :_, collect(Iterators.flatten(all_types_args0))...)
    f_sub_dict[:name] = f_sub_name
    f_sub_dict[:args] = f_args
    f_sub_dict[:kwargs] = :kwargs in keys(f_comps) ? f_comps[:kwargs] : []
    f_sub_dict[:body] = f_comps[:body]
    whereparams != [] && (f_sub_dict[:whereparams] = whereparams)
    return f_sub_dict
end

function inspect_sig end

function define_f_super(mod, f_super_dict, f_cache)
    f_name = f_super_dict[:name]
    cache = mod.Methods_Pattern_Module_219428042303.__pattern_cache__
    if !(f_name in keys(cache))
        cache[f_name] = Dict{Any, Any}(f_cache => [f_super_dict])
    else
        never_same = true
        f_sig = Base.signature_type(mod.DynamicSumTypes.inspect_sig, Tuple(Base.eval(mod, :(tuple($(map(x -> x[1], f_cache)...))))))
        for sig in keys(cache[f_name])
            k_sig = Base.signature_type(mod.DynamicSumTypes.inspect_sig, Tuple(Base.eval(mod, :(tuple($(map(x -> x[1], sig)...))))))
            same_sig = f_sig == k_sig
            if same_sig
                same_cond = findfirst(f_prev -> f_prev[:condition] == f_super_dict[:condition], cache[f_name][sig])
                same_cond === nothing && push!(cache[f_name][sig], f_super_dict)
                never_same = false
                break
            end
        end
        if never_same
            cache[f_name][f_cache] = [f_super_dict]
        end
    end
end

function generate_defs(mod)
    cache = mod.Methods_Pattern_Module_219428042303.__pattern_cache__
    return generate_defs(mod, cache)
end

function generate_defs(mod, cache)
    defs = []
    for f in keys(cache)
        for ds in values(cache[f])
            new_d = Dict{Symbol, Any}()
            new_d[:args] = ds[end][:args]
            new_d[:name] = ds[end][:name]
            !allequal(d[:whereparams] for d in ds) && error("Parameters in where {...} should be the same for all @pattern methods with same signature")
            new_d[:whereparams] = ds[end][:whereparams]
            !allequal(d[:kwargs] for d in ds) && error("Keyword arguments should be the same for all @pattern methods with same signature")
            new_d[:kwargs] = ds[end][:kwargs]
            default = findfirst(d -> d[:condition] == nothing, ds)
            subcall_default = nothing
            if default != nothing
                subcall_default = ds[default][:subcall]
                ds[default], ds[end] = ds[end], ds[default]
            end
            body = nothing
            if default != nothing && length(ds) == 1
                body = subcall_default
            else
                body = Expr(:if, ds[1][:condition], ds[1][:subcall])
                body_prev = body
                for d in ds[2:end-(default != nothing)]
                    push!(body_prev.args, Expr(:elseif, d[:condition], d[:subcall]))
                    body_prev = body_prev.args[end]
                end
                f_end = ds[1][:subcall_default]
                push!(body_prev.args, f_end)
            end
            new_d[:body] = quote $body end
            new_df = mod.DynamicSumTypes.ExprTools.combinedef(new_d)
            !allequal(d[:macros] for d in ds) && error("Applied macros should be the same for all @pattern methods with same signature")
            for m in ds[end][:macros]
                new_df = Expr(:macrocall, m, :(), new_df)
            end
            push!(defs, [new_df, ds[1][:subcall_default].args[1].args[1]])
        end
    end
    return defs
end
