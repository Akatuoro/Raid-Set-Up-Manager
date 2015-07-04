-- important variables
local vgroups_insync = true;


-- virtual raid
local vraidmembers = {};		-- vraidmembers[name] = {raidid, rank, class, role}
local vgroupassignment = {};	-- vgroupassignment[subgroup] = {player1, player2, player3, player4, player5}  where playerx is a name



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

-- set virtual groups based on the real ones
function RSUM_UpdateVGroup()
		RSUM_VGroupInit();
		
		-- Erstelle Test Raid
		if RSUM_test then
			local testclasses = {"WARRIOR","DRUID","HUNTER","WARLOCK","PRIEST","PALADIN","SHAMAN","ROGUE","DEATHKNIGHT","MONK"};
			local testmembernumber = random(22,30);
			for member=1,testmembernumber,1 do
				local playerid = "player" .. member;
				local subgroup = random(maxgroups);
				
				local frame_not_found = true;
				for i=1,5,1 do
					if frame_not_found and vgroupassignment[subgroup][i] == nil then
						local frame = groupmemberframes[subgroup][i];
						vraidmembers[playerid] = {["raidid"] = member, ["rank"] = nil, ["class"] = testclasses[random(10)], ["role"] = "DAMAGE", ["frame"] = frame};
						vgroupassignment[subgroup][i] = playerid;
						frame_not_found = false;
					end
				end
				if frame_not_found then
					for j = 1,maxgroups,1 do
						for i=1,maxmembers,1 do
							if frame_not_found and vgroupassignment[j][i] == nil then
								local frame = groupmemberframes[j][i];
								vraidmembers[playerid] = {["raidid"] = member, ["rank"] = nil, ["class"] = testclasses[random(10)], ["role"] = "DAMAGE", ["frame"] = frame};
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
			local frame_not_found = true;
			for i=1,5,1 do
				if frame_not_found and vgroupassignment[subgroup][i] == nil then
					local frame = groupmemberframes[subgroup][i];
					vraidmembers[name] = {["raidid"] = member, ["rank"] = rank, ["class"] = fileName, ["role"] = role, ["frame"] = frame};
					vgroupassignment[subgroup][i] = name;
					frame_not_found = false;
				end
			end
			if frame_not_found then
				print("RSUM Error, more than " .. maxmembers .. " players in group " .. subgroup .. " refresh please.");
			end
			
		end
		vgroups_insync = true;
		RSUM_UpdateWindows();
end

-- what happens when the raid roster changes
function RSUM_GroupRosterUpdate()
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
					print("left: " .. name);
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
		print("new: " .. name);
		vraidmembers[name] = {["raidid"] = member, ["rank"] = rank, ["class"] = fileName, ["role"] = role, ["frame"] = frame};
		-- find the first group from the rear to put the new group member into
		for group=maxgroups,1,-1 do
			if vgroupassignment[group][maxmembers] == nil then
				print("group " .. group .. " empty");
				for i=1,maxmembers,1 do
					if vgroupassignment[group][i] == nil then
						print("put " .. name .. " to group " .. group .. " memberframe " .. i);
						vgroupassignment[group][i] = name;
						break;
					end
				end
				break;
			end
		end
	end
	
	RSUM_UpdateWindows();
end


function RSUM_BuildGroups()
	-- check for permissions
	if not UnitIsRaidOfficer("player") and not UnitIsGroupLeader("player") then
		print("Raid Set Up Manager - No permission to change groups");
		print("You need to be raid lead or assistant");
		return;
	end
	

	-- Preparation
	local numsubgroupmember = {};	-- numsubgroupmember[subgroup] = number
	local rsubgroup = {};			-- rsubgroup[raidid] = subgroup (number) -- projection of the actual groups that gradually changes, supposed to simulate server side changes
	local vsubgroup = {};			-- vsubgroup[raidid] = subgroup (number) -- projection of the virtual groups used for the target groups
	for group=1,maxgroups,1 do
		numsubgroupmember[group] = 0;
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
			if name then
				vsubgroup[vraidmembers[name]["raidid"]] = group;
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
			if name then
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

