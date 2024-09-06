
using Test
using LightSumTypes

@testset "LightSumTypes.jl Tests" begin
    include("package_sanity_tests.jl")
    include("sumtype_macro_tests.jl")
end
