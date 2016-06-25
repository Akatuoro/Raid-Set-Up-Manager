local addon, ns = ...

local maxgroups = ns.maxgroups
local maxmembers = ns.maxmembers
local roleOrder = {TANK = 1, MELEE = 2, DAMAGER = 3, RANGED = 4, HEALER = 5}
local classOrder = {}

local integer = 1
for class, v in ipairs(CLASS_ICON_TCOORDS) do
	classOrder[class] = integer
	integer = integer + 1
end

ns.autosort = {}
local sortFunc = {}   -- sortFunc[name] = func
ns.autosort.func = sortFunc


local function AddSort(name, func)
	if not sortFunc[name] then
		sortFunc[name] = func
	end
end

local function OrderByRole(name1, name2)
	local role1 = ns.mm.GetRole(name1)
	local role2 = ns.mm.GetRole(name2)
	if role1 and role2 and roleOrder[role1] and roleOrder[role2] then
		if roleOrder[role1] < roleOrder[role2] then
			return true
		elseif roleOrder[role1] == roleOrder[role2] then
			local class1 = ns.mm.GetClass(name1)
			local class2 = ns.mm.GetClass(name2)
			if class1 and class2 and classOrder[class1] and classOrder[class2] then
				if classOrder[class1] < classOrder[class2] then
					return true
				elseif classOrder[class1] == classOrder[class2] then
					if name1 < name2 then
						return true
					else
						return false
					end
				else
					return true
				end
			end
		else
			return false
		end
	end
	return false
end

local function SortByClass(assignment)
	local sorted = {}
	local classlist = {}
	for i, group in pairs(assignment) do
		for j, member in pairs(group) do
			local class = ns.mm.GetClass(member)
			if not classlist[class] then
				classlist[class] = {}
			end
			table.insert(classlist[class], member)
		end
	end

	table.sort(classlist)
	local group = 1
	local member = 1
	for k, v in pairs(classlist) do
		for n, m in pairs(v) do
			if not sorted[group] then
				sorted[group] = {}
			end
			sorted[group][member] = m
			
			member = member+1
			if member > maxmembers then
				group = group + 1
				member = 1
			end
			
		end
	end
	return sorted
end

local function SortByRole(assignment)
	local sorted = {}
	for i, group in pairs(assignment) do
		for j, member in pairs(group) do
			table.insert(sorted, member)
		end
	end

	table.sort(sorted, OrderByRole)

	local ret = {}

	local i = 1
	for group=1,maxgroups,1 do
		ret[group] = {}
		for member=1,maxmembers,1 do
			if i <= #sorted then
				ret[group][member] = sorted[i]
				i = i + 1
			end
		end
	end

	return ret
end
AddSort("test", SortByRole)