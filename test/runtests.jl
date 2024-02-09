
using Test
using MixedStructTypes

@testset "MixedStructTypes.jl Tests" begin
    include("sum_struct_type_macro_tests.jl")
    include("compact_struct_type_macro_tests.jl")
end

