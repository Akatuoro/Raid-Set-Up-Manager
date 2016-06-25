local addon, ns = ...

local savedraidnames = nil

ns.savedraid = {}

local function Init()
	if savedraidnames == nil then
		if RSUM_DB == nil or RSUM_DB["Raids"] == nil then
			savedraidnames = {};
			return;
		end
		
		for name, v in pairs(RSUM_DB["Raids"]) do
			if savedraidnames == nil then
				savedraidnames = {};
			end
			table.insert(savedraidnames, name);
		end
	end
end


-- returns string with names of saved raid. returns nil if there are no saved raids
function ns.savedraid.Names()
	if modus == "testing" then
		return {"Raid 1", "Raid 2", "Raid 3", "Raid 4"};
	end
	Init();
	if ns.Option("sortsavedpresets") then
		table.sort(savedraidnames)
	end
	return savedraidnames;
end

function ns.savedraid.Load(name)
	if modus == "testing" then
		RSUM_UpdateVGroup();
		return;
	end
	if RSUM_DB["Raids"] then
		if RSUM_DB["Raids"][name] then
			ns.GoVirtual();
			ns.gm.Set(RSUM_DB["Raids"][name]);
		end
	end
	ns.mm.SyncSpecs();
	RSUM_UpdateWindows();
	return {};
end

function ns.savedraid.Import(name)
	if RSUM_DB["Raids"] then
		if RSUM_DB["Raids"][name] then
			ns.GoVirtual()
			local v = RSUM_DB["Raids"][name]
			local l = ns.gm.MemberList()
			for group=1,maxgroups,1 do
				if v[group] then
					for member=1,maxmembers,1 do
						if v[group][member] and not l[v[group][member]] then
							ns.gm.Add(v[group][member])
						end
					end
				end
			end
		end
	end
	ns.mm.SyncSpecs();
	RSUM_UpdateWindows();
end

function ns.savedraid.Save(name)
	if modus == "testing" then
		print("Would save: ");
		print(name);
		return;
	end
	if not name then
		return;
	end
	if RSUM_DB["Raids"] then
		if RSUM_DB["Raids"][name] then
			ns.gm.CopyCurrent(RSUM_DB["Raids"][name]);
			
			ns.PrintMsg("Saved preset |cff11ddcc" .. name .. "|r saved")
		end
	end
	ns.mm.SyncSpecs();
end

-- create new table to save a raid. returns true if successful, false if not (e.g. name already taken)
function ns.savedraid.Create(name)
	Init();
	if savedraidnames then
		for k, v in pairs(savedraidnames) do
			if name == v then
				return false;
			end
		end
	end
	
	local newraid = {};
	ns.gm.CopyCurrent(newraid);
	
	if not RSUM_DB["Raids"] then
		RSUM_DB["Raids"] = {};
	end
	RSUM_DB["Raids"][name] = newraid;
	table.insert(savedraidnames, name);
	
	ns.PrintMsg("Saved preset |cff11ddcc" .. name .. "|r created")
	
	ns.GoVirtual();
	return true;
end

function ns.savedraid.Delete(name)
	Init();
	if not savedraidnames then
		return false;
	end
	for k, v in pairs(savedraidnames) do
		if name == v then
			if RSUM_DB["Raids"] and RSUM_DB["Raids"][name] then
				RSUM_DB["Raids"][name] = nil;
				table.remove(savedraidnames, k);
				
				ns.PrintMsg("Saved preset |cff11ddcc" .. name .. "|r deleted.")
			end
			ns.GoReal();
		end
	end
end

function ns.savedraid.ChangeName(name, newname)
	Init();
	for k, v in pairs(savedraidnames) do
		if newname == v then
			return false;
		end
	end
	
	if RSUM_DB["Raids"] and RSUM_DB["Raids"][name] then
		RSUM_DB["Raids"][newname] = RSUM_DB["Raids"][name]
		RSUM_DB["Raids"][name] = nil
		
		for k,v in pairs(savedraidnames) do
			if v == name then
				savedraidnames[k] = newname;
				break;
			end
		end
	end
end
