-- important variables
local window_update = true;

-- UI Element Pointers
local number = 0;
local mainframe;
local windowframe;
local groupframes = {};
local groupmemberframes = {};	-- groupmemberframes[group] = {player1frame, player2frame....}
local groupmemberframesempty = {} -- groupmemberframes[framename] = true / nil
local applyButtonMouseOver = false;
local maxgroups = RSUM_MAXGROUPS;
local maxmembers = RSUM_MAXMEMBERS;

-- Drag Action
local saved_frame = {["frame"] = nil, ["numpoints"] = 0, ["points"] = {}};		-- saved_frame["points"] = {point1, point2, ...} -- point1 = {"point", "relativeTo", "relativePoint", "xoff", "yoff"}


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
			color = RAID_CLASS_COLORS[RSUM_GetMemberClass(name)];
		end
		
		fontstring:SetTextColor(color.r, color.g, color.b, color.a);
		fontstring:SetText(name);
		return true;
end

function RSUM_UpdateWindows()
	window_update = true;
end

RSUM_OnWindowUpdate = function()
	if window_update then
		for group=1,maxgroups,1 do
			for member = 1,maxmembers,1 do
				local name = RSUM_GroupMember(group, member);
				if name then
					RSUM_UpdateGroupMemberWindow(groupmemberframes[group][member], name);
					groupmemberframesempty[groupmemberframes[group][member]:GetName()] = nil;
				else
					RSUM_UpdateGroupMemberWindow(groupmemberframes[group][member], nil);
					groupmemberframesempty[groupmemberframes[group][member]:GetName()] = true;
				end
			end
		end
	end
	window_update = false;

end


-- ---- Window Initiation ----
function RSUM_Window_Init()
		-- Transform Player
		--if PlayerHasToy(116400) then
		--	UseToy(116400);
		--end

		mainframe = CreateFrame("Frame", "rsummainframe", UIParent);
		mainframe:RegisterEvent("GROUP_ROSTER_UPDATE");
		mainframe:SetScript("OnEvent", RSUM_OnEvent);
		mainframe:SetScript("OnUpdate", RSUM_OnWindowUpdate);
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
		button:SetText("Undo Changes / Reload");
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
	if RSUM_GroupMemberFrameEmpty(s) then
		s:StopMovingOrSizing();
		RSUM_ReturnSavedFramePosition();
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
			if RSUM_GroupMember(targetgroup, targetmember) == nil then
				RSUM_MoveVMember(sourcegroup, sourcemember, targetgroup);
			else
				RSUM_SwapVMember(sourcegroup, sourcemember, targetgroup, targetmember);
			end
		else
			RSUM_MoveVMember(sourcegroup, sourcemember, targetgroup);
		end
		
		local nummembers, _ = RSUM_GetNumRaidMembersToMove();
		if nummembers > 0 then
			RSUM_GroupSync(false);
		else
			RSUM_GroupSync(true);
		end
		RSUM_UpdateWindows();
	end
end




RSUM_OnEvent = function(self, event, ...)
	if event == "GROUP_ROSTER_UPDATE" then
		RSUM_GroupRosterUpdate();
	end
end


function RSUM_Toggle()
	if windowframe:IsShown() then
		windowframe:Hide();
	else
		windowframe:Show();
	end
end

function RSUM_Show()
		windowframe:Show();
end

function RSUM_Hide()
		windowframe:Hide();
end