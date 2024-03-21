# MixedStructTypes.jl

[![CI](https://github.com/JuliaDynamics/MixedStructTypes.jl/workflows/CI/badge.svg)](https://github.com/JuliaDynamics/MixedStructTypes.jl/actions?query=workflow%3ACI)
[![](https://img.shields.io/badge/docs-dev-blue.svg)](https://juliadynamics.github.io/MixedStructTypes.jl/stable/)
[![codecov](https://codecov.io/gh/JuliaDynamics/MixedStructTypes.jl/graph/badge.svg?token=rz9b1WTqCa)](https://codecov.io/gh/JuliaDynamics/MixedStructTypes.jl)
[![Aqua QA](https://raw.githubusercontent.com/JuliaTesting/Aqua.jl/master/badge.svg)](https://github.com/JuliaTesting/Aqua.jl)

This package allows to combine multiple heterogeneous types in a single one. This helps to write type-stable code
by avoiding Union-splitting, which have big performance drawbacks when many types are unionized.

More information can be found in the [documentation](https://juliadynamics.github.io/MixedStructTypes.jl/stable/).
