
using PrecompileTools

@setup_workload begin
    @compile_workload let
        abstract type AbstractS end
        struct A{X}
            x::X
        end
        mutable struct B{Y}
            y::Y
        end
        struct C
            z::Int
        end
        sumtype_expr(:(S(C)))
        sumtype_expr(:(S{X}(A{X},C)))
        sumtype_expr(:(S{X}(A{X},B{Int},C) <: AbstractS))
    end
end
