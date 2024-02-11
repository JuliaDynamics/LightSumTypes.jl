
module MixedStructTypes

using ExprTools
using MacroTools
using SumTypes

export @sum_structs
export @compact_structs
export kindof

function kindof end
function constructor end

include("SumStructs.jl")
include("CompactStructs.jl")
include("precompile.jl")

end
