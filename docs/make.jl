using Documenter
using LightSumTypes

println("Documentation Build")
makedocs(
    modules = [LightSumTypes],
    sitename = "LightSumTypes.jl",
    warnonly = [:doctest, :missing_docs, :cross_references],
    pages = [    
        "API" => "index.md",
    ],
)

@info "Deploying Documentation"
CI = get(ENV, "CI", nothing) == "true" || get(ENV, "GITHUB_TOKEN", nothing) !== nothing
if CI
    deploydocs(
        repo = "github.com/JuliaDynamics/LightSumTypes.jl.git",
        target = "build",
        push_preview = true,
        devbranch = "main",
    )
end
println("Finished boulding and deploying docs.")
