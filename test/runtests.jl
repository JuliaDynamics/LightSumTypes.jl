
using Test
using DynamicSumTypes

@testset "DynamicSumTypes.jl Tests" begin
    include("package_sanity_tests.jl")
    include("sum_structs_on_types_macro_tests.jl")
    include("sum_structs_on_fields_macro_tests.jl")
    include("pattern_macro_tests.jl")
end

