@doc raw"""
	write_storage(path::AbstractString, inputs::Dict,setup::Dict, EP::Model)

Function for writing the capacities of different storage technologies, including hydro reservoir, flexible storage tech etc.
"""
function write_onsite_gas_storage(path::AbstractString, inputs::Dict,setup::Dict, EP::Model)
	dfGen = inputs["dfGen"]
	T = inputs["T"]     # Number of time steps (hours)
	G = inputs["G"]
	GAS_PLANTS = inputs["THERM_ALL"]
	
	built_gas_storage_capacities = DataFrame(Resource = inputs["RESOURCES"][GAS_PLANTS], Built_Storage_CAP = value.(EP[:vStorageCap][GAS_PLANTS]).data)
	println("built_gas_storage_capacities pass")
	hourly_gas_storage_charges = DataFrame(transpose(value.(EP[:vStorageCharge]).data), inputs["RESOURCES"][GAS_PLANTS])
	println("hourly_gas_storage_charges pass")
	hourly_gas_storage_discharges = DataFrame(transpose(value.(EP[:vStorageDischarge]).data), inputs["RESOURCES"][GAS_PLANTS])
	println("hourly_gas_storage_discharges pass")
	hourly_gas_storage_states_of_charge = DataFrame(transpose(value.(EP[:vStateOfStorage]).data), inputs["RESOURCES"][GAS_PLANTS])
	println("hourly_gas_storage_states_of_charge pass")

	CSV.write(joinpath(path, "built_gas_storage_capacities.csv"), built_gas_storage_capacities)
	CSV.write(joinpath(path, "hourly_gas_storage_charges.csv"), hourly_gas_storage_charges)
	CSV.write(joinpath(path, "hourly_gas_storage_discharges.csv"), hourly_gas_storage_discharges)
	CSV.write(joinpath(path, "hourly_gas_storage_states_of_charge.csv"), hourly_gas_storage_states_of_charge)

end
