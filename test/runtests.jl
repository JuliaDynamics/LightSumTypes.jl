
using Test
using DynamicSumTypes

@testset "DynamicSumTypes.jl Tests" begin
    include("package_sanity_tests.jl")
    include("sum_structs_memory_macro_tests.jl")
    include("sum_structs_speed_macro_tests.jl")
    include("pattern_macro_tests.jl")
end

