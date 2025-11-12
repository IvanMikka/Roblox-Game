-- UniversalDummyController (Script ‚ ServerScriptService)
-- ¬≈–—»ﬂ 4.0 (”ÌË‚ÂÒ‡Î¸Ì˚È ÍÓÌÚÓÎÎÂ ‰Îˇ ‚ÒÂı ÚËÔÓ‚ Ï‡ÌÂÍÂÌÓ‚)

local ServerScriptService = game:GetService("ServerScriptService")
local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")

local DamageModule = require(ServerScriptService:WaitForChild("DamageModule"))
local SoundManager = require(ServerScriptService:WaitForChild("SoundManager"))

-- =================================================================
--  ŒÕ‘»√”–¿÷»ﬂ “»œŒ¬ Ã¿Õ≈ ≈ÕŒ¬
-- =================================================================
local DUMMY_CONFIGS = {
	["Dummy"] = {
		Type = "Aggressive",
		AttackInterval = 3.0,
		AttackDamage = 25,
		StunOnHit = 2.0,
		AttackRange = 15,
		HitboxSize = Vector3.new(4, 5, 6),
		HitboxOffset = CFrame.new(0, 0, -3),
		Animations = {
			HeavyCharge = "rbxassetid://125477414843644",
			HeavyAttack = "rbxassetid://116874531043574"
		}
	},
	["BlockingDummy"] = {
		Type = "Defensive",
		Animations = {
			BlockIdle = "rbxassetid://111384640757565",
			Stun = "rbxassetid://73467455963940"
		}
	}
}

-- =================================================================
-- ‘”Õ ÷»ﬂ œŒ»— ¿ ÷≈À» (Ó·˘‡ˇ ‰Îˇ ‚ÒÂı ‡Ú‡ÍÛ˛˘Ëı Ï‡ÌÂÍÂÌÓ‚)
-- =================================================================
local function findTargetForDummy(dummy, config)
	local torso = dummy:FindFirstChild("Torso")
	if not torso then return nil, nil end

	local stableCFrame = CFrame.new(torso.Position) * (dummy.PrimaryPart.CFrame - dummy.PrimaryPart.Position)
	local hitboxCFrame = stableCFrame * config.HitboxOffset

	local overlapParams = OverlapParams.new()
	overlapParams.FilterDescendantsInstances = {dummy}
	local partsInHitbox = Workspace:GetPartBoundsInBox(hitboxCFrame, config.HitboxSize, overlapParams)

	for _, part in ipairs(partsInHitbox) do
		if part.Parent and part.Parent.Name == "HitboxContainer" then
			local victimCharacter = part.Parent.Parent
			if victimCharacter and victimCharacter:FindFirstChild("Humanoid") and Players:GetPlayerFromCharacter(victimCharacter) then
				return victimCharacter, part
			end
		end
	end
	return nil, nil
end

-- =================================================================
-- ¿“¿ ”ﬁŸ≈≈ œŒ¬≈ƒ≈Õ»≈
-- =================================================================
local function setupAggressiveDummy(dummy, config)
	local humanoid = dummy:WaitForChild("Humanoid")
	local animator = humanoid:WaitForChild("Animator")
	local torso = dummy:WaitForChild("Torso")

	local animationTracks = {}
	for name, id in pairs(config.Animations) do
		local anim = Instance.new("Animation")
		anim.AnimationId = id
		animationTracks[name] = animator:LoadAnimation(anim)
	end

	local function performHeavyAttack()
		dummy:SetAttribute("IsChargingHeavy", true)
		animationTracks.HeavyCharge:Play()
		SoundManager.broadcastSound("HeavyCharge", torso)
		task.wait(0.75)

		if not dummy or not dummy.Parent or not dummy:GetAttribute("IsChargingHeavy") then return end
		dummy:SetAttribute("IsChargingHeavy", false)
		animationTracks.HeavyAttack:Play()

		task.delay(0.1, function()
			if not dummy or not dummy.Parent then return end
			local target, hitPart = findTargetForDummy(dummy, config)
			local result = DamageModule.handleDamage(dummy, target, hitPart, "Melee", config.AttackDamage, config.StunOnHit)

			if target and target:GetAttribute("IsBlocking") then
				SoundManager.broadcastSound("Blocked", torso)
			else
				if result == "Hit" then
					SoundManager.broadcastSound("HeavyHit", torso)
				elseif result == "Miss" then
					SoundManager.broadcastSound("Miss", torso)
				end
			end
		end)
	end

	-- ÷ËÍÎ ‡Ú‡Í
	task.spawn(function()
		while task.wait(config.AttackInterval) do
			if dummy and dummy.Parent and humanoid.Health > 0 then
				local nearestPlayer, distance = nil, config.AttackRange
				for _, player in ipairs(Players:GetPlayers()) do
					if player.Character and player.Character:FindFirstChild("Torso") then
						local currentDist = (player.Character.Torso.Position - torso.Position).Magnitude
						if currentDist < distance then
							nearestPlayer = player
							distance = currentDist
						end
					end
				end

				if nearestPlayer then
					performHeavyAttack()
				end
			else
				break
			end
		end
	end)
end

-- =================================================================
-- ¡ÀŒ »–”ﬁŸ≈≈ œŒ¬≈ƒ≈Õ»≈
-- =================================================================
local function setupDefensiveDummy(dummy, config)
	local humanoid = dummy:WaitForChild("Humanoid")
	local animator = humanoid:WaitForChild("Animator")

	local animationTracks = {}
	for name, id in pairs(config.Animations) do
		local anim = Instance.new("Animation")
		anim.AnimationId = id
		animationTracks[name] = animator:LoadAnimation(anim)
	end
	animationTracks.BlockIdle.Looped = true
	animationTracks.Stun.Looped = true

	-- ÷ËÍÎ ÛÔ‡‚ÎÂÌËˇ ÒÓÒÚÓˇÌËˇÏË
	task.spawn(function()
		while dummy and dummy.Parent and task.wait(0.2) do
			local isStunned = dummy:GetAttribute("IsStunned")
			local isBlocking = dummy:GetAttribute("IsBlocking")
			local blockDurability = dummy:GetAttribute("BlockDurability")

			if isStunned then
				if animationTracks.BlockIdle.IsPlaying then animationTracks.BlockIdle:Stop() end
				if not animationTracks.Stun.IsPlaying then animationTracks.Stun:Play() end
				dummy:SetAttribute("IsBlocking", false)
			else
				if animationTracks.Stun.IsPlaying then animationTracks.Stun:Stop() end

				if not isBlocking and blockDurability and blockDurability >= 40 then
					dummy:SetAttribute("IsBlocking", true)
					if not animationTracks.BlockIdle.IsPlaying then animationTracks.BlockIdle:Play() end
				end
			end
		end
	end)
end

-- =================================================================
-- ¿¬“ŒÃ¿“»◊≈— ¿ﬂ »Õ»÷»¿À»«¿÷»ﬂ ¬—≈’ Ã¿Õ≈ ≈ÕŒ¬
-- =================================================================
for dummyName, config in pairs(DUMMY_CONFIGS) do
	local dummy = Workspace:FindFirstChild(dummyName)
	if dummy then
		print("[UniversalDummyController] Initializing:", dummyName, "Type:", config.Type)

		if config.Type == "Aggressive" then
			setupAggressiveDummy(dummy, config)
		elseif config.Type == "Defensive" then
			setupDefensiveDummy(dummy, config)
		end
	else
		warn("[UniversalDummyController] Dummy not found:", dummyName)
	end
end

print("[UniversalDummyController] ? All dummies initialized")