
using Aqua

@testset "Code quality" begin
    Aqua.test_all(DynamicSumTypes, ambiguities = false, unbound_args = true)
    @test Test.detect_ambiguities(DynamicSumTypes) == Tuple{Method, Method}[]
end
