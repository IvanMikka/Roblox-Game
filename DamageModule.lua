-- DamageModule (ModuleScript)
-- ВЕРСИЯ 6.3 (Упрощенная)

local Players = game:GetService("Players")
local ServerScriptService = game:GetService("ServerScriptService")
local SoundManager = require(ServerScriptService:WaitForChild("SoundManager"))
local StateManager = require(ServerScriptService:WaitForChild("StateManager"))

local DamageModule = {}

local COMBAT_CONFIG = { HeavyAttack = { StunDurationOnInterrupt = 1.5 } }

function DamageModule.handleDamage(attacker, victim, hitPart, damageType, baseDamage, stunDuration)
	if not victim or not hitPart then 
		return "Miss" 
	end

	local humanoid = victim:FindFirstChild("Humanoid")
	if not humanoid or humanoid.Health <= 0 then return "Miss" end

	local damageMultiplier = 1

	-- =================================================================
	-- ИЗМЕНЕНИЕ: Убираем лишнюю проверку. Сервер теперь сам гарантирует,
	-- что для Melee атак будет передан только TorsoHitbox.
	-- =================================================================
	if damageType == "Melee" then
		damageMultiplier = hitPart:GetAttribute("DamageMultiplierMelee") or 1
	elseif damageType == "Shot" then
		-- Для выстрелов по-прежнему берем множитель с любой части тела
		damageMultiplier = hitPart:GetAttribute("DamageMultiplierShot") or 1
	end

	local finalDamage = baseDamage * damageMultiplier

	print(string.format("Attacker: %s, Victim: %s, HitPart: %s, Type: %s, FinalDamage: %.1f",
		attacker.Name, victim.Name, hitPart.Name, damageType, finalDamage))

	if victim:GetAttribute("IsChargingHeavy") then 
		StateManager.applyStun(victim, COMBAT_CONFIG.HeavyAttack.StunDurationOnInterrupt)
		humanoid:TakeDamage(finalDamage)
		SoundManager.broadcastSound("Stun", victim.Torso)
		return "Hit"
	end

	if victim:GetAttribute("IsBlocking") and damageType == "Melee" then 
		local blockBroken = StateManager.handleBlockDamage(victim, finalDamage)
		if blockBroken then victim:SetAttribute("IsBlocking", false)
		else if Players:GetPlayerFromCharacter(victim) then SoundManager.broadcastSound("BlockHit", victim.Torso) end end
		if Players:GetPlayerFromCharacter(attacker) then SoundManager.broadcastSound("Blocked", attacker.Torso) end
		return "Blocked"
	end

	humanoid:TakeDamage(finalDamage)
	StateManager.applyStun(victim, stunDuration)
	return "Hit"
end

return DamageModule