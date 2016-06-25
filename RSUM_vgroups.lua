-- important variables
local vgroups_insync = true;
local addon, ns = ...

-- modi:
-- "standard" - check for vgroups_insync, vraidmembers contain exactly the real members
-- "ultravirtual" - vraidmembers might be all virtual
local modus = "standard";


local apply_query = false;
local timer_next = 0;
local timer_step = 1;
local reminder_lockout = 0;
local reminder_lockouttime = 10;

local maxgroups = ns.maxgroups
local maxmembers = ns.maxmembers


local groupassignmentcopy = nil;


-- saving and loading groups
-- RSUM_DB["Members"] contains info for vraidmembers
-- RSUM_DB["Raids"][name] equivalent to vgroupassignment for raid identified by name

local savedraidnames = nil;

-- Mode Control

-- GetStatus
-- return modus, sync, apply, number, combat
-- modus - currend mode
-- sync - if vgroups_insync; in future updates if setup is changed from saved setup in ultravirtual mode
-- apply - if apply_query (if it's currently trying to apply changes)
-- number - number of raid members to move
-- combat - numbers of raid members to move that are in combat
function ns.GetStatus()
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

function ns.GoVirtual()
	if modus == "standard" then
		ns.gm.CopyCurrent(groupassignmentcopy);
		RSUM_UpdateWindows();
	end
	modus = "ultravirtual";
	RSUM_SetVirtualTexture();
end

function ns.GoReal()
	if not (modus == "standard") and groupassignmentcopy then
		ns.gm.Set(groupassignmentcopy);
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


function RSUM_RemoveNonRaidMembers()
	for i=1,maxgroups,1 do
		for j=1,maxmembers,1 do
			if ns.gm.Member(i,j) then
				if not UnitInRaid(ns.gm.Member(i,j)) then
					ns.gm.Remove(i,j)
				end
			end
		end
	end
	RSUM_UpdateWindows();
end


function RSUM_ImportFromRaid()
	local l = ns.gm.MemberList()
	
	for i=1,GetNumGroupMembers(),1 do
		local name, rank, subgroup, level, class, fileName, zone, online, isDead, raidrole, isML = GetRaidRosterInfo(i)
		local role = UnitGroupRolesAssigned("raid" .. i)
		if name and not l[name] then
			ns.mm.Create(name, fileName, i, role, rank)
			ns.gm.Add(name)
		end
	end
	RSUM_UpdateWindows();
end

-- set virtual groups based on the real ones
function RSUM_UpdateVGroup()
		ns.gm.Clear();
		
		for member=1,GetNumGroupMembers(),1 do
			local raidid = "raid" .. member;
			local name, rank, subgroup, level, class, fileName, zone, online, isDead, raidrole, isML = GetRaidRosterInfo(member);
			local role = UnitGroupRolesAssigned(raidid);
			if name then
				ns.mm.Create(name, fileName, member, role, rank)
				ns.gm.Add(name, subgroup)
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
	local lostmembers = ns.mm.GetIDList();
	
	-- delete all members from lostmembers that are (still) in the real group
	-- add all members that are in the real group but not found in between the virtual members
	for member=1,GetNumGroupMembers(),1 do
		local name = select(1, GetRaidRosterInfo(member));
		for name2, v in pairs(lostmembers) do
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
		local group, member = ns.gm.GetGroupByName(name)
		ns.gm.Remove(group, member)
	end
	
	-- add new members
	for name, member in pairs(newmembers) do
		local _, rank, subgroup, level, class, fileName, zone, online, isDead, raidrole, isML = GetRaidRosterInfo(member);
		local raidid = "raid" .. member;
		local role = UnitGroupRolesAssigned(raidid);
		ns.mm.Create(name, fileName, member, role, rank)
		-- find the first group from the rear to put the new group member into
		ns.gm.Add(name, nil, true)
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

local function Move(id, group)
	if not UnitAffectingCombat(id) then
		SetRaidSubgroup(id, group)
	end
end

local function Swap(source, target)
	if not UnitAffectingCombat(source) and not UnitAffectingCombat(target) then
		SwapRaidSubgroup(source, target)
	end
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
	local idlist = {}
	for raidmember=1,GetNumGroupMembers(),1 do
		local group = select(3, GetRaidRosterInfo(raidmember));
		local name = select(1, GetRaidRosterInfo(raidmember));
		if name and group then
			idlist[name] = raidmember;
			rsubgroup[raidmember] = group;
			numsubgroupmember[group] = numsubgroupmember[group] + 1;
		end
	end
	ns.mm.UpdateIDs(idlist)

	for group=1,maxgroups,1 do
		for member=1,maxmembers,1 do
			local name = ns.gm.Member(group, member)
			if name and idlist[name] then
				vsubgroup[idlist[name]] = group;
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
				Move(raidmember, vsubgroup[raidmember]);
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
							Swap(raidmember, i);
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
							Move(raidmembertomove, group);
							Move(raidmember, vsubgroup[raidmember]);
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


-- returns number of raid members to move when applying changes and how many of them are in combat
function RSUM_GetNumRaidMembersToMove()
	local vsubgroup = {}
	local numraidmemberstomove = 0
	local numraidmemberstomoveincombat = 0
	local idlist = ns.mm.GetIDList()
	
	for group=1,maxgroups,1 do
		for member=1,maxmembers,1 do
			local name = ns.gm.Member(group, member)
			if name and idlist[name] then
				vsubgroup[idlist[name]] = group;
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
		if apply_query then
			ns.PrintMsg("Groups successfully built")
			apply_query = false;
		end
	end
	RSUM_UpdateWindows()
end






