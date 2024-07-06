
using Test
using DynamicSumTypes

@testset "DynamicSumTypes.jl Tests" begin
    include("package_sanity_tests.jl")
    include("sumtype_macro_tests.jl")
end
