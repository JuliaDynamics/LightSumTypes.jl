
using PrecompileTools

@setup_workload begin
    @compile_workload let
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
        _compact_structs(type, struct_defs)
        _sum_structs(type, struct_defs)
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
        _compact_structs(type, struct_defs)
        _sum_structs(type, struct_defs)
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
        _compact_structs(type, struct_defs)
        _sum_structs(type, struct_defs)
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
        _compact_structs(type, struct_defs)
        _sum_structs(type, struct_defs)
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

        _compact_structs(type, struct_defs)
        _sum_structs(type, struct_defs)
        _dispatch(f0)
        _dispatch(f1)
        _dispatch(f2)
        _dispatch(f3)
        generate_defs(Main, __dispatch_cache__)

        empty!(__variants_types_cache__)
        empty!(__variants_types_with_params_cache__)
        empty(__dispatch_cache__)
    end
end
