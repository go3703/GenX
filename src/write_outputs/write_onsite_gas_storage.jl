@doc raw"""
    write_onsite_gas_storage(path::AbstractString, inputs::Dict, setup::Dict, EP::Model)

Writes the onsite gas storage data of the optimization model to CSV files.

## Description
This function extracts and writes data related to onsite gas storage from an energy production model `EP` to CSV files. It handles data such as built storage capacities, hourly charges, discharges, and states of charge for gas plants.

## Arguments
- `path::AbstractString`: The file path where the CSV files will be saved.
- `inputs::Dict`: A dictionary containing input data required for the function, including:
  - `dfGen`: Dataframe with generators data.
  - `T`: Number of time steps.
  - `G`: Gas plants identifiers.
  - `RESOURCES`: Resource identifiers.
  - Other necessary inputs.
- `setup::Dict`: A dictionary containing setup configurations (not directly used in this function).
- `EP::Model`: The energy production optimization model containing gas storage data.

## Output
Creates and saves four CSV files at the specified `path`:
- `built_gas_storage_capacities.csv`: Contains built storage capacities for each resource.
- `hourly_gas_storage_charges.csv`: Contains hourly gas storage charges for each resource.
- `hourly_gas_storage_discharges.csv`: Contains hourly gas storage discharges for each resource.
- `hourly_gas_storage_states_of_charge.csv`: Contains hourly states of charge for each resource.

## Example
```julia
write_onsite_gas_storage("path/to/directory", inputDict, setupDict, energyModel)

"""

function write_onsite_gas_storage(path::AbstractString, inputs::Dict,setup::Dict, EP::Model)

	dfGen = inputs["dfGen"]
	T = inputs["T"]  
	G = inputs["G"]
	GAS_PLANTS = intersect(inputs["THERM_COMMIT"], inputs["RSV"])

	# Building DataFrame for built gas storage capacities
	built_gas_storage_capacities = DataFrame(Resource = inputs["RESOURCES"][GAS_PLANTS], Built_Storage_CAP = value.(EP[:vStorageCap][GAS_PLANTS]).data)

	# Building DataFrame for hourly gas storage charges
	hourly_gas_storage_charges = DataFrame(transpose(value.(EP[:vStorageCharge]).data), inputs["RESOURCES"][GAS_PLANTS])
	insertcols!(hourly_gas_storage_charges, 1, :Time_index => 1:T)

	# Building DataFrame for hourly gas storage discharges
	hourly_gas_storage_discharges = DataFrame(transpose(value.(EP[:vStorageDischarge]).data), inputs["RESOURCES"][GAS_PLANTS])
	insertcols!(hourly_gas_storage_discharges, 1, :Time_index => 1:T)

	# Building DataFrame for hourly gas storage states of charge
	hourly_gas_storage_states_of_charge = DataFrame(transpose(value.(EP[:vStateOfStorage]).data), inputs["RESOURCES"][GAS_PLANTS])
	insertcols!(hourly_gas_storage_states_of_charge, 1, :Time_index => 1:T)

	# Writing DataFrames to CSV files at the specified path
	CSV.write(joinpath(path, "built_gas_storage_capacities.csv"), built_gas_storage_capacities)
	CSV.write(joinpath(path, "hourly_gas_storage_charges.csv"), hourly_gas_storage_charges)
	CSV.write(joinpath(path, "hourly_gas_storage_discharges.csv"), hourly_gas_storage_discharges)
	CSV.write(joinpath(path, "hourly_gas_storage_states_of_charge.csv"), hourly_gas_storage_states_of_charge)

end
