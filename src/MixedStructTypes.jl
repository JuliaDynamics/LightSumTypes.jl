
module MixedStructTypes

using ExprTools
using MacroTools
using SumTypes

export @sum_struct_type
export @compact_struct_type
export kindof

include("SumStructTypes.jl")
include("CompactStructTypes.jl")

end
