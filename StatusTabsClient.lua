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
local ICON_BLEEDING    = "rbxassetid://76205278425713"  -- < ЯВНО ДЛЯ BLEEDING

local DEFAULT_TIMER_TEXT = "--:--"

local BLOOD_BUCKETS = {
        lt75 = { name = "Light Blood Loss", iconId = ICON_BLOOD_MID },
        lt50 = { name = "Moderate Blood Loss", iconId = ICON_BLOOD_MID },
        lt25 = { name = "Severe Blood Loss", iconId = ICON_BLOOD_HEAVY },
        lt7  = { name = "Critical Blood Loss", iconId = ICON_BLOOD_HEAVY },
}

local BLOOD_TAB_KEY = "BloodLoss"

local function show(key, name, iconId, extra)
        log("Show", key, name)
        local data = extra or {}
        data.name = name
        data.iconId = iconId
        StatusTabsUI.Show(player, key, data)
end
local function hide(key)
	log("Hide", key)
	StatusTabsUI.Hide(key)
end

local function bindCharacter(char)
        if not char then warnlog("bindCharacter(nil)"); return end
        log("bindCharacter:", char:GetFullName())

        -- COLLAPSED
        local function refreshCollapsed()
                local on = char:GetAttribute("IsCollapsed")
                log("IsCollapsed changed ->", on)
                if on then
                        show("Collapsed", "Collapsed", nil, {
                                expiresAt = char:GetAttribute("IsCollapsedUntil"),
                                timerText = DEFAULT_TIMER_TEXT,
                        })
                else
                        hide("Collapsed")
                end
        end
        char:GetAttributeChangedSignal("IsCollapsed"):Connect(refreshCollapsed)
        char:GetAttributeChangedSignal("IsCollapsedUntil"):Connect(function()
                if char:GetAttribute("IsCollapsed") then
                        refreshCollapsed()
                end
        end)
        refreshCollapsed()

        -- STUN
        local function refreshStun()
                local on = char:GetAttribute("IsStunned")
                log("IsStunned changed ->", on)
                if on then
                        show("Stun", "Stun", nil, {
                                expiresAt = char:GetAttribute("StunUntil"),
                                timerText = DEFAULT_TIMER_TEXT,
                        })
                else
                        hide("Stun")
                end
        end
        char:GetAttributeChangedSignal("IsStunned"):Connect(refreshStun)
        char:GetAttributeChangedSignal("StunUntil"):Connect(function()
                if char:GetAttribute("IsStunned") then
                        refreshStun()
                end
        end)
        refreshStun()

        -- BLEEDING
        local function refreshBleed()
                local on = char:GetAttribute("IsBleeding")
                log("IsBleeding changed ->", on)
                if on then
                        show("Bleeding", "Bleeding", ICON_BLEEDING, {
                                expiresAt = char:GetAttribute("BleedUntil"),
                                timerText = DEFAULT_TIMER_TEXT,
                        })
                else
                        hide("Bleeding")
                end
        end
        char:GetAttributeChangedSignal("IsBleeding"):Connect(refreshBleed)
        char:GetAttributeChangedSignal("BleedUntil"):Connect(function()
                if char:GetAttribute("IsBleeding") then
                        refreshBleed()
                end
        end)
        refreshBleed()

        -- === BLOOD THRESHOLDS ===
        local lastBloodBucket = nil  -- "lt75" | "lt50" | "lt25" | "lt7" | "none"

        local function bloodToBucket(b)
                if b < 7 then return "lt7"
                elseif b < 25 then return "lt25"
                elseif b < 50 then return "lt50"
                elseif b < 75 then return "lt75"
                else return "none" end
        end

        local function updateBloodLevel()
                local raw = char:GetAttribute("Blood")
                if raw == nil then return end
                local blood = tonumber(raw)
                if not blood then return end

                local bucket = bloodToBucket(blood)
                if bucket == lastBloodBucket then
                        return
                end

                lastBloodBucket = bucket
                if bucket == "none" then
                        hide(BLOOD_TAB_KEY)
                        return
                end

                local bucketConfig = BLOOD_BUCKETS[bucket]
                if not bucketConfig then
                        warnlog("Unknown blood bucket:", bucket)
                        return
                end

                show(BLOOD_TAB_KEY, bucketConfig.name, bucketConfig.iconId, {
                        timerText = DEFAULT_TIMER_TEXT,
                })
        end

        char:GetAttributeChangedSignal("Blood"):Connect(updateBloodLevel)
        updateBloodLevel()

end
-- hook character
player.CharacterAdded:Connect(bindCharacter)
if player.Character then bindCharacter(player.Character) end

-- дополнительный safeguard: если GUI не появился через 2с — явно дернём Show на тест
task.delay(2, function()␊
        log("SAFETY PING: forcing test show/hide to verify GUI path")
        show("TestPing", "Ping", nil, { timerText = DEFAULT_TIMER_TEXT })
        task.delay(1.0, function() hide("TestPing") end)
end
