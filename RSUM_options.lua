--Option Window

local addon, ns = ...

local options = {}
local optionsByKey = {}

function ns.Option(name)
	if optionsByKey[name] == nil then
		return nil
	end
	
	return RSUM_Options[name]
end

-- name: descriptor of option
-- parent: outside frame
-- text: description of the options
-- default: default value. has to be boolean
-- tooltip: text to show in game tooltip 
local function CreateCheckbox(name, default, parent, text, tooltip)
	local frame = CreateFrame("Frame", "$PARENT_" .. name, parent)
	frame:SetHeight(ns.buttonsize + ns.padding)
	
	local check = CreateFrame("CheckButton", "$PARENT_checkbutton", frame, "UICheckButtonTemplate")
	check:SetPoint("TOPLEFT", ns.padding, -ns.padding)
	check:SetSize(ns.buttonsize, ns.buttonsize)
	if RSUM_Options[name] == true then
		check:SetChecked(true)
	elseif RSUM_Options[name] == false then
		check:SetChecked(false)
	else
		check:SetChecked(default)
	end
	check.name = name
	check:SetScript("OnClick", function(s) RSUM_Options[s.name] = s:GetChecked(); end)
	if tooltip then
		check.tooltip = tooltip
		check:SetScript("OnEnter", function(s) GameTooltip:SetOwner(s); GameTooltip:AddLine(s.tooltip); GameTooltip:Show(); end)
		check:SetScript("OnLeave", function(s) GameTooltip:Hide(); end)
	end
	
	local fontstring = frame:CreateFontString("$PARENT_fontstring")
	fontstring:SetPoint("TOPRIGHT", -ns.padding, -ns.padding)
	fontstring:SetPoint("BOTTOMLEFT", check, "BOTTOMRIGHT", 0, 0)
	if not fontstring:SetFont(ns.font, ns.fontsize, "") then
		print("Font not valid")
	end
	fontstring:SetText(text)
	
	return frame
end

local Keybind_OnClick = function(s, ...)
	if s:IsKeyboardEnabled() then
		s:EnableKeyboard(false);
		return;
	end
	
	s:EnableKeyboard(true);
end

local Keybind_OnKeyUp = function(s, key)
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
		RSUM_Options[s.name] = binding;
	end
	
	s:EnableKeyboard(false);
end

local function CreateKeybind(name, default, parent, text, tooltip)
	local frame = CreateFrame("Frame", "$PARENT_" .. name, parent)
	frame:SetHeight(ns.padding * 3 + ns.buttonsize * 2)
	

	local fontstring = frame:CreateFontString("$PARENT_fontstring")
	fontstring:SetPoint("TOPLEFT", ns.padding, -ns.padding)
	fontstring:SetPoint("TOPRIGHT", -ns.padding, -ns.padding)
	fontstring:SetHeight(ns.buttonsize)
	if not fontstring:SetFont(ns.font, ns.fontsize, "") then
		print("Font not valid")
	end
	fontstring:SetText(text)
	
	
	local button = CreateFrame("Button", "$PARENT_button", frame, "UIPanelButtonTemplate")
	button:SetPoint("TOPLEFT", fontstring, "BOTTOMLEFT", 0, -ns.padding)
	button:SetPoint("TOPRIGHT", fontstring, "BOTTOMRIGHT", 0, -ns.padding)
	button:SetHeight(ns.buttonsize)
	if RSUM_Options and RSUM_Options[name] then
		button:SetText(RSUM_Options[name])
	else
		button:SetText(default)
	end
	button:Enable()
	button.name = name
	button:SetScript("OnClick", Keybind_OnClick)
	button:SetScript("OnKeyUp", Keybind_OnKeyUp)
	if tooltip then
		button.tooltip = tooltip
		button:SetScript("OnEnter", function(s) GameTooltip:SetOwner(s); GameTooltip:SetText(s.tooltip); end)
		button:SetScript("OnLeave", function(s) GameTooltip:Hide(); end)
	end
	button:EnableKeyboard(false)
	
	return frame
end

local function CreateSlider(name, default, parent, text, minval, maxval, tooltip)

end

local function CreateDropbox(name, default, parent, text, list, tooltip)

end


-- typ: "checkbox" / "keybind" / "slider" / "dropbox"
-- name: descriptor of option
-- ...: arguments depending on typ
function ns.CreateOption(name, typ, default, ...)
	
	table.insert(options, {name = name, typ = typ, default = default, parameters = {...} })
	
	if RSUM_Options[name] == nil then
		optionsByKey[name] = default
	else
		optionsByKey[name] = RSUM_Options[name]
	end
	
end

-- parent: outside frame
function ns.CreateOptionFrames(parent)
	local preframe
	for i, o in ipairs(options) do
		if not o.frame then
			if o.typ and o.parameters then
				if o.typ == "checkbox" then
					o.frame = CreateCheckbox(o.name, o.default, parent, unpack(o.parameters))
				elseif o.typ == "keybind" then
					o.frame = CreateKeybind(o.name, o.default, parent, unpack(o.parameters))
				elseif o.typ == "slider" then
					o.frame = CreateSlider(o.name, o.default, parent, unpack(o.parameters))
				elseif o.typ == "dropbox" then
					o.frame = CreateDropbox(o.name, o.default, parent, unpack(o.parameters))
				end
			end
		end
		
		if o.frame then
			if preframe then
				o.frame:SetPoint("TOP", preframe, "BOTTOM", 0, 0)
				o.frame:SetWidth(preframe:GetWidth())
			else
				o.frame:SetPoint("TOP", parent, "TOP", 0, 0)
				o.frame:SetWidth(parent:GetWidth())
			end
			preframe = o.frame
		end
	end
end
