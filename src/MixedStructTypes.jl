
module MixedStructTypes

using ExprTools
using MacroTools
using SumTypes

export @sum_structs
export @compact_structs
export kindof, allkinds

function kindof end
function allkinds end
function constructor end

include("SumStructs.jl")
include("CompactStructs.jl")
include("precompile.jl")

end
