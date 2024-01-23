
module MixedStructTypes

using ExprTools
using MacroTools
using SumTypes

export @sum_struct_type
export @compact_struct_type

include("SumStructTypes.jl")
include("CompactStructTypes.jl")

end
