
module MixedStructTypes

using MacroTools
using SumTypes

export SumTypes
export @lazy

export @sum_struct_type
export @compact_struct_type

include("SumStructTypes.jl")
include("CompactStructTypes.jl")
#include("precompile.jl")

end