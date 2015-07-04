-- important variables
local initiated = false;
local RSUM_test = false;

-- Debugging
local debugframe;
local debugfontstring;



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
