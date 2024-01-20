
module MixedStructTypes

using LazilyInitializedFields
using MacroTools
using SumTypes

export SumTypes
export @lazy

export @sum_struct_type
export @compact_struct_type

include("SumStructTypes.jl")
include("CompactStructTypes.jl")

end