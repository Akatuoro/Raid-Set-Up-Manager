-- important variables
local window_update = true;
local addon, ns = ...

-- UI Element Pointers
local number = 0;
local mainframe;
local windowframe;
local windowframetexture;
local groupframes = {};
local groupmemberframes = {};	-- groupmemberframes[group] = {player1frame, player2frame....}
local groupmemberframesempty = {} -- groupmemberframes[framename] = true / nil
local applyButtonMouseOver = false;
local groupmemberframedropdown;
local maxgroups = RSUM_MAXGROUPS;
local maxmembers = RSUM_MAXMEMBERS;

-- Options UI Element Pointers
local optionsframe = false;

-- savenload UI Element Pointers
local savenloadframe = false;
local savenloadmenutable = {};
local savenloaddropdownmenu = nil;

local newmember_class = "WARRIOR";
local newmember_class_texture = nil;
local newmember_editbox = nil;

-- side frame table
local sideframetable = {["Options"] = optionsframe, ["SaveNLoad"] = savenloadframe};
local sideframebuttontable = {};

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
local symbolbutton_height = 32;
local symbolbutton_width = 32;

local options_height = 400;
local options_width = 300;
local sidewindow_offx = 0;
local sidewindow_offy = -40;

-- visuals (aka textures, maybe fonts):
local mainwindowframecolor = {0,0,0,0.9};
local mainwindowframevirtualcolor = {0,0,0.2,0.9};
local titleregioncolor = {0.1,0,0,1};
local buttoncolor = {0.2,0,0,1};
local buttoncolorhighlighted = {0.4,0,0,1};
local groupframecolor = {0,0,0,1};
local groupmemberframecolor = {0.1,0,0,1};
local groupmemberframecolorhighlighted = {0.4,0,0,1};
local sidewindowframecolor = {0,0,0,1};
local savenloadsymboltexture = "Interface\\AddOns\\RSUM\\Media\\button_savenload.tga";
local savenloadsymboltexturehighlighted = "Interface\\AddOns\\RSUM\\Media\\button_savenloadhighlighted.tga";
local savenloadsymboltexturepressed = "Interface\\AddOns\\RSUM\\Media\\button_savenloadpressed.tga";
local optionssymboltexture = "Interface\\AddOns\\RSUM\\Media\\button_options.tga";
local optionssymboltexturehighlighted = "Interface\\AddOns\\RSUM\\Media\\button_optionshighlighted.tga";
local optionssymboltexturepressed = "Interface\\AddOns\\RSUM\\Media\\button_optionspressed.tga";

-- Tex Coords
local roleTexCoords = {DAMAGER = {left = 0.3125, right = 0.609375, top = 0.328125, bottom = 0.625}, HEALER = {left = 0.3125, right = 0.609375, top = 0.015625, bottom = 0.3125}, TANK = {left = 0, right = 0.296875, top = 0.328125, bottom = 0.625}};

-- descriptions
local titleregiontext = "Raid Set Up Manager";


-- popup dialogs:
StaticPopupDialogs["RSUM_SAVENLOAD_CREATE"] = {
	text = "Enter a name for the setup:",
	button1 = "Accept",
	button2 = "Cancel",
	OnAccept = function(s, data)
		local text = s.editBox:GetText();
		RSUM_SaveNLoadCreate(text);
		end,
	hasEditBox = true,
	timeout = 0,
	whileDead = true,
	hideOnEscape = true,
	preferredIndex = 3
}

StaticPopupDialogs["RSUM_SAVENLOAD_DELETE"] = {
	text = "Do you really want to delete the setup %s?",
	button1 = "Delete",
	button2 = "Cancel",
	OnAccept = function(s, data)
		RSUM_SaveNLoadDelete();
		end,
	timeout = 0,
	whileDead = true,
	hideOnEscape = true,
	preferredIndex = 3
}

StaticPopupDialogs["RSUM_SAVENLOAD_CHANGENAME"] = {
	text = "Enter a new name for setup %s :",
	button1 = "Accept",
	button2 = "Cancel",
	OnAccept = function(s, data)
		local text = s.editBox:GetText();
		RSUM_SaveNLoadChangeName(text);
		end,
	hasEditBox = true,
	timeout = 0,
	whileDead = true,
	hideOnEscape = true,
	preferredIndex = 3
}

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
function ns.gm.MemberFrameContainsPoint(x, y)
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

function ns.gm.MemberFrameAnchoring(group, member)
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

function ns.gm.MemberFrameHighlight(frame, enable)
	if enable then
		frame.background:SetColorTexture(unpack(groupmemberframecolorhighlighted));
	else
		frame.background:SetColorTexture(unpack(groupmemberframecolor));
	end
end

function ns.gm.MemberFrameEmpty(frame)
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
		
		local color;
		if name == nil then
			name = "empty"
			color = {["r"] = 0.8, ["g"] = 0.8, ["b"] = 0.8, ["a"] = 0.8};
			window.roleTexture:Hide();
		else
			local class = ns.mm.GetClass(name);
			if class then
				color = RAID_CLASS_COLORS[class];
			else
				color = {r = 0.8, g = 0.8, b = 0.8, a = 1.0};
			end
			local role = ns.mm.GetRole(name);
			if role and roleTexCoords[role] then
				window.roleTexture:SetTexCoord(roleTexCoords[role].left, roleTexCoords[role].right, roleTexCoords[role].top, roleTexCoords[role].bottom);
				window.roleTexture:Show();
			else
				window.roleTexture:Hide();
			end
		end
		
		window.nameText:SetTextColor(color.r, color.g, color.b, color.a);
		window.nameText:SetText(name);
		return true;
end

function RSUM_UpdateWindows()
	window_update = true;
end

local function RSUM_StatusTextUpdate()
	local mode, sync, apply, number, combat = ns.GetStatus();
	local firstline, secondline = "", "";
	
	if mode == "standard" then
		if sync == true then
			firstline = "Standard mode";
			secondline = "";
		else
			if apply then
				firstline = "Applying Changes";
			else
				firstline = "Changes have been made";
			end
			secondline = "Changes: " .. tostring(number) .. " Combat: " .. tostring(combat);
		end
	elseif mode == "ultravirtual" then
		firstline = "Modifying a template";
	end
	
	windowframe.status:SetText(firstline .. "\n" .. secondline);
end

RSUM_OnWindowUpdate = function()
	if window_update then
		if ns.Option("sortmembersingroup") then
			for group=1,maxgroups,1 do
				ns.gm.SortByName(group)
			end
		end
		for group=1,maxgroups,1 do
			for member = 1,maxmembers,1 do
				local name = ns.gm.Member(group, member);
				if name then
					RSUM_UpdateGroupMemberWindow(groupmemberframes[group][member], name);
					groupmemberframesempty[groupmemberframes[group][member]:GetName()] = nil;
				else
					RSUM_UpdateGroupMemberWindow(groupmemberframes[group][member], nil);
					groupmemberframesempty[groupmemberframes[group][member]:GetName()] = true;
				end
			end
		end
		RSUM_StatusTextUpdate();
	end
	window_update = false;
	
	RSUM_TimedEvents();
	
end


function RSUM_SetVirtualTexture()
	windowframe.texture:Hide();
	windowframe.texturevirtual:Show();
end

function RSUM_SetStandardTexture()
	windowframe.texture:Show();
	windowframe.texturevirtual:Hide();
end


function ns.gm.MemberFrameDropdown_Initialize(frame, level, menuList)
	local group, member = RSUM_GetGroupMemberByFrame(frame:GetParent());
	if group and member then
		local info;
		if level == 1 then
			info = UIDropDownMenu_CreateInfo();
			info.text = ns.gm.Member(RSUM_GetGroupMemberByFrame(frame:GetParent()));
			info.isTitle = true;
			info.notCheckable = true;
			UIDropDownMenu_AddButton(info);
		
			info = UIDropDownMenu_CreateInfo();
			info.text = "Change Class";
			info.hasArrow = true;
			info.notCheckable = true;
			info.menuList = "Change Class";
			UIDropDownMenu_AddButton(info);
			
			info = UIDropDownMenu_CreateInfo();
			info.text = "Remove";
			info.func = function(s, arg1, arg2, checked) local group, member = RSUM_GetGroupMemberByFrame(arg1:GetParent()); ns.gm.Remove(group, member); RSUM_UpdateWindows(); end;
			info.arg1 = frame;
			info.notCheckable = true;
			UIDropDownMenu_AddButton(info);
			
			info = UIDropDownMenu_CreateInfo();
			info.text = "Cancel";
			info.notCheckable = true;
			UIDropDownMenu_AddButton(info);
		
		elseif menuList == "Change Class" then
			for k, v in pairs(CLASS_ICON_TCOORDS) do
				info = UIDropDownMenu_CreateInfo();
				info.text = k;
				info.arg1 = frame;
				frame.mm = ns.mm
				info.arg2 = k;
				info.func = function(s,arg1,arg2,checked) local group, member = RSUM_GetGroupMemberByFrame(arg1:GetParent()); arg1.mm.ChangeClass(group, member, arg2); CloseDropDownMenus(); end;
				info.notCheckable = true;
				UIDropDownMenu_AddButton(info, level);
			end
		
		end
	end
end

-- ---- Window Initiation ----
function RSUM_Window_Init()
		-- Transform Player
		--if PlayerHasToy(116400) then
		--	UseToy(116400);
		--end

		mainframe = CreateFrame("Frame", "rsummainframe", UIParent);
		mainframe:RegisterEvent("GROUP_ROSTER_UPDATE");
		mainframe:RegisterEvent("CHAT_MSG_SYSTEM");
		mainframe:SetScript("OnEvent", RSUM_OnEvent);
		mainframe:SetScript("OnUpdate", RSUM_OnWindowUpdate);
		mainframe:Show();
		ns.mainframe = mainframe;
		
		local texture = nil;
		local font = "Fonts\\FRIZQT__.TTF", 12, "";
		local fontstring = nil;
		local button = nil;
		windowframe = CreateFrame("Frame", "rsummainwindow", UIParent);
		windowframe:SetWidth(gw_padding * 3 + gw_width * 2);
		windowframe:SetHeight(gw_padding * 5 + gw_height * 4 + button_height * 2 + gw_padding * 2 + symbolbutton_height + gw_padding);
		windowframe:SetPoint("CENTER", 0, 0);
		windowframe:SetFrameStrata("FULLSCREEN");
		windowframe:SetMovable(true);
		windowframetexture = windowframe:CreateTexture("rsummainwindowtexture");
		windowframetexture:SetAllPoints(windowframetexture:GetParent());
		windowframetexture:SetColorTexture(unpack(mainwindowframecolor));
		windowframe.texture = windowframetexture;
		
		texture = windowframe:CreateTexture("rsummainwindowtexturevirtual");
		texture:SetAllPoints(texture:GetParent());
		texture:SetColorTexture(unpack(mainwindowframevirtualcolor));
		texture:Hide();
		windowframe.texturevirtual = texture;
		
		-- symbol button line:
		button = CreateFrame("Button", "rsumoptionssymbolbutton", windowframe);
		button:SetSize(symbolbutton_width, symbolbutton_height);
		button:SetPoint("TOPRIGHT", -gw_padding, -gw_padding);
		button:Enable();
		button:RegisterForClicks("LeftButtonDown");
		button:SetScript("OnClick", function(s) RSUM_SideWindow("Options"); end);
		button:SetScript("OnEnter", function(s) if not s.down then s.texture:Hide(); s.highlighted:Show(); end end);
		button:SetScript("OnLeave", function(s) if not s.down then s.texture:Show(); s.highlighted:Hide(); end end);
		button:Show();
		
		texture = button:CreateTexture("rsumoptionssymbolbuttoncolor");
		texture:SetTexture(optionssymboltexture);
		texture:SetAllPoints(texture:GetParent());
		texture:Show();
		button.texture = texture;
		
		texture = button:CreateTexture("rsumoptionssymbolbuttoncolorhighlighted");
		texture:SetTexture(optionssymboltexturehighlighted);
		texture:SetAllPoints(texture:GetParent());
		texture:Hide();
		button.highlighted = texture;
		
		texture = button:CreateTexture("rsumoptionssymbolbuttoncolorpressed");
		texture:SetTexture(optionssymboltexturepressed);
		texture:SetAllPoints(texture:GetParent());
		texture:Hide();
		button.pressed = texture;
		
		button.down = false;
		sideframebuttontable["Options"] = button;
		
		
		button = CreateFrame("Button", "rsumsavenloadsymbolbutton", windowframe);
		button:SetSize(symbolbutton_width, symbolbutton_height);
		button:SetPoint("TOPRIGHT", -gw_padding * 2 - symbolbutton_width, -gw_padding);
		button:Enable();
		button:RegisterForClicks("LeftButtonDown");
		button:SetScript("OnClick", function(s) RSUM_SideWindow("SaveNLoad"); end);
		button:SetScript("OnEnter", function(s) if not s.down then s.texture:Hide(); s.highlighted:Show(); end end);
		button:SetScript("OnLeave", function(s) if not s.down then s.texture:Show(); s.highlighted:Hide(); end end);
		button:Show();
		
		texture = button:CreateTexture("rsumsavenloadsymbolbuttoncolor");
		texture:SetTexture(savenloadsymboltexture);
		texture:SetAllPoints(texture:GetParent());
		texture:Show();
		button.texture = texture;
		
		texture = button:CreateTexture("rsumsavenloadsymbolbuttoncolorhighlighted");
		texture:SetTexture(savenloadsymboltexturehighlighted);
		texture:SetAllPoints(texture:GetParent());
		texture:Hide();
		button.highlighted = texture;
		
		texture = button:CreateTexture("rsumsavenloadsymbolbuttoncolorpressed");
		texture:SetTexture(savenloadsymboltexturepressed);
		texture:SetAllPoints(texture:GetParent());
		texture:Hide();
		button.pressed = texture;
		
		button.down = false;
		sideframebuttontable["SaveNLoad"] = button;
		
		-- status text area
		local frame = CreateFrame("Frame", "$PARENTstatusframe", windowframe);
		frame:SetPoint("TOPLEFT", gw_padding, -gw_padding);
		frame:SetPoint("BOTTOMRIGHT", button, "BOTTOMLEFT", -gw_padding, 0);
		local fontstring = frame:CreateFontString("$PARENTfontstring");
		
		if not fontstring:SetFont("Fonts\\FRIZQT__.TTF", floor(frame:GetHeight() / 2) - 1, "") then
			print("Font not valid");
		end
		fontstring:SetAllPoints();
		fontstring:Show();
		fontstring:SetJustifyH("CENTER");
		fontstring:SetJustifyV("CENTER");
		fontstring:SetTextColor(230/255, 190/255, 0, 1);
		fontstring:SetText("Initialized");
		windowframe.status = fontstring;
		
		-- raid quicksetup line - raid difficulty etc.
		local frame = CreateFrame("Frame", "$PARENT_quicksetupline", windowframe);
		frame:SetPoint("TOPLEFT", gw_padding, -gw_padding*2 - symbolbutton_height);
		frame:SetPoint("TOPRIGHT", -gw_padding, - gw_padding*2 - symbolbutton_height);
		frame:SetHeight(button_height);

		local button = CreateFrame("Button", "$PARENT_raidorgroup", frame, "UIGoldBorderButtonTemplate");
		button:SetSize(button_height, button_height);
		button:SetText("S");
		button:SetPoint("TOPLEFT", gw_padding, 0);
		button:SetScript("OnClick", ns.qs.RaidOrGroupToggle);
		button:SetScript("OnEnter", function(s) GameTooltip:SetOwner(s); GameTooltip:AddLine("Toggle between Group and Raid");
												if s:GetText() == "S" then GameTooltip:AddLine("Currently Solo"); end
												if s:GetText() == "G" then GameTooltip:AddLine("Currently in a Group"); end
												if s:GetText() == "R" then GameTooltip:AddLine("Currently in a Raid"); end GameTooltip:Show(); end);
		button:SetScript("OnLeave", function(s) GameTooltip:Hide(); end);
		ns.qs.raidorgroupbutton = button;

		local button = CreateFrame("Button", "$PARENT_normaldiff", frame, "UIGoldBorderButtonTemplate");
		button:SetSize(button_height, button_height);
		button:SetText("N");
		button:SetPoint("TOPLEFT", ns.qs.raidorgroupbutton, "TOPRIGHT", gw_padding, 0);
		button:SetScript("OnClick", ns.qs.SetNormalDifficulty);
		button:SetScript("OnEnter", function(s) GameTooltip:SetOwner(s); GameTooltip:AddLine("Normal Difficulty"); GameTooltip:Show(); end);
		button:SetScript("OnLeave", function(s) GameTooltip:Hide(); end);
		ns.qs.normaldiffbutton = button;

		local button = CreateFrame("Button", "$PARENT_heroicdiff", frame, "UIGoldBorderButtonTemplate");
		button:SetSize(button_height, button_height);
		button:SetText("H");
		button:SetPoint("TOPLEFT", ns.qs.normaldiffbutton, "TOPRIGHT", 0, 0);
		button:SetScript("OnClick", ns.qs.SetHeroicDifficulty);
		button:SetScript("OnEnter", function(s) GameTooltip:SetOwner(s); GameTooltip:AddLine("Heroic Difficulty"); GameTooltip:Show(); end);
		button:SetScript("OnLeave", function(s) GameTooltip:Hide(); end);
		ns.qs.heroicdiffbutton = button;

		local button = CreateFrame("Button", "$PARENT_mythicdiff", frame, "UIGoldBorderButtonTemplate");
		button:SetSize(button_height, button_height);
		button:SetText("M");
		button:SetPoint("TOPLEFT", ns.qs.heroicdiffbutton, "TOPRIGHT", 0, 0);
		button:SetScript("OnClick", ns.qs.SetMythicDifficulty);
		button:SetScript("OnEnter", function(s) GameTooltip:SetOwner(s); GameTooltip:AddLine("Mythic Difficulty"); GameTooltip:Show(); end);
		button:SetScript("OnLeave", function(s) GameTooltip:Hide(); end);
		ns.qs.mythicdiffbutton = button;

		ns.qs.Initiate(button);
		ns.qs.CheckButtons();

		
		-- buttons:
		button = CreateFrame("Button", "rsumexitbutton", windowframe, "UIPanelCloseButton");
		button:SetWidth(exitbutton_width);
		button:SetHeight(exitbutton_height);
		button:SetPoint("CENTER", button:GetParent(), "TOPRIGHT", exitbutton_offx, exitbutton_offy);
		button:Enable();
		button:RegisterForClicks("LeftButtonUp");
		button:SetScript("OnClick", function(s) windowframe:Hide(); end);
		
		button = CreateFrame("Button", "rsumrefreshbutton", windowframe, "UIPanelButtonTemplate");
		button:SetWidth(button_width);
		button:SetHeight(button_height);
		button:SetPoint("BOTTOMLEFT", button:GetParent(), "BOTTOMLEFT", gw_padding, gw_padding);
		button:SetPoint("TOPRIGHT", button:GetParent(), "BOTTOMLEFT", gw_padding+button_width, gw_padding+button_height);
		--button:SetNormalTexture(buttoncolor);
		--button:SetHighlightTexture(buttoncolorhighlighted);
		button:SetText("Undo Changes / Reload");
		button:Enable();
		button:RegisterForClicks("LeftButtonUp");
		button:SetScript("OnClick", function(s) ns.GoReal(); RSUM_UpdateVGroup(); end);
		
		button = CreateFrame("Button", "rsumapplybutton", windowframe, "UIPanelButtonTemplate");
		button:SetWidth(button_width);
		button:SetHeight(button_height);
		button:SetPoint("BOTTOMRIGHT", button:GetParent(), "BOTTOMRIGHT", -gw_padding, gw_padding);
		button:SetPoint("TOPLEFT", button:GetParent(), "BOTTOMRIGHT", -gw_padding-button_width, gw_padding+button_height);
		--button:SetNormalTexture(buttoncolor);
		--button:SetHighlightTexture(buttoncolorhighlighted);
		button:SetText("Apply Changes");
		button:Enable();
		button:RegisterForClicks("LeftButtonUp");
		button:SetScript("OnClick", function(s) RSUM_Apply(); ns.GoReal(); end);
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
		texture = windowframe:CreateTexture("rsumtitleregioncolor");
		texture:SetAllPoints(titleregion);
		texture:SetColorTexture(unpack(titleregioncolor));
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
			local y = symbolbutton_height + button_height + 3 * gw_padding + floor((group-1) / 2) * (gw_height + gw_padding);
			local x;
			if floor((group-1) / 2) == (group-1) / 2 then
				x = gw_padding;
			else
				x = gw_padding * 2 + mw_width;
			end
			groupframes[group]:SetPoint("TOPLEFT",x,-y);
			
			local texture = groupframes[group]:CreateTexture("rsumgroupmemberwindowtexture" .. group);
			texture:SetAllPoints(texture:GetParent());
			texture:SetColorTexture(unpack(groupframecolor));
			
			
			groupmemberframes[group] = {};
			for member=1,maxmembers,1 do
				groupmemberframes[group][member] = CreateFrame("Button","rsumgroup" .. group .. "memberwindow" .. member, groupframes[group]);
				ns.gm.MemberFrameAnchoring(group, member);
				
				local texture = groupmemberframes[group][member]:CreateTexture("rsumgroup" .. group .. "memberwindowtexture" .. member);
				local fontstring = groupmemberframes[group][member]:CreateFontString("rsumgroup" .. group .. "memberwindowstring" .. member);
				texture:SetAllPoints(texture:GetParent());
				texture:SetColorTexture(unpack(groupmemberframecolor));
				texture:SetDrawLayer("BACKGROUND", 0);
				groupmemberframes[group][member].background = texture;
				
				fontstring:SetPoint("TOP", 0, 0);
				fontstring:SetPoint("BOTTOM", 0, 0);
				fontstring:SetPoint("LEFT", fontstring:GetParent():GetHeight() + 4, 0);
				fontstring:SetPoint("RIGHT", -fontstring:GetParent():GetHeight() - 4, 0);
				fontstring:SetJustifyH("CENTER");
				fontstring:SetJustifyV("CENTER");
				local font_valid = fontstring:SetFont("Fonts\\FRIZQT__.TTF", 12, "");
				if not font_valid then
					print("Font not valid");
				end
				groupmemberframes[group][member].nameText = fontstring;
				
				texture = groupmemberframes[group][member]:CreateTexture();
				texture:SetPoint("LEFT", 4, 0);
				texture:SetPoint("RIGHT", texture:GetParent(), "LEFT", texture:GetParent():GetHeight() + 4, 0);
				texture:SetHeight(texture:GetParent():GetHeight());
				texture:SetTexture("Interface\\LFGFRAME\\UI-LFG-ICON-PORTRAITROLES.tga");
				texture:SetDrawLayer("OVERLAY", 7);
				groupmemberframes[group][member].roleTexture = texture;
				texture:Hide();
				
				groupmemberframes[group][member]:SetFrameStrata("FULLSCREEN");
				groupmemberframes[group][member]:RegisterForDrag("LeftButton");
				groupmemberframes[group][member]:RegisterForClicks("RightButtonDown");
				groupmemberframes[group][member]:SetMovable(true);
				groupmemberframes[group][member]:EnableMouse(true);
				groupmemberframes[group][member]:SetScript("OnDragStart", RSUM_OnDragStart);
				groupmemberframes[group][member]:SetScript("OnDragStop", RSUM_OnDragStop);
				groupmemberframes[group][member]:SetScript("OnEnter", RSUM_OnEnter);
				groupmemberframes[group][member]:SetScript("OnLeave", RSUM_OnLeave);
				groupmemberframes[group][member]:SetScript("OnClick", function(s) if savenloadframe and savenloadframe:IsShown() and not groupmemberframesempty[s:GetName()] then ToggleDropDownMenu(1, nil, s.dropdown, "cursor", 0, 0); end end);
				
				groupmemberframes[group][member].dropdown = CreateFrame("Frame", "rsumgroup" .. group .. "memberwindow" .. member .. "dropdown", groupmemberframes[group][member], "UIDropDownMenuTemplate");
				UIDropDownMenu_Initialize(groupmemberframes[group][member].dropdown, ns.gm.MemberFrameDropdown_Initialize);
				
			end
		end
		
end

function RSUM_OptionsWindow()
	if optionsframe == nil or optionsframe == false then
		RSUM_OptionsWindowInit();
		return;
	end
	if optionsframe:IsShown() then
		optionsframe:Hide();
	else
		optionsframe:Show();
	end
end


function RSUM_OptionsWindowInit()
	if optionsframe == nil or optionsframe == false then
		if windowframe then
			optionsframe = CreateFrame("Frame", "rsumoptionswindow", windowframe);
			optionsframe:SetPoint("TOPLEFT", windowframe, "TOPRIGHT", sidewindow_offx, sidewindow_offy);
			optionsframe:SetSize(button_width + gw_padding * 2, 350);
			local texture = optionsframe:CreateTexture();
			texture:SetColorTexture(unpack(sidewindowframecolor));
			texture:SetAllPoints(texture:GetParent());
			
			local fontstring = optionsframe:CreateFontString("rsumoptionsheader");
			fontstring:SetPoint("TOP", 0, -gw_padding);
			fontstring:SetSize(button_width, button_height);
			if not fontstring:SetFont("Fonts\\FRIZQT__.TTF", 12, "") then
				print("Font not valid");
			end
			fontstring:SetText("Options");
			
			local frame = CreateFrame("Frame", "rsumoptionsframe", optionsframe)
			frame:SetPoint("TOP", fontstring, "BOTTOM", 0, -gw_padding)
			frame:SetPoint("BOTTOM", 0, 0)
			frame:SetWidth(optionsframe:GetWidth())
			
			ns.CreateOptionFrames(frame)
		end
	end
end


RSUM_SaveNLoadCreatePopup = function(s)
	StaticPopup_Show("RSUM_SAVENLOAD_CREATE");
end

function RSUM_SaveNLoadCreate(name)
	if name then
		if ns.savedraid.Create(name) then
			RSUM_SaveNLoadSetSelected(name);
		else
			print("Failed to create setup " .. name);
			print("A setup with this name propably already exists.");
		end
	end
end

RSUM_SaveNLoadDeletePopup = function(s)
	local text = UIDropDownMenu_GetText(savenloaddropdownmenu);
	if text then
		StaticPopup_Show("RSUM_SAVENLOAD_DELETE", text);
	end
end

function RSUM_SaveNLoadDelete()
	local name = UIDropDownMenu_GetText(savenloaddropdownmenu);
	if name then
		ns.savedraid.Delete(name);
		RSUM_SaveNLoadSetSelected();
	end
end

RSUM_SaveNLoadChangeNamePopup = function(s)
	local text = UIDropDownMenu_GetText(savenloaddropdownmenu);
	if text then
		StaticPopup_Show("RSUM_SAVENLOAD_CHANGENAME", text);
	end
end

function RSUM_SaveNLoadChangeName(newname)
	local name = UIDropDownMenu_GetText(savenloaddropdownmenu);
	if name then
		ns.savedraid.ChangeName(name, newname);
		RSUM_SaveNLoadSetSelected(newname);
	end
end

function RSUM_SaveNLoadSetSelected(name)
	if name then
		UIDropDownMenu_SetText(savenloaddropdownmenu, name);
		savenloadframe.deletebutton:Enable();
		savenloadframe.changenamebutton:Enable();
	else
		UIDropDownMenu_SetText(savenloaddropdownmenu);
		savenloadframe.deletebutton:Disable();
		savenloadframe.changenamebutton:Disable();
	end
end

RSUM_SaveNLoadSave = function(s)
	local name = UIDropDownMenu_GetText(savenloaddropdownmenu);
	if name then
		ns.savedraid.Save(name);
	end
end

RSUM_SaveNLoadReload = function(s)
	local name = UIDropDownMenu_GetText(savenloaddropdownmenu);
	if name and not (name == "") then
		ns.savedraid.Load(name);
	end
end

function RSUM_SaveNLoadDropDown_Menu(frame, level, menuList)
	local info = UIDropDownMenu_CreateInfo()
	
	if level == 1 then
		local names = ns.savedraid.Names();
		if names then
			for k, v in ipairs(names) do
				info.text, info.arg1, info.func = v, v, function(s, arg1, arg2, checked) ns.savedraid.Load(arg1); RSUM_SaveNLoadSetSelected(arg1); end;
				UIDropDownMenu_AddButton(info);
			end
		end
	end
	local text = UIDropDownMenu_GetText(savenloaddropdownmenu);
	if text and not (text == "") then
		UIDropDownMenu_SetSelectedName(savenloaddropdownmenu, text);
	else
		UIDropDownMenu_SetSelectedName(savenloaddropdownmenu);
		UIDropDownMenu_SetText(savenloaddropdownmenu);
	end
end

function RSUM_NewMemberClassDropDownInitialize(frame, level, menuList)
	
	for class, v in pairs(CLASS_ICON_TCOORDS) do
		local info = {};
		info.text = class;
		info.func = function(s, arg1, arg2, checked) RSUM_SetNewMemberClass(arg1); end;
		info.arg1 = class;
		info.arg2 = frame;
		info.notCheckable = true;
		UIDropDownMenu_AddButton(info);
	end
end

function RSUM_SetNewMemberClass(class)
	newmember_class = class;
	newmember_class_texture:SetTexCoord(unpack(CLASS_ICON_TCOORDS[class]));
end

function RSUM_SaveNLoadImportDropDown(frame, level, menuList)
	local info;
	if level == 1 then
		info = UIDropDownMenu_CreateInfo();
		info.text = "Import from another setup";
		info.hasArrow = true;
		info.notCheckable = true;
		info.menuList = "setup";
		UIDropDownMenu_AddButton(info);
		
		info = UIDropDownMenu_CreateInfo();
		info.text = "Import from raid";
		info.notCheckable = true;
		info.func = RSUM_ImportFromRaid;
		UIDropDownMenu_AddButton(info);
		
		info = UIDropDownMenu_CreateInfo();
		info.text = "Cancel";
		info.notCheckable = true;
		UIDropDownMenu_AddButton(info);
		
	else
		if menuList == "setup" then
			local names = ns.savedraid.Names();
			if names then
				for k, v in ipairs(names) do
					info = UIDropDownMenu_CreateInfo();
					info.text = v;
					info.arg1 = v;
					info.func = function(s,name) ns.savedraid.Import(name); CloseDropDownMenus(); end;
					info.notCheckable = true;
					UIDropDownMenu_AddButton(info, level);
				end
			end
		end
	end
end

function RSUM_SaveNLoadWindowInit()
	if savenloadframe == nil or savenloadframe == false then
		if windowframe then
			savenloadframe = CreateFrame("Frame", "rsumsavenloadwindow", windowframe);
			savenloadframe:SetPoint("TOPLEFT", windowframe, "TOPRIGHT", sidewindow_offx, sidewindow_offy);
			savenloadframe:SetSize(button_width + gw_padding * 2, 200);
			savenloadframe:SetScript("OnHide", function(s) ns.GoReal(); end);
			savenloadframe:SetScript("OnShow", function(s) if savenloaddropdownmenu then
								local name = UIDropDownMenu_GetText(savenloaddropdownmenu);
								if name and not (name == "") then ns.savedraid.Load(name) end end end);
			local texture = savenloadframe:CreateTexture();
			texture:SetColorTexture(unpack(sidewindowframecolor));
			texture:SetAllPoints(texture:GetParent());
			
			local fontstring = savenloadframe:CreateFontString("rsumsavenloadheader");
			fontstring:SetPoint("TOP", 0, -gw_padding - 30);
			fontstring:SetSize(button_width, button_height);
			if not fontstring:SetFont("Fonts\\FRIZQT__.TTF", 12, "") then
				print("Font not valid");
			end
			fontstring:SetText("Add new raid member:");
			
			local width = savenloadframe:GetWidth() - 3 * button_height - 2 * mw_padding - 3 * gw_padding;
			savenloaddropdownmenu = CreateFrame("Frame", "rsumsavenloaddropdown", savenloadframe, "UIDropDownMenuTemplate");
			savenloaddropdownmenu:SetPoint("CENTER", savenloadframe, "TOPLEFT", gw_padding + width / 2, -gw_padding - button_height / 2 - 2);
			savenloaddropdownmenu:SetHeight(button_height);
			UIDropDownMenu_SetWidth(savenloaddropdownmenu, width);
			UIDropDownMenu_Initialize(savenloaddropdownmenu, RSUM_SaveNLoadDropDown_Menu);
			
			local button = CreateFrame("Button", "rsumsavenloadcreatebutton", savenloadframe, "UIGoldBorderButtonTemplate");
			button:SetSize(button_height, button_height);
			button:SetText("+");
			button:SetPoint("CENTER", savenloadframe, "TOPRIGHT", -button_height / 2 -gw_padding - mw_padding * 2 - button_height * 2, -button_height / 2 -gw_padding);
			button:SetScript("OnClick", RSUM_SaveNLoadCreatePopup);
			button:SetScript("OnEnter", function(s) GameTooltip:SetOwner(s); GameTooltip:AddLine("Add a new set up"); GameTooltip:Show(); end);
			button:SetScript("OnLeave", function(s) GameTooltip:Hide(); end);
			savenloadframe.createbutton = button;
			
			local button = CreateFrame("Button", "rsumsavenloaddeletebutton", savenloadframe, "UIGoldBorderButtonTemplate");
			button:SetSize(button_height, button_height);
			button:SetText("-");
			button:SetPoint("CENTER", savenloadframe, "TOPRIGHT", -button_height / 2 -gw_padding - mw_padding - button_height, -button_height / 2 -gw_padding);
			button:SetScript("OnClick", RSUM_SaveNLoadDeletePopup);
			button:SetScript("OnEnter", function(s) GameTooltip:SetOwner(s); GameTooltip:AddLine("Delete this set up"); GameTooltip:Show(); end);
			button:SetScript("OnLeave", function(s) GameTooltip:Hide(); end);
			button:Disable();
			savenloadframe.deletebutton = button;
			
			local button = CreateFrame("Button", "rsumsavenloadchangenamebutton", savenloadframe, "UIGoldBorderButtonTemplate");
			button:SetSize(button_height, button_height);
			button:SetText("*");
			button:SetPoint("CENTER", savenloadframe, "TOPRIGHT", -button_height / 2 -gw_padding, -button_height / 2 -gw_padding);
			button:SetScript("OnClick", RSUM_SaveNLoadChangeNamePopup);
			button:SetScript("OnEnter", function(s) GameTooltip:SetOwner(s); GameTooltip:AddLine("Change the name of this set up"); GameTooltip:Show(); end);
			button:SetScript("OnLeave", function(s) GameTooltip:Hide(); end);
			button:Disable();
			savenloadframe.changenamebutton = button;
			
			local button = CreateFrame("Button", "rsumsavenloadsavebutton", savenloadframe, "UIPanelButtonTemplate");
			button:SetPoint("BOTTOMLEFT", gw_padding, gw_padding);
			button:SetSize( (savenloadframe:GetWidth() - gw_padding * 2) / 2, button_height);
			button:SetText("Reload");
			button:SetScript("OnClick", RSUM_SaveNLoadReload);
			
			local button = CreateFrame("Button", "rsumsavenloadsavebutton", savenloadframe, "UIPanelButtonTemplate");
			button:SetPoint("BOTTOMRIGHT", -gw_padding, gw_padding);
			button:SetSize( (savenloadframe:GetWidth() - gw_padding * 2) / 2, button_height);
			button:SetText("Save");
			button:SetScript("OnClick", RSUM_SaveNLoadSave);
			
			local button = CreateFrame("Button", "rsumsavenloadclearbutton", savenloadframe, "UIPanelButtonTemplate");
			button:SetPoint("BOTTOMLEFT", gw_padding, gw_padding * 2 + button_height);
			button:SetSize( (savenloadframe:GetWidth() - gw_padding * 2) / 2, button_height);
			button:SetText("Clear");
			button:RegisterForClicks("AnyUp");
			button:SetScript("OnClick", function(s, button) if button == "LeftButton" then ns.GoVirtual(); ns.gm.Clear(); RSUM_UpdateWindows(); elseif button == "RightButton" then RSUM_RemoveNonRaidMembers(); end end);
			button:SetScript("OnEnter", function(s) GameTooltip:SetOwner(s); GameTooltip:AddLine("Left Click: Remove all members from setup."); 
																			 GameTooltip:AddLine("Right Click: Remove members currently not in the raid."); GameTooltip:Show(); end);
			button:SetScript("OnLeave", function(s) GameTooltip:Hide(); end);
			
			local button = CreateFrame("Button", "rsumsavenloadclearbutton", savenloadframe, "UIPanelButtonTemplate");
			button:SetPoint("BOTTOMRIGHT", -gw_padding, gw_padding * 2 + button_height);
			button:SetSize( (savenloadframe:GetWidth() - gw_padding * 2) / 2, button_height);
			button:SetText("Import");
			button:SetScript("OnClick", function(s) ToggleDropDownMenu(1, nil, s.dropdown, "cursor", 0, 0); end);
			
			button.dropdown = CreateFrame("Frame", "rsumsavenloadimportbutton", button, "UIDropDownMenuTemplate");
			UIDropDownMenu_Initialize(button.dropdown, RSUM_SaveNLoadImportDropDown);
			
			
			
			local newmemberbox = CreateFrame("Frame", nil, savenloadframe);
			newmemberbox:SetPoint("TOP", 0, -gw_padding * 2 - button_height - 20);
			newmemberbox:SetWidth(newmemberbox:GetParent():GetWidth() - gw_padding * 2);
			newmemberbox:SetHeight(400);
			
			local editbox = CreateFrame("EditBox", "rsumsavenloadnewmembereditbox", newmemberbox, "InputBoxTemplate");
			editbox:SetSize(button_width, button_height);
			editbox:SetPoint("TOPLEFT", 0, 0);
			editbox:ClearFocus();
			editbox:SetAutoFocus(false);
			editbox:SetText("player name");
			editbox:SetScript("OnKeyUp", function(s, key) if key == "ESC" or key == "ENTER" then s:ClearFocus(); end end);
			editbox:SetScript("OnEnterPressed", function(s) s:ClearFocus(); end);
			savenloadframe.newmembereditbox = editbox;
			newmember_editbox = editbox;
			
			local button = CreateFrame("Button", "rsumsavenloadnewmemberaddbutton", newmemberbox, "UIPanelButtonTemplate");
			button:SetPoint("TOPRIGHT", 0, -mw_padding - button_height);
			button:SetSize(50, button_height);
			button:SetText("Add");
			button:Enable();
			button:RegisterForClicks("AnyUp");
			button:SetScript("OnClick", function(s) ns.GoVirtual(); if ns.mm.Create(newmember_editbox:GetText(), newmember_class) then ns.gm.Add(newmember_editbox:GetText(), nil); end RSUM_UpdateWindows(); end);
			
			local button = CreateFrame("Button", "rsumsavenloadnewmemberclassbutton", newmemberbox);
			button:SetPoint("TOPLEFT", 0, -mw_padding - button_height);
			button:Enable();
			button:RegisterForClicks("AnyDown");
			button:SetScript("OnClick", function(s) ToggleDropDownMenu(1, nil, s.dropdown, "cursor", 0, 0); end);
			button:SetSize(button_height, button_height);
			
			button.dropdown = CreateFrame("Frame", "rsumsavenloadnewmemberclassdropdown", button);
			UIDropDownMenu_Initialize(button.dropdown, RSUM_NewMemberClassDropDownInitialize);
			
			button.texture = button:CreateTexture("rsumsavenloadnewmemberclasstexture");
			button.texture:SetAllPoints(button);
			button.texture:SetTexture("Interface\\GLUES\\CHARACTERCREATE\\UI-CHARACTERCREATE-CLASSES");
			button.texture:SetTexCoord(unpack(CLASS_ICON_TCOORDS[newmember_class]));
			newmember_class_texture = button.texture;
			
		end
	end
end

function RSUM_SideWindowInit(name)
	if name == "Options" then
		RSUM_OptionsWindowInit();
		sideframetable[name] = optionsframe;
		return true;
	end
	if name == "SaveNLoad" then 
		RSUM_SaveNLoadWindowInit();
		sideframetable[name] = savenloadframe;
		return true;
	end
end

local function RSUM_SideWindowButtonDown(name, value)
	if not sideframebuttontable[name] then
		return;
	end
	if value then
		sideframebuttontable[name].down = true;
		sideframebuttontable[name].texture:Hide();
		sideframebuttontable[name].highlighted:Hide();
		sideframebuttontable[name].pressed:Show();
	else
		sideframebuttontable[name].down = false;
		sideframebuttontable[name].texture:Show();
		sideframebuttontable[name].highlighted:Hide();
		sideframebuttontable[name].pressed:Hide();
	end
end

function RSUM_SideWindow(name)
	if name == nil then
		for k, v in pairs(sideframetable) do
			if v then
				v:Hide();
			end
		end
	end
	
	if not sideframetable[name] then
		if not RSUM_SideWindowInit(name) then
			return;
		end
		RSUM_SideWindowButtonDown(name, true);
	else
		if sideframetable[name]:IsShown() then
			sideframetable[name]:Hide();
			RSUM_SideWindowButtonDown(name, false);
		else
			sideframetable[name]:Show();
			RSUM_SideWindowButtonDown(name, true);
		end
	end
	
	for k, v in pairs(sideframetable) do
		if v and not (k == name) then
			v:Hide();
			RSUM_SideWindowButtonDown(k, false)
		end
	end
end

RSUM_OptionButton_Keybind_OnClick = function(s, ...)
	print("clicked");
	if s:IsKeyboardEnabled() then
		s:EnableKeyboard(false);
		return;
	end
	
	s:EnableKeyboard(true);
end

RSUM_OptionButton_Keybind_OnKeyUp = function(s, key)
	if key == "ESC" then
		s:EnableKeyboard(false);
		return;
	end
	
	local binding = key;
	if IsControlKeyDown() then
		binding = "CTRL-" .. binding;
	end
	if IsAltKeyDown() then
		binding = "ALT-" .. binding;
	end
	if IsShiftKeyDown() then
		binding = "SHIFT-" .. binding;
	end
	
	if RSUM_SetBinding(binding, "togglewindow") then
		s:SetText(binding);
		RSUM_Options["keybind_togglewindow"] = binding;
	end
	
	s:EnableKeyboard(false);
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
	if ns.gm.MemberFrameEmpty(s) == true then
		return;
	end
	ns.gm.MemberFrameHighlight(s, true);
end

RSUM_OnLeave = function(s)
	ns.gm.MemberFrameHighlight(s, false);
end

RSUM_OnDragStart = function(s, ...)
	if ns.gm.MemberFrameEmpty(s) == true then
		return;
	end
	RSUM_SaveFramePosition(s);
	s:SetFrameStrata("TOOLTIP");
	s:StartMoving();
end

RSUM_OnDragStop = function(s, ...)
	if ns.gm.MemberFrameEmpty(s) then
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
	local targetgroup, targetmember = ns.gm.MemberFrameContainsPoint(mousex, mousey);
	if targetgroup then
		local sourcegroup, sourcemember = RSUM_GetGroupMemberByFrame(s)
		if targetmember then
			if ns.gm.Member(targetgroup, targetmember) == nil then
				ns.gm.Move(sourcegroup, sourcemember, targetgroup);
			else
				ns.gm.Swap(sourcegroup, sourcemember, targetgroup, targetmember);
			end
		else
			ns.gm.Move(sourcegroup, sourcemember, targetgroup);
		end
		
		RSUM_GroupSync(false);
		RSUM_UpdateWindows();
	end
end




RSUM_OnEvent = function(self, event, ...)
	if event == "GROUP_ROSTER_UPDATE" then
		RSUM_GroupRosterUpdate();
	elseif event == "CHAT_MSG_SYSTEM" then
		ns.qs.CheckButtons();
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