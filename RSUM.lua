-- important variables
local initiated = false;
local RSUM_test = false;
local vgroups_insync = true;


-- Debugging
local debugframe;
local debugfontstring;



-- UI Element Pointers
local number = 0;
local mainframe;
local windowframe;
local groupframes = {};
local groupmemberframes = {};	-- groupmemberframes[group] = {player1frame, player2frame....}
local groupmemberframesempty = {} -- groupmemberframes[framename] = true / nil
local maxgroups = 8;
local maxmembers = 5;
local applyButtonMouseOver = false;

-- Drag Action
local saved_frame = {["frame"] = nil, ["numpoints"] = 0, ["points"] = {}};		-- saved_frame["points"] = {point1, point2, ...} -- point1 = {"point", "relativeTo", "relativePoint", "xoff", "yoff"}



-- virtual raid
local vraidmembers = {};		-- vraidmembers[name] = {raidid, rank, class, role}
local vgroupassignment = {};	-- vgroupassignment[subgroup] = {player1, player2, player3, player4, player5}  where playerx is a name



-- UI Element Properties
local mw_width = 150;
local mw_height = 14;
local mw_padding = 1;
local gw_width = mw_width + mw_padding * 2;
local gw_height = mw_height*maxmembers + mw_padding * (maxmembers+1);
local gw_padding = 12;
local button_height = 20;
local button_width = 150;
local titleregion_height = 14;
local titleregion_width = 200;
local titleregion_offy = 4;
local exitbutton_height = 24;
local exitbutton_width = 24;
local exitbutton_offx = 4;
local exitbutton_offy = 4;

-- visuals (aka textures, maybe fonts):
local mainwindowframetexture = 0,0,0,0.7;
local titleregiontexture = 0.1,0.1,0.1,1;
local buttontexture = 0.2,0.2,0,1;
local buttontexturehighlighted = 0.4,0.4,0,1;
local groupframetexture = 0,0,0.4,1;
local groupmemberframetexture = 0.1,0.1,0.1,1;
local groupmemberframetexturehighlighted = 0.4,0.4,0.4,1;

-- descriptions
local titleregiontext = "Raid Set Up Manager";


-- Slash commands
SLASH_RAIDSETUP1, SLASH_RAIDSETUP2 = '/raidsetup', '/rsum';
local function slashhandler(msg, editbox)
		if msg == "init" then
			RSUM_Init();
			return;
		end
		if msg == "show" then
			RSUM_Show();
			return;
		end
		if msg == "hide" then
			RSUM_Hide();
			return;
		end
		if msg == "refresh" then
			RSUM_UpdateVGroup();
			return;
		end
		if msg == "test" then
			if RSUM_test then
				RSUM_test = false;
			else
				RSUM_test = true;
				if not initiated then
					RSUM_Init();
				end
			end
			return;
		end
		if msg == "apply" then
			RSUM_BuildGroups();
			return;
		end
		if not initiated then
			RSUM_Init();
		end
		RSUM_Show();
end

SlashCmdList["RAIDSETUP"] = slashhandler;


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

-- returns group, member of the groupmemberframes as integer
function RSUM_GetGroupMemberByFrame(frame)
	for group=1,maxgroups,1 do
		if frame:GetParent():GetName() == groupframes[group]:GetName() then
			for member=1,maxmembers,1 do
				if frame:GetName() == groupmemberframes[group][member]:GetName() then
					return group, member;
				end
			end
			return group, nil;
		end
	end
	return nil, nil;
end

function RSUM_FrameContainsPoint(frame, x, y)
	local left, bottom, width, height = frame:GetRect();
	if x >= left then
		if y >= bottom then
			if x <= left + width then
				if y <= bottom + height then
					return true;
				end
			end
		end
	end
	return false;
end

-- search for mouseover frame which is actually overlapped by the dragged frame
function RSUM_GroupMemberFrameContainsPoint(x, y)
	if RSUM_FrameContainsPoint(windowframe, x, y) then
		for group=1,maxgroups,1 do
			if RSUM_FrameContainsPoint(groupframes[group], x, y) then
				for member=1,maxmembers,1 do
					if RSUM_FrameContainsPoint(groupmemberframes[group][member], x, y) then
						return group, member;
					end
				end
				return group, nil;
			end
		end
	end
	return nil, nil;
end

function RSUM_SaveFramePosition(frame)
	saved_frame.frame = frame;
	saved_frame.numpoints = frame:GetNumPoints();
	for i=1,saved_frame.numpoints,1 do
		local point, relativeTo, relativePoint, xoff, yoff = frame:GetPoint(i);
		saved_frame.points[i] = {["point"] = point, ["relativeTo"] = relativeTo, ["relativePoint"] = relativePoint, ["xoff"] = xoff, ["yoff"] = yoff};
	end
end

function RSUM_ReturnSavedFramePosition()
	if saved_frame.frame then
		for i=1,saved_frame.numpoints,1 do
			saved_frame.frame:SetPoint(saved_frame.points[i]["point"], saved_frame.points[i]["relativeTo"], saved_frame.points[i]["relativePoint"], saved_frame.points[i]["xoff"], saved_frame.points[i]["yoff"]);
		end
	end
end

function RSUM_GroupMemberFrameAnchoring(group, member)
	local f = groupmemberframes[group][member];
	local p = f:GetParent();
	local xoff = mw_padding;
	local yoff = mw_padding + (mw_height+mw_padding) * (member-1);
	groupmemberframes[group][member]:SetPoint("BOTTOMLEFT", p, "TOPLEFT", xoff, -yoff-mw_height);
	groupmemberframes[group][member]:SetPoint("BOTTOM", p, "TOPLEFT", xoff+mw_width/2, -yoff-mw_height);
	groupmemberframes[group][member]:SetPoint("BOTTOMRIGHT", p, "TOPLEFT", xoff+mw_width, -yoff-mw_height);
	groupmemberframes[group][member]:SetPoint("LEFT", p, "TOPLEFT", xoff, -yoff-mw_height/2);
	groupmemberframes[group][member]:SetPoint("RIGHT", p, "TOPLEFT", xoff+mw_width, -yoff-mw_height/2);
	groupmemberframes[group][member]:SetPoint("TOPLEFT", p, "TOPLEFT", xoff, -yoff);
	groupmemberframes[group][member]:SetPoint("TOP", p, "TOPLEFT", xoff+mw_width/2, -yoff);
	groupmemberframes[group][member]:SetPoint("TOPRIGHT", p, "TOPLEFT", xoff+mw_width, -yoff);
	groupmemberframes[group][member]:SetPoint("CENTER", p, "TOPLEFT", xoff+mw_width/2, -yoff-mw_height/2);
end

function RSUM_GroupMemberFrameHighlight(frame, enable)
	for i=1,frame:GetNumRegions(),1 do
		local texture = select(i,frame:GetRegions());
		if texture:GetObjectType() == "Texture" then
			if enable then
				texture:SetTexture(groupmemberframetexturehighlighted);
			else
				texture:SetTexture(groupmemberframetexture);
			end
		end
	end
end

function RSUM_GroupMemberFrameEmpty(frame)
	if frame and groupmemberframesempty[frame:GetName()] then
		return true;
	end
	return false;
end

function RSUM_UpdateGroupMemberWindow(window, name)
		if window:GetNumRegions() < 1 then
			print("window name")
			print(window:GetName());
			return false;
		end
		local fontstring;
		for i=1,window:GetNumRegions(),1 do
			fontstring = select(i, window:GetRegions());
			if fontstring:GetObjectType() == "FontString" then
				break;
			end
		end
		if fontstring == nil then
			return false;
		end
		
		local color;
		if name == nil then
			name = "empty"
			color = {["r"] = 0.8, ["g"] = 0.8, ["b"] = 0.8, ["a"] = 0.8};
		else
			color = RAID_CLASS_COLORS[vraidmembers[name]["class"]];
		end
		
		fontstring:SetTextColor(color.r, color.g, color.b, color.a);
		fontstring:SetText(name);
		return true;
end

function RSUM_UpdateWindows()
		for group=1,maxgroups,1 do
			for member = 1,maxmembers,1 do
				if vgroupassignment[group] and vgroupassignment[group][member] then
					RSUM_UpdateGroupMemberWindow(groupmemberframes[group][member], vgroupassignment[group][member])
					groupmemberframesempty[groupmemberframes[group][member]:GetName()] = nil;
				else
					RSUM_UpdateGroupMemberWindow(groupmemberframes[group][member], nil);
					groupmemberframesempty[groupmemberframes[group][member]:GetName()] = true;
				end
			end
		end
end


-- ---- Window Initiation ----
local function RSUM_Window_Init()
		-- Transform Player
		--if PlayerHasToy(116400) then
		--	UseToy(116400);
		--end

		mainframe = CreateFrame("Frame", "rsummainframe", UIParent);
		mainframe:RegisterEvent("GROUP_ROSTER_UPDATE");
		mainframe:SetScript("OnEvent", RSUM_OnEvent);
		mainframe:Show();
		
		local texture = nil;
		local font = "Fonts\\FRIZQT__.TTF", 12, "";
		local fontstring = nil;
		local button = nil;
		windowframe = CreateFrame("Frame", "rsummainwindow", UIParent);
		windowframe:SetWidth(gw_padding * 3 + gw_width * 2);
		windowframe:SetHeight(gw_padding * 5 + gw_height * 4 + button_height + gw_padding);
		windowframe:SetPoint("CENTER", 0, 0);
		windowframe:SetFrameStrata("FULLSCREEN");
		windowframe:SetMovable(true);
		texture = windowframe:CreateTexture("rsummainwindowtexture");
		texture:SetAllPoints(texture:GetParent());
		texture:SetTexture(mainwindowframetexture);
		
		-- buttons:
		button = CreateFrame("Button", "rsumexitbutton", windowframe, "UIPanelCloseButton");
		button:SetWidth(exitbutton_width);
		button:SetHeight(exitbutton_height);
		button:SetPoint("CENTER", button:GetParent(), "TOPRIGHT", exitbutton_offx, exitbutton_offy);
		button:EnableMouse(true);
		button:Enable();
		button:RegisterForClicks("LeftButtonUp");
		button:SetScript("OnClick", function(s) windowframe:Hide(); end);
		
		button = CreateFrame("Button", "rsumrefreshbutton", windowframe, "UIPanelButtonTemplate");
		button:SetWidth(button_width);
		button:SetHeight(button_height);
		button:SetPoint("BOTTOMLEFT", button:GetParent(), "BOTTOMLEFT", gw_padding, gw_padding);
		button:SetPoint("TOPRIGHT", button:GetParent(), "BOTTOMLEFT", gw_padding+button_width, gw_padding+button_height);
		--button:SetNormalTexture(buttontexture);
		--button:SetHighlightTexture(buttontexturehighlighted);
		button:SetText("Undo Changes");
		button:EnableMouse(true);
		button:Enable();
		button:RegisterForClicks("LeftButtonUp");
		button:SetScript("OnClick", function(s) RSUM_UpdateVGroup(); end);
		button:SetScript("OnEnter", function(s) GameTooltip:SetOwner(s); GameTooltip:AddLine("Carefull!!!", 1, 0, 0); GameTooltip:AddLine("This will overwrite the virtual groups"); GameTooltip:Show(); end);
		button:SetScript("OnLeave", function(s) GameTooltip:Hide(); end);
		
		button = CreateFrame("Button", "rsumapplybutton", windowframe, "UIPanelButtonTemplate");
		button:SetWidth(button_width);
		button:SetHeight(button_height);
		button:SetPoint("BOTTOMRIGHT", button:GetParent(), "BOTTOMRIGHT", -gw_padding, gw_padding);
		button:SetPoint("TOPLEFT", button:GetParent(), "BOTTOMRIGHT", -gw_padding-button_width, gw_padding+button_height);
		--button:SetNormalTexture(buttontexture);
		--button:SetHighlightTexture(buttontexturehighlighted);
		button:SetText("Apply Changes");
		button:EnableMouse(true);
		button:Enable();
		button:RegisterForClicks("LeftButtonUp");
		button:SetScript("OnClick", function(s) RSUM_BuildGroups(); end);
		button:SetScript("OnEnter", function(s) applyButtonMouseOver = true; GameTooltip:SetOwner(s); GameTooltip:AddLine("Apply Changes to Raid", 1, 0, 0); GameTooltip:AddLine("Can't be done to members in combat"); GameTooltip:Show(); end);
		button:SetScript("OnLeave", function(s) applyButtonMouseOver = false; GameTooltip:Hide(); end);
		button:SetScript("OnUpdate", RSUM_ApplyButtonOnUpdate);
		
		-- title region:
		local titleregion = CreateFrame("Frame", "rsummainwindowtitleregion", windowframe);
		titleregion:SetWidth(titleregion_width);
		titleregion:SetHeight(titleregion_height);
		titleregion:SetPoint("CENTER", titleregion:GetParent(), "TOP", 0, titleregion_offy);
		titleregion:EnableMouse(true);
		titleregion:RegisterForDrag("LeftButton");
		titleregion:SetScript("OnDragStart", function(s) s:GetParent():StartMoving(); end);
		titleregion:SetScript("OnDragStop", function(s) s:GetParent():StopMovingOrSizing(); end);
		titleregion:SetScript("OnHide", function(s) s:GetParent():StopMovingOrSizing(); end);
		texture = windowframe:CreateTexture("rsumtitleregiontexture");
		texture:SetAllPoints(titleregion);
		texture:SetTexture(titleregiontexture);
		fontstring = windowframe:CreateFontString("rsumtitleregionfontstring");
		fontstring:SetAllPoints(titleregion);
		if not fontstring:SetFont("Fonts\\FRIZQT__.TTF", 12, "") then
			print("Font not valid");
		end
		fontstring:SetJustifyH("CENTER");
		fontstring:SetJustifyV("CENTER");
		fontstring:SetText(titleregiontext);
		
		
		-- group slots:
		for group=1,maxgroups,1 do
			groupframes[group] = CreateFrame("Frame","rsumgroupwindow" .. group, windowframe)
			groupframes[group]:SetWidth(gw_width);
			groupframes[group]:SetHeight(gw_height);
			local y = gw_padding + floor((group-1) / 2) * (gw_height + gw_padding);
			local x;
			if floor((group-1) / 2) == (group-1) / 2 then
				x = gw_padding;
			else
				x = gw_padding * 2 + mw_width;
			end
			groupframes[group]:SetPoint("TOPLEFT",x,-y);
			
			local texture = groupframes[group]:CreateTexture("rsumgroupmemberwindowtexture" .. group);
			texture:SetAllPoints(texture:GetParent());
			texture:SetTexture(groupframetexture);
			
			
			groupmemberframes[group] = {};
			for member=1,maxmembers,1 do
				groupmemberframes[group][member] = CreateFrame("Frame","rsumgroup" .. group .. "memberwindow" .. member, groupframes[group]);
				RSUM_GroupMemberFrameAnchoring(group, member);
				
				local texture = groupmemberframes[group][member]:CreateTexture("rsumgroup" .. group .. "memberwindowtexture" .. member);
				local fontstring = groupmemberframes[group][member]:CreateFontString("rsumgroup" .. group .. "memberwindowstring" .. member);
				texture:SetAllPoints(texture:GetParent());
				texture:SetTexture(groupmemberframetexture);
				fontstring:SetAllPoints(fontstring:GetParent());
				fontstring:SetJustifyH("CENTER");
				fontstring:SetJustifyV("CENTER");
				local font_valid = fontstring:SetFont("Fonts\\FRIZQT__.TTF", 12, "");
				if not font_valid then
					print("Font not valid");
				end
				groupmemberframes[group][member]:SetFrameStrata("FULLSCREEN");
				groupmemberframes[group][member]:RegisterForDrag("LeftButton");
				groupmemberframes[group][member]:SetMovable(true);
				groupmemberframes[group][member]:EnableMouse(true);
				groupmemberframes[group][member]:SetScript("OnDragStart", RSUM_OnDragStart);
				groupmemberframes[group][member]:SetScript("OnDragStop", RSUM_OnDragStop);
				groupmemberframes[group][member]:SetScript("OnEnter", RSUM_OnEnter);
				groupmemberframes[group][member]:SetScript("OnLeave", RSUM_OnLeave);
				
			end
		end
		
end

RSUM_ApplyButtonOnUpdate = function(s)
	if applyButtonMouseOver then
		local tomove, incombat = RSUM_GetNumRaidMembersToMove();
		GameTooltip:SetText("Apply changes to raid", 1, 0, 0);
		GameTooltip:AddDoubleLine("Players to move:", tomove);
		GameTooltip:AddDoubleLine("which are in combat:", incombat);
		GameTooltip:Show();
	end
end

RSUM_OnEnter = function(s)
	if RSUM_GroupMemberFrameEmpty(s) == true then
		return;
	end
	RSUM_GroupMemberFrameHighlight(s, true);
end

RSUM_OnLeave = function(s)
	RSUM_GroupMemberFrameHighlight(s, false);
end

RSUM_OnDragStart = function(s, ...)
	if RSUM_GroupMemberFrameEmpty(s) == true then
		return;
	end
	RSUM_SaveFramePosition(s);
	s:SetFrameStrata("TOOLTIP");
	s:StartMoving();
end

RSUM_OnDragStop = function(s, ...)
	if RSUM_GroupMemberFrameEmpty(s) == true then
		return;
	end
	s:StopMovingOrSizing();
	RSUM_ReturnSavedFramePosition();
	s:SetFrameStrata("FULLSCREEN");
	
	local mousex, mousey = GetCursorPosition();
	local scale = UIParent:GetEffectiveScale();
	mousex = mousex / scale;
	mousey = mousey / scale;
	local targetgroup, targetmember = RSUM_GroupMemberFrameContainsPoint(mousex, mousey);
	if targetgroup then
		local sourcegroup, sourcemember = RSUM_GetGroupMemberByFrame(s)
		if targetmember then
			if vgroupassignment[targetgroup][targetmember] == nil then
				RSUM_MoveVMember(sourcegroup, sourcemember, targetgroup);
			else
				RSUM_SwapVMember(sourcegroup, sourcemember, targetgroup, targetmember);
			end
		else
			RSUM_MoveVMember(sourcegroup, sourcemember, targetgroup);
		end
		
		local nummembers, _ = RSUM_GetNumRaidMembersToMove();
		if nummembers > 0 then
			vgroups_insync = false;
		else
			vgroups_insync = true;
		end
		RSUM_UpdateWindows();
	end
end

RSUM_Debug_OnUpdate = function(s)
	
end

function RSUM_Debug_Init()
	debugframe = CreateFrame("Frame", "rsumdebug", UIParent);
	debugframe:SetPoint("CENTER", 0, -340);
	debugframe:SetSize(400, 80);
	debugfontstring = debugframe:CreateFontString("rsumdebugfontstring");
	debugfontstring:SetFont("Fonts\\FRIZQT__.TTF", 12, "");
	debugfontstring:SetAllPoints(debugfontstring:GetParent());
	debugfontstring:SetJustifyH("CENTER");
	debugfontstring:SetJustifyV("CENTER");
	debugframe:SetScript("OnUpdate", RSUM_Debug_OnUpdate);
	debugframe:Show();
	
end

function RSUM_Show()
		windowframe:Show();
end

function RSUM_Hide()
		windowframe:Hide();
end

function RSUM_Init()
		if not initiated then
			RSUM_Window_Init();
			RSUM_UpdateVGroup();
			RSUM_UpdateWindows();
			RSUM_Debug_Init();
			initiated = true;
		else
			print("RSUM is already initiated");
		end
end

RSUM_OnEvent = function(self, event, ...)
	if event == "GROUP_ROSTER_UPDATE" then
		RSUM_GroupRosterUpdate();
	end
end