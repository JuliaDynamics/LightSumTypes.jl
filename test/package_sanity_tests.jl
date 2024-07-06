
using Aqua

@testset "Code quality" begin
    Aqua.test_all(DynamicSumTypes, ambiguities = true, unbound_args = true)
end
