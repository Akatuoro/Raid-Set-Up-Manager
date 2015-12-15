-- important variables
local vgroups_insync = true;

-- modi:
-- "standard" - check for vgroups_insync, vraidmembers contain exactly the real members
-- "ultravirtual" - vraidmembers might be all virtual
local modus = "standard";


local apply_query = false;
local timer_next = 0;
local timer_step = 1;
local reminder_lockout = 0;
local reminder_lockouttime = 10;


-- virtual raid
local vraidmembers = {};		-- vraidmembers[name] = {raidid, rank, class, role}
local vgroupassignment = {};	-- vgroupassignment[subgroup] = {player1, player2, player3, player4, player5}  where playerx is a name
local maxgroups = RSUM_MAXGROUPS;
local maxmembers = RSUM_MAXMEMBERS;

local groupassignmentcopy = nil;


-- saving and loading groups
-- RSUM_DB["Members"] contains info for vraidmembers
-- RSUM_DB["Raids"][name] equivalent to vgroupassignment for raid identified by name

local savedraidnames = nil;

-- Mode Control

-- RSUM_GetStatus
-- return modus, sync, apply, number, combat
-- modus - currend mode
-- sync - if vgroups_insync; in future updates if setup is changed from saved setup in ultravirtual mode
-- apply - if apply_query (if it's currently trying to apply changes)
-- number - number of raid members to move
-- combat - numbers of raid members to move that are in combat
function RSUM_GetStatus()
	local sync, apply, number, combat = false, false, 0, 0;
	if modus == "standard" then
		if vgroups_insync then
			sync = true;
		else
			number, combat = RSUM_GetNumRaidMembersToMove();
		end
		if apply_query then
			apply = true;
		end
	end
	if modus == "ultravirtual" then
		if apply_query then
			apply = true;
			number, combat = RSUM_GetNumRaidMembersToMove();
		end
	end
	
	return modus, sync, apply, number, combat;
end

function RSUM_VirtualMode()
	if modus == "standard" then
		RSUM_CopyGroup(vgroupassignment, groupassignmentcopy);
		RSUM_UpdateWindows();
	end
	modus = "ultravirtual";
	RSUM_SetVirtualTexture();
end

function RSUM_StandardMode()
	if not (modus == "standard") and groupassignmentcopy then
		RSUM_CopyGroup(groupassignmentcopy, vgroupassignment);
		groupassignmentcopy = nil;
		RSUM_UpdateWindows();
	end
	modus = "standard";
	RSUM_GroupRosterUpdate();
	RSUM_SetStandardTexture();
end

function RSUM_Test()
	if modus == "testing" then
		modus = "standard";
	else
		modus = "testing";
	end
end

local function RSUM_MasterlootCheck()
	if RSUM_Options["masterloot"] then
		if IsInRaid() and GetRaidDifficultyID() == 16 and reminder_lockout < GetTime() then
			local lootmethod, _, masterlooterRaidID = GetLootMethod();
			if not (lootmethod == "master") then
				print("|cffff0000Loot is currently being distributed by " .. lootmethod);
				reminder_lockout = GetTime() + reminder_lockouttime;
			elseif select(3, GetRaidRosterInfo(masterlooterRaidID)) > 4 then
				print("|cffff0000Loot master " .. GetRaidRosterInfo(masterlooterRaidID) .. " is not in group 1-4");
				reminder_lockout = GetTime() + reminder_lockouttime;
			end
		end
	end
end

function RSUM_TimedEvents()
	if apply_query then
		if timer_next < GetTime() then
			RSUM_Apply();
			timer_next = GetTime() + timer_step;
		end
	end
	RSUM_MasterlootCheck();
end

local function RSUM_VGroupInit()
		for i=1,maxgroups,1 do
			vgroupassignment[i] = {};
			for j=1,maxmembers,1 do
				vgroupassignment[i][j] = nil;
			end
		end
		for name, v in pairs(vraidmembers) do
			vraidmembers[name] = nil;
		end
end

local function RSUM_GroupByName(name)
	if name then
		if vgroupassignment then
			for group=1,maxgroups,1 do
				if vgroupassignment[group] then
					for member=1,maxmembers,1 do
						if vgroupassignment[group][member] == name then
							return group, member;
						end
					end
				end
			end
		end
	end
	return nil,nil;
end

local function RSUM_FindSpotForMember(rear)
	-- searches a free sport for the member. if rear is true then search from the rear
	local start, finish, step;
	if rear then
		start = maxgroups;
		finish = 1;
		step = -1;
	else
		start = 1;
		finish = maxgroups;
		step = 1;
	end
	
	for group=start,finish,step do
		if vgroupassignment[group] then
			if not vgroupassignment[group][maxmembers] then
				return group;
			end
		end
	end
end

function RSUM_ClearVGroup()
	RSUM_VirtualMode();
	for i=1,maxgroups,1 do
		vgroupassignment[i] = {};
	end
	RSUM_UpdateWindows();
end


function RSUM_RemoveNonRaidMembers()
	for i=1,maxgroups,1 do
		for j=1,maxmembers,1 do
			if vgroupassignment[i][j] then
				if not UnitInRaid(vgroupassignment[i][j]) then
					vgroupassignment[i][j] = nil;
				else
					for k=1,j-1,1 do
						if vgroupassignment[i][k] == nil then
							vgroupassignment[i][k] = vgroupassignment[i][j];
							vgroupassignment[i][j] = nil;
							break;
						end
					end
				end
			end
		end
	end
	RSUM_UpdateWindows();
end


function RSUM_ImportFromRaid()
	local l = {};
	for group=1,maxgroups,1 do
		for member=1,maxmembers,1 do
			if vgroupassignment[group][member] then
				l[vgroupassignment[group][member]] = true;
			end
		end
	end
	
	for i=1,GetNumGroupMembers(),1 do
		local name, rank, subgroup, level, class, fileName, zone, online, isDead, raidrole, isML = GetRaidRosterInfo(i);
		local role = UnitGroupRolesAssigned("raid" .. i);
		if name and not l[name] then
			vraidmembers[name] = {rank = rank, class = fileName, role = role, real = true};
			local group = RSUM_FindSpotForMember();
			RSUM_AddVMemberToGroup(name, group);
		end
	end
	RSUM_UpdateWindows();
end

-- set virtual groups based on the real ones
function RSUM_UpdateVGroup()
		RSUM_VGroupInit();
		
		-- Erstelle Test Raid
		if modus == "testing" then
			local testclasses = {"WARRIOR","DRUID","HUNTER","WARLOCK","PRIEST","PALADIN","SHAMAN","ROGUE","DEATHKNIGHT","MONK"};
			local testmembernumber = random(22,30);
			for member=1,testmembernumber,1 do
				local playerid = "player" .. member;
				local subgroup = random(maxgroups);
				
				local frame_not_found = true;
				for i=1,5,1 do
					if frame_not_found and vgroupassignment[subgroup][i] == nil then
						vraidmembers[playerid] = {["raidid"] = member, ["rank"] = nil, ["class"] = testclasses[random(10)], ["role"] = "DAMAGE"};
						vgroupassignment[subgroup][i] = playerid;
						frame_not_found = false;
					end
				end
				if frame_not_found then
					for j = 1,maxgroups,1 do
						for i=1,maxmembers,1 do
							if frame_not_found and vgroupassignment[j][i] == nil then
								vraidmembers[playerid] = {["raidid"] = member, ["rank"] = nil, ["class"] = testclasses[random(10)], ["role"] = "DAMAGE"};
								vgroupassignment[j][i] = playerid;
								frame_not_found = false;
							end
						end
					end
				end
			end
			RSUM_UpdateWindows();
			
			return;
		end
		
		
		for member=1,GetNumGroupMembers(),1 do
			local raidid = "raid" .. member;
			local name, rank, subgroup, level, class, fileName, zone, online, isDead, raidrole, isML = GetRaidRosterInfo(member);
			local role = UnitGroupRolesAssigned(raidid);
			if name then
				local frame_not_found = true;
				for i=1,5,1 do
					if frame_not_found and vgroupassignment[subgroup][i] == nil then
						vraidmembers[name] = {["raidid"] = member, ["rank"] = rank, ["class"] = fileName, ["role"] = role, ["real"] = true};
						vgroupassignment[subgroup][i] = name;
						frame_not_found = false;
					end
				end
				if frame_not_found then
					print("RSUM Error, more than " .. maxmembers .. " players in group " .. subgroup .. " refresh please.");
				end
			end
		end
		RSUM_GroupSync(true);
		RSUM_UpdateWindows();
end

-- what happens when the raid roster changes
function RSUM_GroupRosterUpdate()
	if modus == "ultravirtual" then
		return;
	end
	if vgroups_insync then
		RSUM_UpdateVGroup();
		return;
	end
	
	local newmembers = {};
	local lostmembers = {};
	-- add all virtual members to lostmembers
	for name, v in pairs(vraidmembers) do
		lostmembers[name] = v["raidid"];
	end
	
	-- delete all members from lostmembers that are (still) in the real group
	-- add all members that are in the real group but not found in between the virtual members
	for member=1,GetNumGroupMembers(),1 do
		local name = select(1, GetRaidRosterInfo(member));
		for name2, v in pairs(vraidmembers) do
			if name and name == name2 then
				lostmembers[name] = nil;
				name = nil;
				break;
			end
		end
		if name then
			newmembers[name] = member;
		end
	end
	
	-- Remove lost members
	for name, id in pairs(lostmembers) do
		vraidmembers[name] = nil;
		for group=1,maxgroups,1 do
			for member=1,maxmembers,1 do
				if vgroupassignment[group][member] and vgroupassignment[group][member] == name then
					RSUM_RemoveVMemberFromGroup(group, member);
				end
			end
		end
	end
	
	-- add new members
	for name, member in pairs(newmembers) do
		local _, rank, subgroup, level, class, fileName, zone, online, isDead, raidrole, isML = GetRaidRosterInfo(member);
		local raidid = "raid" .. member;
		local role = UnitGroupRolesAssigned(raidid);
		vraidmembers[name] = {["raidid"] = member, ["rank"] = rank, ["class"] = fileName, ["role"] = role, ["frame"] = frame, ["real"] = true};
		-- find the first group from the rear to put the new group member into
		for group=maxgroups,1,-1 do
			if vgroupassignment[group][maxmembers] == nil then
				for i=1,maxmembers,1 do
					if vgroupassignment[group][i] == nil then
						vgroupassignment[group][i] = name;
						break;
					end
				end
				break;
			end
		end
	end
	
	RSUM_GroupSync(true);
	
	RSUM_UpdateWindows();
end


function RSUM_Apply()
	-- check for permissions
	if not UnitIsRaidOfficer("player") and not UnitIsGroupLeader("player") then
		print("Raid Set Up Manager - No permission to change groups");
		print("You need to be raid lead or assistant");
		return;
	end
	
	if not UnitAffectingCombat("player") then
		RSUM_BuildGroups();
	end
	
	RSUM_GroupSync(true, true);
	groupassignmentcopy = nil;
end

function RSUM_BuildGroups()
	-- Preparation
	local numsubgroupmember = {};	-- numsubgroupmember[subgroup] = number
	local vnumsubgroupmember = {};	-- vnumsubgroupmember[subgroup] = member -- number of players supposed to be in the subgroup
	local rsubgroup = {};			-- rsubgroup[raidid] = subgroup (number) -- projection of the actual groups that gradually changes, supposed to simulate server side changes
	local vsubgroup = {};			-- vsubgroup[raidid] = subgroup (number) -- projection of the virtual groups used for the target groups
	for group=1,maxgroups,1 do
		numsubgroupmember[group] = 0;
		vnumsubgroupmember[group] = 0;
	end
	for k, v in pairs(vraidmembers) do
		v["raidid"] = nil;
	end
	for raidmember=1,GetNumGroupMembers(),1 do
		local group = select(3, GetRaidRosterInfo(raidmember));
		vraidmembers[select(1,GetRaidRosterInfo(raidmember))]["raidid"] = raidmember;
		rsubgroup[raidmember] = group;
		numsubgroupmember[group] = numsubgroupmember[group] + 1;
	end

	for group=1,maxgroups,1 do
		for member=1,maxmembers,1 do
			local name = vgroupassignment[group][member]
			if name and vraidmembers[name]["raidid"] then
				vsubgroup[vraidmembers[name]["raidid"]] = group;
				vnumsubgroupmember[group] = vnumsubgroupmember[group] + 1;
			end
		end
	end
	
	-- moving raid members (THIS DOES NOT WORK IN FULL RAIDS (aka full 40 man raids))
	-- three possibilities:
	-- - target subgroup not full -> just move
	-- - target subgroup full -> find member that is in target subgroup but assigned to another subgroup
	-- 		- and there's a member to swap groups with (target subgroups are each others current groups)
	--		- and there's no member to swap with -> move the member to move away to the first not full subgroup from the rear
	for raidmember=1, GetNumGroupMembers(),1 do
		local formersubgroup = rsubgroup[raidmember];
		if not (vsubgroup[raidmember] == formersubgroup) then
			-- if raidmember is not accounted for yet, put him to the rear
			if vsubgroup[raidmember] == nil then
				for i=maxgroups,1,-1 do
					if vnumsubgroupmember[i] < maxmembers then
						vsubgroup[raidmember] = i;
						vnumsubgroupmember[i] = vnumsubgroupmember[i] + 1;
						break;
					end
				end
			end
			-- move raidmember
			if numsubgroupmember[vsubgroup[raidmember]] < maxmembers then
				SetRaidSubgroup(raidmember, vsubgroup[raidmember]);
				-- change projection of actual groups
				rsubgroup[raidmember] = vsubgroup[raidmember];
				numsubgroupmember[vsubgroup[raidmember]] = numsubgroupmember[vsubgroup[raidmember]] + 1;
				numsubgroupmember[formersubgroup] = numsubgroupmember[formersubgroup] - 1;
			else
				local raidmembertomove = nil;
				local swapped = false;
				-- look for group member to move away
				for i=1,GetNumGroupMembers(),1 do
					-- if target subgroup == current subgroup of i AND current subgroup of i != target subgroup of i
					if vsubgroup[raidmember] == rsubgroup[i] and not (vsubgroup[i] == vsubgroup[raidmember]) then
						raidmembertomove = i;
						-- if they can be swapped
						if formersubgroup == vsubgroup[i] then
							SwapRaidSubgroup(raidmember, i);
							-- change projection of actual groups
							rsubgroup[raidmember] = vsubgroup[raidmember];
							rsubgroup[i] = formersubgroup;
							swapped = true;
							break;
						end
					end
				end
				if raidmembertomove == nil then
					print("RSUM Error: Some kind of error. (Subgroup supposed to be full, but no member found to remove from this subgroup)");
				end
				if not swapped then
					-- look for not full subgroup from the rear
					for group=maxgroups,1,-1 do
						if numsubgroupmember[group] < maxmembers then
							SetRaidSubgroup(raidmembertomove, group);
							SetRaidSubgroup(raidmember, vsubgroup[raidmember]);
							-- change projection of actual groups
							rsubgroup[raidmembertomove] = group;
							rsubgroup[raidmember] = vsubgroup[raidmember];
							numsubgroupmember[group] = numsubgroupmember[group] + 1;
							numsubgroupmember[formersubgroup] = numsubgroupmember[formersubgroup] - 1;
							swapped = true;
							break;
						end
					end
					if not swapped then
						print("RSUM Error: Some kind of error. (no empty group found to move raid member to)");
					end
				end
			end
		end
	end
end

-- add virtual member to virtual group. fails if group full
function RSUM_AddVMemberToGroup(name, group)
	for i=1,maxmembers,1 do
		if vgroupassignment[group][i] == nil then
			vgroupassignment[group][i] = name;
			return true;
		end
	end
	return false;
end

-- remove virtual member from virtual group
function RSUM_RemoveVMemberFromGroup(group, member)
	for i=member,maxmembers-1,1 do
		vgroupassignment[group][i] = vgroupassignment[group][i+1];
	end
	vgroupassignment[group][maxmembers] = nil;
end

-- swap virtual members in different groups
function RSUM_SwapVMember(sourcegroup, sourcemember, targetgroup, targetmember)
	if sourcegroup == targetgroup then
		return;
	end
	local tempname = vgroupassignment[sourcegroup][sourcemember];
	vgroupassignment[sourcegroup][sourcemember] = vgroupassignment[targetgroup][targetmember];
	vgroupassignment[targetgroup][targetmember] = tempname;
end

-- try to move virtual member to new group. fails if targetgroup is full
function RSUM_MoveVMember(sourcegroup, sourcemember, targetgroup)
	if sourcegroup == targetgroup then
		return true;
	end
	if RSUM_AddVMemberToGroup(vgroupassignment[sourcegroup][sourcemember], targetgroup) then
		RSUM_RemoveVMemberFromGroup(sourcegroup, sourcemember);
		return true;
	end
	return false;
end

-- currently not used?
function RSUM_MoveChildFrames(startframe, endframe)
	if not startframe then
		print("RSUM Error: No Frame to move childs from");
		return;
	end
	if not endframe then
		print("RSUM Error: No Frame to move childs to");
		return;
	end
	for i=1,startframe:GetNumRegions(),1 do
		local child = startframe:GetRegions();
		if not child then
			print("Child " .. i .. " = nil");
			return;
		end
		child:SetParent(endframe);
		child:SetPoint("CENTER",-2,0);
	end
end

-- returns number of raid members to move when applying changes and how many of them are in combat
function RSUM_GetNumRaidMembersToMove()
	local vsubgroup = {};
	local numraidmemberstomove = 0;
	local numraidmemberstomoveincombat = 0;
	
	for group=1,maxgroups,1 do
		for member=1,maxmembers,1 do
			local name = vgroupassignment[group][member]
			if name and vraidmembers[name] and vraidmembers[name]["raidid"] then
				vsubgroup[vraidmembers[name]["raidid"]] = group;
			end
		end
	end
	
	for member=1,GetNumGroupMembers(),1 do
		local currentsubgroup = select(3, GetRaidRosterInfo(member));
		if not (currentsubgroup == vsubgroup[member]) then
			numraidmemberstomove = numraidmemberstomove + 1;
			raidid = "raid" .. member;
			if UnitAffectingCombat(raidid) then
				numraidmemberstomoveincombat = numraidmemberstomoveincombat + 1;
			end
		end
	end
	
	if numraidmemberstomove == 0 then
		vgroups_insync = true;
	end
	
	return numraidmemberstomove, numraidmemberstomoveincombat;
end

function RSUM_GroupMember(group, member)
	if vgroupassignment[group] and vgroupassignment[group][member] then
		return vgroupassignment[group][member];
	end
	return nil;
end

function RSUM_GetMemberClass(name)
	if name and vraidmembers[name] then
		return vraidmembers[name]["class"];
	end
	return nil;
end

function RSUM_GetMemberRole(name)
	if name and vraidmembers[name] then
		return vraidmembers[name]["role"];
	end
	return nil;
end

function RSUM_ChangeMemberClass(group, member, class)
	if group and member then
		if vgroupassignment[group] and vgroupassignment[group][member] then
			local name = vgroupassignment[group][member];
			if not vraidmembers[name] then
				vraidmembers[name] = {};
			end
			vraidmembers[name].class = class;
			RSUM_UpdateWindows();
		end
	end
end

function RSUM_CreateMember(name, class)
	if name then
		if RSUM_GroupByName(name) then
			return;
		end
		
		RSUM_VirtualMode();
	
		vraidmembers[name] = {};
		if class then
			vraidmembers[name].class = class;
		end
		
		-- put new member into a group
		local group = RSUM_FindSpotForMember();
		if group then
			RSUM_AddVMemberToGroup(name, group);
		end
	end
	RSUM_UpdateWindows();
end

function RSUM_GroupSync(enable, apply)
	local nummembers, _ = RSUM_GetNumRaidMembersToMove();
	if nummembers > 0 then
		if enable == false then
			vgroups_insync = enable;
			if not apply then
				apply_query = false;
			end
		else
			if apply and not apply_query then
				apply_query = true;
				timer_next = GetTime() + timer_step;
			end
		end
	else
		vgroups_insync = true;
		
		RSUM_MasterlootCheck();
		apply_query = false;
	end
end

function RSUM_CopyGroup(source, target)
	if not source or not target then
		return;
	end
	for group=1,maxgroups,1 do
		target[group] = {};
		for member=1,maxmembers,1 do
			target[group][member] = source[group][member];
		end
	end
end

local function RSUM_InitSavedRaids()
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

function RSUM_SyncMemberSpecs()
	if vraidmembers then
		if not RSUM_DB["Members"] then
			RSUM_DB["Members"] = {};
		end
		for k, v in pairs(vraidmembers) do
			if v.real then
				RSUM_DB["Members"][k] = v;
			else
				if RSUM_DB["Members"][k] and RSUM_DB["Members"][k].real then
					vraidmembers[k] = RSUM_DB["Members"][k];
				else
					RSUM_DB["Members"][k] = v;
				end
			end
		end
	end
	if not vraidmembers then
		vraidmembers = {};
	end
	if RSUM_DB["Members"] then
		for group=1,maxgroups,1 do
			if vgroupassignment[group] then
				for member=1,maxmembers,1 do
					local name = vgroupassignment[group][member];
					if name then
						local v = vraidmembers[name];
						if not v or not v.class then
							if RSUM_DB["Members"][name] then
								vraidmembers[name] = RSUM_DB["Members"][name];
							end
						end
					end
				end
			end
		end
	end
end

-- returns string with names of saved raid. returns nil if there are no saved raids
function RSUM_GetSavedRaidNames()
	if modus == "testing" then
		return {"Raid 1", "Raid 2", "Raid 3", "Raid 4"};
	end
	RSUM_InitSavedRaids();
	return savedraidnames;
end

function RSUM_LoadSavedRaid(name)
	if modus == "testing" then
		RSUM_UpdateVGroup();
		return;
	end
	if RSUM_DB["Raids"] then
		if RSUM_DB["Raids"][name] then
			RSUM_VirtualMode();
			RSUM_CopyGroup(RSUM_DB["Raids"][name], vgroupassignment);
		end
	end
	RSUM_SyncMemberSpecs();
	RSUM_UpdateWindows();
	return {};
end

function RSUM_ImportFromSavedRaid(name)
	if RSUM_DB["Raids"] then
		if RSUM_DB["Raids"][name] then
			RSUM_VirtualMode();
			local v = RSUM_DB["Raids"][name];
			local l = {};
			for group=1,maxgroups,1 do
				for member=1,maxmembers,1 do
					if vgroupassignment[group][member] then
						l[vgroupassignment[group][member]] = true;
					end
				end
			end
			for group=1,maxgroups,1 do
				if v[group] then
					for member=1,maxmembers,1 do
						if v[group][member] and not l[v[group][member]] then
							local targetgroup = RSUM_FindSpotForMember();
							RSUM_AddVMemberToGroup(v[group][member], targetgroup);
						end
					end
				end
			end
		end
	end
	RSUM_SyncMemberSpecs();
	RSUM_UpdateWindows();
end

function RSUM_UpdateSavedRaid(name)
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
			RSUM_CopyGroup(vgroupassignment, RSUM_DB["Raids"][name]);
		end
	end
	RSUM_SyncMemberSpecs();
end

-- create new table to save a raid. returns true if successful, false if not (e.g. name already taken)
function RSUM_CreateSavedRaid(name)
	RSUM_InitSavedRaids();
	if savedraidnames then
		for k, v in pairs(savedraidnames) do
			if name == v then
				return false;
			end
		end
	end
	
	local newraid = {};
	RSUM_CopyGroup(vgroupassignment, newraid);
	
	if not RSUM_DB["Raids"] then
		RSUM_DB["Raids"] = {};
	end
	RSUM_DB["Raids"][name] = newraid;
	table.insert(savedraidnames, name);
	
	RSUM_VirtualMode();
	return true;
end

function RSUM_DeleteSavedRaid(name)
	RSUM_InitSavedRaids();
	if not savedraidnames then
		return false;
	end
	for k, v in pairs(savedraidnames) do
		if name == v then
			if RSUM_DB["Raids"] and RSUM_DB["Raids"][name] then
				RSUM_DB["Raids"][name] = nil;
				table.remove(savedraidnames, k);
			end
			RSUM_StandardMode();
		end
	end
end

function RSUM_ChangeSavedRaidName(name, newname)
	RSUM_InitSavedRaids();
	for k, v in pairs(savedraidnames) do
		if newname == v then
			return false;
		end
	end
	
	if RSUM_DB["Raids"] and RSUM_DB["Raids"][name] then
		local newraid = {};
		RSUM_CopyGroup(RSUM_DB["Raids"][name], newraid);
		RSUM_DB["Raids"][newname] = newraid;
		RSUM_DB["Raids"][name] = nil;
		
		for k,v in pairs(savedraidnames) do
			if v == name then
				savedraidnames[k] = newname;
				break;
			end
		end
	end
end



