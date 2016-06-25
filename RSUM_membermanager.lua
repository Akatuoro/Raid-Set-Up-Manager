local addon, ns = ...

ns.mm = {}

local raidmembers = {};		-- raidmembers[name] = {raidid, rank, class, role}


function ns.mm.Clear()
	for name, v in pairs(raidmembers) do
		raidmembers[name] = nil;
	end
end


function ns.mm.GetClass(name)
	if name and raidmembers[name] then
		return raidmembers[name]["class"];
	end
	return nil;
end

function ns.mm.GetRole(name)
	if name and raidmembers[name] then
		return raidmembers[name]["role"];
	end
	return nil;
end

function ns.mm.UpdateIDs(list)
	for k, v in pairs(raidmembers) do
		v.raidid = nil
	end
	for name, id in pairs(list) do
		if raidmembers[name] then
			raidmembers[name].raidid = id
		end
	end
end

function ns.mm.GetIDList()
	local list = {}
	for k, v in pairs(raidmembers) do
		list[k] = v.raidid
	end
	return list
end

function ns.mm.ChangeClass(group, member, class)
	if group and member then
		local name = ns.gm.Member(group, member)
		if name then
			if not raidmembers[name] then
				raidmembers[name] = {}
			end
			raidmembers[name].class = class
			RSUM_UpdateWindows()
		end
	end
end

function ns.mm.SyncSpecs()
	if raidmembers then
		if not RSUM_DB["Members"] then
			RSUM_DB["Members"] = {};
		end
		for k, v in pairs(raidmembers) do
			if v.real then
				RSUM_DB["Members"][k] = v;
			else
				if RSUM_DB["Members"][k] and RSUM_DB["Members"][k].real then
					raidmembers[k] = RSUM_DB["Members"][k];
				else
					RSUM_DB["Members"][k] = v;
				end
			end
		end
	end
end

function ns.mm.Create(name, class, raidid, role, rank)
	if name then
		if raidmembers[name] then
			return false
		end
		
		raidmembers[name] = {}
		if class then
			raidmembers[name].class = class
		end
		if raidid then
			raidmembers[name].raidid = raidid
			raidmembers[name].real = true
		end
		if role then
			raidmembers[name].role = role
		end
		if rank then
			raidmembers[name].rank = rank
		end
		
	end
	return true
end

function ns.mm.Remove(name)
	if name and raidmembers[name] then
		raidmembers[name] = nil
	end
end