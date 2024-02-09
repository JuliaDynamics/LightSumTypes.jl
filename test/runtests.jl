
using Test
using MixedStructTypes

@testset "MixedStructTypes.jl Tests" begin
    include("sum_structs_macro_tests.jl")
    include("compact_structs_macro_tests.jl")
end

