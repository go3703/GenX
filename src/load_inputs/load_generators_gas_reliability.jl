@doc raw"""
	load_generators_gas_reliability!(setup::Dict, path::AbstractString, inputs::Dict)

"""
function load_generators_gas_reliability!(setup::Dict, path::AbstractString, inputs::Dict)
	
    filename = "Generators_gas_reliability.csv"
    gen_gas_rel = load_dataframe(joinpath(path, filename))

    #Hourly gas reliability factors for thermal units
    inputs["g_GR"] = transpose(Matrix{Float64}(gen_gas_rel[1:inputs["T"],2:(inputs["G"]+1)]))

	println(filename * " Successfully Read!")

end

