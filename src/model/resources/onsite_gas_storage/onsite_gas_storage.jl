function onsite_gas_storage!(EP::Model, inputs::Dict, setup::Dict)

	println("Onsite Gas Storage Module")

	dfGen = inputs["dfGen"]

	T = inputs["T"]     # Number of time steps (hours)
	Z = inputs["Z"]     # Number of zones

	p = inputs["hours_per_subperiod"] 	# total number of hours per subperiod

	GAS_PLANTS = inputs["THERM_ALL"]	# Set of all gas fired power plants
	
    # Heat rate of all resources (million BTUs/MWh)
	heat_rate = convert(Array{Float64}, inputs["dfGen"][!,:Heat_Rate_MMBTU_per_MWh])
	
	println("top safe")
	### Variables ###

	@variables(EP, begin
			vStorageCap[y in GAS_PLANTS] >= 0 # Capacity of storage required by gas fired resource "y" in MMBtu
			vStorageCharge[y in GAS_PLANTS, t in 1:T] >=0 # Amount of gas purchased and stored by resource "y" in hour "t", in MMBtu
			vStorageDischarge[y in GAS_PLANTS, t in 1:T] >=0 # Amount of gas discharged from storage by resource "y" in hour "t", in MMBtu
			vStateOfStorage[y in GAS_PLANTS, t in 1:T] >=0 # Amount of gas in on-site storage of resource "y" in hour "t", in MMBtu

	end);

	println("variables safe")

	### Expressions ###

	## Objective Function Expressions ##
	
	# Fixed costs of "on-site gas storage" for resource "y" 

	if setup["CNGStorage"] == 1
		@expression(EP, eCStorage_fixed[y in GAS_PLANTS], dfGen[y,:Fixed_CNG_Storage_Cost_per_MMBTUyr]*vStorageCap[y] + dfGen[y,:Fixed_CNG_Compressor_Cost_per_yr])
	end
	
	if setup["OilStorage"] == 1
		@expression(EP, eCStorage_fixed[y in GAS_PLANTS], dfGen[y,:Fixed_Oil_Storage_Cost_per_MMBTUyr]*vStorageCap[y] + dfGen[y,:Fixed_Dual_Oil_Combustor_Cost_per_MWyr]*EP[:vCAP][y])
	end

	if setup["HydrogenStorage"] == 1
		@expression(EP, eCStorage_fixed[y in GAS_PLANTS], dfGen[y,:Fixed_Hydrogen_Storage_Cost_per_MMBTUyr]*vStorageCap[y] + dfGen[y,:Fixed_Dual_Hydrogen_Combustor_Cost_per_MWyr]*EP[:vCAP][y])
	end

	# Sum individual resource contributions to fixed costs to get total on-site storage fixed costs
	@expression(EP, eTotalCStorage_fixed, sum(eCStorage_fixed[y] for y in GAS_PLANTS))
	
	
	
	# Add total fixed on-site storage cost contribution to the objective function
	EP[:eObj] += eTotalCStorage_fixed
    
	
	
	# Variable charging costs of "on-site storage" for resource "y" during hour "t" = fuel cost
	@expression(EP, eCStorage_var[y in GAS_PLANTS,t=1:T], (inputs["C_Fuel_per_MWh"][y,t]/heat_rate[y])*vStorageCharge[y,t]*inputs["omega"][t])
	

	# Sum individual resource contributions to variable charging costs to get total variable charging costs
	@expression(EP, eTotalCStorage_var, sum(eCStorage_var[y,t] for y in GAS_PLANTS for t in 1:T))
	

	# Add total variable discharging cost contribution to the objective function
	EP[:eObj] += eTotalCStorage_var

	println("expressions safe")
	### Constratints ###

	### Constraints commmon to all on-site storage of resource y (y in set GAS_PLANTS) ###
	@constraints(EP, begin


		# State of storage constraint 
		cStateOfStorage[y in GAS_PLANTS, t in 1:T], vStateOfStorage[y,t] == vStateOfStorage[y, hoursbefore(p,t,1)] + vStorageCharge[y,t] - vStorageDischarge[y,t]

	end)
	
		# #End State of Storage
		# cStateOfStorageEnd[y in GAS_PLANTS], vStateOfStorage[y,T]==0

	println("first 1 constraint safe")


	@constraints(EP, begin
		# Storage Discharge Constraint
        cStorageDischarge[y in GAS_PLANTS, t in 1:T], vStorageDischarge[y,t] == (1-inputs["g_GR"][y,t])*EP[:vP][y,t]*heat_rate[y]
	
		# Minimum State of Storage
		cStateOfStorageMin[y in GAS_PLANTS, t in 1:T], vStateOfStorage[y,t] >= vStorageDischarge[y,t] + EP[:vRSV][y,t]

		# Maximum State of Storage
		cStateOfStorageMax[y in GAS_PLANTS, t in 1:T], vStateOfStorage[y,t] <= vStorageCap[y]
	
		#Maximum Storage Charge rate
		cStorageChargeMax[y in GAS_PLANTS, t in 1:T], vStorageCharge[y,t] <= dfGen[y,:CNG_Storage_Max_Charge_Rate_MMBtu_per_hr]*inputs["g_GR"][y,t]
	
		#Gas conver
		# # Big-M Storage Charge Constraint
		# cStorageChargeBM[y in GAS_PLANTS, t in 1:T], vStorageCharge[y,t] <= *100000 
	end)

	println("constraints safe")
	println("Successfully read onsite_gas_storage module")
end
	