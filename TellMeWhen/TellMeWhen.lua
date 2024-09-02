local folder, core = ...
_G.TellMeWhen = core

local L = core.L
local ACD = LibStub("AceConfigDialog-3.0")

local GetItemCooldown = GetItemCooldown
local GetSpellCooldown = GetSpellCooldown
local GetSpellInfo = GetSpellInfo
local GetSpellTexture = GetSpellTexture
local IsSpellInRange = IsSpellInRange
local IsUsableSpell = IsUsableSpell
local IsSpellKnown = IsSpellKnown
local GetItemInfo = GetItemInfo
local IsEquippedItem = IsEquippedItem
local UnitBuff, UnitDebuff = UnitBuff, UnitDebuff
local hasElvUI

local clipboard = {}

local LiCD = LibStub("LibInternalCooldowns", true)
if LiCD and LiCD.GetItemCooldown then
	GetItemCooldown = function(...)
		return LiCD:GetItemCooldown(...)
	end
end

local function TMW_IsSpellInRange(spellId, unit)
	local spellName = tonumber(spellId) and GetSpellInfo(spellId) or spellId
	return IsSpellInRange(spellName, unit)
end

local function TMW_GetSpellTexture(spellName)
	if tonumber(spellName) then
		return select(3, GetSpellInfo(spellName))
	end
	return GetSpellTexture(spellName)
end

local maxGroups, maxColumns, maxRows = 8, 8, 7
local updateInterval = 0.25
local activeSpec, _
local highlightColor = HIGHLIGHT_FONT_COLOR
local normalColor = NORMAL_FONT_COLOR

local iconDefaults = {
	BuffOrDebuff = "HELPFUL",
	BuffShowWhen = "present",
	CooldownShowWhen = "usable",
	CooldownType = "spell",
	Enabled = false,
	Name = "",
	OnlyMine = false,
	ShowTimer = false,
	Type = "",
	Unit = "player",
	WpnEnchantType = "mainhand"
}

local groupDefaults = {
	Enabled = false,
	Width = 30,
	Height = 30,
	Scale = 2.0,
	Rows = 1,
	Columns = 4,
	Icons = {},
	OnlyInCombat = false,
	PrimarySpec = true,
	SecondarySpec = true
}

for i = 1, maxColumns * maxRows do
	groupDefaults.Icons[i] = iconDefaults
end

local DB, _
local defaults = {
	Locked = false,
	Desaturate = false,
	Groups = {}
}

local TellMeWhen_BuffEquivalencies = {
	-- Pounce Bleed, Rake, Rip, Lacerate, Rupture, Garrot, Savage Rend, Rend, Deep Wounds
	Bleeding = "9007;9824;9826;27007;49804;1822;1823;1824;9904;27003;48573;48574;1079;9492;9493;9752;9894;9896;27008;49799;49800;33745;48567;48568;1943;8639;8640;11273;11274;11275;26867;48671;48672;703;8631;8632;8633;11289;11290;26839;26884;48675;48676;50498;53578;53579;53580;53581;53582;772;6546;6547;6548;11572;11573;11574;25208;46845;47465;12834;12849;12867",
	-- Berserk, Evasion, Shield Wall, Retaliation, Dispersion, Hand of Sacrifice, Hand of Protection, Divine Shield, Divine Protection, Ice Block, Icebound Fortitude, Cyclone, Banish
	DontMelee = "50334;5277;26669;871;20230;47585;6940;1022;5599;10278;642;498;45438;48792;33786;710;18647",
	-- Faerie Fire and Faerie Fire (Feral)
	FaerieFires = "770;16857",
	-- Divine Shield, Ice Block, The Beast Within, Beastial Wrath, Cyclone, Banish
	ImmuneToMagicCC = "642;45438;34471;19574;33786;710;18647",
	-- Divine Shield, Ice Block, The Beast Within, Beastial Wrath, Icebound Fortitude, Hand of Protection, Cyclone, Banish
	ImmuneToStun = "642;45438;34471;33786;48792;1022;5599;10278;33786;710;18647",
	-- Gouge, Maim, Repentance, Reckless Charge, Hungering Cold
	Incapacitated = "1776;1777;8629;11285;11286;38764;22570;49802;20066;13327;51209",
	-- Rocket Burst, Infected Wounds, Judgements of the Just, Earth Shock, Thunder Clap, Icy Touch
	MeleeSlowed = "69192;58179;58180;58181;68055;8042;8044;8045;8046;10412;10413;10414;25454;49230;49231;6343;8198;8204;8205;11580;11581;25264;47501;47502;45477;49896;49903;49904;49909",
	-- Incapacitating Shout, Chains of Ice, Icy Clutch, Slow, Daze, Hamstring, Piercing Howl, Wing Clip, Frost Trap Aura;Frostbolt, Cone of Cold, Blast Wave, Mind Flay, Crippling Poison, Deadly Throw, Frost Shock, Earthbind, Curse of Exhaustion
	MovementSlowed = "18328;61578;45524;50434;50435;50436;31589;38767;1715;52744;2974;13810;116;205;837;7322;8406;8407;8408;10179;10180;10181;25304;27071;27072;38697;42841;42842;120;8492;10159;10160;10161;42930;42931;11113;13018;13019;13020;13021;27133;33933;42944;42945;15407;17311;17312;17313;17314;18807;25387;48155;48156;58381;30981;26679;48673;48674;8056;8058;10472;10473;25464;49235;49236;2484;65815",
	-- Reckless Charge, Bash, Maim, Pounce, Starfire Stun, Intimidation, Impact, Hammer of Justice, Stun, Blackout, Kidney Shot, Cheap Shot, Shadowfury, Intercept, Charge Stun, Concussion Blow, War Stomp
	Stunned = "13327;5211;6798;8983;22570;49802;9005;9823;9827;27006;49803;16922;24394;12355;853;5588;5589;10308;2880;46025;408;8643;1833;30283;30413;30414;47846;47847;20253;20614;20615;25273;25274;65929;12809;19482",
	-- Gouge, Maim, Repentance, Reckless Charge, Hungering Cold, Bash, Pounce, Starfire Stun, Intimidation, Impact, Hammer of Justice, Stun, Blackout, Kidney Shot, Cheap Shot, Shadowfury, Intercept, Charge Stun, Concussion Blow, War Stomp
	StunnedOrIncapacitated = "1776;1777;8629;11285;11286;38764;22570;49802;20066;13327;51209;5211;6798;8983;9005;9823;9827;27006;49803;16922;24394;12355;853;5588;5589;10308;2880;46025;408;8643;1833;30283;30413;30414;47846;47847;20253;20614;20615;25273;25274;65929;12809;19482",
	-- Mangle (Bear) & Mangle (Cat)
	VulnerableToBleed = "33878;33986;33987;48563;48564;33876;33982;33983;48565;48566",
	WoTLKDebuffs = "71237;71289;71204;72293;69279;69674;72272;73020;70447;70672;70911;72999;71822;70867;71340;71267;70923;70873;70106;69762;69766;70128;70126;70541;70337;69409;69409;73797;73798;74453;74367;74562;74792"
}

local function TellMeWhen_CreateGroup(name, parent, ...)
	local group = CreateFrame("Frame", name, parent or UIParent)
	group:SetSize(1, 1)
	group:SetToplevel(true)
	group:SetMovable(true)
	if select(1, ...) then group:SetPoint(...) end

	local t = group:CreateTexture(nil, "BACKGROUND")
	t:SetTexture(0, 0, 0, 0)
	t:SetVertexColor(0.6, 0.6, 0.6)
	t:SetAllPoints(true)
	group.texture = t

	local resize = CreateFrame("Button", nil, group)
	resize:SetPoint("BOTTOMRIGHT")
	resize:SetSize(10, 10)
	t = resize:CreateTexture(nil, "BACKGROUND")
	t:SetTexture([[Interface\AddOns\TellMeWhen\Resize]])
	t:SetVertexColor(0.6, 0.6, 0.6)
	t:SetSize(10, 10)
	t:SetAllPoints(resize)
	resize.texture = t
	resize:SetScript("OnMouseDown", function(self, button) core:StartSizing(self, button) end)
	resize:SetScript("OnMouseUp", function(self, button) core:StopSizing(self, button) end)
	resize:SetScript("OnEnter", function(self)
		core:GUIButton_OnEnter(self, L["Resize"], L["Click and drag to change size."])
		self.texture:SetVertexColor(1, 1, 1)
	end)
	resize:SetScript("OnLeave", function(self)
		GameTooltip:Hide()
		self.texture:SetVertexColor(0.6, 0.6, 0.6)
	end)
	group.resize = resize

	return group
end

local function TellMeWhen_CreateIcon(name, parent, width, height)
	width = hasElvUI and 30 or width or 30
	height = hasElvUI and 30 or height or 30

	local left = (36 - width) / 72
	local right = 1 - left
	local top = (36 - height) / 72
	local bottom = 1 - top

	local icon = CreateFrame("Frame", name, parent)
	icon:SetSize(width, height)

	local border = CreateFrame("Frame", nil, icon)
	border:SetAllPoints(icon)
	border:SetFrameStrata("HIGH")
	border:SetFrameLevel(1)

	local delta = 0

	border.left = border:CreateTexture(nil, "ARTWORK")
	border.left:SetPoint("BOTTOMLEFT", border, "BOTTOMLEFT", delta, delta)
	border.left:SetPoint("TOPRIGHT", border, "TOPLEFT", delta + 1, -delta)
	border.left:SetTexture(1, 0, 0, 1)

	border.right = border:CreateTexture(nil, "BORDER")
	border.right:SetPoint("BOTTOMLEFT", border, "BOTTOMRIGHT", -(delta + 1), delta)
	border.right:SetPoint("TOPRIGHT", border, "TOPRIGHT", -delta, -delta)
	border.right:SetTexture(1, 0, 0, 1)

	border.top = border:CreateTexture(nil, "BORDER")
	border.top:SetPoint("BOTTOMLEFT", border, "TOPLEFT", delta + 1, -(delta + 1))
	border.top:SetPoint("TOPRIGHT", border, "TOPRIGHT", -(delta + 1), -delta)
	border.top:SetTexture(1, 0, 0, 1)

	border.bottom = border:CreateTexture(nil, "BORDER")
	border.bottom:SetPoint("BOTTOMLEFT", border, "BOTTOMLEFT", delta + 1, delta)
	border.bottom:SetPoint("TOPRIGHT", border, "BOTTOMRIGHT", -(delta + 1), delta + 1)
	border.bottom:SetTexture(1, 0, 0, 1)

	icon.border = border

	icon.border:Hide()

	local t = icon:CreateTexture(nil, "BACKGROUND")
	t:SetTexture([[Interface\DialogFrame\UI-DialogBox-Background]])
	t:SetTexCoord(left, right, top, bottom)
	t:SetAllPoints(icon)
	icon.bg = t

	t = icon:CreateTexture("$parentTexture", "ARTWORK")
	t:SetTexture([[Interface\Icons\INV_Misc_QuestionMark]])
	t:SetTexCoord(left, right, top, bottom)
	t:SetAllPoints(icon)
	icon.texture = t

	t = icon:CreateTexture("$parentHighlight", "HIGHLIGHT")
	t:SetTexture([[Interface\Buttons\ButtonHilight-Square]])
	t:SetAllPoints(icon)
	t:SetBlendMode("ADD")
	icon.highlight = t

	t = icon:CreateFontString("$parentCount", "ARTWORK", "NumberFontNormalSmall")
	t:SetPoint("BOTTOMRIGHT", -2, 2)
	t:SetJustifyH("RIGHT")
	icon.countText = t

	t = CreateFrame("Cooldown", "$parentCooldown", icon)
	t:SetAllPoints(icon)
	icon.Cooldown = t

	t = CreateFrame("Frame", "$parentDropDown", icon, "UIDropDownMenuTemplate")
	t:SetPoint("TOP")
	t:Hide()
	UIDropDownMenu_Initialize(t, core.IconMenu_Initialize, "MENU")
	t:SetScript("OnShow", function(self)
		UIDropDownMenu_Initialize(self, core.IconMenu_Initialize, "MENU")
	end)

	icon:SetScript("OnEnter", function(self, motion) core:Icon_OnEnter(self, motion) end)
	icon:SetScript("OnLeave", function(self) GameTooltip:Hide() end)

	icon:RegisterForDrag("LeftButton")
	icon:SetScript("OnDragStart", function(self) self:GetParent():StartMoving() end)
	icon:SetScript("OnDragStop", function(self)
		self:GetParent():StopMovingOrSizing()
		local group = DB.Groups[self:GetParent():GetID()]
		group.point, _, _, group.x, group.y = self:GetParent():GetPoint(1)
	end)
	icon:SetScript("OnMouseDown", function(self, button) core:Icon_OnMouseDown(self, button) end)

	return icon
end

local function TellMeWhen_ResizeIcon(icon, width, height)
	if not icon then return end

	width = hasElvUI and 30 or width or 30
	height = hasElvUI and 30 or height or 30

	local left = (36 - width) / 72
	local right = 1 - left
	local top = (36 - height) / 72
	local bottom = 1 - top

	icon:SetSize(width, height)
	icon.bg:SetTexCoord(left, right, top, bottom)
	icon.texture:SetTexCoord(left, right, top, bottom)
end

-- -------------
-- RESIZE BUTTON
-- -------------

function core:GUIButton_OnEnter(icon, shortText, longText)
	local tooltip = _G["GameTooltip"]
	if GetCVar("UberTooltips") == "1" then
		GameTooltip_SetDefaultAnchor(tooltip, icon)
		tooltip:AddLine(shortText, highlightColor.r, highlightColor.g, highlightColor.b, 1)
		tooltip:AddLine(longText, normalColor.r, normalColor.g, normalColor.b, 1)
		tooltip:Show()
	else
		tooltip:SetOwner(icon, "ANCHOR_BOTTOMLEFT")
		tooltip:SetText(shortText)
	end
end

do
	local function TellMeWhen_SizeUpdate(icon)
		local uiScale = UIParent:GetScale()
		local scalingFrame = icon:GetParent()
		local cursorX, cursorY = GetCursorPosition(UIParent)

		local newXScale = scalingFrame.oldScale * (cursorX / uiScale - scalingFrame.oldX * scalingFrame.oldScale) / (icon.oldCursorX / uiScale - scalingFrame.oldX * scalingFrame.oldScale)
		local newYScale = scalingFrame.oldScale * (cursorY / uiScale - scalingFrame.oldY * scalingFrame.oldScale) / (icon.oldCursorY / uiScale - scalingFrame.oldY * scalingFrame.oldScale)
		local newScale = max(0.6, newXScale, newYScale)
		scalingFrame:SetScale(newScale)

		local newX = scalingFrame.oldX * scalingFrame.oldScale / newScale
		local newY = scalingFrame.oldY * scalingFrame.oldScale / newScale
		scalingFrame:SetPoint("TOPLEFT", UIParent, "BOTTOMLEFT", newX, newY)
	end

	function core:StartSizing(icon, button)
		local scalingFrame = icon:GetParent()
		scalingFrame.oldScale = scalingFrame:GetScale()
		icon.oldCursorX, icon.oldCursorY = GetCursorPosition(UIParent)
		scalingFrame.oldX = scalingFrame:GetLeft()
		scalingFrame.oldY = scalingFrame:GetTop()
		icon:SetScript("OnUpdate", TellMeWhen_SizeUpdate)
	end
end

function core:StopSizing(icon, button)
	icon:SetScript("OnUpdate", nil)
	DB.Groups[icon:GetParent():GetID()].Scale = icon:GetParent():GetScale()
end

-- -------------
-- ICON FUNCTION
-- -------------

local function TellMeWhen_SplitNames(buffName, convertIDs)
	local buffNames
	if buffName:find(";") ~= nil then
		buffNames = {strsplit(";", buffName)}
	else
		buffNames = {buffName}
	end
	for i, name in ipairs(buffNames) do
		buffNames[i] = name
	end

	return buffNames
end

local function TellMeWhen_GetSpellNames(buffName, firstOnly)
	local buffNames
	if TellMeWhen_BuffEquivalencies[buffName] then
		buffNames = TellMeWhen_SplitNames(TellMeWhen_BuffEquivalencies[buffName], "spell")
	else
		buffNames = TellMeWhen_SplitNames(buffName, "spell")
	end
	return firstOnly and buffNames[1] or buffNames
end

local function TellMeWhen_GetItemNames(buffName, firstOnly)
	local buffNames = TellMeWhen_SplitNames(buffName, "item")
	return firstOnly and buffNames[1] or buffNames
end

local defaultSpells = {
	ROGUE = 1752, -- sinister strike
	PRIEST = 139, -- renew
	DRUID = 774, -- rejuvenation
	WARRIOR = 6673, -- battle shout
	MAGE = 168, -- frost armor
	WARLOCK = 1454, -- life tap
	PALADIN = 1152, -- purify
	SHAMAN = 324, -- lightning shield
	HUNTER = 1978, -- serpent sting
	DEATHKNIGHT = 45462 -- plague strike
}
local defaultSpell = defaultSpells[select(2, UnitClass("player"))]
local function TellMeWhen_GetGCD()
	return IsSpellKnown(defaultSpell) and select(2, GetSpellCooldown(defaultSpell)) or 0
end

local function TellMeWhen_Desaturate(texture, desaturate, r, g, b, a)
	if DB.Desaturate and desaturate then
		texture:SetVertexColor(r or 0.5, g or 0.5, b or 0.5, a or 1)
		if not texture:IsDesaturated() then
			texture:SetDesaturated(true)
		end
	elseif DB.Desaturate then
		texture:SetVertexColor(r or 1, g or 1, b or 1, a or 1)
		if texture:IsDesaturated() then
			texture:SetDesaturated(false)
		end
	elseif desaturate then
		texture:SetVertexColor(r or 0.5, g or 0.5, b or 0.5, a or 1)
		if texture:IsDesaturated() then
			texture:SetDesaturated(false)
		end
	else
		texture:SetVertexColor(r or 1, g or 1, b or 1, a or 1)
		if texture:IsDesaturated() then
			texture:SetDesaturated(false)
		end
	end
end

local function TellMeWhen_Icon_SpellCooldown_OnUpdate(self, elapsed)
	self.updateTimer = self.updateTimer - elapsed
	if self.updateTimer <= 0 then
		self.updateTimer = updateInterval
		local name = self.Name[1] or ""
		local _, timeLeft, _ = GetSpellCooldown(name)
		local inrange = TMW_IsSpellInRange(name, self.Unit)
		if LiCD and LiCD.talentsRev[name] then
			name = LiCD.talentsRev[name]
			timeLeft = 0
		end
		local _, nomana = IsUsableSpell(name)
		local OnGCD = TellMeWhen_GetGCD() == timeLeft and timeLeft > 0
		local _, _, _, _, _, _, _, minRange, maxRange = GetSpellInfo(name)
		if not maxRange or inrange == nil then
			inrange = 1
		end
		if timeLeft then
			if (timeLeft == 0 or OnGCD) and inrange == 1 and not nomana then
				TellMeWhen_Desaturate(self.texture, false)
				self:SetAlpha(self.usableAlpha)
			elseif self.usableAlpha == 1 and (timeLeft == 0 or OnGCD) then
				TellMeWhen_Desaturate(self.texture, true)
				self:SetAlpha(self.usableAlpha)
			else
				TellMeWhen_Desaturate(self.texture, false)
				self:SetAlpha(self.unusableAlpha)
			end
		end
	end
end

local function TellMeWhen_Icon_SpellCooldown_OnEvent(self, event, _, arg2, _, _, _, _, _, _, arg9)
	local startTime, timeLeft, _

	if event == "COMBAT_LOG_EVENT_UNFILTERED" and arg2 == "SPELL_ENERGIZE" then
		if arg9 and LiCD and LiCD.cooldowns[arg9] then
			startTime, timeLeft = GetTime(), LiCD.cooldowns[arg9]
		end
	else
		startTime, timeLeft, _ = GetSpellCooldown(self.Name[1] or "")
	end
	if timeLeft then
		CooldownFrame_SetTimer(self.Cooldown, startTime, timeLeft, 1)
	end
end

local function TellMeWhen_Icon_ItemCooldown_OnUpdate(self, elapsed)
	self.updateTimer = self.updateTimer - elapsed
	if self.updateTimer <= 0 then
		self.updateTimer = updateInterval
		local _, timeLeft, _ = GetItemCooldown(self.iName or self.Name[1] or "")
		if timeLeft then
			if timeLeft == 0 or TellMeWhen_GetGCD() == timeLeft then
				self:SetAlpha(self.usableAlpha)
			elseif timeLeft > 0 and TellMeWhen_GetGCD() ~= timeLeft then
				self:SetAlpha(self.unusableAlpha)
			end
		end
	end
end

local function TellMeWhen_Icon_ItemCooldown_OnEvent(self, event)
	if event == "PLAYER_EQUIPMENT_CHANGED" then
		core:Icon_Update(self, self.groupID, self.iconID)
	end

	local startTime, timeLeft, enable = GetItemCooldown(self.iName or self.Name[1] or "")
	if timeLeft then
		CooldownFrame_SetTimer(self.Cooldown, startTime, timeLeft, 1)
	end
end

local function TellMeWhen_Icon_BuffCheck(icon)
	if UnitExists(icon.Unit) then
		local maxExpirationTime = 0
		local processedBuffInAuraNames = false

		local filter = icon.OnlyMine and "PLAYER"
		local func = (icon.BuffOrDebuff == "HELPFUL") and UnitBuff or UnitDebuff

		for _, iName in ipairs(icon.Name) do
			local buffName, iconTexture, count, duration, expirationTime
			local auraId = tonumber(iName)
			if auraId then
				for i = 1, 32 do
					local name, _, tex, stack, _, dur, expirers, _, _, _, spellId = func(icon.Unit, i, nil, filter)
					if name and spellId and spellId == auraId then
						buffName, iconTexture, count, duration, expirationTime = name, tex, stack, dur, expirers
						break
					end
				end
			else
				buffName, _, iconTexture, count, _, duration, expirationTime = func(icon.Unit, iName, nil, filter)
			end

			if buffName then
				if icon.texture:GetTexture() ~= iconTexture then
					icon.texture:SetTexture(iconTexture)
					icon.learnedTexture = true
				end
				if icon.presentAlpha then
					icon:SetAlpha(icon.presentAlpha)
				end
				TellMeWhen_Desaturate(icon.texture, false)
				if count > 1 then
					icon.countText:SetText(count)
					icon.countText:Show()
				else
					icon.countText:Hide()
				end
				if icon.ShowTimer and not UnitIsDead(icon.Unit) then
					CooldownFrame_SetTimer(icon.Cooldown, expirationTime - duration, duration, 1)
				end
				processedBuffInAuraNames = true
			end
		end
		if processedBuffInAuraNames then
			return
		end

		if icon.absentAlpha then
			icon:SetAlpha(icon.absentAlpha)
		end
		if icon.presentAlpha == 1 and icon.absentAlpha == 1 then
			TellMeWhen_Desaturate(icon.texture, true, 1, 0.35, 0.35, 1)
		end

		icon.countText:Hide()
		if icon.ShowTimer then
			CooldownFrame_SetTimer(icon.Cooldown, 0, 0, 0)
		end
	else
		icon:SetAlpha(0)
		CooldownFrame_SetTimer(icon.Cooldown, 0, 0, 0)
	end
end

local function TellMeWhen_Icon_Buff_OnEvent(self, event, arg1, arg2, _, _, _, arg6)
	if event == "COMBAT_LOG_EVENT_UNFILTERED" and arg2 == "UNIT_DIED" then
		if arg6 == UnitGUID(self.Unit) then
			TellMeWhen_Icon_BuffCheck(self)
		end
	elseif event == "UNIT_AURA" and arg1 == self.Unit then
		TellMeWhen_Icon_BuffCheck(self)
	elseif
		(self.Unit == "target" and event == "PLAYER_TARGET_CHANGED") or
			(self.Unit == "focus" and event == "PLAYER_FOCUS_CHANGED")
	 then
		TellMeWhen_Icon_BuffCheck(self)
	end
end

local function TellMeWhen_Icon_ReactiveCheck(icon)
	local name = icon.Name[1] or ""
	local usable, nomana = IsUsableSpell(name)
	local _, timeLeft, _ = GetSpellCooldown(name)
	local inrange = TMW_IsSpellInRange(name, icon.Unit)
	if (inrange == nil) then
		inrange = 1
	end
	if usable then
		if inrange and not nomana then
			TellMeWhen_Desaturate(icon.texture, false)
			icon:SetAlpha(icon.usableAlpha)
		elseif not inrange or nomana then
			TellMeWhen_Desaturate(icon.texture, true, 0.35, 0.35, 0.35, 1)
			icon:SetAlpha(icon.usableAlpha)
		else
			TellMeWhen_Desaturate(icon.texture, false)
			icon:SetAlpha(icon.unusableAlpha)
		end
	else
		icon:SetAlpha(icon.unusableAlpha)
	end
end

local function TellMeWhen_Icon_Reactive_OnEvent(self, event)
	if event == "ACTIONBAR_UPDATE_USABLE" then
		TellMeWhen_Icon_ReactiveCheck(self)
	elseif event == "ACTIONBAR_UPDATE_COOLDOWN" then
		if self.ShowTimer then
			TellMeWhen_Icon_SpellCooldown_OnEvent(self, event)
		end
		TellMeWhen_Icon_ReactiveCheck(self)
	end
end

local function TellMeWhen_Icon_WpnEnchant_OnEvent(self, event, arg1)
	if event == "UNIT_INVENTORY_CHANGED" and arg1 == "player" then
		local slotID, _
		if self.WpnEnchantType == "mainhand" then
			slotID, _ = GetInventorySlotInfo("MainHandSlot")
		elseif self.WpnEnchantType == "offhand" then
			slotID, _ = GetInventorySlotInfo("SecondaryHandSlot")
		end
		local wpnTexture = GetInventoryItemTexture("player", slotID)
		if wpnTexture then
			self.texture:SetTexture(wpnTexture)
		else
			self.texture:SetTexture("Interface\\Icons\\INV_Misc_QuestionMark")
		end
		self.startTime = GetTime()
	end
end

local function TellMeWhen_Icon_WpnEnchant_OnUpdate(self, elapsed)
	self.updateTimer = self.updateTimer - elapsed
	if self.updateTimer <= 0 then
		self.updateTimer = updateInterval
		local hasMainHandEnchant, mainHandExpiration, mainHandCharges, hasOffHandEnchant, offHandExpiration, offHandCharges = GetWeaponEnchantInfo()
		if self.WpnEnchantType == "mainhand" and hasMainHandEnchant then
			self:SetAlpha(self.presentAlpha)
			if mainHandCharges > 1 then
				self.countText:SetText(mainHandCharges)
				self.countText:Show()
			else
				self.countText:Hide()
			end
			if self.ShowTimer then
				if self.startTime ~= nil then
					CooldownFrame_SetTimer(self.Cooldown, GetTime(), mainHandExpiration / 1000, 1)
				else
					self.startTime = GetTime()
				end
			end
		elseif self.WpnEnchantType == "offhand" and hasOffHandEnchant then
			self:SetAlpha(self.presentAlpha)
			if offHandCharges > 1 then
				self.countText:SetText(offHandCharges)
				self.countText:Show()
			else
				self.countText:Hide()
			end
			if self.ShowTimer then
				if self.startTime ~= nil then
					CooldownFrame_SetTimer(self.Cooldown, GetTime(), offHandExpiration / 1000, 1)
				else
					self.startTime = GetTime()
				end
			end
		else
			self:SetAlpha(self.absentAlpha)
			CooldownFrame_SetTimer(self.Cooldown, 0, 0, 0)
		end
	end
end

local function TellMeWhen_Icon_Totem_OnEvent(self, event, ...)
	local foundTotem
	for iSlot = 1, 4 do
		local haveTotem, totemName, startTime, totemDuration, totemIcon = GetTotemInfo(iSlot)
		for i, iName in ipairs(self.Name) do
			if totemName and totemName:find(iName) then
				foundTotem = true
				TellMeWhen_Desaturate(self.texture, false)
				self:SetAlpha(self.presentAlpha)

				if self.texture:GetTexture() ~= totemIcon then
					self.texture:SetTexture(totemIcon)
					self.learnedTexture = true
				end

				if self.ShowTimer then
					local precise = GetTime()
					if precise - startTime > 1 then
						precise = startTime + 1
					end
					CooldownFrame_SetTimer(self.Cooldown, precise, totemDuration, 1)
				end
				self:SetScript("OnUpdate", nil)
				break
			end
		end
	end
	if not foundTotem then
		if self.absentAlpha == 1 and self.presentAlpha == 1 then
			TellMeWhen_Desaturate(self.texture, true, 1, 0.35, 0.35, 1)
		end
		self:SetAlpha(self.absentAlpha)
		CooldownFrame_SetTimer(self.Cooldown, 0, 0, 0)
	end
end

local function TellMeWhen_Group_OnEvent(self, event)
	if event == "PLAYER_REGEN_DISABLED" then
		self:Show()
	elseif event == "PLAYER_REGEN_ENABLED" then
		self:Hide()
	end
end

do
	local currentIcon = {groupID = 1, iconID = 1}

	StaticPopupDialogs["TELLMEWHEN_CHOOSENAME_DIALOG"] = {
		text = L["Enter the Name or Id of the Spell, Ability, Item, Buff, Debuff you want this icon to monitor. You can add multiple Buffs/Debuffs by seperating them with ;"],
		button1 = ACCEPT,
		button2 = CANCEL,
		hasEditBox = 1,
		maxLetters = 200,
		OnShow = function(this)
			local groupID = currentIcon.groupID
			local iconID = currentIcon.iconID
			local text = DB.Groups[groupID].Icons[iconID].Name
			_G[this:GetName() .. "EditBox"]:SetText(text)
			_G[this:GetName() .. "EditBox"]:SetFocus()
		end,
		OnAccept = function(iconNumber)
			local text = _G[this:GetParent():GetName() .. "EditBox"]:GetText()
			core:IconMenu_ChooseName(text)
		end,
		EditBoxOnEnterPressed = function(iconNumber)
			local text = _G[this:GetParent():GetName() .. "EditBox"]:GetText()
			core:IconMenu_ChooseName(text)
			this:GetParent():Hide()
		end,
		EditBoxOnEscapePressed = function()
			this:GetParent():Hide()
		end,
		OnHide = function()
			if _G.ChatFrameEditBox and _G.ChatFrameEditBox:IsVisible() then
				_G.ChatFrameEditBox:SetFocus()
			end
			_G[this:GetName() .. "EditBox"]:SetText("")
		end,
		timeout = 0,
		whileDead = 1,
		hideOnEscape = 1
	}

	StaticPopupDialogs["TELLMEWHEN_SIMPLE_DIALOG"] = {
		text = "%s",
		button1 = "OK",
		timeout = 0,
		whileDead = true,
		hideOnEscape = true,
	}

	local TellMeWhen_IconMenu_CooldownOptions = {
		{value = "CooldownType", text = L["Cooldown type"], hasArrow = true},
		{value = "CooldownShowWhen", text = L["Show icon when"], hasArrow = true},
		{value = "ShowTimer", text = L["Show timer"]},
		{value = "noCooldownCount", text = L["Disable OmniCC"]}
	}

	local TellMeWhen_IconMenu_ReactiveOptions = {
		{value = "CooldownShowWhen", text = L["Show icon when"], hasArrow = true},
		{value = "ShowTimer", text = L["Show timer"]},
		{value = "noCooldownCount", text = L["Disable OmniCC"]}
	}

	local TellMeWhen_IconMenu_BuffOptions = {
		{value = "BuffOrDebuff", text = L["Buff or Debuff"], hasArrow = true},
		{value = "Unit", text = L["Unit to watch"], hasArrow = true},
		{value = "BuffShowWhen", text = L["Show icon when"], hasArrow = true},
		{value = "ShowTimer", text = L["Show timer"]},
		{value = "noCooldownCount", text = L["Disable OmniCC"]},
		{value = "OnlyMine", text = L["Only show if cast by self"]}
	}

	local TellMeWhen_IconMenu_WpnEnchantOptions = {
		{value = "WpnEnchantType", text = L["Weapon slot to monitor"], hasArrow = true},
		{value = "BuffShowWhen", text = L["Show icon when"], hasArrow = true},
		{value = "ShowTimer", text = L["Show timer"]},
		{value = "noCooldownCount", text = L["Disable OmniCC"]}
	}

	local TellMeWhen_IconMenu_TotemOptions = {
		{value = "Unit", text = L["Unit to watch"], hasArrow = true},
		{value = "BuffShowWhen", text = L["Show icon when"], hasArrow = true},
		{value = "ShowTimer", text = L["Show timer"]},
		{value = "noCooldownCount", text = L["Disable OmniCC"]}
	}

	local TellMeWhen_IconMenu_SubMenus = {
		-- the keys on this table need to match the settings variable names
		Type = {
			{value = "cooldown", text = L["Cooldown"]},
			{value = "buff", text = L["Buff or Debuff"]},
			{value = "reactive", text = L["Reactive spell or ability"]},
			{value = "wpnenchant", text = L["Temporary weapon enchant"]},
			{value = "totem", text = L["Totem/non-MoG Ghoul"]}
		},
		CooldownType = {
			{value = "spell", text = L["Spell or ability"]},
			{value = "item", text = L["Item"]}
		},
		BuffOrDebuff = {
			{value = "HELPFUL", text = L["Buff"]},
			{value = "HARMFUL", text = L["Debuff"]}
		},
		Unit = {
			{value = "player", text = STATUS_TEXT_PLAYER},
			{value = "target", text = STATUS_TEXT_TARGET},
			{value = "targettarget", text = L["Target of Target"]},
			{value = "focus", text = FOCUS},
			{value = "focustarget", text = L["Focus Target"]},
			{value = "pet", text = PET},
			{value = "pettarget", text = L["Pet Target"]},
			{disabled = true},
			{text = PARTY, isTitle = true},
			{text = PLAYER .. " " .. 1, value = "party1"},
			{text = PLAYER .. " " .. 2, value = "party2"},
			{text = PLAYER .. " " .. 3, value = "party3"},
			{text = PLAYER .. " " .. 4, value = "party4"},
			{text = ARENA, isTitle = true},
			{text = ENEMY .. " " .. 1, value = "arena1"},
			{text = ENEMY .. " " .. 2, value = "arena2"},
			{text = ENEMY .. " " .. 3, value = "arena3"},
			{text = ENEMY .. " " .. 4, value = "arena4"},
			{text = ENEMY .. " " .. 5, value = "arena5"}
		},
		BuffShowWhen = {
			{value = "present", text = L["Present"]},
			{value = "absent", text = L["Absent"]},
			{value = "always", text = L["Always"]}
		},
		CooldownShowWhen = {
			{value = "usable", text = L["Usable"]},
			{value = "unusable", text = L["Unusable"]},
			{value = "always", text = L["Always"]}
		},
		WpnEnchantType = {
			{value = "mainhand", text = INVTYPE_WEAPONMAINHAND},
			{value = "offhand", text = INVTYPE_WEAPONOFFHAND}
		}
	}

	function core:Icon_OnEnter(this, motion)
		GameTooltip_SetDefaultAnchor(GameTooltip, this)
		GameTooltip:AddLine("TellMeWhen", highlightColor.r, highlightColor.g, highlightColor.b, 1)
		GameTooltip:AddLine(L["Right click for icon options. More options in Blizzard interface options menu. Type /tellmewhen to lock and enable addon."], normalColor.r, normalColor.g, normalColor.b, 1)
		GameTooltip:Show()
	end

	function core:Icon_OnMouseDown(this, button)
		if button == "RightButton" then
			PlaySound("UChatScrollButton")
			currentIcon.iconID = this:GetID()
			currentIcon.groupID = this:GetParent():GetID()
			ToggleDropDownMenu(1, nil, _G[this:GetName() .. "DropDown"], "cursor", 0, 0)
		end
	end

	function core:IconMenu_Initialize()
		local groupID = currentIcon.groupID
		local iconID = currentIcon.iconID

		local name = DB.Groups[groupID].Icons[iconID].Name
		local iconType = DB.Groups[groupID].Icons[iconID]["Type"]
		local enabled = DB.Groups[groupID].Icons[iconID]["Enabled"]

		if UIDROPDOWNMENU_MENU_LEVEL >= 2 then
			local settingVariantsSubMenu = TellMeWhen_IconMenu_SubMenus[UIDROPDOWNMENU_MENU_VALUE]
			if settingVariantsSubMenu ~= nil then
				local settingName = UIDROPDOWNMENU_MENU_VALUE
				for _, subMenuButton in ipairs(settingVariantsSubMenu) do
					local settingVariantInfo = UIDropDownMenu_CreateInfo()
					settingVariantInfo.text = subMenuButton.text
					settingVariantInfo.isTitle = subMenuButton.isTitle
					settingVariantInfo.disabled = subMenuButton.disabled
					settingVariantInfo.value = subMenuButton.value
					settingVariantInfo.hasArrow = subMenuButton.hasArrow
					settingVariantInfo.checked = (settingVariantInfo.value == DB.Groups[groupID].Icons[iconID][settingName])
					settingVariantInfo.func = core.IconMenu_ChooseSetting
					UIDropDownMenu_AddButton(settingVariantInfo, UIDROPDOWNMENU_MENU_LEVEL)
				end
			end
			local submenuInfo
			if UIDROPDOWNMENU_MENU_VALUE == "Row" then
				submenuInfo = UIDropDownMenu_CreateInfo()
				submenuInfo.text = L["Row"]
				submenuInfo.disabled = true
				submenuInfo.isTitle = true
				UIDropDownMenu_AddButton(submenuInfo, UIDROPDOWNMENU_MENU_LEVEL)

				submenuInfo = UIDropDownMenu_CreateInfo()
				submenuInfo.text = L["Copy"]
				submenuInfo.func = core.IconMenu_Row_Copy
				UIDropDownMenu_AddButton(submenuInfo, UIDROPDOWNMENU_MENU_LEVEL)

				submenuInfo = UIDropDownMenu_CreateInfo()
				submenuInfo.text = L["Cut"]
				submenuInfo.func = core.IconMenu_Row_Cut
				UIDropDownMenu_AddButton(submenuInfo, UIDROPDOWNMENU_MENU_LEVEL)

				submenuInfo = UIDropDownMenu_CreateInfo()
				submenuInfo.text = L["Paste"]
				submenuInfo.func = core.IconMenu_Row_Paste
				UIDropDownMenu_AddButton(submenuInfo, UIDROPDOWNMENU_MENU_LEVEL)

				submenuInfo = UIDropDownMenu_CreateInfo()
				submenuInfo.text = L["Insert"]
				submenuInfo.func = core.IconMenu_Row_Insert
				UIDropDownMenu_AddButton(submenuInfo, UIDROPDOWNMENU_MENU_LEVEL)

				submenuInfo = UIDropDownMenu_CreateInfo()
				submenuInfo.text = L["Add"]
				submenuInfo.func = core.IconMenu_Row_Add
				UIDropDownMenu_AddButton(submenuInfo, UIDROPDOWNMENU_MENU_LEVEL)

				submenuInfo = UIDropDownMenu_CreateInfo()
				submenuInfo.text = L["Delete"]
				submenuInfo.func = core.IconMenu_Row_Delete
				UIDropDownMenu_AddButton(submenuInfo, UIDROPDOWNMENU_MENU_LEVEL)

				submenuInfo = UIDropDownMenu_CreateInfo()
				submenuInfo.text = L["Up"]
				submenuInfo.func = core.IconMenu_Row_Up
				UIDropDownMenu_AddButton(submenuInfo, UIDROPDOWNMENU_MENU_LEVEL)

				submenuInfo = UIDropDownMenu_CreateInfo()
				submenuInfo.text = L["Down"]
				submenuInfo.func = core.IconMenu_Row_Down
				UIDropDownMenu_AddButton(submenuInfo, UIDROPDOWNMENU_MENU_LEVEL)

				submenuInfo = UIDropDownMenu_CreateInfo()
				submenuInfo.text = L["Clear"]
				submenuInfo.func = core.IconMenu_Row_Clear
				UIDropDownMenu_AddButton(submenuInfo, UIDROPDOWNMENU_MENU_LEVEL)

				submenuInfo = UIDropDownMenu_CreateInfo()
				submenuInfo.disabled = true
				UIDropDownMenu_AddButton(submenuInfo, UIDROPDOWNMENU_MENU_LEVEL)

				submenuInfo = UIDropDownMenu_CreateInfo()
				submenuInfo.text = L["Icon in row"]
				submenuInfo.disabled = true
				submenuInfo.isTitle = true
				UIDropDownMenu_AddButton(submenuInfo, UIDROPDOWNMENU_MENU_LEVEL)

				submenuInfo = UIDropDownMenu_CreateInfo()
				submenuInfo.text = L["Insert"]
				submenuInfo.func = core.IconMenu_Row_Icon_Insert
				UIDropDownMenu_AddButton(submenuInfo, UIDROPDOWNMENU_MENU_LEVEL)

				submenuInfo = UIDropDownMenu_CreateInfo()
				submenuInfo.text = L["Delete"]
				submenuInfo.func = core.IconMenu_Row_Icon_Delete
				UIDropDownMenu_AddButton(submenuInfo, UIDROPDOWNMENU_MENU_LEVEL)

				submenuInfo = UIDropDownMenu_CreateInfo()
				submenuInfo.text = L["Left"]
				submenuInfo.func = core.IconMenu_Row_Icon_Left
				UIDropDownMenu_AddButton(submenuInfo, UIDROPDOWNMENU_MENU_LEVEL)

				submenuInfo = UIDropDownMenu_CreateInfo()
				submenuInfo.text = L["Right"]
				submenuInfo.func = core.IconMenu_Row_Icon_Right
				UIDropDownMenu_AddButton(submenuInfo, UIDROPDOWNMENU_MENU_LEVEL)
			elseif UIDROPDOWNMENU_MENU_VALUE == "Column" then
				submenuInfo = UIDropDownMenu_CreateInfo()
				submenuInfo.text = L["Column"]
				submenuInfo.disabled = true
				submenuInfo.isTitle = true
				UIDropDownMenu_AddButton(submenuInfo, UIDROPDOWNMENU_MENU_LEVEL)

				submenuInfo = UIDropDownMenu_CreateInfo()
				submenuInfo.text = L["Copy"]
				submenuInfo.func = core.IconMenu_Column_Copy
				UIDropDownMenu_AddButton(submenuInfo, UIDROPDOWNMENU_MENU_LEVEL)

				submenuInfo = UIDropDownMenu_CreateInfo()
				submenuInfo.text = L["Cut"]
				submenuInfo.func = core.IconMenu_Column_Cut
				UIDropDownMenu_AddButton(submenuInfo, UIDROPDOWNMENU_MENU_LEVEL)

				submenuInfo = UIDropDownMenu_CreateInfo()
				submenuInfo.text = L["Paste"]
				submenuInfo.func = core.IconMenu_Column_Paste
				UIDropDownMenu_AddButton(submenuInfo, UIDROPDOWNMENU_MENU_LEVEL)

				submenuInfo = UIDropDownMenu_CreateInfo()
				submenuInfo.text = L["Insert"]
				submenuInfo.func = core.IconMenu_Column_Insert
				UIDropDownMenu_AddButton(submenuInfo, UIDROPDOWNMENU_MENU_LEVEL)

				submenuInfo = UIDropDownMenu_CreateInfo()
				submenuInfo.text = L["Add"]
				submenuInfo.func = core.IconMenu_Column_Add
				UIDropDownMenu_AddButton(submenuInfo, UIDROPDOWNMENU_MENU_LEVEL)

				submenuInfo = UIDropDownMenu_CreateInfo()
				submenuInfo.text = L["Delete"]
				submenuInfo.func = core.IconMenu_Column_Delete
				UIDropDownMenu_AddButton(submenuInfo, UIDROPDOWNMENU_MENU_LEVEL)

				submenuInfo = UIDropDownMenu_CreateInfo()
				submenuInfo.text = L["Clear"]
				submenuInfo.func = core.IconMenu_Column_Clear
				UIDropDownMenu_AddButton(submenuInfo, UIDROPDOWNMENU_MENU_LEVEL)

				submenuInfo = UIDropDownMenu_CreateInfo()
				submenuInfo.text = L["Left"]
				submenuInfo.func = core.IconMenu_Column_Left
				UIDropDownMenu_AddButton(submenuInfo, UIDROPDOWNMENU_MENU_LEVEL)

				submenuInfo = UIDropDownMenu_CreateInfo()
				submenuInfo.text = L["Right"]
				submenuInfo.func = core.IconMenu_Column_Right
				UIDropDownMenu_AddButton(submenuInfo, UIDROPDOWNMENU_MENU_LEVEL)

				submenuInfo = UIDropDownMenu_CreateInfo()
				submenuInfo.disabled = true
				UIDropDownMenu_AddButton(submenuInfo, UIDROPDOWNMENU_MENU_LEVEL)

				submenuInfo = UIDropDownMenu_CreateInfo()
				submenuInfo.text = L["Icon in column"]
				submenuInfo.disabled = true
				submenuInfo.isTitle = true
				UIDropDownMenu_AddButton(submenuInfo, UIDROPDOWNMENU_MENU_LEVEL)

				submenuInfo = UIDropDownMenu_CreateInfo()
				submenuInfo.text = L["Insert"]
				submenuInfo.func = core.IconMenu_Column_Icon_Insert
				UIDropDownMenu_AddButton(submenuInfo, UIDROPDOWNMENU_MENU_LEVEL)

				submenuInfo = UIDropDownMenu_CreateInfo()
				submenuInfo.text = L["Delete"]
				submenuInfo.func = core.IconMenu_Column_Icon_Delete
				UIDropDownMenu_AddButton(submenuInfo, UIDROPDOWNMENU_MENU_LEVEL)

				submenuInfo = UIDropDownMenu_CreateInfo()
				submenuInfo.text = L["Up"]
				submenuInfo.func = core.IconMenu_Column_Icon_Up
				UIDropDownMenu_AddButton(submenuInfo, UIDROPDOWNMENU_MENU_LEVEL)

				submenuInfo = UIDropDownMenu_CreateInfo()
				submenuInfo.text = L["Down"]
				submenuInfo.func = core.IconMenu_Column_Icon_Down
				UIDropDownMenu_AddButton(submenuInfo, UIDROPDOWNMENU_MENU_LEVEL)
			elseif UIDROPDOWNMENU_MENU_VALUE == "Group" then
				submenuInfo = UIDropDownMenu_CreateInfo()
				submenuInfo.text = L["Group"]
				submenuInfo.disabled = true
				submenuInfo.isTitle = true
				UIDropDownMenu_AddButton(submenuInfo, UIDROPDOWNMENU_MENU_LEVEL)

				submenuInfo = UIDropDownMenu_CreateInfo()
				submenuInfo.text = L["Copy"]
				submenuInfo.func = core.IconMenu_Group_Copy
				UIDropDownMenu_AddButton(submenuInfo, UIDROPDOWNMENU_MENU_LEVEL)

				submenuInfo = UIDropDownMenu_CreateInfo()
				submenuInfo.text = L["Paste"]
				submenuInfo.func = core.IconMenu_Group_Paste
				UIDropDownMenu_AddButton(submenuInfo, UIDROPDOWNMENU_MENU_LEVEL)

				submenuInfo = UIDropDownMenu_CreateInfo()
				submenuInfo.text = L["Clear"]
				submenuInfo.func = core.IconMenu_Group_Clear
				UIDropDownMenu_AddButton(submenuInfo, UIDROPDOWNMENU_MENU_LEVEL)
			end
			return
		end

		-- show name
		if name and name ~= "" then
			local info = UIDropDownMenu_CreateInfo()
			info.text = name
			info.isTitle = true
			UIDropDownMenu_AddButton(info)
		end

		-- choose name
		if iconType ~= "wpnenchant" then
			info = UIDropDownMenu_CreateInfo()
			info.text = L["Choose spell/item/buff/etc."]
			info.func = core.IconMenu_ShowNameDialog
			UIDropDownMenu_AddButton(info)
		end

		-- enable icon
		info = UIDropDownMenu_CreateInfo()
		info.value = "Enabled"
		info.text = L["Enable"]
		info.checked = enabled
		info.func = core.IconMenu_ToggleSetting
		info.keepShownOnClick = true
		UIDropDownMenu_AddButton(info)

		-- icon type
		info = UIDropDownMenu_CreateInfo()
		info.value = "Type"
		info.text = L["Icon type"]
		info.hasArrow = true
		UIDropDownMenu_AddButton(info)

		-- additional options
		if
		iconType == "cooldown" or iconType == "buff" or iconType == "reactive" or iconType == "wpnenchant" or
				iconType == "totem"
		then
			info = UIDropDownMenu_CreateInfo()
			info.disabled = true
			UIDropDownMenu_AddButton(info)

			local moreOptions
			if iconType == "cooldown" then
				moreOptions = TellMeWhen_IconMenu_CooldownOptions
			elseif iconType == "buff" then
				moreOptions = TellMeWhen_IconMenu_BuffOptions
			elseif iconType == "reactive" then
				moreOptions = TellMeWhen_IconMenu_ReactiveOptions
			elseif iconType == "wpnenchant" then
				moreOptions = TellMeWhen_IconMenu_WpnEnchantOptions
			elseif iconType == "totem" then
				moreOptions = TellMeWhen_IconMenu_TotemOptions
			end

			for index, value in ipairs(moreOptions) do
				info = UIDropDownMenu_CreateInfo()
				info.text = moreOptions[index].text
				info.value = moreOptions[index].value
				info.hasArrow = moreOptions[index].hasArrow
				if not info.hasArrow then
					info.func = core.IconMenu_ToggleSetting
					info.checked = DB.Groups[groupID].Icons[iconID][info.value]
				end
				info.keepShownOnClick = true
				UIDropDownMenu_AddButton(info)
			end
		end

		info = UIDropDownMenu_CreateInfo()
		info.disabled = true
		UIDropDownMenu_AddButton(info)

		info = UIDropDownMenu_CreateInfo()
		info.text = L["Copy"]
		info.func = core.IconMenu_Copy
		UIDropDownMenu_AddButton(info)

		info = UIDropDownMenu_CreateInfo()
		info.text = L["Cut"]
		info.func = core.IconMenu_Cut
		UIDropDownMenu_AddButton(info)

		info = UIDropDownMenu_CreateInfo()
		info.text = L["Paste"]
		info.func = core.IconMenu_Paste
		UIDropDownMenu_AddButton(info)

		info = UIDropDownMenu_CreateInfo()
		info.text = L["Clear"]
		info.func = core.IconMenu_ClearSettings
		UIDropDownMenu_AddButton(info)

		-- Row
		info = UIDropDownMenu_CreateInfo()
		info.value = "Row"
		info.text = L["Row"]
		info.hasArrow = true
		UIDropDownMenu_AddButton(info)

		-- Column
		info = UIDropDownMenu_CreateInfo()
		info.value = "Column"
		info.text = L["Column"]
		info.hasArrow = true
		UIDropDownMenu_AddButton(info)

		-- Column
		info = UIDropDownMenu_CreateInfo()
		info.value = "Group"
		info.text = L["Group"]
		info.hasArrow = true
		UIDropDownMenu_AddButton(info)

		info = UIDropDownMenu_CreateInfo()
		info.text = L["Clear clipboard"]
		info.func = core.Clipboard_Clear
		UIDropDownMenu_AddButton(info)
	end

	function core:IconMenu_ShowNameDialog()
		local dialog = StaticPopup_Show("TELLMEWHEN_CHOOSENAME_DIALOG")
	end

	function core:Clipboard_Clear()
		clipboard = {}
		core:Group_UpdateAll()
	end

	function core:Group_UpdateAll()
		for groupID = 1, maxGroups do
			core:Group_Update(groupID)
		end
	end

	function core:IconMenu_Copy()
		local groupID = currentIcon.groupID
		local iconID = currentIcon.iconID

		core:Clipboard_Clear()

		clipboard.icon = {
			groupID = groupID,
			iconID = iconID,
			data = CopyTable(DB.Groups[groupID].Icons[iconID]),
		}

		core:Group_UpdateAll()
	end

	function core:IconMenu_Cut()
		core:IconMenu_Copy()
		clipboard.icon.groupID = nil
		clipboard.icon.iconID = nil
		core:IconMenu_ClearSettings()
	end

	function core:IconMenu_Paste()
		local iconSettings

		local clipboardIcon = clipboard.icon
		if not clipboardIcon then
			return
		end

		iconSettings = clipboardIcon.data
		if not iconSettings then
			return
		end

		local groupID = currentIcon.groupID
		local iconID = currentIcon.iconID

		DB.Groups[groupID].Icons[iconID] = CopyTable(iconSettings)

		core:Icon_Update(
				_G["TellMeWhen_Group" .. groupID .. "_Icon" .. iconID],
				groupID,
				iconID
		)
	end

	function core:IconMenu_Row_Icon_Left()
		local groupID = currentIcon.groupID
		local iconID = currentIcon.iconID

		local maxRowIndex = DB.Groups[groupID].Rows - 1
		local maxColumnIndex = DB.Groups[groupID].Columns - 1

		local iconIndex = iconID - 1

		local columnIndex = iconIndex % (maxColumnIndex + 1)
		local rowIndex = math.floor(iconIndex / (maxColumnIndex + 1))

		if columnIndex == 0 then
			CloseDropDownMenus()
			return
		end

		local leftIconID = iconID - 1
		local leftIconSettings = DB.Groups[groupID].Icons[leftIconID]

		local thisIconSettings = DB.Groups[groupID].Icons[iconID]

		DB.Groups[groupID].Icons[leftIconID] = thisIconSettings
		DB.Groups[groupID].Icons[iconID] = leftIconSettings

		core:Clipboard_Clear()

		core:Group_Update(groupID)

		CloseDropDownMenus()
	end

	function core:IconMenu_Row_Icon_Right()
		local groupID = currentIcon.groupID
		local iconID = currentIcon.iconID

		local maxRowIndex = DB.Groups[groupID].Rows - 1
		local maxColumnIndex = DB.Groups[groupID].Columns - 1

		local iconIndex = iconID - 1

		local columnIndex = iconIndex % (maxColumnIndex + 1)
		local rowIndex = math.floor(iconIndex / (maxColumnIndex + 1))

		if columnIndex == maxColumnIndex then
			CloseDropDownMenus()
			return
		end

		local thisIconSettings = DB.Groups[groupID].Icons[iconID]

		local rightIconID = iconID + 1
		local rightIconSettings = DB.Groups[groupID].Icons[rightIconID]

		DB.Groups[groupID].Icons[iconID] = rightIconSettings
		DB.Groups[groupID].Icons[rightIconID] = thisIconSettings

		core:Clipboard_Clear()

		core:Group_Update(groupID)

		CloseDropDownMenus()
	end

	function core:IconMenu_Column_Icon_Up()
		local groupID = currentIcon.groupID
		local iconID = currentIcon.iconID

		local maxRowIndex = DB.Groups[groupID].Rows - 1
		local maxColumnIndex = DB.Groups[groupID].Columns - 1

		local iconIndex = iconID - 1

		local columnIndex = iconIndex % (maxColumnIndex + 1)
		local rowIndex = math.floor(iconIndex / (maxColumnIndex + 1))

		if rowIndex == 0 then
			CloseDropDownMenus()
			return
		end

		local upIconID = iconID - DB.Groups[groupID].Columns
		local upIconSettings = DB.Groups[groupID].Icons[upIconID]

		local thisIconSettings = DB.Groups[groupID].Icons[iconID]

		DB.Groups[groupID].Icons[upIconID] = thisIconSettings
		DB.Groups[groupID].Icons[iconID] = upIconSettings

		core:Clipboard_Clear()

		core:Group_Update(groupID)

		CloseDropDownMenus()
	end

	function core:IconMenu_Column_Icon_Down()
		local groupID = currentIcon.groupID
		local iconID = currentIcon.iconID

		local maxRowIndex = DB.Groups[groupID].Rows - 1
		local maxColumnIndex = DB.Groups[groupID].Columns - 1

		local iconIndex = iconID - 1

		local columnIndex = iconIndex % (maxColumnIndex + 1)
		local rowIndex = math.floor(iconIndex / (maxColumnIndex + 1))

		if rowIndex == maxRowIndex then
			CloseDropDownMenus()
			return
		end

		local thisIconSettings = DB.Groups[groupID].Icons[iconID]

		local downIconID = iconID + DB.Groups[groupID].Columns
		local downIconSettings = DB.Groups[groupID].Icons[downIconID]

		DB.Groups[groupID].Icons[iconID] = downIconSettings
		DB.Groups[groupID].Icons[downIconID] = thisIconSettings

		core:Clipboard_Clear()

		core:Group_Update(groupID)

		CloseDropDownMenus()
	end

	function core:IconMenu_Row_Icon_Insert()
		local groupID = currentIcon.groupID
		local iconID = currentIcon.iconID

		local maxRowIndex = DB.Groups[groupID].Rows - 1
		local maxColumnIndex = DB.Groups[groupID].Columns - 1

		local iconIndex = iconID - 1

		local columnIndex = iconIndex % (maxColumnIndex + 1)
		local rowIndex = math.floor(iconIndex / (maxColumnIndex + 1))

		local lastIconID = core:Group_GetIconID(groupID, rowIndex, maxColumnIndex)

		local lastIcon = DB.Groups[groupID].Icons[lastIconID]

		if not core:IconSettings_IsEmpty(lastIcon) then
			StaticPopup_Show("TELLMEWHEN_SIMPLE_DIALOG", "Last icon in row is not empty")
			CloseDropDownMenus()
			return
		end

		for otherColumnIndex = maxColumnIndex - 1, columnIndex, -1 do
			local otherIconID = core:Group_GetIconID(groupID, rowIndex, otherColumnIndex)
			DB.Groups[groupID].Icons[otherIconID + 1] = DB.Groups[groupID].Icons[otherIconID]
		end

		DB.Groups[groupID].Icons[iconID] = CopyTable(iconDefaults)

		core:IconMenu_Paste()

		core:Clipboard_Clear()

		core:Group_Update(groupID)

		CloseDropDownMenus()
	end

	function core:IconMenu_Column_Icon_Insert()
		local groupID = currentIcon.groupID
		local iconID = currentIcon.iconID

		local maxRowIndex = DB.Groups[groupID].Rows - 1
		local maxColumnIndex = DB.Groups[groupID].Columns - 1

		local iconIndex = iconID - 1

		local columnIndex = iconIndex % (maxColumnIndex + 1)
		local rowIndex = math.floor(iconIndex / (maxColumnIndex + 1))

		local lastIconID = core:Group_GetIconID(groupID, maxRowIndex, columnIndex)

		local lastIcon = DB.Groups[groupID].Icons[lastIconID]

		if not core:IconSettings_IsEmpty(lastIcon) then
			StaticPopup_Show("TELLMEWHEN_SIMPLE_DIALOG", "Last icon in column is not empty")
			CloseDropDownMenus()
			return
		end

		for otherRowIndex = maxRowIndex - 1, rowIndex, -1 do
			local otherIconID = core:Group_GetIconID(groupID, otherRowIndex, columnIndex)

			DB.Groups[groupID].Icons[otherIconID + maxColumnIndex + 1] = DB.Groups[groupID].Icons[otherIconID]
		end

		DB.Groups[groupID].Icons[iconID] = CopyTable(iconDefaults)

		core:IconMenu_Paste()

		core:Clipboard_Clear()

		core:Group_Update(groupID)

		CloseDropDownMenus()
	end

	function core:IconMenu_Row_Icon_Delete()
		local groupID = currentIcon.groupID
		local iconID = currentIcon.iconID

		local maxRowIndex = DB.Groups[groupID].Rows - 1
		local maxColumnIndex = DB.Groups[groupID].Columns - 1

		local iconIndex = iconID - 1

		local columnIndex = iconIndex % (maxColumnIndex + 1)
		local rowIndex = math.floor(iconIndex / (maxColumnIndex + 1))

		for otherColumnIndex = columnIndex, maxColumnIndex - 1 do
			local otherIconID = core:Group_GetIconID(groupID, rowIndex, otherColumnIndex)

			DB.Groups[groupID].Icons[otherIconID] = DB.Groups[groupID].Icons[otherIconID + 1]
		end

		local lastIconID = core:Group_GetIconID(groupID, rowIndex, maxColumnIndex)
		DB.Groups[groupID].Icons[lastIconID] = CopyTable(iconDefaults)

		core:Clipboard_Clear()

		core:Group_Update(groupID)

		CloseDropDownMenus()
	end

	function core:IconMenu_Column_Icon_Delete()
		local groupID = currentIcon.groupID
		local iconID = currentIcon.iconID

		local maxRowIndex = DB.Groups[groupID].Rows - 1
		local maxColumnIndex = DB.Groups[groupID].Columns - 1

		local iconIndex = iconID - 1

		local columnIndex = iconIndex % (maxColumnIndex + 1)
		local rowIndex = math.floor(iconIndex / (maxColumnIndex + 1))

		for otherRowIndex = rowIndex, maxRowIndex - 1 do
			local otherIconID = core:Group_GetIconID(groupID, otherRowIndex, columnIndex)

			DB.Groups[groupID].Icons[otherIconID] = DB.Groups[groupID].Icons[otherIconID + maxColumnIndex + 1]
		end

		local lastIconID = core:Group_GetIconID(groupID, maxRowIndex, columnIndex)
		DB.Groups[groupID].Icons[lastIconID] = CopyTable(iconDefaults)

		core:Clipboard_Clear()

		core:Group_Update(groupID)

		CloseDropDownMenus()
	end

	function core:IconMenu_Row_Delete()
		local groupID = currentIcon.groupID
		local iconID = currentIcon.iconID

		local maxRowIndex = DB.Groups[groupID].Rows - 1
		local maxColumnIndex = DB.Groups[groupID].Columns - 1

		local iconIndex = iconID - 1

		local rowIndex = math.floor(iconIndex / (maxColumnIndex + 1))

		for columnIndex = 0, maxColumnIndex do
			for otherRowIndex = rowIndex, maxRowIndex - 1 do
				local otherIconID = core:Group_GetIconID(groupID, otherRowIndex, columnIndex)

				DB.Groups[groupID].Icons[otherIconID] = DB.Groups[groupID].Icons[otherIconID + maxColumnIndex + 1]
			end

			local lastIconID = core:Group_GetIconID(groupID, maxRowIndex, columnIndex)
			DB.Groups[groupID].Icons[lastIconID] = CopyTable(iconDefaults)
		end

		if DB.Groups[groupID].Rows > 1 then
			DB.Groups[groupID].Rows = DB.Groups[groupID].Rows - 1
		end

		core:Clipboard_Clear()

		core:Group_Update(groupID)

		CloseDropDownMenus()
	end

	function core:IconMenu_Column_Delete()
		local groupID = currentIcon.groupID
		local iconID = currentIcon.iconID

		local maxRowIndex = DB.Groups[groupID].Rows - 1
		local maxColumnIndex = DB.Groups[groupID].Columns - 1

		local iconIndex = iconID - 1

		local columnIndex = iconIndex % (maxColumnIndex + 1)

		for rowIndex = 0, maxRowIndex do
			for otherColumnIndex = columnIndex, maxColumnIndex - 1 do
				local otherIconID = core:Group_GetIconID(groupID, rowIndex, otherColumnIndex)

				DB.Groups[groupID].Icons[otherIconID] = DB.Groups[groupID].Icons[otherIconID + 1]
			end

			local lastIconID = core:Group_GetIconID(groupID, rowIndex, maxColumnIndex)
			DB.Groups[groupID].Icons[lastIconID] = CopyTable(iconDefaults)
		end

		if DB.Groups[groupID].Columns > 1 then

			for rowIndex = 0, maxRowIndex do
				local removedIconID = core:Group_GetIconID(groupID, rowIndex, maxColumnIndex)
				DB.Groups[groupID].Icons[removedIconID] = CopyTable(iconDefaults)
			end

			local matrix = core:Group_GetMatrix(groupID)

			DB.Groups[groupID].Columns = DB.Groups[groupID].Columns - 1
			maxColumnIndex = maxColumnIndex - 1

			core:Group_LoadFromMatrix(groupID, matrix)
		end

		core:Clipboard_Clear()

		core:Group_Update(groupID)

		CloseDropDownMenus()
	end

	function core:IconMenu_Row_Copy()
		core:Clipboard_Clear()

		local groupID = currentIcon.groupID
		local iconID = currentIcon.iconID
		local maxColumnIndex = DB.Groups[groupID].Columns - 1
		local iconIndex = iconID - 1
		local rowIndex = math.floor(iconIndex / (maxColumnIndex + 1))

		clipboard.row = {
			groupID = groupID,
			index = rowIndex,
			icons = {},
		}

		for columnIndex = 0, maxColumnIndex do
			local currentIconID = core:Group_GetIconID(groupID, rowIndex, columnIndex)
			clipboard.row.icons[columnIndex] = CopyTable(DB.Groups[groupID].Icons[currentIconID])
		end

		core:Group_UpdateAll()

		CloseDropDownMenus()
	end

	function core:IconMenu_Group_Copy()
		core:Clipboard_Clear()

		clipboard.group = {
			groupID = currentIcon.groupID,
		}

		core:Group_UpdateAll()

		CloseDropDownMenus()
	end

	function core:IconMenu_Group_Paste()
		if clipboard.group == nil then
			return
		end

		local groupID = currentIcon.groupID

		if clipboard.group.groupID == groupID then
			return
		end

		DB.Groups[groupID].Rows = DB.Groups[clipboard.group.groupID].Rows
		DB.Groups[groupID].Columns = DB.Groups[clipboard.group.groupID].Columns

		for iconID = 1, maxColumns * maxRows do
			local iconSettings = DB.Groups[clipboard.group.groupID].Icons[iconID]
			if iconSettings ~= nil then
				iconSettings = CopyTable(iconSettings)
			end

			DB.Groups[groupID].Icons[iconID] = iconSettings
		end

		core:Clipboard_Clear()

		core:Group_UpdateAll()

		CloseDropDownMenus()
	end

	function core:IconMenu_Group_Clear()
		core:Clipboard_Clear()

		local groupID = currentIcon.groupID

		for iconID = 1, maxColumns * maxRows do
			DB.Groups[groupID].Icons[iconID] = CopyTable(iconDefaults)
		end

		core:Group_UpdateAll()

		CloseDropDownMenus()
	end

	function core:IconMenu_Row_Cut()
		core:IconMenu_Row_Copy()
		clipboard.row.groupID = nil
		clipboard.row.index = nil
		core:IconMenu_Row_Delete()
	end

	function core:IconMenu_Column_Copy()
		core:Clipboard_Clear()

		local groupID = currentIcon.groupID
		local iconID = currentIcon.iconID
		local maxRowIndex = DB.Groups[groupID].Rows - 1
		local maxColumnIndex = DB.Groups[groupID].Columns - 1
		local iconIndex = iconID - 1
		local columnIndex = iconIndex % (maxColumnIndex + 1)

		clipboard.column = {
			groupID = groupID,
			index = columnIndex,
			icons = {},
		}

		for rowIndex = 0, maxRowIndex do
			local currentIconID = core:Group_GetIconID(groupID, rowIndex, columnIndex)
			clipboard.column.icons[rowIndex] = CopyTable(DB.Groups[groupID].Icons[currentIconID])
		end

		core:Group_UpdateAll()

		CloseDropDownMenus()
	end

	function core:IconMenu_Column_Cut()
		core:IconMenu_Column_Copy()
		clipboard.column.groupID = nil
		clipboard.column.index = nil
		core:IconMenu_Column_Delete()
	end

	function core:IconMenu_Row_Insert()
		local groupID = currentIcon.groupID
		local iconID = currentIcon.iconID

		local maxRowIndex = DB.Groups[groupID].Rows - 1
		local maxColumnIndex = DB.Groups[groupID].Columns - 1

		local iconIndex = iconID - 1
		local rowIndex = math.floor(iconIndex / (maxColumnIndex + 1))

		local nonEmptyIcons = false

		for columnIndex = 0, maxColumnIndex do
			local lastIconID = core:Group_GetIconID(groupID, maxRowIndex, columnIndex)
			local lastIcon = DB.Groups[groupID].Icons[lastIconID]
			if not core:IconSettings_IsEmpty(lastIcon) then
				nonEmptyIcons = true
				break
			end
		end
		if nonEmptyIcons then
			if DB.Groups[groupID].Rows >= maxRows then
				StaticPopup_Show("TELLMEWHEN_SIMPLE_DIALOG", "Some last row icons are not empty")
				CloseDropDownMenus()
				return
			end
			DB.Groups[groupID].Rows = DB.Groups[groupID].Rows + 1
			maxRowIndex = maxRowIndex + 1
		end

		for columnIndex = 0, maxColumnIndex do
			for otherRowIndex = maxRowIndex - 1, rowIndex, -1 do
				local otherIconID = core:Group_GetIconID(groupID, otherRowIndex, columnIndex)

				DB.Groups[groupID].Icons[otherIconID + maxColumnIndex + 1] = DB.Groups[groupID].Icons[otherIconID]
			end

			local thisRowIconID = core:Group_GetIconID(groupID, rowIndex, columnIndex)
			DB.Groups[groupID].Icons[thisRowIconID] = CopyTable(iconDefaults)
		end

		core:IconMenu_Row_Paste()

		core:Clipboard_Clear()

		core:Group_Update(groupID)

		CloseDropDownMenus()
	end

	function core:IconMenu_Row_Paste()
		local clipboardRow = clipboard.row
		if not (clipboardRow and clipboardRow.icons) then
			return
		end

		local groupID = currentIcon.groupID
		local iconID = currentIcon.iconID

		local maxRowIndex = DB.Groups[groupID].Rows - 1
		local maxColumnIndex = DB.Groups[groupID].Columns - 1

		local iconIndex = iconID - 1
		local rowIndex = math.floor(iconIndex / (maxColumnIndex + 1))

		for columnIndex = 0, maxColumnIndex do
			local thisRowIconID = core:Group_GetIconID(groupID, rowIndex, columnIndex)
			local iconSettings = clipboardRow.icons[columnIndex]
			if iconSettings then
				DB.Groups[groupID].Icons[thisRowIconID] = CopyTable(iconSettings)
			end
		end

		core:Group_Update(groupID)

		CloseDropDownMenus()
	end

	function core:IconMenu_Row_Up()
		local groupID = currentIcon.groupID
		local iconID = currentIcon.iconID

		local maxRowIndex = DB.Groups[groupID].Rows - 1
		local maxColumnIndex = DB.Groups[groupID].Columns - 1

		local iconIndex = iconID - 1
		local rowIndex = math.floor(iconIndex / (maxColumnIndex + 1))

		if rowIndex == 0 then
			CloseDropDownMenus()
			return
		end

		for columnIndex = 0, maxColumnIndex do
			local upperRowIconID = core:Group_GetIconID(groupID, rowIndex - 1, columnIndex)
			local upperRowIcon = DB.Groups[groupID].Icons[upperRowIconID]

			local thisRowIconID = core:Group_GetIconID(groupID, rowIndex, columnIndex)
			local thisRowIcon = DB.Groups[groupID].Icons[thisRowIconID]

			DB.Groups[groupID].Icons[upperRowIconID] = thisRowIcon
			DB.Groups[groupID].Icons[thisRowIconID] = upperRowIcon
		end

		core:Clipboard_Clear()

		core:Group_Update(groupID)

		CloseDropDownMenus()
	end

	function core:IconMenu_Row_Down()
		local groupID = currentIcon.groupID
		local iconID = currentIcon.iconID

		local maxRowIndex = DB.Groups[groupID].Rows - 1
		local maxColumnIndex = DB.Groups[groupID].Columns - 1

		local iconIndex = iconID - 1
		local rowIndex = math.floor(iconIndex / (maxColumnIndex + 1))

		if rowIndex == maxRowIndex then
			CloseDropDownMenus()
			return
		end

		for columnIndex = 0, maxColumnIndex do
			local thisRowIconID = core:Group_GetIconID(groupID, rowIndex, columnIndex)
			local thisRowIcon = DB.Groups[groupID].Icons[thisRowIconID]

			local lowerRowIconID = core:Group_GetIconID(groupID, rowIndex + 1, columnIndex)
			local lowerRowIcon = DB.Groups[groupID].Icons[lowerRowIconID]

			DB.Groups[groupID].Icons[thisRowIconID] = lowerRowIcon
			DB.Groups[groupID].Icons[lowerRowIconID] = thisRowIcon
		end

		core:Clipboard_Clear()

		core:Group_Update(groupID)

		CloseDropDownMenus()
	end

	function core:IconMenu_Row_Clear()
		local groupID = currentIcon.groupID
		local iconID = currentIcon.iconID

		local maxRowIndex = DB.Groups[groupID].Rows - 1
		local maxColumnIndex = DB.Groups[groupID].Columns - 1

		local iconIndex = iconID - 1
		local rowIndex = math.floor(iconIndex / (maxColumnIndex + 1))

		for columnIndex = 0, maxColumnIndex do
			local thisRowIconID = core:Group_GetIconID(groupID, rowIndex, columnIndex)
			DB.Groups[groupID].Icons[thisRowIconID] = CopyTable(iconDefaults)
		end

		core:Group_Update(groupID)

		CloseDropDownMenus()
	end

	function core:IconMenu_Column_Insert()
		local groupID = currentIcon.groupID
		local iconID = currentIcon.iconID

		local maxRowIndex = DB.Groups[groupID].Rows - 1
		local maxColumnIndex = DB.Groups[groupID].Columns - 1

		local iconIndex = iconID - 1

		local menuRowIndex = math.floor(iconIndex / (maxColumnIndex + 1))
		local menuColumnIndex = iconIndex % (maxColumnIndex + 1)

		local nonEmptyIcons = false
		for rowIndex = 0, maxRowIndex do
			local lastIconID = core:Group_GetIconID(groupID, rowIndex, maxColumnIndex)
			local lastIcon = DB.Groups[groupID].Icons[lastIconID]
			if not core:IconSettings_IsEmpty(lastIcon) then
				nonEmptyIcons = true
			end
		end
		if nonEmptyIcons then
			if DB.Groups[groupID].Columns >= maxColumns then
				StaticPopup_Show("TELLMEWHEN_SIMPLE_DIALOG", "Some last column icons are not empty")
				CloseDropDownMenus()
				return
			end

			local matrix = core:Group_GetMatrix(groupID)

			DB.Groups[groupID].Columns = DB.Groups[groupID].Columns + 1
			maxColumnIndex = maxColumnIndex + 1
			currentIcon.iconID = core:Group_GetIconID(groupID, menuRowIndex, menuColumnIndex)

			core:Group_LoadFromMatrix(groupID, matrix)
		end

		for rowIndex = 0, maxRowIndex do
			for otherColumnIndex = maxColumnIndex - 1, menuColumnIndex, -1 do
				local otherIconID = core:Group_GetIconID(groupID, rowIndex, otherColumnIndex)

				DB.Groups[groupID].Icons[otherIconID + 1] = DB.Groups[groupID].Icons[otherIconID]
			end
			local thisColumnIconID = core:Group_GetIconID(groupID, rowIndex, menuColumnIndex)
			DB.Groups[groupID].Icons[thisColumnIconID] = CopyTable(iconDefaults)
		end

		core:IconMenu_Column_Paste()

		core:Clipboard_Clear()

		core:Group_Update(groupID)

		CloseDropDownMenus()
	end

	function core:IconMenu_Column_Paste()
		local clipboardColumn = clipboard.column
		if not (clipboardColumn and clipboardColumn.icons) then
			return
		end

		local groupID = currentIcon.groupID
		local iconID = currentIcon.iconID

		local maxRowIndex = DB.Groups[groupID].Rows - 1
		local maxColumnIndex = DB.Groups[groupID].Columns - 1

		local iconIndex = iconID - 1

		local columnIndex = iconIndex % (maxColumnIndex + 1)

		for rowIndex = 0, maxRowIndex do
			local thisColumnIconID = core:Group_GetIconID(groupID, rowIndex, columnIndex)
			local iconSettings = clipboardColumn.icons[rowIndex]
			if iconSettings then
				DB.Groups[groupID].Icons[thisColumnIconID] = CopyTable(iconSettings)
			end
		end

		core:Group_Update(groupID)

		CloseDropDownMenus()
	end

	function core:IconMenu_Column_Left()
		local groupID = currentIcon.groupID
		local iconID = currentIcon.iconID

		local maxRowIndex = DB.Groups[groupID].Rows - 1
		local maxColumnIndex = DB.Groups[groupID].Columns - 1

		local iconIndex = iconID - 1

		local columnIndex = iconIndex % (maxColumnIndex + 1)

		if columnIndex == 0 then
			CloseDropDownMenus()
			return
		end

		for rowIndex = 0, maxRowIndex do
			local leftColumnIconID = core:Group_GetIconID(groupID, rowIndex, columnIndex - 1)
			local leftColumnIcon = DB.Groups[groupID].Icons[leftColumnIconID]

			local thisColumnIconID = core:Group_GetIconID(groupID, rowIndex, columnIndex)
			local thisColumnIcon = DB.Groups[groupID].Icons[thisColumnIconID]

			DB.Groups[groupID].Icons[leftColumnIconID] = thisColumnIcon
			DB.Groups[groupID].Icons[thisColumnIconID] = leftColumnIcon
		end

		core:Clipboard_Clear()

		core:Group_Update(groupID)

		CloseDropDownMenus()
	end

	function core:IconMenu_Column_Right()
		local groupID = currentIcon.groupID
		local iconID = currentIcon.iconID

		local maxRowIndex = DB.Groups[groupID].Rows - 1
		local maxColumnIndex = DB.Groups[groupID].Columns - 1

		local iconIndex = iconID - 1

		local columnIndex = iconIndex % (maxColumnIndex + 1)

		if columnIndex == maxColumnIndex then
			CloseDropDownMenus()
			return
		end

		for rowIndex = 0, maxRowIndex do
			local thisColumnIconID = core:Group_GetIconID(groupID, rowIndex, columnIndex)
			local thisColumnIcon = DB.Groups[groupID].Icons[thisColumnIconID]

			local rightColumnIconID = core:Group_GetIconID(groupID, rowIndex, columnIndex + 1)
			local rightColumnIcon = DB.Groups[groupID].Icons[rightColumnIconID]

			DB.Groups[groupID].Icons[thisColumnIconID] = rightColumnIcon
			DB.Groups[groupID].Icons[rightColumnIconID] = thisColumnIcon
		end

		core:Clipboard_Clear()

		core:Group_Update(groupID)

		CloseDropDownMenus()
	end

	function core:IconMenu_Column_Clear()
		local groupID = currentIcon.groupID
		local iconID = currentIcon.iconID

		local maxRowIndex = DB.Groups[groupID].Rows - 1
		local maxColumnIndex = DB.Groups[groupID].Columns - 1

		local iconIndex = iconID - 1

		local columnIndex = iconIndex % (maxColumnIndex + 1)

		for rowIndex = 0, maxRowIndex do
			local thisColumnIconID = core:Group_GetIconID(groupID, rowIndex, columnIndex)
			DB.Groups[groupID].Icons[thisColumnIconID] = CopyTable(iconDefaults)
		end

		core:Group_Update(groupID)

		CloseDropDownMenus()
	end

	function core:IconMenu_Row_Add()
		local groupID = currentIcon.groupID
		if DB.Groups[groupID].Rows >= maxRows then
			StaticPopup_Show("TELLMEWHEN_SIMPLE_DIALOG", "Maximum rows number is "..maxRows)
			CloseDropDownMenus()
			return
		end
		DB.Groups[groupID].Rows = DB.Groups[groupID].Rows + 1

		core:Clipboard_Clear()

		core:Group_Update(groupID)

		CloseDropDownMenus()
	end

	function core:IconMenu_Column_Add()
		local groupID = currentIcon.groupID

		if DB.Groups[groupID].Columns >= maxColumns then
			StaticPopup_Show("TELLMEWHEN_SIMPLE_DIALOG", "Maximum columns number is "..maxColumns)
			CloseDropDownMenus()
			return
		end

		local matrix = core:Group_GetMatrix(groupID)

		DB.Groups[groupID].Columns = DB.Groups[groupID].Columns + 1

		core:Group_LoadFromMatrix(groupID, matrix)

		core:Clipboard_Clear()

		core:Group_Update(groupID)

		CloseDropDownMenus()
	end

	function core:IconMenu_ChooseName(text)
		local groupID = currentIcon.groupID
		local iconID = currentIcon.iconID
		DB.Groups[groupID].Icons[iconID].Name = text
		_G["TellMeWhen_Group" .. groupID .. "_Icon" .. iconID].learnedTexture = nil
		core:Icon_Update(_G["TellMeWhen_Group" .. groupID .. "_Icon" .. iconID], groupID, iconID)
	end

	function core:IconMenu_ToggleSetting()
		local groupID = currentIcon.groupID
		local iconID = currentIcon.iconID
		DB.Groups[groupID].Icons[iconID][this.value] = this.checked
		core:Icon_Update(_G["TellMeWhen_Group" .. groupID .. "_Icon" .. iconID], groupID, iconID)
	end

	function core:IconMenu_ChooseSetting()
		local groupID = currentIcon.groupID
		local iconID = currentIcon.iconID
		DB.Groups[groupID].Icons[iconID][UIDROPDOWNMENU_MENU_VALUE] = this.value
		core:Icon_Update(_G["TellMeWhen_Group" .. groupID .. "_Icon" .. iconID], groupID, iconID)
		if UIDROPDOWNMENU_MENU_VALUE == "Type" then
			CloseDropDownMenus()
		end
	end

	function core:IconMenu_ClearSettings()
		local groupID = currentIcon.groupID
		local iconID = currentIcon.iconID
		DB.Groups[groupID].Icons[iconID] = CopyTable(iconDefaults)
		core:Icon_Update(_G["TellMeWhen_Group" .. groupID .. "_Icon" .. iconID], groupID, iconID)
		CloseDropDownMenus()
	end
end

-- ---------------
-- GROUP FUNCTIONS
-- ---------------

function core:Group_Update(groupID)
	local currentSpec = core:GetActiveTalentGroup()
	local groupName = "TellMeWhen_Group" .. groupID
	local group = _G[groupName]
	local resizeButton = group.resize

	local locked = DB.Locked
	local genabled = DB.Groups[groupID].Enabled
	local scale = DB.Groups[groupID].Scale
	local rows = DB.Groups[groupID].Rows
	local columns = DB.Groups[groupID].Columns
	local onlyInCombat = DB.Groups[groupID].OnlyInCombat
	local activePriSpec = DB.Groups[groupID].PrimarySpec
	local activeSecSpec = DB.Groups[groupID].SecondarySpec
	local iconSpacing = TELLMEWHEN_ICONSPACING or DB.Groups[groupID].Spacing or 1
	local iconWidth = DB.Groups[groupID].Width or 30
	local iconHeight = DB.Groups[groupID].Height or 30

	if (currentSpec == 1 and not activePriSpec) or (currentSpec == 2 and not activeSecSpec) then
		genabled = false
	end

	if genabled then
		for row = 1, rows do
			for column = 1, columns do
				local iconID = (row - 1) * columns + column
				local iconName = groupName .. "_Icon" .. iconID
				local icon = _G[iconName]
				if not icon then
					icon = TellMeWhen_CreateIcon(iconName, group, iconWidth, iconHeight)
				elseif icon:GetHeight() ~= iconHeight or icon:GetWidth() ~= iconWidth then
					TellMeWhen_ResizeIcon(icon, iconWidth, iconHeight)
				end
				icon:SetID(iconID)
				icon:Show()
				if (column > 1) then
					icon:SetPoint("TOPLEFT", _G[groupName .. "_Icon" .. (iconID - 1)], "TOPRIGHT", iconSpacing, 0)
				elseif row > 1 and column == 1 then
					icon:SetPoint("TOPLEFT", _G[groupName .. "_Icon" .. (iconID - columns)], "BOTTOMLEFT", 0, -iconSpacing)
				elseif iconID == 1 then
					icon:SetPoint("TOPLEFT", group, "TOPLEFT")
				end
				core:Icon_Update(icon, groupID, iconID)
				if not genabled then
					core:Icon_ClearScripts(icon)
				end
			end
		end
		for iconID = rows * columns + 1, maxColumns * maxRows do
			local icon = _G[groupName .. "_Icon" .. iconID]
			if icon then
				icon:Hide()
				core:Icon_ClearScripts(icon)
			end
		end

		group:SetScale(scale)
		local lastIcon = groupName .. "_Icon" .. (rows * columns)
		resizeButton:SetPoint("BOTTOMRIGHT", lastIcon, "BOTTOMRIGHT", 3, -3)
		if locked then
			resizeButton:Hide()
		else
			resizeButton:Show()
		end
	end

	if onlyInCombat and genabled and locked then
		group:RegisterEvent("PLAYER_REGEN_ENABLED")
		group:RegisterEvent("PLAYER_REGEN_DISABLED")
		group:SetScript("OnEvent", TellMeWhen_Group_OnEvent)
		group:Hide()
	else
		group:UnregisterEvent("PLAYER_REGEN_ENABLED")
		group:UnregisterEvent("PLAYER_REGEN_DISABLED")
		group:SetScript("OnEvent", nil)
		if genabled then
			group:Show()
		else
			group:Hide()
		end
	end
end

function core:Group_GetIconID(groupID, rowIndex, columnIndex)
	local columns = DB.Groups[groupID].Columns
	return rowIndex * columns + columnIndex + 1
end

function core:Group_GetMatrix(groupID)

	local matrix = {}

	local maxRowIndex = DB.Groups[groupID].Rows - 1
	local maxColumnIndex = DB.Groups[groupID].Columns - 1

	for rowIndex = 0, maxRowIndex do
		matrix[rowIndex + 1] = {}
		for columnIndex = 0, maxColumnIndex do
			local iconID = core:Group_GetIconID(groupID, rowIndex, columnIndex)
			matrix[rowIndex + 1][columnIndex + 1] = DB.Groups[groupID].Icons[iconID]
		end
	end

	return matrix
end

function core:Group_LoadFromMatrix(groupID, matrix)
	local maxRowIndex = DB.Groups[groupID].Rows - 1
	local maxColumnIndex = DB.Groups[groupID].Columns - 1

	for rowIndex = 0, maxRowIndex do
		for columnIndex = 0, maxColumnIndex do
			local otherIconID = core:Group_GetIconID(groupID, rowIndex, columnIndex)

			local matrixIcon = nil
			local matrixRow = matrix[rowIndex + 1]
			if matrixRow ~= nil then
				matrixIcon = matrixRow[columnIndex + 1]
			end
			if matrixIcon == nil then
				matrixIcon = CopyTable(iconDefaults)
			end

			DB.Groups[groupID].Icons[otherIconID] = matrixIcon
		end
	end
end

function core:Icon_Update(icon, groupID, iconID)
	local iconSettings = DB.Groups[groupID].Icons[iconID]
	local Enabled = iconSettings.Enabled
	local iconType = iconSettings.Type
	local CooldownType = iconSettings.CooldownType
	local CooldownShowWhen = iconSettings.CooldownShowWhen
	local BuffShowWhen = iconSettings.BuffShowWhen
	if CooldownType == "spell" then
		icon.Name = TellMeWhen_GetSpellNames(iconSettings.Name)
	elseif CooldownType == "item" then
		icon.Name = TellMeWhen_GetItemNames(iconSettings.Name)
	end
	icon.Unit = iconSettings.Unit
	icon.ShowTimer = iconSettings.ShowTimer
	icon.OnlyMine = iconSettings.OnlyMine
	icon.BuffOrDebuff = iconSettings.BuffOrDebuff
	icon.WpnEnchantType = iconSettings.WpnEnchantType
	icon.noCooldownCount = iconSettings.noCooldownCount

	icon.groupID = icon.groupID or groupID
	icon.iconID = icon.iconID or iconID
	icon.updateTimer = updateInterval

	icon:UnregisterEvent("ACTIONBAR_UPDATE_STATE")
	icon:UnregisterEvent("ACTIONBAR_UPDATE_USABLE")
	icon:UnregisterEvent("ACTIONBAR_UPDATE_COOLDOWN")
	icon:UnregisterEvent("PLAYER_TARGET_CHANGED")
	icon:UnregisterEvent("PLAYER_FOCUS_CHANGED")
	icon:UnregisterEvent("COMBAT_LOG_EVENT_UNFILTERED")
	icon:UnregisterEvent("UNIT_INVENTORY_CHANGED")
	icon:UnregisterEvent("PLAYER_EQUIPMENT_CHANGED")
	icon:UnregisterEvent("BAG_UPDATE_COOLDOWN")
	icon:UnregisterEvent("UNIT_AURA")
	icon:UnregisterEvent("PLAYER_TOTEM_UPDATE")

	if Enabled or not DB.Locked then
		if CooldownShowWhen == "usable" then
			icon.usableAlpha = 1
			icon.unusableAlpha = 0
		elseif CooldownShowWhen == "unusable" then
			icon.usableAlpha = 0
			icon.unusableAlpha = 1
		elseif CooldownShowWhen == "always" then
			icon.usableAlpha = 1
			icon.unusableAlpha = 1
		else
			icon.usableAlpha = 1
			icon.unusableAlpha = 1
		end

		if BuffShowWhen == "present" then
			icon.presentAlpha = 1
			icon.absentAlpha = 0
		elseif BuffShowWhen == "absent" then
			icon.presentAlpha = 0
			icon.absentAlpha = 1
		elseif BuffShowWhen == "always" then
			icon.presentAlpha = 1
			icon.absentAlpha = 1
		else
			icon.presentAlpha = 1
			icon.absentAlpha = 1
		end

		if iconType == "cooldown" then
			if CooldownType == "spell" then
				local spell = icon.Name[1]
				if LiCD and LiCD.talentsRev[icon.Name[1]] then
					spell = LiCD.talentsRev[icon.Name[1]]
				end
				if GetSpellCooldown(spell or "") then
					icon.texture:SetTexture(TMW_GetSpellTexture(spell) or select(3, GetSpellInfo(spell)))
					icon:SetScript("OnUpdate", TellMeWhen_Icon_SpellCooldown_OnUpdate)
					if icon.ShowTimer then
						icon:RegisterEvent("ACTIONBAR_UPDATE_USABLE")
						icon:RegisterEvent("ACTIONBAR_UPDATE_COOLDOWN")
						icon:RegisterEvent("COMBAT_LOG_EVENT_UNFILTERED")
						icon:SetScript("OnEvent", TellMeWhen_Icon_SpellCooldown_OnEvent)
					else
						icon:SetScript("OnEvent", nil)
					end
				else
					core:Icon_ClearScripts(icon)
					icon.texture:SetTexture("Interface\\Icons\\INV_Misc_QuestionMark")
				end
			elseif CooldownType == "item" then
				icon.iName = nil
				for _, name in ipairs(icon.Name) do
					local itemName, _, _, _, _, _, _, _, _, itemTexture = GetItemInfo(name or "")
					if itemName and IsEquippedItem(itemName) then
						icon.iName = itemName
						icon.texture:SetTexture(itemTexture)
						icon:SetScript("OnUpdate", TellMeWhen_Icon_ItemCooldown_OnUpdate)
						if icon.ShowTimer then
							icon:RegisterEvent("PLAYER_EQUIPMENT_CHANGED")
							icon:RegisterEvent("BAG_UPDATE_COOLDOWN")
							icon:SetScript("OnEvent", TellMeWhen_Icon_ItemCooldown_OnEvent)
						else
							icon:SetScript("OnEvent", nil)
						end
						break
					end
				end
				if icon.iName == nil then
					core:Icon_ClearScripts(icon)
					icon.learnedTexture = false
					icon.texture:SetTexture("Interface\\Icons\\INV_Misc_QuestionMark")
				end
			end
			icon.Cooldown:SetReverse(false)
		elseif iconType == "buff" then
			icon:RegisterEvent("PLAYER_TARGET_CHANGED")
			icon:RegisterEvent("PLAYER_FOCUS_CHANGED")
			icon:RegisterEvent("COMBAT_LOG_EVENT_UNFILTERED")
			icon:RegisterEvent("UNIT_AURA")
			icon:SetScript("OnEvent", TellMeWhen_Icon_Buff_OnEvent)
			icon:SetScript("OnUpdate", nil)

			if not icon.Name[1] then
				icon.texture:SetTexture("Interface\\Icons\\INV_Misc_QuestionMark")
			elseif TMW_GetSpellTexture(icon.Name[1] or "") then
				icon.texture:SetTexture(TMW_GetSpellTexture(icon.Name[1]))
			elseif (not icon.learnedTexture) then
				icon.texture:SetTexture("Interface\\Icons\\INV_Misc_PocketWatch_01")
			end
			icon.Cooldown:SetReverse(true)
		elseif iconType == "reactive" then
			if TMW_GetSpellTexture(icon.Name[1] or "") then
				icon.texture:SetTexture(TMW_GetSpellTexture(icon.Name[1]))
				icon:RegisterEvent("ACTIONBAR_UPDATE_USABLE")
				icon:RegisterEvent("ACTIONBAR_UPDATE_COOLDOWN")
				icon:SetScript("OnEvent", TellMeWhen_Icon_Reactive_OnEvent)
				icon:SetScript("OnUpdate", TellMeWhen_Icon_Reactive_OnEvent)
			else
				core:Icon_ClearScripts(icon)
				icon.learnedTexture = false
				icon.texture:SetTexture("Interface\\Icons\\INV_Misc_QuestionMark")
			end
		elseif iconType == "wpnenchant" then
			icon:RegisterEvent("UNIT_INVENTORY_CHANGED")
			local slotID, _
			if icon.WpnEnchantType == "mainhand" then
				slotID, _ = GetInventorySlotInfo("MainHandSlot")
			elseif icon.WpnEnchantType == "offhand" then
				slotID, _ = GetInventorySlotInfo("SecondaryHandSlot")
			end
			local wpnTexture = GetInventoryItemTexture("player", slotID)
			if wpnTexture then
				icon.texture:SetTexture(wpnTexture)
				icon:SetScript("OnEvent", TellMeWhen_Icon_WpnEnchant_OnEvent)
				icon:SetScript("OnUpdate", TellMeWhen_Icon_WpnEnchant_OnUpdate)
			else
				core:Icon_ClearScripts(icon)
				icon.texture:SetTexture("Interface\\Icons\\INV_Misc_QuestionMark")
			end
		elseif iconType == "totem" then
			icon:RegisterEvent("PLAYER_TOTEM_UPDATE")
			icon:SetScript("OnEvent", TellMeWhen_Icon_Totem_OnEvent)
			icon:SetScript("OnUpdate", TellMeWhen_Icon_Totem_OnEvent)
			TellMeWhen_Icon_Totem_OnEvent(icon)
			if not icon.Name[1] then
				icon.texture:SetTexture("Interface\\Icons\\INV_Misc_QuestionMark")
				icon.learnedTexture = false
			elseif TMW_GetSpellTexture(icon.Name[1] or "") then
				icon.texture:SetTexture(TMW_GetSpellTexture(icon.Name[1]))
			elseif not icon.learnedTexture then
				icon.texture:SetTexture("Interface\\Icons\\INV_Misc_PocketWatch_01")
			end
		else
			core:Icon_ClearScripts(icon)
			if icon.Name[1] ~= "" then
				icon.texture:SetTexture("Interface\\Icons\\INV_Misc_QuestionMark")
			else
				icon.texture:SetTexture(nil)
			end
		end
	end

	icon.countText:Hide()
	icon.Cooldown:Hide()
	icon.Cooldown.noCooldownCount = icon.noCooldownCount or nil

	if Enabled then
		icon:SetAlpha(1.0)
	else
		icon:SetAlpha(0.4)
		core:Icon_ClearScripts(icon)
	end

	icon:Show()
	if DB.Locked then
		icon:EnableMouse(0)
		if not Enabled then
			icon:Hide()
		elseif not icon.Name[1] and iconType ~= "wpnenchant" then
			icon:Hide()
		end
		core:Icon_StatusCheck(icon, iconType)
	else
		icon:EnableMouse(1)
		TellMeWhen_Desaturate(icon.texture, false)
		core:Icon_ClearScripts(icon)

		local maxColumnIndex = DB.Groups[groupID].Columns - 1

		local iconIndex = iconID - 1

		local columnIndex = iconIndex % (maxColumnIndex + 1)
		local rowIndex = math.floor(iconIndex / (maxColumnIndex + 1))

		if
			clipboard.icon ~= nil and clipboard.icon.groupID == groupID and clipboard.icon.iconID == iconID
			or
			clipboard.row ~= nil and clipboard.row.groupID == groupID and clipboard.row.index == rowIndex
			or
			clipboard.column ~= nil and clipboard.column.groupID == groupID and clipboard.column.index == columnIndex
			or
			clipboard.group ~= nil and clipboard.group.groupID == groupID
		then
			icon.border:Show()
		else
			icon.border:Hide()
		end
	end
end

function core:Icon_ClearScripts(icon)
	icon:SetScript("OnEvent", nil)
	icon:SetScript("OnUpdate", nil)
end

function core:Icon_StatusCheck(icon, iconType)
	if iconType == "reactive" then
		TellMeWhen_Icon_ReactiveCheck(icon)
	elseif iconType == "buff" then
		TellMeWhen_Icon_BuffCheck(icon)
	elseif iconType == "cooldown" then
		TellMeWhen_Icon_SpellCooldown_OnEvent(icon)
	end
end

function core:IconSettings_IsEmpty(iconSettings)
	return (not iconSettings.Enabled) and iconSettings.Name == "" and iconSettings.Type == ""
end

function core:TalentUpdate()
	activeSpec = GetActiveTalentGroup()
end

function core:GetActiveTalentGroup()
	if not activeSpec then
		core:TalentUpdate()
	end
	return activeSpec
end

function core:Print(...)
	print("|cff33ff99TellMeWhen|r", ...)
end

function core:Update()
	for i = 1, maxGroups do
		core:Group_Update(i)
	end
end

function core:LockToggle()
	if DB.Locked then
		DB.Locked = false
	else
		DB.Locked = true
	end
	PlaySound("UChatScrollButton")
	core:Update()
end

function core:OpenConfig()
	InterfaceOptionsFrame_OpenToCategory(folder)
end

function core:Reset()
	for i = 1, maxGroups do
		defaults.Groups[i] = groupDefaults
	end
	TellMeWhen_Settings = CopyTable(defaults)
	for i = 1, maxGroups do
		local group = _G["TellMeWhen_Group" .. i]
		group:ClearAllPoints()
		group:SetPoint("TOPLEFT", "UIParent", "TOPLEFT", 100, -50 - (35 * i))
	end
	DB = TellMeWhen_Settings
	DB.Groups[1].Enabled = true
	core:Update()
	core:Print(L["Groups have been reset!"], "TellMeWhen")
end

local function SlashCommandHandler(cmd)
	if cmd == "reset" or cmd == "default" then
		core:Reset()
	elseif cmd == "config" or cmd == "options" then
		core:OpenConfig()
	else
		core:LockToggle()
	end
end

local options = {
	type = "group",
	name = "TellMeWhen",
	args = {
		desc1 = {
			type = "description",
			name = L["These options allow you to change the number, arrangement, and behavior of reminder icons."],
			order = 0,
			width = "full"
		},
		Locked = {
			type = "execute",
			name = function()
				return DB.Locked and L["Unlock"] or L["Lock"]
			end,
			desc = L['Icons work when locked. When unlocked, you can move/size icon groups and right click individual icons for more settings. You can also type "/tellmewhen" or "/tmw" to lock/unlock.'],
			order = 0.1,
			func = function()
				core:LockToggle()
			end
		},
		Reset = {
			type = "execute",
			name = RESET,
			order = 0.2,
			func = function()
				core:Reset()
			end,
			confirm = function()
				return L["Are you sure you want to reset all groups?"]
			end
		},
		Desaturate = {
			type = "toggle",
			name = L["Desaturate Icons"],
			desc = L["Icons will be desaturated instead of being colored."],
			get = function() return DB.Desaturate end,
			set = function() DB.Desaturate = not DB.Desaturate end,
			order = 0.3
		}
	}
}

-- event frame
local f = CreateFrame("Frame")
f:RegisterEvent("ADDON_LOADED")
f:RegisterEvent("PLAYER_LOGIN")
f:RegisterEvent("PLAYER_ENTERING_WORLD")
f:RegisterEvent("PLAYER_TALENT_UPDATE")
f:SetScript("OnEvent", function(self, event, arg1)
	if event == "ADDON_LOADED" and arg1 == folder then
		if _G.ElvUI then
			_G.TELLMEWHEN_VERSION = "1.2.4"
			_G.TellMeWhen_Group_Update = core.Group_Update
			hasElvUI = true
		end

		if type(TellMeWhen_Settings) ~= "table" or not next(TellMeWhen_Settings) then
			for i = 1, maxGroups do
				defaults.Groups[i] = groupDefaults
			end

			TellMeWhen_Settings = CopyTable(defaults)
			TellMeWhen_Settings.Groups[1].Enabled = true
		end
		DB = TellMeWhen_Settings

		local pos = {"TOPLEFT", 100, -50}
		for i = 1, maxGroups do
			local g =
				TellMeWhen_CreateGroup(
				"TellMeWhen_Group" .. i,
				UIParent,
				DB.Groups[i].point or pos[1],
				DB.Groups[i].x or pos[2],
				DB.Groups[i].y or pos[3]
			)
			pos[3] = pos[3] - 35
			g:SetID(i)
		end

		SLASH_TELLMEWHEN1 = "/tellmewhen"
		SLASH_TELLMEWHEN2 = "/tmw"
		SlashCmdList.TELLMEWHEN = SlashCommandHandler
	elseif event == "PLAYER_LOGIN" then
		core:Update()

		for i = 1, maxGroups do
			local opt = {
				type = "group",
				name = GROUP .. " " .. i,
				order = i,
				get = function(info)
					return DB.Groups[i][info[#info]]
				end,
				set = function(info, val)
					DB.Groups[i][info[#info]] = val
					core:Update()
				end,
				args = {
					header = {
						type = "header",
						name = GROUP .. " " .. i,
						order = 0
					},
					Enabled = {
						type = "toggle",
						name = L["Enable"],
						desc = L["Show and enable this group of icons."],
						order = 1
					},
					PrimarySpec = {
						type = "toggle",
						name = L["Primary Spec"],
						desc = L["Check to show this group of icons while in primary spec."],
						order = 2
					},
					SecondarySpec = {
						type = "toggle",
						name = L["Secondary Spec"],
						desc = L["Check to show this group of icons while in secondary spec."],
						order = 3
					},
					OnlyInCombat = {
						type = "toggle",
						name = L["Only in combat"],
						desc = L["Check to only show this group of icons while in combat."],
						order = 4
					},
					Scale = {
						type = "range",
						name = L["Scale"],
						order = 7,
						min = 0.5,
						max = 8,
						step = 0.01,
						bigStep = 0.1
					},
					Columns = {
						type = "range",
						name = L["Columns"],
						desc = L["Set the number of icon columns in this group."],
						order = 8,
						min = 1,
						max = maxColumns,
						step = 1
					},
					Rows = {
						type = "range",
						name = L["Rows"],
						desc = L["Set the number of icon rows in this group."],
						order = 9,
						min = 1,
						max = maxRows,
						step = 1
					},
					sep1 = {
						type = "description",
						name = " ",
						order = 11
					},
					Reset = {
						type = "execute",
						name = L["Reset Position"],
						order = 99,
						width = "full",
						func = function()
							local locked

							if DB.Locked then
								locked = true
								DB.Locked = false
								core:Group_Update(i)
							end
							local group = _G["TellMeWhen_Group" .. i]
							group:ClearAllPoints()
							group:SetPoint("TOPLEFT", UIParent, "TOPLEFT", 100, -50 - (35 * i - 1))
							group.Scale = 2
							DB.Groups[i].Scale = 2
							core:Group_Update(i)

							if locked then
								DB.Locked = true
								core:Group_Update(i)
							end
							core:Print(L:F("Group %d position successfully reset.", i))
						end
					}
				}
			}
			if not hasElvUI then
				opt.args.Width = {
					type = "range",
					name = L["Width"],
					order = 5,
					min = 15,
					max = 30,
					step = 1,
					bigStep = 1,
					get = function()
						return DB.Groups[i].Width or 30
					end
				}
				opt.args.Height = {
					type = "range",
					name = L["Height"],
					order = 6,
					min = 15,
					max = 30,
					step = 1,
					bigStep = 1,
					get = function()
						return DB.Groups[i].Height or 30
					end
				}
				opt.args.Spacing = {
					type = "range",
					name = L["Spacing"],
					order = 10,
					min = 0,
					max = 50,
					step = 1
				}
			end
			options.args["group" .. i] = opt
		end

		core.options = options
		LibStub("AceConfig-3.0"):RegisterOptionsTable(folder, core.options)
		core.optionsFrame = ACD:AddToBlizOptions(folder, folder)
	elseif event == "PLAYER_ENTERING_WORLD" then
		core:Update()
	elseif event == "PLAYER_TALENT_UPDATE" then
		core:TalentUpdate()
		core:Update()
	end
end)