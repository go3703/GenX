"""
    onsite_gas_storage!(EP::Model, inputs::Dict, setup::Dict)

Integrates an onsite gas storage module into the optimization model 'EP'.

## Description
This function adds variables, expressions, and constraints related to onsite gas storage to the energy production model `EP`. It utilizes input data and configuration parameters from `inputs` and `setup` dictionaries.

## Arguments
- `EP::Model`: The optimization model to which the onsite gas storage functionality is added.
- `inputs::Dict`: A dictionary containing input data such as:
  - `dfGen`: Dataframe with generators data.
  - `T`: Number of time steps (hours).
  - `Z`: Number of zones.
  - `hours_per_subperiod`: Total number of hours per subperiod.
  - Other required parameters for gas, oil, and hydrogen storage calculation.
- `setup::Dict`: A dictionary containing setup configurations like the types of storage (`CNGStorage`, `OilStorage`, `HydrogenStorage`) and their associated flags.

## Functionality
- Defines variables for storage capacity, charge, discharge, and state of storage for each gas plant.
- Calculates fixed and variable costs associated with different types of gas storages (CNG, oil, hydrogen).
- Adds these costs to the objective function of the `EP` model.
- Imposes constraints for state of storage, discharge, minimum state of storage, maximum state of storage, and maximum charge rate depending on the type of storage and other model parameters.

## Output
- Modifies the `EP` model by adding new variables, constraints, and objective function components related to onsite gas storage.
- Prints confirmation upon successful integration of the module.

## Example
```julia
onsite_gas_storage!(energyModel, inputDict, setupDict)

"""

function onsite_gas_storage!(EP::Model, inputs::Dict, setup::Dict)
    println("Onsite Gas Storage Module")

    dfGen = inputs["dfGen"]  # Dataframe containing generators data
    T = inputs["T"]          # Number of time steps (hours)
    Z = inputs["Z"]          # Number of zones
    p = inputs["hours_per_subperiod"]  # Total number of hours per subperiod
    GAS_PLANTS = intersect(inputs["THERM_COMMIT"], inputs["RSV"])  # Set of all gas-fired power plants
    heat_rate = convert(Array{Float64}, inputs["dfGen"][!,:Heat_Rate_MMBTU_per_MWh])  # Heat rate of all resources (million BTUs/MWh)

    # Additional model variables for onsite gas storage
    @variables(EP, begin
        vStorageCap[y in GAS_PLANTS] >= 0         # Capacity of storage required by gas-fired resource "y" in MMBtu
        vStorageCharge[y in GAS_PLANTS, t in 1:T] >= 0  # Amount of gas purchased and stored by resource "y" in hour "t", in MMBtu
        vStorageDischarge[y in GAS_PLANTS, t in 1:T] >= 0  # Amount of gas/oil discharged from onsite storage of resource "y" in hour "t", in MMBtu
        vStateOfStorage[y in GAS_PLANTS, t in 1:T] >= 0  # Amount of gas in on-site storage of resource "y" in hour "t", in MMBtu
    end)

    # Model Expressions

    # Objective Function Expressions
    # Fixed costs of "on-site gas storage" for resource "y"
    if setup["CNGStorage"] == 1
        @expression(EP, eCStorage_fixed[y in GAS_PLANTS], (dfGen[y,:Fixed_CNG_Storage_Cost_per_MMBTUyr] + 1*dfGen[y,:Fixed_CNG_Compressor_Cost_per_MMBtuyr])*vStorageCap[y])
    end

    if setup["OilStorage"] == 1
        @expression(EP, eCStorage_fixed[y in GAS_PLANTS], dfGen[y,:Fixed_Oil_Storage_Cost_per_MMBTUyr]*vStorageCap[y] + 2938*EP[:vCAP][y])
    end

    if setup["HydrogenStorage"] == 1
        @expression(EP, eCStorage_fixed[y in GAS_PLANTS], (dfGen[y,:Fixed_Hydrogen_Storage_Cost_per_MMBTUyr] + 0*dfGen[y,:Fixed_Hydrogen_Compressor_Cost_per_MMBtuyr])*vStorageCap[y])
    end

    # Sum individual resource contributions to fixed costs to get total on-site storage fixed costs
    @expression(EP, eTotalCStorage_fixed, sum(eCStorage_fixed[y] for y in GAS_PLANTS))

    # Add total fixed on-site storage cost contribution to the objective function
    EP[:eObj] += eTotalCStorage_fixed

    # Variable charging costs of "on-site storage" for resource "y" during hour "t" = fuel cost
    if setup["CNGStorage"] == 1
        @expression(EP, eCStorage_var[y in GAS_PLANTS,t=1:T], (inputs["C_Fuel_per_MWh"][y,t]/heat_rate[y])*vStorageCharge[y,t]*inputs["omega"][t])
    end

    if setup["OilStorage"] == 1
        @expression(EP, eCStorage_var[y in GAS_PLANTS,t=1:T], dfGen[y,:Oil_Fuel_Cost_per_MMBtu]*vStorageCharge[y,t]*inputs["omega"][t])
    end

    if setup["HydrogenStorage"] == 1
        @expression(EP, eCStorage_var[y in GAS_PLANTS,t=1:T], dfGen[y,:Green_Hydrogen_Fuel_Cost_per_MMBtu]*vStorageCharge[y,t]*inputs["omega"][t])
    end

    # Sum individual resource contributions to variable charging costs to get total variable charging costs
    @expression(EP, eTotalCStorage_var, sum(eCStorage_var[y,t] for y in GAS_PLANTS for t in 1:T))

    # Add total variable discharging cost contribution to the objective function
    EP[:eObj] += eTotalCStorage_var

    # Constraints

    # Constraints common to all on-site storage resource y (y in set GAS_PLANTS)
    @constraints(EP, begin
        # State of storage constraint
        cStateOfStorage[y in GAS_PLANTS, t in 1:T], vStateOfStorage[y,t] == vStateOfStorage[y, hoursbefore(p,t,1)] + vStorageCharge[y,t] - vStorageDischarge[y,t]

        # Conditional storage discharge constraint (to ensure that discharge happens by resource y in hour t only when the hourly gas reliability factor g_GR is zero)
        cStorageDischarge[y in GAS_PLANTS, t in 1:T], vStorageDischarge[y,t] == (1-inputs["g_GR"][y,t])*EP[:vP][y,t]*heat_rate[y]

        # Minimum state of storage constraint (to meet both discharge and reserve requirements by each resource y in each hour t) 
        cStateOfStorageMin[y in GAS_PLANTS, t in 1:T], vStateOfStorage[y,t] >= vStorageDischarge[y,t] + EP[:vRSV][y,t]*heat_rate[y]

        # Maximum State of Storage constraint (to ensure the level of storage in each hour t by storage resource of y does not exceed the built storage capacity of y)
        cStateOfStorageMax[y in GAS_PLANTS, t in 1:T], vStateOfStorage[y,t] <= vStorageCap[y]
    end)

    # Maximum storage charge rate by resource y in each hour t
    if setup["CNGStorage"] == 1
		@constraints(EP, begin
        	cStorageChargeMax[y in GAS_PLANTS, t in 1:T], vStorageCharge[y,t] <= dfGen[y,:CNG_Storage_Max_Charge_Rate_MMBtu_per_hr]*inputs["g_GR"][y,t]
		end)
    end

    if setup["OilStorage"] == 1
		@constraints(EP, begin
        	cStorageChargeMax[y in GAS_PLANTS, t in 1:T], vStorageCharge[y,t] <= dfGen[y,:Oil_Storage_Max_Charge_Rate_MMBtu_per_hr]*inputs["g_GR"][y,t]
		end)
    end

    if setup["HydrogenStorage"] == 1
		@constraints(EP, begin
        	cStorageChargeMax[y in GAS_PLANTS, t in 1:T], vStorageCharge[y,t] <= dfGen[y,:Hydrogen_Storage_Max_Charge_Rate_MMBtu_per_hr]*inputs["g_GR"][y,t]
		end)
    end

    println("Successfully read onsite_gas_storage module")
end
