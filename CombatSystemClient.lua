-- CombatSystemClient (StarterPlayerScripts)
-- ВЕРСИЯ 24.3 (Запрет атак в прыжке)

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")
local Debris = game:GetService("Debris")

local Player = Players.LocalPlayer
local Events = ReplicatedStorage:WaitForChild("Events")
local AttackEvent = Events:WaitForChild("AttackEvent")
local BlockEvent = Events:WaitForChild("BlockEvent")
local SoundEvent = Events:WaitForChild("SoundEvent")
local CharacterReadyEvent = Events:WaitForChild("CharacterReadyEvent")

local function initializeCharacter(character)
	character:WaitForChild("AppearanceLoaded")
	if character:FindFirstChild("CombatInitialized") then return end
	if Player:GetAttribute("InMenu") then
		print("[CombatSystemClient] Игрок в меню, инициализация отложена.")
		return
	end

	print("[CombatSystemClient] Сигнал от сервера получен. Инициализация боевой системы...")
	local flag = Instance.new("BoolValue"); flag.Name = "CombatInitialized"; flag.Parent = character

	local Humanoid = character:WaitForChild("Humanoid")
	local RootPart = character:WaitForChild("Torso")
	local Animator = Humanoid:WaitForChild("Animator")
	local connections = {}

	local canAttack = true
	local isBlocking = false
	local currentCombo = 0
	local lastAttackTime = 0
	local lightComboCooldownUntil = 0
	local heavyCooldownUntil = 0

	-- ==== НОВАЯ ФУНКЦИЯ: Проверка хотбара ====
	local function hasItemsInHotbar()
		-- Проверяем атрибуты персонажа
		local leftHand = character:GetAttribute("HotbarLeftHand")
		local rightHand = character:GetAttribute("HotbarRightHand")

		-- ? ДИАГНОСТИЧЕСКИЙ ЛОГ
		print("[CombatSystemClient] Checking hotbar:")
		print("  LeftHand attribute:", leftHand, "Type:", type(leftHand))
		print("  RightHand attribute:", rightHand, "Type:", type(rightHand))

		-- ? ИСПРАВЛЕННАЯ ПРОВЕРКА
		local hasLeft = leftHand ~= nil and leftHand ~= ""
		local hasRight = rightHand ~= nil and rightHand ~= ""

		print("  Has items:", hasLeft or hasRight)

		return hasLeft or hasRight
	end

	local COMBAT_CONFIG = {
		LightAttack = { ComboTimeout = 2.0, AttackDuration = 0.33, DashDistance = 1.5, ComboCooldown = 3.0 },
		HeavyAttack = { WindupTime = 0.75, AttackDuration = 0.33, DashDistance = 2.5, Cooldown = 6.0 }
	}
	local ANIMATIONS = {
		RightPunch = { ID = "rbxassetid://104396840666728" }, LeftPunch = { ID = "rbxassetid://94967065468230" },
		HeavyCharge = { ID = "rbxassetid://125477414843644" }, HeavyAttack = { ID = "rbxassetid://116874531043574" },
		BlockIdle = { ID = "rbxassetid://111384640757565", Looped = true }, BlockWalk = { ID = "rbxassetid://94503499130199", Looped = true },
		Stun = { ID = "rbxassetid://73467455963940", Looped = true }
	}
	local animationTracks = {}; for name, data in pairs(ANIMATIONS) do local anim = Instance.new("Animation"); anim.AnimationId = data.ID; local track = Animator:LoadAnimation(anim); track.Priority = Enum.AnimationPriority.Action; track.Looped = data.Looped or false; animationTracks[name] = track end
	local function playAnimation(name, fadeTime) for trackName, track in pairs(animationTracks) do if trackName ~= name and track.IsPlaying then track:Stop(fadeTime or 0.1) end end; if animationTracks[name] and not animationTracks[name].IsPlaying then animationTracks[name]:Play(fadeTime or 0.1) end end

	local function performAttackDash(distance)
		local velocity = Instance.new("LinearVelocity")
		velocity.Attachment0 = RootPart:FindFirstChild("RootRigAttachment") or RootPart:FindFirstChild("BodyFrontAttachment")
		velocity.MaxForce = 50000 
		velocity.VelocityConstraintMode = Enum.VelocityConstraintMode.Line
		velocity.LineDirection = RootPart.CFrame.LookVector
		velocity.PrimaryTangentAxis = RootPart.CFrame.RightVector
		velocity.SecondaryTangentAxis = RootPart.CFrame.UpVector
		local DASH_DURATION = 0.15
		local speed = distance / DASH_DURATION
		velocity.LineVelocity = speed
		velocity.Parent = RootPart
		Debris:AddItem(velocity, DASH_DURATION)
	end

	local function canPerformAction()
		-- абсолютный запрет при коллапсе
		local blood = character:GetAttribute("Blood") or 100
		if blood < 7 then return false end

		-- стандартные запреты
		if isBlocking or character:GetAttribute("IsStunned") or character:GetAttribute("InInventory") or character:GetAttribute("IsDashing") then
			return false
		end

		local state = Humanoid:GetState()
		if state == Enum.HumanoidStateType.Jumping or state == Enum.HumanoidStateType.Freefall then
			return false
		end
		return true
	end

	local function performLightAttack()
		-- ? Определяем, что в руках; разрешаем нож и кулаки при пустой правой
		local rightId = character:GetAttribute("HotbarRightHand")
		local leftId  = character:GetAttribute("HotbarLeftHand")

		local isRightEmpty = (rightId == nil or rightId == "")
		local isLeftEmpty  = (leftId == nil or leftId == "")

		local isKnife = (rightId == "Sworld" or rightId == "Sword")

		-- Если ПРАВАЯ НЕ пуста, и это НЕ нож > кулаками нельзя
		if (not isRightEmpty) and (not isKnife) then
			print("[CombatSystemClient] Cannot attack: right hand occupied (not a knife)")
			return
		end
		
		-- Стиль анимации
		-- Нож: правая с ножом + левая пустая > TwoHand, иначе OneHand
		-- Кулаки: обе пустые > TwoHand; правая пустая + левая занята > OneHand
		local style
		if isKnife then
			style = isLeftEmpty and "TwoHand" or "OneHand"
		else
			if isRightEmpty and isLeftEmpty then
				style = "TwoHand"
			elseif isRightEmpty and not isLeftEmpty then
				style = "OneHand"
			else
				style = "OneHand"
			end
		end

		-- Выбор клипа: пока используем текущие RightPunch/LeftPunch (позже подменим на отдельные)
		local idx = currentCombo or 1 -- если у тебя так называется счётчик
		local clipName = (idx == 2) and "LeftPunch" or "RightPunch"

		if not canAttack or not canPerformAction() or os.clock() < lightComboCooldownUntil then return end

		canAttack = false
		if os.clock() - lastAttackTime > COMBAT_CONFIG.LightAttack.ComboTimeout then currentCombo = 0 end
		lastAttackTime = os.clock(); currentCombo += 1
		
		-- Blood input-lag при <25
		local blood = character:GetAttribute("Blood") or 100
		if blood < 25 then
			task.wait( (math.random(50,80))/1000 )
		end

		-- Пока клипы одинаковые; style оставляем для будущей подмены
		playAnimation(clipName)
		performAttackDash(COMBAT_CONFIG.LightAttack.DashDistance)
		task.delay(0.1, function() if character and character.Parent then AttackEvent:FireServer("Light") end end)
		if currentCombo >= 3 then currentCombo = 0; lightComboCooldownUntil = os.clock() + COMBAT_CONFIG.LightAttack.ComboCooldown end
		task.wait(COMBAT_CONFIG.LightAttack.AttackDuration)
		
		-- Доп. лок-аут для ножа, чтобы ощущался замедленный темп
		if isKnife then
			local baseExtra = COMBAT_CONFIG.LightAttack.AttackDuration * 1.5
			if style == "OneHand" then
				baseExtra = baseExtra * 1.5  -- итого ?2.25 для одноручного ножа
			end
			task.wait(baseExtra)
		end
		
		-- Доп. задержка: одноручные КУЛАКИ > +3.0 сек
		local isFistOneHand = (not isKnife) and isRightEmpty and (not isLeftEmpty)
		if isFistOneHand then
			task.wait(3.0)
		end

		canAttack = true
	end

	local function performHeavyAttack()
		
		local rightId = character:GetAttribute("HotbarRightHand")
		if rightId == "Sworld" or rightId == "Sword" then
			print("[CombatSystemClient] Heavy disabled for knife")
			return
		end
		
		-- ? ПРОВЕРКА: Есть ли предметы в хотбаре
		if hasItemsInHotbar() then
			print("[CombatSystemClient] Cannot attack with fists - items in hotbar")
			return
		end

		if not canAttack or not canPerformAction() or character:GetAttribute("IsChargingHeavy") or os.clock() < heavyCooldownUntil then return end

		canAttack = false
		character:SetAttribute("IsChargingHeavy", true); playAnimation("HeavyCharge")
		AttackEvent:FireServer("HeavyWindup")  -- <=== ДОБАВЛЕНО
		task.wait(COMBAT_CONFIG.HeavyAttack.WindupTime)
		if character and character.Parent and character:GetAttribute("IsChargingHeavy") and not character:GetAttribute("IsStunned") then
			playAnimation("HeavyAttack"); performAttackDash(COMBAT_CONFIG.HeavyAttack.DashDistance)
			task.delay(0.1, function() if character and character.Parent then AttackEvent:FireServer("HeavyRelease") end end)
		end
		character:SetAttribute("IsChargingHeavy", false); heavyCooldownUntil = os.clock() + COMBAT_CONFIG.HeavyAttack.Cooldown
		task.wait(COMBAT_CONFIG.HeavyAttack.AttackDuration)
		canAttack = true
	end

	local function toggleBlock(blocking) 
		if character:GetAttribute("IsStunned") or character:GetAttribute("IsChargingHeavy") or character:GetAttribute("InInventory") then return end; 

		isBlocking = blocking; BlockEvent:FireServer(isBlocking);
		if isBlocking then playAnimation(Humanoid.MoveDirection.Magnitude > 0.1 and "BlockWalk" or "BlockIdle") else animationTracks["BlockIdle"]:Stop(0.1); animationTracks["BlockWalk"]:Stop(0.1) end 
	end

	local function onInputBegan(input, gp) if gp or Player:GetAttribute("InMenu") then return end; if input.UserInputType == Enum.UserInputType.MouseButton1 then performLightAttack() elseif input.KeyCode == Enum.KeyCode.R then performHeavyAttack() elseif input.KeyCode == Enum.KeyCode.F then toggleBlock(true) end end

	connections["InputBegan"] = UserInputService.InputBegan:Connect(onInputBegan)
	connections["InputEnded"] = UserInputService.InputEnded:Connect(function(input, gp) if gp or Player:GetAttribute("InMenu") then return end; if input.KeyCode == Enum.KeyCode.F then toggleBlock(false) end end)
	connections["MoveDirection"] = Humanoid:GetPropertyChangedSignal("MoveDirection"):Connect(function() if isBlocking and not Player:GetAttribute("InMenu") then playAnimation(Humanoid.MoveDirection.Magnitude > 0.1 and "BlockWalk" or "BlockIdle") end end)
	connections["Stun"] = character:GetAttributeChangedSignal("IsStunned"):Connect(function() if character:GetAttribute("IsStunned") then playAnimation("Stun"); character:SetAttribute("IsChargingHeavy", false); if isBlocking then toggleBlock(false) end else animationTracks["Stun"]:Stop(0.2) end end)
	connections["Blocking"] = character:GetAttributeChangedSignal("IsBlocking"):Connect(function() local serverState = character:GetAttribute("IsBlocking"); isBlocking = serverState; if not serverState then animationTracks["BlockIdle"]:Stop(0.1); animationTracks["BlockWalk"]:Stop(0.1) end end)
	connections["Destroying"] = character.Destroying:Connect(function() for _, connection in pairs(connections) do connection:Disconnect() end end)
end

local function onCharacterReady()
	if not Player.Character then return end
	print("[CombatSystemClient] Character is ready. Waiting for 'InMenu' attribute to be false.")

	local function onStateChange()
		if not Player.Character then return end
		if Player:GetAttribute("InMenu") == false then
			print("[CombatSystemClient] 'InMenu' is now false. Initializing combat.")
			initializeCharacter(Player.Character)
			if connections then connections:Disconnect() connections = nil end
		end
	end

	local connections = Player:GetAttributeChangedSignal("InMenu"):Connect(onStateChange)

	if Player:GetAttribute("InMenu") == false then
		onStateChange()
	end
end

CharacterReadyEvent.OnClientEvent:Connect(onCharacterReady)

SoundEvent.OnClientEvent:Connect(function(soundName, sourcePart)
	local SOUND_IDS = { LightHit = "rbxassetid://17733314210", Miss = "rbxassetid://112758963155190", Blocked = "rbxassetid://139520673393967", HeavyCharge = "rbxassetid://6645293593", HeavyHit = "rbxassetid://8595974357", BlockBreak = "rbxassetid://1234", Stun = "rbxassetid://8730871251" }
	if SOUND_IDS[soundName] and sourcePart and typeof(sourcePart) == "Instance" then local sound = Instance.new("Sound"); sound.SoundId = SOUND_IDS[soundName]; sound.Parent = sourcePart; sound.Volume = 3; sound:Play(); Debris:AddItem(sound, sound.TimeLength) end
end)