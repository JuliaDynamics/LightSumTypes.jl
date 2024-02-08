
using Test
using MixedStructTypes

@testset "MixedStructTypes.jl Tests" begin
    include("test_sum_struct_type.jl")
    include("test_compact_struct_type.jl")
end
