
using Test
using MixedStructTypes

@testset "MixedStructTypes.jl Tests" begin
    include("package_sanity_tests.jl")
    include("sum_structs_macro_tests.jl")
    include("compact_structs_macro_tests.jl")
    include("dispatch_macro_tests.jl")
end

