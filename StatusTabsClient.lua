-- StarterPlayerScripts/StatusTabsClient.lua (DEBUG)

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local player = Players.LocalPlayer

local function log(...) print("[StatusTabsClient]", ...) end
local function warnlog(...) warn("[StatusTabsClient]", ...) end

-- безопасный require
local ok, StatusTabsUI = pcall(function()
	return require(ReplicatedStorage:WaitForChild("StatusTabsUI", 10))
end)
if not ok then
	warnlog("StatusTabsUI load failed:", StatusTabsUI)
	return
else
	log("StatusTabsUI loaded")
end

-- иконки уровней крови
local ICON_BLOOD_MID   = "rbxassetid://126009312869682"
local ICON_BLOOD_HEAVY = "rbxassetid://130010949003740"
local ICON_BLEEDING    = "rbxassetid://76205278425713"  -- < я¬Ќќ ƒЋя BLEEDING

-- описани€
local DESC_STUN      = "You are stunned."
local DESC_COLLAPSE  = "You are incapacitated."
local DESC_BLEEDING  = "You are bleeding."

local BLOOD_DESCS = {
	lt75 = "Light Blood Loss | Damage ?10%, Run speed ?5%, Jump ?10%, Dashes: unaffected, Max stamina ?10%, Stamina regen ?15%, Slight coordination loss, Mild vision dimming.",
	lt50 = "Moderate Blood Loss | Damage ?20%, Run speed ?10%, Jump ?20%, Dashes: limited, Max stamina ?25%, Stamina regen ?35%, Coordination impaired, Vision blur.",
	lt25 = "Severe Blood Loss | Damage ?30%, Run speed ?18%, Jump ?30%, Dashes: heavily limited, Max stamina ?40%, Stamina regen ?55%, Coordination unstable, Vision tunneling.",
	lt7  = "Critical Blood Loss | Damage ?40%, Run speed ?25%, Jump ?40%, Dashes: blocked, Max stamina ?50%, Stamina regen ?70%, Coordination failure, Vision impairment.",
}

local function show(key, name, desc, iconId)
	log("Show", key, name)
	StatusTabsUI.Show(player, key, { name = name, description = desc, iconId = iconId })
end
local function hide(key)
	log("Hide", key)
	StatusTabsUI.Hide(key)
end

local function bindCharacter(char)
	if not char then warnlog("bindCharacter(nil)"); return end
	log("bindCharacter:", char:GetFullName())

	-- COLLAPSED
	local function updateCollapsed()
		local on = char:GetAttribute("IsCollapsed")
		log("IsCollapsed changed ->", on)
		if on then show("Collapsed", "Collapsed", DESC_COLLAPSE) else hide("Collapsed") end
	end
	char:GetAttributeChangedSignal("IsCollapsed"):Connect(updateCollapsed)
	updateCollapsed()

	-- STUN
	local function updateStun()
		local on = char:GetAttribute("IsStunned")
		log("IsStunned changed ->", on)
		if on then show("Stun", "Stun", DESC_STUN) else hide("Stun") end
	end
	char:GetAttributeChangedSignal("IsStunned"):Connect(updateStun)
	updateStun()

	-- BLEEDING
	local function updateBleed()
		local on = char:GetAttribute("IsBleeding")
		log("IsBleeding changed ->", on)
		if on then StatusTabsUI.Show(player, "Bleeding", {
			name = "Bleeding",
			description = "",
			iconId = ICON_BLEEDING,      -- < вот это важно
			})
		else hide("Bleeding") end
	end
	char:GetAttributeChangedSignal("IsBleeding"):Connect(updateBleed)
	updateBleed()

	-- === BLOOD THRESHOLDS (stable bucket, no flicker) ===
	local lastBloodBucket = nil  -- "lt75" | "lt50" | "lt25" | "lt7" | "none"

	local function bloodToBucket(b)
		if b < 7 then return "lt7"
		elseif b < 25 then return "lt25"
		elseif b < 50 then return "lt50"
		elseif b < 75 then return "lt75"
		else return "none" end
	end

	local function hideAllBloodTabs()
		StatusTabsUI.Hide("Blood_lt75")
		StatusTabsUI.Hide("Blood_lt50")
		StatusTabsUI.Hide("Blood_lt25")
		StatusTabsUI.Hide("Blood_lt7")
	end

	local function showBucket(bucket)
		if bucket == "lt7" then
			StatusTabsUI.Show(player, "Blood_lt7", {
				name = "Critical Blood Loss",
				description = "" .. BLOOD_DESCS.lt7,  -- если хочешь Ч можно "" чтобы было только им€
				iconId = ICON_BLOOD_HEAVY
			})
		elseif bucket == "lt25" then
			StatusTabsUI.Show(player, "Blood_lt25", {
				name = "Severe Blood Loss",
				description = "" .. BLOOD_DESCS.lt25,
				iconId = ICON_BLOOD_HEAVY
			})
		elseif bucket == "lt50" then
			StatusTabsUI.Show(player, "Blood_lt50", {
				name = "Moderate Blood Loss",
				description = "" .. BLOOD_DESCS.lt50,
				iconId = ICON_BLOOD_MID
			})
		elseif bucket == "lt75" then
			StatusTabsUI.Show(player, "Blood_lt75", {
				name = "Light Blood Loss",
				description = "" .. BLOOD_DESCS.lt75,
				iconId = ICON_BLOOD_MID
			})
		end
	end

	local function updateBloodLevel()
		local blood = tonumber(char:GetAttribute("Blood")) or 100
		local bucket = bloodToBucket(blood)
		if bucket == lastBloodBucket then
			-- Ќичего не мен€ем > никаких дерганий
			return
		end

		-- —менилс€ уровень Ч спр€чем прошлый и покажем текущий
		hideAllBloodTabs()
		if bucket ~= "none" then
			showBucket(bucket)
		end
		lastBloodBucket = bucket
	end

	char:GetAttributeChangedSignal("Blood"):Connect(updateBloodLevel)
	-- первичный расчЄт
	updateBloodLevel()

end
-- hook character
player.CharacterAdded:Connect(bindCharacter)
if player.Character then bindCharacter(player.Character) end

-- дополнительный safeguard: если GUI не по€вилс€ через 2с Ч €вно дернЄм Show на тест
task.delay(2, function()
	log("SAFETY PING: forcing test show/hide to verify GUI path")
	show("TestPing", "Ping", "If you see this tab, GUI path works.")
	task.delay(1.0, function() hide("TestPing") end)
end)
