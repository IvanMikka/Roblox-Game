-- StateManager (ModuleScript) — единый менеджер состояний: Stun / Collapsed / Bleeding

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local StateManager = {}

local COMBAT_CONFIG = {
	Block = { MaxDurability = 40, RegenRate = 10, RegenDelay = 3, BreakStunDuration = 3.0 },
	Blood = { Start = 100, CollapseThreshold = 7 },   -- Порог коллапса
}

-- === STUN (оставляем твою логику/анимацию) ===
local StunAnimation = Instance.new("Animation")
StunAnimation.AnimationId = "rbxassetid://73467455963940"
local loadedStunTracks = {}

-- === Память по персонажам ===
local characterData = {}      -- { [character] = { blockDurability, lastDamageTime, prevSpeed } }
local activeBleeds = {}       -- { [character] = { {t=0, dur=60, dps=1.5}, ... } }
local bleedTickerStarted = false
local bleedAcc = 0

local function now() return os.time() end

local function ensureCharacterData(character)
	if not character or characterData[character] then return end
	characterData[character] = {
		blockDurability = COMBAT_CONFIG.Block.MaxDurability,
		lastDamageTime = 0,
		prevSpeed = nil,
	}
	character:SetAttribute("BlockDurability", COMBAT_CONFIG.Block.MaxDurability)
	if character:GetAttribute("Blood") == nil then
		character:SetAttribute("Blood", COMBAT_CONFIG.Blood.Start)
	end
	character:SetAttribute("IsStunned", false)
	character:SetAttribute("IsCollapsed", false)
	character:SetAttribute("IsBleeding", false)

	character.Destroying:Connect(function()
		characterData[character] = nil
		loadedStunTracks[character] = nil
		activeBleeds[character] = nil
	end)
end

-- === ВСПОМОГАТЕЛЬНОЕ: Коллапс (обездвиживание) ===
local function applyCollapsed(character, on)
	if not character or not character.Parent then return end
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	if not humanoid then return end

	if on then
		if characterData[character] and characterData[character].prevSpeed == nil then
			characterData[character].prevSpeed = humanoid.WalkSpeed
		end
		humanoid.WalkSpeed = 0
		humanoid.Jump = false
		humanoid.JumpPower = 0
		local root = character:FindFirstChild("HumanoidRootPart")
		if root and root.AssemblyLinearVelocity then
			root.AssemblyLinearVelocity = Vector3.new()
		end
	else
		humanoid.JumpPower = 50
		local restore = (characterData[character] and characterData[character].prevSpeed) or 12
		humanoid.WalkSpeed = restore
		if characterData[character] then
			characterData[character].prevSpeed = nil
		end
	end
end

function StateManager.setCollapsed(character, on, duration)
	ensureCharacterData(character)
	character:SetAttribute("IsCollapsed", on and true or false)
	if on and duration and duration > 0 then
		character:SetAttribute("IsCollapsedUntil", now() + math.floor(duration))
		task.delay(duration, function()
			if character and character.Parent then
				character:SetAttribute("IsCollapsed", false)
				character:SetAttribute("IsCollapsedUntil", nil)
				applyCollapsed(character, false)
			end
		end)
	else
		character:SetAttribute("IsCollapsedUntil", nil)
	end
	applyCollapsed(character, on)
end

-- === STUN ===
function StateManager.applyStun(character, duration)
	ensureCharacterData(character)
	character:SetAttribute("IsStunned", true)
	character:SetAttribute("StunUntil", now() + math.floor(duration))  -- < ВАЖНО

	local humanoid = character:FindFirstChildOfClass("Humanoid")
	local animator = humanoid and humanoid:FindFirstChildOfClass("Animator")
	if animator then
		if not loadedStunTracks[character] then
			loadedStunTracks[character] = animator:LoadAnimation(StunAnimation)
			loadedStunTracks[character].Looped = true
			loadedStunTracks[character].Priority = Enum.AnimationPriority.Action4
		end
		loadedStunTracks[character]:Play()
	end

	task.delay(duration, function()
		if character and character.Parent then
			character:SetAttribute("IsStunned", false)
			character:SetAttribute("StunUntil", nil)
			if loadedStunTracks[character] and loadedStunTracks[character].IsPlaying then
				loadedStunTracks[character]:Stop(0.2)
			end
		end
	end)
end

-- === КРОВОТЕЧЕНИЕ (стаки) ===
-- addBleed: добавляет стек с длительностью (сек) и скоростью потерь (ед/сек).
-- пример: addBleed(char, 60, 1.2) > 60 сек по 1.2/сек
-- пересчёт мета-атрибутов bleed
local function refreshBleedMeta(character)
	local stacks = activeBleeds[character]
	if not stacks or #stacks == 0 then
		character:SetAttribute("IsBleeding", false)
		character:SetAttribute("BleedStacks", 0)
		character:SetAttribute("BleedSeverity", 0)
		character:SetAttribute("BleedUntil", nil)
		return
	end
	character:SetAttribute("IsBleeding", true)
	character:SetAttribute("BleedStacks", #stacks)
	-- тяжесть = максимальный dps (можешь маппить в 1..5 по своему правилу)
	local maxDps, maxEnd = 0, 0
	for _, s in ipairs(stacks) do
		if s.dps > maxDps then maxDps = s.dps end
		if s.endAt > maxEnd then maxEnd = s.endAt end
	end
	character:SetAttribute("BleedSeverity", maxDps)   -- или round/карту 1..5
	character:SetAttribute("BleedUntil", maxEnd)      -- < ключевой атрибут для UI
end

function StateManager.addBleed(character, duration, dps)
	ensureCharacterData(character)
	activeBleeds[character] = activeBleeds[character] or {}
	local stacks = activeBleeds[character]

	local MAX_STACKS = 5
	if #stacks >= MAX_STACKS then
		table.sort(stacks, function(a,b)
			if a.dps == b.dps then return a.endAt < b.endAt end
			return a.dps < b.dps
		end)
		table.remove(stacks, 1)
	end

	table.insert(stacks, {
		dps = dps,
		endAt = now() + duration,
	})
	refreshBleedMeta(character)

	if not bleedTickerStarted then
		bleedTickerStarted = true
		RunService.Heartbeat:Connect(function(dt)
			bleedAcc += dt
			if bleedAcc < 1 then return end
			bleedAcc -= 1

			local tnow = now()
			for char, list in pairs(activeBleeds) do
				if not char or not char.Parent then
					activeBleeds[char] = nil
				else
					local total = 0
					-- списание и чистка просроченных стеков
					for i = #list, 1, -1 do
						local s = list[i]
						if tnow >= s.endAt then
							table.remove(list, i)
						else
							total += s.dps
						end
					end

					if total > 0 then
						local blood = char:GetAttribute("Blood") or COMBAT_CONFIG.Blood.Start
						blood = math.max(0, blood - total)
						char:SetAttribute("Blood", blood)
						local collapsed = blood < COMBAT_CONFIG.Blood.CollapseThreshold
						if char:GetAttribute("IsCollapsed") ~= collapsed then
							StateManager.setCollapsed(char, collapsed)
						end
					end

					-- обновляем мету после чистки
					refreshBleedMeta(char)
				end
			end
		end)
	end
end

function StateManager.clearBleed(character)
	if activeBleeds[character] then
		activeBleeds[character] = nil
	end
	if character then
		character:SetAttribute("IsBleeding", false)
	end
end

-- === Блок/пробой щита (твоё изначальное) ===
function StateManager.handleBlockDamage(character, damage)
	ensureCharacterData(character)
	local data = characterData[character]
	data.lastDamageTime = os.clock()
	data.blockDurability = math.max(0, data.blockDurability - damage)
	character:SetAttribute("BlockDurability", data.blockDurability)

	if data.blockDurability <= 0 then
		StateManager.applyStun(character, COMBAT_CONFIG.Block.BreakStunDuration)
		return true
	end
	return false
end

local function processBlockRegen(deltaTime)
	for character, data in pairs(characterData) do
		if character and character.Parent and not character:GetAttribute("IsBlocking") then
			if os.clock() - data.lastDamageTime > COMBAT_CONFIG.Block.RegenDelay then
				if data.blockDurability < COMBAT_CONFIG.Block.MaxDurability then
					local regenAmount = COMBAT_CONFIG.Block.RegenRate * deltaTime
					data.blockDurability = math.min(COMBAT_CONFIG.Block.MaxDurability, data.blockDurability + regenAmount)
					character:SetAttribute("BlockDurability", data.blockDurability)
				end
			end
		end
	end
end

-- === Инициализация на всех персонажах ===
local function initChar(character) ensureCharacterData(character) end

Players.PlayerAdded:Connect(function(player)
	player.CharacterAdded:Connect(initChar)
	if player.Character then initChar(player.Character) end
end)
for _, p in ipairs(Players:GetPlayers()) do
	if p.Character then initChar(p.Character) end
end

workspace.DescendantAdded:Connect(function(d)
	if d:IsA("Model") and d:FindFirstChild("Humanoid") then initChar(d) end
end)
for _, d in ipairs(workspace:GetDescendants()) do
	if d:IsA("Model") and d:FindFirstChild("Humanoid") then initChar(d) end
end

RunService.Heartbeat:Connect(processBlockRegen)

return StateManager
