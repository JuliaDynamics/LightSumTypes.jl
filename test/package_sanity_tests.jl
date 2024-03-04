
using Aqua

@testset "Code quality" begin
    Aqua.test_all(MixedStructTypes, ambiguities = false, unbound_args = true)
    @test Test.detect_ambiguities(MixedStructTypes) == Tuple{Method, Method}[]
end
