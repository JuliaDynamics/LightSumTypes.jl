using Documenter
using DynamicSumTypes

println("Documentation Build")
makedocs(
    modules = [DynamicSumTypes],
    sitename = "DynamicSumTypes.jl",
    pages = [    
        "API" => "index.md",
    ],
)

@info "Deploying Documentation"
CI = get(ENV, "CI", nothing) == "true" || get(ENV, "GITHUB_TOKEN", nothing) !== nothing
if CI
    deploydocs(
        repo = "github.com/JuliaDynamics/DynamicSumTypes.jl.git",
        target = "build",
        push_preview = true,
        devbranch = "main",
    )
end
println("Finished boulding and deploying docs.")
