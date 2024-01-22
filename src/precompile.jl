using PrecompileTools

@setup_workload begin
    @compile_workload begin

       	@compact_struct_type @kwdef E{X} begin
            mutable struct F{X}
                a::Tuple{X, X} = (1,1)
                b::Tuple{Float64, Float64} = (1.0, 1.0)
                const c::Symbol = :s
            end
            mutable struct G{X}
                a::Tuple{X, X} = (1,1)
                const c::Symbol = :q
                d::Int32 = Int32(2)
                e::Bool = false
            end
            mutable struct H{X}
                a::Tuple{X, X} = (1,1)
                const c::Symbol = :s
                f::Char = 'p'
                g::Tuple{Complex, Complex} = (im, im)
            end
       	end

	f = F((1,1), (1.0, 1.0), :s)
	f.a
	f.a = (3, 3)
    end
end
