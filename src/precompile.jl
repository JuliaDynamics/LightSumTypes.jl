
using PrecompileTools

@setup_workload begin
    @compile_workload let
        vtc = Dict{Symbol, Symbol}()
        vtwpc = Dict{Symbol, Vector{Any}}()
        type = :(E{X<:Real,Y<:Real} <: AbstractE{X,Y})
        struct_defs = :(begin
                            @kwdef mutable struct F{X<:Int}
                                a::Tuple{X, X}
                                b::Tuple{Float64, Float64}
                                const c::Symbol
                            end
                            @kwdef mutable struct G{X}
                                a::Tuple{X, X}
                                d::Int32
                                e::Bool
                                const c::Symbol
                            end
                            @kwdef mutable struct H{X,Y<:Real}
                                a::Tuple{X, X}
                                f::Y
                                g::Tuple{Complex, Complex}
                                const c::Symbol
                            end
                        end)
        _compact_structs(type, struct_defs, vtc, vtwpc)
        _sum_structs(type, struct_defs, vtc, vtwpc)
        type = :(Animal{T,N,J})
        struct_defs = :(begin
                            @kwdef mutable struct Wolf{T,N}
                                energy::T = 0.5
                                ground_speed::N
                                const fur_color::Symbol
                            end
                            @kwdef mutable struct Hawk{T,N,J}
                                energy::T = 0.1
                                ground_speed::N
                                flight_speed::J
                            end
                        end)
        _compact_structs(type, struct_defs, vtc, vtwpc)
        _sum_structs(type, struct_defs, vtc, vtwpc)
        type = :(Simple2 <: AbstractSimple2)
        struct_defs = :(begin
                            struct SimpleA2
                                x
                                z::Int
                            end
                            struct SimpleB2
                                y
                                q::String
                            end
                        end)
        _compact_structs(type, struct_defs, vtc, vtwpc)
        _sum_structs(type, struct_defs, vtc, vtwpc)
        type = :(TestOrder2)
        struct_defs = :(begin
                            struct TestOrder21
                                x::String
                                y::Float64
                            end
                            struct TestOrder22
                                y::Float64
                                z::Vector{Int}
                                x::String
                            end
                        end)
        _compact_structs(type, struct_defs, vtc, vtwpc)
        _sum_structs(type, struct_defs, vtc, vtwpc)
        type = :(AA{T})
        struct_defs = :(begin
                            @kwdef mutable struct BB{T}
                                id::Int
                                a::T = 1
                                b::Int
                                c::Symbol
                            end
                            @kwdef mutable struct CC
                                id::Int
                                b::Int = 2
                                c::Symbol
                                d::Vector{Int}
                            end
                            @kwdef mutable struct DD{T}
                                id::Int
                                c::Symbol = :k
                                d::Vector{Int}
                                a::T
                            end
                        end)

        f0 = :(f(x::Int, y, z::AA, ::AA) = 3)
        f1 = :(f(x::Int, y, z::BB, ::CC) = 3)
        f2 = :(f(x::Int, y, z::DD, ::CC) = 3)
        f3 = :(f(x::Int, y, z::Hawk{Int, N, J} where N, ::CC; s = 1) where J = 3)

        _compact_structs(type, struct_defs, vtc, vtwpc)
        _sum_structs(type, struct_defs, vtc, vtwpc)
        _dispatch(f0, vtc, vtwpc)
        _dispatch(f1, vtc, vtwpc)
        _dispatch(f2, vtc, vtwpc)
        f_sub, f_super_dict, f_cache = _dispatch(f3, vtc, vtwpc)
        cache = Dict{Symbol, Any}()
        cache[:f] = Dict{Any, Any}(f_cache => [f_super_dict])
        generate_defs(parentmodule(@__MODULE__), cache)
    end
end
