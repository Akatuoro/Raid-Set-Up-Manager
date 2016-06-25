-- important variables
local bindings_initiated = false;
local initiated = false;
local onload_frame = CreateFrame("Frame", "rsumonload", UIParent);
-- Debugging
local debugframe;
local debugfontstring;

local addon, ns = ...

ns.font = "Fonts\\FRIZQT__.TTF"
ns.fontsize = 12
ns.padding = 12
ns.buttonsize = 20

-- Options
ns.CreateOption("keybind_togglewindow", "keybind", "CTRL-O", "Keybind for /rsum", "Click to change")
ns.CreateOption("masterloot", "checkbox", false, "Masterloot reminder", "Get reminded when you should maybe use master loot or change the master looter")
ns.CreateOption("noautoreset", "checkbox", true, "No auto reset", "If not checked: Resets all changes when RSUM window is closed")
ns.CreateOption("printmsg", "checkbox", true, "Print feedback", "Print a response of what has been done")
ns.CreateOption("sortsavedpresets", "checkbox", false, "Sort saved presets", "Sort saved presets alphabetically")
ns.CreateOption("sortmembersingroup", "checkbox", false, "members by name", "Sort members alphabetically in each group")



function ns.PrintMsg(msg)
	if msg and ns.Option("printmsg") then
		print("|cffaa0000RSUM:|r " .. msg)
	end
end

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
			RSUM_Test();
			if not initiated then
				RSUM_Init();
			end
			return;
		end
		if msg == "apply" then
			RSUM_BuildGroups();
			return;
		end
		if msg == "options" then
			if not initiated then
				RSUM_Init();
			end
			RSUM_Show();
			RSUM_OptionsWindow();
			return;
		end
		if msg == "sort" then
			ns.gm.Sort("test")
			RSUM_UpdateWindows();
			return;
		end
		if not initiated then
			RSUM_Init();
		end
		RSUM_Show();
end

SlashCmdList["RAIDSETUP"] = slashhandler;


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

function RSUM_SetBinding(binding, target)
	local setbinding = false;
	if GetBindingByKey(binding) == "" or GetBindingByKey(binding) == nil then
		setbinding = true;
	else
		local key, list = GetBindingKey(GetBindingByKey(binding));
		if key == binding then
			setbinding = false;
		else
			setbinding = true;
		end
	end
	
	if setbinding then
		if target and target == "togglewindow" then
			ok = SetBindingClick(binding, "rsumshowwindowbutton");
			if not ok then
				print("RSUM: Binding could not be set");
				return false;
			end
			-- clear old binding
			local key, otherkey = GetBindingKey(GetBindingByKey(binding));
			if not (key == binding) then
				if key then
					SetBinding(key);
				end
			end
			if not (otherkey == binding) then
				if otherkey then
					SetBinding(otherkey);
				end
			end
		end
	else
		print("RSUM: Binding already in use");
		return false;
	end
	return true;
end

local function RSUM_SetBindings()
	-- Create invisible button
	local showwindow_button = CreateFrame("Button", "rsumshowwindowbutton", mainframe);
	showwindow_button:SetScript("OnClick", RSUM_ShowWindowButtonOnClick);
	
	-- set binding to click button
	if RSUM_Options and RSUM_Options["keybind_togglewindow"] then
		ok = SetBindingClick(RSUM_Options["keybind_togglewindow"], showwindow_button:GetName());
	else
		ok = SetBindingClick("CTRL-O", showwindow_button:GetName());
	end
	if not ok then
		print("RSUM Error when setting key bindings");
		return;
	end
	
	bindings_initiated = true;
end

RSUM_ShowWindowButtonOnClick = function(s, ...)
	if not initiated then
		RSUM_Init();
		return;
	end
	RSUM_Toggle();
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

-- do code that needs to be done
onload_frame:RegisterEvent("PLAYER_ENTERING_WORLD");
onload_frame:SetScript("OnEvent", function(s, eventname, ...) if not bindings_initiated and eventname == "PLAYER_ENTERING_WORLD" then RSUM_SetBindings(); end end);
