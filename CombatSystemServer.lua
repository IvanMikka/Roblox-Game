-- CombatSystemServer (ServerScriptService)
-- ВЕРСИЯ 23.0 (Упрощенный и надежный поиск цели)

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
local ServerScriptService = game:GetService("ServerScriptService")
local Debris = game:GetService("Debris")

local Events = ReplicatedStorage:WaitForChild("Events")
local AttackEvent = Events:WaitForChild("AttackEvent")
local BlockEvent = Events:WaitForChild("BlockEvent")

local DamageModule = require(ServerScriptService:WaitForChild("DamageModule"))
local SoundManager = require(ServerScriptService:WaitForChild("SoundManager"))

local COMBAT_CONFIG = {
	LightAttack = { Damage = 10, StunDuration = 0.33, ComboTimeout = 2.0, ComboCooldown = 3.0 },
	HeavyAttack = { Damage = 25, StunDurationOnHit = 2.0, Cooldown = 6.0 },
	HitboxSize = Vector3.new(4, 5, 6),
	HitboxOffset = CFrame.new(0, 0, -3.5) 
}

local playerData = {}

local function initializePlayerData(player)
	playerData[player] = { lastLightAttackTime = 0, lightComboCount = 0, lightAttackCooldownUntil = 0, heavyAttackCooldownUntil = 0 }
	if player.Character then 
		player.Character:SetAttribute("IsBlocking", false); player.Character:SetAttribute("IsStunned", false); player.Character:SetAttribute("IsChargingHeavy", false) 
	end
end

local function visualizeHitbox(cframe, size)
	local part = Instance.new("Part"); part.Name = "VisualHitbox"; part.Anchored = true; part.CanCollide = false; part.CanQuery = false; part.CanTouch = false; part.Transparency = 0.7; part.Color = Color3.fromRGB(255, 0, 0); part.Material = Enum.Material.ForceField; part.CFrame = cframe; part.Size = size; part.Parent = workspace; Debris:AddItem(part, 0.2)
end

-- =================================================================
-- ИЗМЕНЕНИЕ ЗДЕСЬ: Логика поиска упрощена до предела
-- =================================================================
local function findTargetOnServer(character)
	local rootPart = character:FindFirstChild("HumanoidRootPart")
	if not rootPart then return nil, nil end

	local hitboxCFrame = rootPart.CFrame * COMBAT_CONFIG.HitboxOffset
	visualizeHitbox(hitboxCFrame, COMBAT_CONFIG.HitboxSize)

	local overlapParams = OverlapParams.new()
	overlapParams.FilterDescendantsInstances = {character}
	overlapParams.FilterType = Enum.RaycastFilterType.Exclude
	overlapParams.RespectCanCollide = false

	local partsInHitbox = workspace:GetPartBoundsInBox(hitboxCFrame, COMBAT_CONFIG.HitboxSize, overlapParams)

	-- Ищем ЦЕЛЕНАПРАВЛЕННО только TorsoHitbox
	for _, part in ipairs(partsInHitbox) do
		if part.Name == "TorsoHitbox" and part.Parent and part.Parent.Name == "HitboxContainer" then
			local victimCharacter = part.Parent.Parent
			if victimCharacter and victimCharacter:FindFirstChild("Humanoid") and victimCharacter.Humanoid.Health > 0 then
				-- Нашли торс - это 100% наша цель. Сразу возвращаем его.
				return victimCharacter, part 
			end
		end
	end

	-- Если мы прошли весь цикл и не нашли торс, значит это точно промах.
	return nil, nil
end

AttackEvent.OnServerEvent:Connect(function(player, attackType)
	local character = player.Character
	if not character or not character.PrimaryPart or character:GetAttribute("IsStunned") then return end
	-- Blood: <7 полностью обездвижен (коллапс) — атаки запрещены
	if (character:GetAttribute("IsCollapsed")) then return end

	local data = playerData[player]
	if not data then initializePlayerData(player); data = playerData[player] end
	if not data then return end

	local victim, hitPart = nil, nil

	if attackType == "Light" or attackType == "HeavyRelease" then
		victim, hitPart = findTargetOnServer(character)
	end

	if attackType == "Light" then
		if os.clock() < data.lightAttackCooldownUntil then return end
		if os.clock() - data.lastLightAttackTime > COMBAT_CONFIG.LightAttack.ComboTimeout then data.lightComboCount = 0 end
		data.lastLightAttackTime = os.clock(); data.lightComboCount += 1

		-- Определяем, нож ли в правой руке
		local rightId = character:GetAttribute("HotbarRightHand")
		local leftId  = character:GetAttribute("HotbarLeftHand")
		local isLeftEmpty = (leftId == nil or leftId == "")
		local isKnife = (rightId == "Sworld" or rightId == "Sword")

		-- Базовый урон с учётом ножа
		local base = COMBAT_CONFIG.LightAttack.Damage
		if isKnife then
			base = math.floor(base * 2.0) -- ?2 для ножа
		end

		-- === Blood: исходящий урон атакующего ===
		local blood = character:GetAttribute("Blood") or 100
		local mult = 1.0
		if blood < 25 then
			mult = 0.60   -- ?40%
		elseif blood < 50 then
			mult = 0.80   -- ?20%
		elseif blood < 75 then
			mult = 0.90   -- ?10%
		end
		local damage = math.floor(base * mult)

		local result = DamageModule.handleDamage(character, victim, hitPart, "Melee", damage, COMBAT_CONFIG.LightAttack.StunDuration)

		if victim and victim:GetAttribute("IsBlocking") then
			-- < только звук «удар по блоку»
			SoundManager.broadcastSound("Blocked", character.Torso)
		else
			if result == "Hit" then
				SoundManager.broadcastSound("LightHit", character.Torso)
			elseif result == "Miss" then
				SoundManager.broadcastSound("Miss", character.Torso)
			end
		end
		
		-- === Кровотечение от ножа (tier 1) ===
		do
			local rightId = character:GetAttribute("HotbarRightHand")
			if result == "Hit" and victim and (rightId == "Sworld" or rightId == "Sword") then
				if _G.Blood and _G.Blood.ApplyBleed then
					_G.Blood.ApplyBleed(victim, 1)
				end
			end
		end
		
		-- Авторитетный КД для ножа (между любыми лайт-ударами)
		if isKnife then
			local extra = 0.33 * 1.5 -- базовое AttackDuration 0.33 ?1.5
			if not isLeftEmpty then
				extra = extra * 1.5  -- если одноручный нож > ?2.25
			end
			data.lightAttackCooldownUntil = math.max(data.lightAttackCooldownUntil, os.clock() + extra)
		end

		if data.lightComboCount >= 3 then data.lightComboCount = 0; data.lightAttackCooldownUntil = os.clock() + COMBAT_CONFIG.LightAttack.ComboCooldown end

	elseif attackType == "HeavyWindup" then
		local rightId = character:GetAttribute("HotbarRightHand")
		if rightId == "Sworld" or rightId == "Sword" then return end
		if os.clock() < data.heavyAttackCooldownUntil then return end
		character:SetAttribute("IsChargingHeavy", true); SoundManager.broadcastSound("HeavyCharge", character.Torso)

	elseif attackType == "HeavyRelease" then
		local rightId = character:GetAttribute("HotbarRightHand")
		if rightId == "Sworld" or rightId == "Sword" then return end
		if os.clock() < data.heavyAttackCooldownUntil or not character:GetAttribute("IsChargingHeavy") then return end
		character:SetAttribute("IsChargingHeavy", false); data.heavyAttackCooldownUntil = os.clock() + COMBAT_CONFIG.HeavyAttack.Cooldown
		
		-- === Blood: исходящий урон атакующего ===
		local base = COMBAT_CONFIG.HeavyAttack.Damage
		local blood = character:GetAttribute("Blood") or 100
		local mult = 1.0
		if blood < 25 then
			mult = 0.60   -- ?40%
		elseif blood < 50 then
			mult = 0.80   -- ?20%
		elseif blood < 75 then
			mult = 0.90   -- ?10%
		end
		local damage = math.floor(base * mult)

		local result = DamageModule.handleDamage(character, victim, hitPart, "Melee", damage, COMBAT_CONFIG.LightAttack.StunDuration)

		if victim and victim:GetAttribute("IsBlocking") then
			SoundManager.broadcastSound("Blocked", character.Torso)
		else
			if result == "Hit" then
				SoundManager.broadcastSound("HeavyHit", character.Torso)
			elseif result == "Miss" then
				SoundManager.broadcastSound("Miss", character.Torso)
			end
		end


	end
end)

BlockEvent.OnServerEvent:Connect(function(player, isBlocking) 
	local character = player.Character; if not character or character:GetAttribute("IsStunned") or character:GetAttribute("IsChargingHeavy") then return end; character:SetAttribute("IsBlocking", isBlocking)
end)

Players.PlayerAdded:Connect(initializePlayerData)
Players.PlayerRemoving:Connect(function(player) playerData[player] = nil end)
for _, p in ipairs(Players:GetPlayers()) do initializePlayerData(p) end