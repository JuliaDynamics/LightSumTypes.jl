
using Aqua

@testset "Code quality" begin
    Aqua.test_all(LightSumTypes, ambiguities = true, unbound_args = true)
end
