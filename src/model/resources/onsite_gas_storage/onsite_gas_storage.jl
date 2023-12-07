function onsite_gas_storage!(EP::Model, inputs::Dict, setup::Dict)

	println("Onsite Gas Storage Module")

	dfGen = inputs["dfGen"]

	T = inputs["T"]     # Number of time steps (hours)
	Z = inputs["Z"]     # Number of zones

	p = inputs["hours_per_subperiod"] 	# total number of hours per subperiod

	GAS_PLANTS = inputs["THERM_ALL"]	# Set of all gas fired power plants
	
    # Heat rate of all resources (million BTUs/MWh)
	heat_rate = convert(Array{Float64}, inputs["dfGen"][!,:Heat_Rate_MMBTU_per_MWh])
	

	### Variables ###

	@variables(EP, begin
			vStorageCap[y in GAS_PLANTS] >= 0 # Capacity of storage required by gas fired resource "y" in MMBtu
			vStorageCharge[y in GAS_PLANTS, t in 1:T] >=0 # Amount of gas purchased and stored by resource "y" in hour "t", in MMBtu
			vStorageDischarge[y in GAS_PLANTS, t in 1:T] >=0 # Amount of gas discharged from storage by resource "y" in hour "t", in MMBtu
			vStateOfStorage[y in GAS_PLANTS, t in 1:T] >=0 # Amount of gas in on-site storage of resource "y" in hour "t", in MMBtu

	end);

	
	

	### Expressions ###

	## Objective Function Expressions ##
	#println(dfGen[1,:Fixed_StorCost_per_MMBTUyr])
	# Fixed costs of "on-site storage" for resource "y" 
	@expression(EP, eCStorage_fixed[y in GAS_PLANTS], dfGen[y,:Fixed_StorCost_per_MMBTUyr]*vStorageCap[y])
	
	

	# Sum individual resource contributions to fixed costs to get total on-site storage fixed costs
	@expression(EP, eTotalCStorage_fixed, sum(eCStorage_fixed[y] for y in GAS_PLANTS))
	
	
	
	# Add total fixed on-site storage cost contribution to the objective function
	EP[:eObj] += eTotalCStorage_fixed
    
	
	
	# Variable charging costs of "on-site storage" for resource "y" during hour "t" = fuel cost
	@expression(EP, eCStorage_var[y in GAS_PLANTS,t=1:T], inputs["fuel_costs"]["NG"][t]*vStorageCharge[y,t])
	println("StorageExpression 1")
	# Sum individual resource contributions to variable charging costs to get total variable charging costs
	@expression(EP, eTotalCStorage_var, sum(eCStorage_var[y,t] for y in GAS_PLANTS for t in 1:T))
	println("StorageExpression 2")
	# Add total variable discharging cost contribution to the objective function
	EP[:eObj] += eTotalCStorage_var

	println("StorageExpression 3")

	println("No issues with expressions")

	### Constratints ###

	### Constraints commmon to all on-site storage of resource y (y in set GAS_PLANTS) ###
	@constraints(EP, begin
	
		# State of storage constraint
		cStateOfStorage[y in GAS_PLANTS, t in 1:T], vStateOfStorage[y,t] == (vStateOfStorage[y, hoursbefore(p,t,1)]
				+ vStorageCharge[y,t] - vStorageDischarge[y,t])

		# Storage Discharge Constraint
        cStorageDischarge[y in GAS_PLANTS, t in 1:T], vStorageDischarge[y,t] == (1-inputs["g_GR"][y,t])*EP[:vP][y,t]*heat_rate[y]

		# Minimum State of Storage
		cStateOfStorageMin[y in GAS_PLANTS, t in 1:T], vStateOfStorage[y,t] >= vStorageDischarge[y,t] + EP[:vRSV][y,t]

		# + EP[:vRSV][y,t]

		# Big-M Storage Charge Constraint
		cStorageChargeBM[y in GAS_PLANTS, t in 1:T], vStorageCharge[y,t] <= inputs["g_GR"][y,t]*vStorageCap[y] 


	end)
	println("No issues with constraints")
	println("Successfully read")
end
	