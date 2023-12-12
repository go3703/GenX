@doc raw"""
	load_generators_gas_reliability!(setup::Dict, path::AbstractString, inputs::Dict)

"""
function load_generators_gas_reliability!(setup::Dict, path::AbstractString, inputs::Dict)
	
    data_directory = joinpath(path, setup["TimeDomainReductionFolder"])
    if setup["TimeDomainReduction"] == 1  && time_domain_reduced_files_exist(data_directory)
        my_dir = data_directory
	else
        my_dir = path
	end
    filename = "Generators_gas_reliability.csv"
    gen_gas_rel = load_dataframe(joinpath(my_dir, filename))

    #Hourly gas reliability factors for thermal units
    inputs["g_GR"] = transpose(Matrix{Float64}(gen_gas_rel[1:inputs["T"],2:(inputs["G"]+1)]))

	println(filename * " Successfully Read!")

end

