local addon, ns = ...

ns.qs = {};

local deselectedfont = CreateFont("RSUM_QuickSetup_DeselectedFont");
local selectedfont;

function ns.qs.RaidOrGroupToggle(s) 
	if IsInRaid("player") then
		ConvertToParty();
	elseif IsInGroup("player") then
		ConvertToRaid();
	end
end

function ns.qs.SetNormalDifficulty() 
	SetRaidDifficultyID(14);
	ns.qs.CheckButtons();
end

function ns.qs.SetHeroicDifficulty() 
	SetRaidDifficultyID(15);
	ns.qs.CheckButtons();
end

function ns.qs.SetMythicDifficulty() 
	SetRaidDifficultyID(16);
	ns.qs.CheckButtons();
end

function ns.qs.Initiate(button)
	selectedfont = button:GetNormalFontObject();
	deselectedfont:CopyFontObject(selectedfont);
	deselectedfont:SetTextColor(0.5,0.5,0.5,1);
	selectedfont:SetTextColor(230/255, 190/255, 0, 1);
end

function ns.qs.CheckButtons()
	if ns.qs.raidorgroupbutton then
		if IsInRaid("player") then
			ns.qs.raidorgroupbutton:SetText("R");
		elseif IsInGroup("player") then
			ns.qs.raidorgroupbutton:SetText("G");
		else
			ns.qs.raidorgroupbutton:SetText("S");
		end
	end
	if ns.qs.normaldiffbutton then
		if GetRaidDifficultyID() == 14 then
			ns.qs.normaldiffbutton:SetNormalFontObject(selectedfont);
		else
			ns.qs.normaldiffbutton:SetNormalFontObject(deselectedfont);
		end
	end
	if ns.qs.heroicdiffbutton then
		if GetRaidDifficultyID() == 15 then
			ns.qs.heroicdiffbutton:SetNormalFontObject(selectedfont);
		else
			ns.qs.heroicdiffbutton:SetNormalFontObject(deselectedfont);
		end
	end
	if ns.qs.mythicdiffbutton then
		if GetRaidDifficultyID() == 16 then
			ns.qs.mythicdiffbutton:SetNormalFontObject(selectedfont);
		else
			ns.qs.mythicdiffbutton:SetNormalFontObject(deselectedfont);
		end

	end
end