
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
        _sumtype(:(S(C)))
        _sumtype(:(S{X}(A{X},C)))
        _sumtype(:(S{X}(A{X},B{Int},C) <: AbstractS))
    end
end
