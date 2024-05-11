
"""
    @dispatch(function_definition)

This macro allows to dispatch on types created by [`@compact_structs`](@ref)
or [`@sum_structs`](@ref). Notice that this only works when the kinds in
the macro are not wrapped by any type containing them.

## Example

```julia
julia> @compact_structs AB begin
           struct A x::Int end
           struct B y::Int end
       end

julia> @dispatch f(::A) = 1;

julia> @dispatch f(::B) = 2;

julia> @dispatch f(::Vector{B}) = 3; # this doesn't work
ERROR: UndefVarError: `B` not defined
Stacktrace:
 [1] top-level scope
   @ REPL[7]:1

julia> f(A(0))
1

julia> f(B(0))
2
```

"""
macro dispatch(f_def)

    macros = []
    while f_def.head == :macrocall
        f_def_comps = rmlines(f_def.args)
        push!(macros, f_def.args[1])
        f_def = f_def.args[end]
    end

    is_arg_no_name(s) = s isa Expr && s.head == :(::) && length(s.args) == 1 

    vtc = __variants_types_cache__
    vtwpc = __variants_types_with_params_cache__

    f_comps = ExprTools.splitdef(f_def; throw=true)
    f_args = f_comps[:args]
    f_args = [x isa Symbol ? :($x::Any) : x for x in f_args]
    
    f_args_t = [is_arg_no_name(a) ? a.args[1] : a.args[2] for a in f_args]
    f_args_n = [a isa Symbol ? a : namify(a) for a in f_args_t]

    if !any(a -> a in keys(vtc) || a in values(vtc), f_args_n)
        return f_def
    end

    idxs_mctc = findall(a -> a in values(vtc), f_args_n)

    if !isempty(idxs_mctc)
        error("Dispatching on the overall type $(first(f_args_n)) is not supported")
    end

    idxs_mvtc = findall(a -> a in keys(vtc), f_args_n)

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
                                type_abstract_args[i] != :(MixedStructTypes.Uninitialized) &&
                                type_abstract_args[i] != :(MixedStructTypes.SumTypes.Uninit))]

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

    g_args = deepcopy(f_args)
    for i in length(f_args)
        if f_args[i] isa Expr && f_args[i].head == :(::) && length(f_args[i].args) == 1
            push!(f_args[i].args, gensym(:a))
            f_args[i].args[1], f_args[i].args[2] = f_args[i].args[2], f_args[i].args[1]
        end
    end
    for i in 1:length(f_args)
        a = Symbol("##argv#563487$i")
        if !(g_args[i] isa Symbol)
            g_args[i].args[1] = a
        else
            g_args[i] = a
        end
    end

    f_args_names = namify.(f_args)
    g_args_names = namify.(g_args)

    idx_and_variant0 = collect(zip(idxs_mvtc, map(i -> f_args_n[i], idxs_mvtc)))
    idx_and_variant = collect(zip(idxs_mvtc, map(i -> vtc[f_args_n[i]], idxs_mvtc)))
    idx_and_type = collect(zip(idxs_mctc, map(i -> f_args_n[i], idxs_mctc)))

    all_types_args0 = sort(idx_and_variant0)
    all_types_args = sort(idx_and_variant)

    f_cache = (f_comps[:name], all_types_args)

    if f_cache in keys(__dispatch_cache__)
        f_body_start = __dispatch_cache__[f_cache]
    else
        f_body_start = nothing
    end

    f_sub_dict = Dict{Symbol, Any}()
    f_sub_name = Symbol(f_comps[:name], :_sub_, collect(Iterators.flatten(all_types_args0))..., :_, length(f_args))
    f_sub_dict[:name] = f_sub_name
    f_sub_dict[:args] = f_args
    f_sub_dict[:kwargs] = :kwargs in keys(f_comps) ? f_comps[:kwargs] : []
    f_sub_dict[:body] = f_comps[:body]
    whereparams != [] && (f_sub_dict[:whereparams] = whereparams)
    f_sub = ExprTools.combinedef(f_sub_dict)

    f_super_dict = Dict{Symbol, Any}()
    f_super_dict[:name] = f_comps[:name]
    f_super_dict[:args] = g_args
    new_cond = nothing
    a_cond = [:(kindof($(g_args[i].args[1])) === $(Expr(:quote, x))) for (i, x) in idx_and_variant0]
    if length(a_cond) == 1
        tif = f_body_start == nothing ? :if : (:elseif)
        new_cond = a_cond[1]
        new_cond_if = Expr(tif, a_cond[1], :(return $(f_sub_dict[:name])($(g_args_names...))))
    else
        new_cond = Expr(:&&, a_cond[1], a_cond[2])
        for x in a_cond[3:end]
            new_cond = Expr(:&&, x, new_cond)
        end
        tif = f_body_start == nothing ? :if : (:elseif)
        new_cond_if = Expr(tif, new_cond, :(return $(f_sub_dict[:name])($(g_args_names...))))
    end

    if f_body_start == nothing
        f_body_start = new_cond_if
    elseif !(inexpr(f_body_start, new_cond))
        f_body_in = f_body_start
        while length(f_body_in.args) == 3
            f_body_in = f_body_in.args[end]
        end
        push!(f_body_in.args, new_cond_if)
    end

    f_super_dict[:body] = quote
            $f_body_start
            error("unreacheable reached!")
        end
    whereparams != [] && (f_super_dict[:whereparams] = whereparams)
    f_super_dict[:kwargs] = :kwargs in keys(f_comps) ? f_comps[:kwargs] : []
    f_super = ExprTools.combinedef(f_super_dict)

    __dispatch_cache__[f_cache] = f_body_start

    f_super = :(global $(f_super))
    for m in macros
        f_super = Expr(:macrocall, m, LineNumberNode(0, Symbol()), f_super)
    end

    return quote
            $(esc(f_sub))
            $(esc(f_comps[:name])) = MixedStructTypes.Suppressor.@suppress $(esc(f_super))
        end
end
