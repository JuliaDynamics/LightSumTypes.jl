
using ExprTools

export @sum_structs
export @pattern
export @finalize_patterns
export export_variants
export kindof
export allkinds
export variant_constructor

const __modules_cache__ = Set{Module}()
const __variants_types_cache__ = Dict{Module, Dict{Any, Any}}()
const __variants_types_with_params_cache__ = Dict{Module, Dict{Any, Vector{Any}}}()

"""
    kindof(instance)

Return a symbol representing the conceptual type of an instance:

```julia
julia> @sum_structs AB begin
           struct A x::Int end
           struct B y::Int end
       end

julia> a = AB'.A(1);

julia> kindof(a)
:A
```
"""
function kindof end

"""
    allkinds(type)

Return a `Tuple` containing all kinds associated with the overarching 
type defined with `@sum_structs`

```julia
julia> @sum_structs AB begin
           struct A x::Int end
           struct B y::Int end
       end

julia> allkinds(AB)
(:A, :B)
```
"""
function allkinds end

"""
    variant_constructor(instance)

Return the constructor of an instance in a more
efficient way than doing `typeof(inst)'[kindof(inst)]`:

```julia
julia> @sum_structs AB begin
           struct A x::Int end
           struct B y::Int end
       end

julia> a = AB'.A(1)
AB'.A(1)

julia> typeof(a)'[kindof(a)]
AB'.A

julia> variant_constructor(a)
AB'.A
```
"""
function variant_constructor end

"""
    export_variants(T)

Export all variants types into the module the
function it is called into.

## Example

```julia
julia> @sum_structs AB begin
           struct A x::Int end
           struct B y::Int end
       end

julia> AB'.A(1)
AB'.A(1)

julia> export_variants(AB)

julia> A(1) # now this also works
AB'.A(1)
```
"""
function export_variants end

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

julia> @pattern f(::AB'.A) = 1;

julia> @pattern f(::AB'.B) = 2;

julia> @pattern f(::Vector{AB}) = 3; # this works 

julia> @pattern f(::Vector{AB'.B}) = 3; # this doesn't work
ERROR: LoadError: It is not possible to dispatch on a variant wrapped in another type
...

julia> f(AB'.A(0))
1

julia> f(AB'.B(0))
2

julia> f([AB'.A(0), AB'.B(0)])
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
        expr_m = quote 
                     const __pattern_cache__ = Dict{Any, Any}()
                     const __finalized_methods_cache__ = Set{Expr}()
                 end
    else
        expr_m = :()
    end
    expr_d = :(DynamicSumTypes.define_f_super($(__module__), $(QuoteNode(f_super_dict)), $(QuoteNode(f_cache))))
    expr_fire = quote 
                    if isinteractive() && (@__MODULE__) == Main
                        DynamicSumTypes.@finalize_patterns
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
    f_args_n = [dotted_arg(a) for a in f_args_t]

    idxs_mctc = findall(a -> a in values(vtc), f_args_n)
    idxs_mvtc = findall(a -> a in keys(vtc), f_args_n)

    f_args = [restructure_arg(f_args[i], i, idxs_mvtc) for i in 1:length(f_args)]
    f_args_t = [is_arg_no_name(a) ? a.args[1] : a.args[2] for a in f_args]

    for k in keys(vtc)
        if any(a -> inexpr(a[2], k) && !(a[1] in idxs_mvtc), enumerate(f_args_t)) 
            error("It is not possible to dispatch on a variant wrapped in another type")
        end
    end

    if !isempty(idxs_mctc) && !isempty(idxs_mvtc) 
        error("Using `@pattern` with signatures containing sum types and variants at the same time is not supported")
    end

    if isempty(idxs_mvtc) && isempty(idxs_mctc)
        return f_def, nothing, nothing
    end

    new_arg_types = [vtc[f_args_n[i]] for i in idxs_mvtc]
    transform_name(v) = v isa Expr && v.head == :. ? v.args[2].value : v
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
            v = transform_name(variant)
            f_args[i] = MacroTools.postwalk(s -> is_variant_symbol(s, v) ? type : s, f_args[i])
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

    idx_and_variant0 = collect(zip(idxs_mvtc, map(i -> transform_name(f_args_n[i]), idxs_mvtc)))
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

function dotted_arg(a)
    while true
        a isa Symbol && return a
        a.head == :. && a.args[1] isa Expr && a.args[1].head == Symbol("'") && return a
        a = a.args[1]
    end
end

function restructure_arg(a, i, idxs_mvtc)
    (!(i in idxs_mvtc) || a isa Symbol) && return a
    return MacroTools.postwalk(s -> s isa Expr && s.head == :. ? s.args[2].value : s, a)
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
    cache = mod.__pattern_cache__
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
    cache = mod.__pattern_cache__
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

"""
    @finalize_patterns

Calling `@finalize_patterns` is needed to define at some 
points all the functions `@pattern` constructed in that 
module.

If you don't need to call any of them before the functions 
are imported, you can just put a single invocation at the end of
the module. 
"""
macro finalize_patterns()
    quote
        defs = DynamicSumTypes.generate_defs($__module__)
        for (d, f_default) in defs
            if d in $__module__.__finalized_methods_cache__
                continue
            else
                !isdefined($__module__, f_default) && evaluate_func($__module__, :(function $f_default end))
                push!($__module__.__finalized_methods_cache__, d)
                $__module__.DynamicSumTypes.evaluate_func($__module__, d)
            end
        end
    end
end

function evaluate_func(mod, d)
    @eval mod $d
end


struct Uninitialized end
const uninit = Uninitialized()

"""
    @sum_structs [version] type_definition begin
        structs_definitions
    end

This macro allows to combine multiple types in a single one. 
The default version is `:on_fields` which has been built to yield 
a performance almost identical to having just one type. Using
`:on_types` consumes less memory at the cost of being a bit slower.

## Example

```julia
julia> @sum_structs AB begin
           struct A x::Int end
           struct B y::Int end
       end

julia> a = AB'.A(1)
AB'.A(1)

julia> a.x
1
```

"""
macro sum_structs(new_type, struct_defs)
    @warn "@sum_structs is deprecated in v3 in favour of a much simpler methodology using @sumtype.
           Please update your package to use that."
    vtc = get!(__variants_types_cache__, __module__, Dict{Any, Any}())
    vtwpc = get!(__variants_types_with_params_cache__, __module__, Dict{Any, Vector{Any}}())
    return esc(_compact_structs(new_type, struct_defs, vtc, vtwpc))
end

function _compact_structs(new_type, struct_defs, vtc, vtwpc)
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
        return error("`@sum_structs :on_fields` does not accept mixing mutable and immutable structs.")
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

    types_each_vis = types_each
    types_each = [t isa Symbol ? Symbol("###", namify(new_type), "###", t) : 
                                 :($(Symbol("###", namify(new_type), "###", t.args[1])){$(t.args[2:end]...)})
                  for t in types_each]

    expr_comp_types = [Expr(:struct, false, t, :(begin sdfnsdfsdfak() = 1 end)) for t in types_each]
    type_name = new_type isa Symbol ? new_type : new_type.args[1]

    type_no_constr = MacroTools.postwalk(s -> s isa Expr && s.head == :(<:) ? s.args[1] : s, new_type)
    type_params = new_type isa Symbol ? [] : [x isa Expr && x.head == :(<:) ? x.args[1] : x for x in new_type.args[2:end]]
    uninit_val = :(DynamicSumTypes.Uninitialized)
    compact_t = MacroTools.postwalk(s -> s isa Expr && s.head == :(<:) ? make_union_uninit(s, type_name, uninit_val) : s, new_type)
    
    expr_new_type = Expr(:struct, is_mutable, :($compact_t <: $abstract_type),
                         :(begin 
                            $field_type
                            $(all_fields_transf...)
                          end))

    expr_params_each = []
    expr_functions = []
    for (struct_t, kind_t, struct_f, struct_d, is_kw) in zip(types_each, types_each_vis, fields_each, default_each, is_kws)
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
        type = Symbol(string(namify(kind_t)))
        f_inside_args = all_fields_n

        conv_maybe = [x isa Symbol ? :() : x.args[2] for x in retrieve_fields_names(all_fields, true)]
        f_inside_args_no_t = maybe_convert_fields(conv_maybe, f_inside_args, new_type_p, struct_spec_n)
        f_inside_args2_no_t = maybe_convert_fields(conv_maybe, f_inside_args, new_type_p, struct_spec_n; with_params=true)
        f_inside_args = [Expr(:quote, type), f_inside_args_no_t...]
        f_inside_args2 = [Expr(:quote, type), f_inside_args2_no_t...]

        @capture(struct_t, struct_t_n_{struct_t_p__})
        struct_t_p === nothing && (struct_t_p = [])
        struct_t_p_no_sup = [p isa Expr && p.head == :(<:) ? p.args[1] : p for p in struct_t_p]
        struct_t_arg = struct_t_p_no_sup != [] ? :($struct_t_n{$(struct_t_p_no_sup...)}) : struct_t
        new_type_p = [t in struct_t_p_no_sup ? t : (:(DynamicSumTypes.Uninitialized)) 
                      for t in new_type_p]

        expr_function_kwargs = :()
        expr_function_kwargs2 = :()
        expr_function_args = :()
        expr_function_args2 = :()

        struct_t_p_in = [p for p in struct_t_p if any(x -> inexpr(x, p isa Expr && p.head == :(<:) ? p.args[1] : p), f_params_args_with_T)]
        struct_t_p_in_no_sup = [p isa Expr && p.head == :(<:) ? p.args[1] : p for p in struct_t_p_in]
        new_type_p_in = [t in struct_t_p_in_no_sup ? t : (:(DynamicSumTypes.Uninitialized)) 
                         for t in new_type_p]

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
                    function $(namify(struct_t))($(f_params_args_with_T...)) where {$(struct_t_p_in...)}
                        return $new_type_n{$(new_type_p_in...)}($(f_inside_args...))
                    end)
            if !isempty(struct_t_p)
                expr_function_args2 = :(function $(struct_t_arg)($(f_params_args...)) where {$(struct_t_p...)}
                                            return $new_type_n{$(new_type_p...)}($(f_inside_args2...))
                                        end)
            end
            if is_kw
                expr_function_kwargs = :(
                    function $(namify(struct_t))($f_params_kwargs_with_T) where {$(struct_t_p_in...)}
                        return $new_type_n{$(new_type_p_in...)}($(f_inside_args...))
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

    add_types_to_cache(type_name, types_each_vis, vtc)
    add_types_params_to_cache(expr_params_each, types_each_vis, type_name, vtwpc)

    expr_kindof = :(DynamicSumTypes.kindof(a::$(namify(new_type))) = getfield(a, $(Expr(:quote, gensym_type))))

    expr_allkinds = []
    expr_allkinds1 = :(DynamicSumTypes.allkinds(a::Type{$(namify(new_type))}) = $(Tuple(namify.(types_each_vis))))
    push!(expr_allkinds, expr_allkinds1)
    if namify(type_no_constr) !== type_no_constr
        expr_allkinds2 = :(DynamicSumTypes.allkinds(a::Type{$type_no_constr} where {$(type_params...)}) = $(Tuple(namify.(types_each_vis))))
        push!(expr_allkinds, expr_allkinds2)
    end

    branching_constructor = generate_branching_types(namify.(types_each_vis), [:(return $v) for v in namify.(types_each)])
    expr_constructor = :(function DynamicSumTypes.variant_constructor(a::$(namify(new_type)))
                        kind = kindof(a)

                        $(branching_constructor...)
                     end)

    expr_show = :(function Base.show(io::IO, a::$(namify(new_type)))
                      f_vals = [getfield(a, x) for x in fieldnames(typeof(a))[2:end] if getfield(a, x) != DynamicSumTypes.uninit]
                      vals = join([DynamicSumTypes.print_transform(x) for x in f_vals], ", ")
                      params = [x for x in typeof(a).parameters if x != DynamicSumTypes.Uninitialized] 
                      if isempty(params)
                          print(io, $(namify(new_type)), "'.", string(kindof(a)), "($vals)")
                      else
                          print(io, $(namify(new_type)), "'.", string(kindof(a), "{", join(params, ", "), "}"), "($vals)")
                      end
                  end
                  )

    expr_getprop = :(function Base.getproperty(a::$(namify(new_type)), s::Symbol)
                        f = getfield(a, s)
                        if f isa DynamicSumTypes.Uninitialized
                            return error(lazy"type $(kindof(a)) has no field $s")
                        end
                        return f
                     end)

    if is_mutable
        expr_setprop = :(function Base.setproperty!(a::$(namify(new_type)), s::Symbol, v)
                            f = getfield(a, s)
                            if f isa DynamicSumTypes.Uninitialized
                                return error(lazy"type $(kindof(a)) has no field $s")
                            end
                            setfield!(a, s, v)
                         end)
    else
        expr_setprop = :()
    end

    fields_each_symbol = [:(return $(Tuple(f))) for f in retrieve_fields_names.(fields_each)]
    branching_propnames = generate_branching_types(namify.(types_each_vis), fields_each_symbol)
    expr_propnames = :(function Base.propertynames(a::$(namify(new_type)))
                           kind = kindof(a)
                           $(branching_propnames...)
                           $(fields_each_symbol[end])
                       end)

    expr_copy = :(function Base.copy(a::$(namify(new_type)))
                      A = typeof(a)
                      return A((getfield(a, x) for x in fieldnames(A))...)
                  end)

    expr_adjoint = :(Base.adjoint(::Type{<:$(namify(new_type))}) =
            $NamedTuple{$(Expr(:tuple, QuoteNode.(namify.(types_each_vis))...))}($(Expr(:tuple, namify.(types_each)...))))

    fake_prints = [:($Base.show(io::IO, ::MIME"text/plain", T::Type{<:$(namify(fn))}) = print(io, $(string(namify(new_type), "'.", namify(v))))) 
                   for (fn, v) in zip(types_each, types_each_vis)]

    expr_exports = def_export_variants(new_type)

    expr = quote 
            $(expr_comp_types...)
            $(fake_prints...)
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
            $(expr_adjoint)
            $(expr_exports)
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
            new_f = :(DynamicSumTypes.uninit)
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
            f = :($name::Union{DynamicSumTypes.Uninitialized, $T})
            if const_x
                f = Expr(:const, f)
            end
            return f
        else
            return x
        end
    end
end

function add_types_to_cache(type, variants, vtc)
    type = namify(type)
    variants = namify.(variants)
    for v in variants
        vtc[:(($type)'.$v)] = type
    end
end

function add_types_params_to_cache(params, variants, type, vtwpc)
    type = namify(type)
    variants_n = namify.(variants)
    for (v1, v2, p) in zip(variants, variants_n, params)
        vtwpc[:(($type)'.$v2)] = [v1, p]
    end
end

function def_export_variants(type)
    t = namify(type)
    return quote
            function DynamicSumTypes.export_variants(T::Type{<:$t})
                Ts = $(QuoteNode(t))
                vtc = DynamicSumTypes.__variants_types_cache__[@__MODULE__]
                vtwpc = DynamicSumTypes.__variants_types_with_params_cache__[@__MODULE__]
                for V in allkinds(T)
                    eval(:(const $V = ($(Ts))'.$V))
                    for k in collect(keys(vtc))
                        b = DynamicSumTypes.MacroTools.inexpr(k, :(($Ts)'))
                        b == true && (vtc[V] = vtc[k])
                    end
                    for k in collect(keys(vtwpc))
                        b = DynamicSumTypes.MacroTools.inexpr(k, :(($Ts)'))
                        b == true && (vtwpc[k.args[2].value] = vtwpc[k])
                    end
                end  
            end      
    end
end

macro sum_structs(version, type, struct_defs)
    return esc(:(DynamicSumTypes.@sum_structs $type $struct_defs))
end

function print_transform(x)
    x isa String && return "\"$x\""
    x isa Symbol && return QuoteNode(x)
    return x
end

function make_union_uninit(s, type_name, uninit_val)
    s.args[1] == type_name && return s
    s.args[2] = :(Union{$(s.args[2]), $uninit_val})
    return s
end
