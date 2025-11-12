-- MovementSystem (LocalScript in StarterPlayerScripts)
-- ВЕРСИЯ 10.8 (ИСПРАВЛЕНЫ НАКЛОН И ПОВОРОТ ДЛЯ R6)

local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local RunService = game:GetService("RunService")
local StarterGui = game:GetService("StarterGui")
local Player = Players.LocalPlayer
local PlayerGui = Player:WaitForChild("PlayerGui")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Events = ReplicatedStorage:WaitForChild("Events")
local CharacterReadyEvent = Events:WaitForChild("CharacterReadyEvent")

local playerStatsUI=Instance.new("ScreenGui",PlayerGui);playerStatsUI.Name="PlayerStatsUI";playerStatsUI.ResetOnSpawn=false;playerStatsUI.Enabled=false;local statsHolder=Instance.new("Frame",playerStatsUI);statsHolder.Name="StatsHolder";statsHolder.Position=UDim2.new(0.019,0,0.876,0);statsHolder.Size=UDim2.new(0,400,0,120);statsHolder.BackgroundTransparency=1;local healthFrame=Instance.new("Frame",statsHolder);healthFrame.Name="HealthFrame";healthFrame.Position=UDim2.fromOffset(0,0);healthFrame.Size=UDim2.new(0,370,0,28);healthFrame.BackgroundColor3=Color3.fromRGB(39,4,4);healthFrame.BorderSizePixel=2;local healthBar=Instance.new("Frame",healthFrame);healthBar.Name="HealthBar";healthBar.Size=UDim2.new(1,0,1,0);healthBar.BackgroundColor3=Color3.fromRGB(0,165,0);local healthText=Instance.new("TextLabel",healthFrame);healthText.Name="HealthText";healthText.Size=UDim2.new(1,0,1,0);healthText.BackgroundTransparency=1;healthText.Font=Enum.Font.SourceSansBold;healthText.TextSize=14;healthText.TextColor3=Color3.fromRGB(255,255,255);healthText.TextXAlignment=Enum.TextXAlignment.Left;local hp=Instance.new("UIPadding",healthText);hp.PaddingLeft=UDim.new(0,5);
-- === BLOOD BAR (красный, над HP) ===
local bloodFrame = Instance.new("Frame", statsHolder)
bloodFrame.Name = "BloodFrame"
bloodFrame.Position = UDim2.fromOffset(0, -1) -- над healthFrame
bloodFrame.Size = UDim2.new(0,370,0,4)
bloodFrame.BackgroundColor3 = Color3.fromRGB(39,4,4)
bloodFrame.BorderSizePixel = 1
local bloodBar = Instance.new("Frame", bloodFrame)
bloodBar.Name = "BloodBar"
bloodBar.Size = UDim2.new(1,0,1,0)
bloodBar.BackgroundColor3 = Color3.fromRGB(170,15,15)
-- метки порогов 75/50/25/7
local marks = {75,50,25,7}
for _,v in ipairs(marks) do
	local m = Instance.new("Frame")
	m.Name = "Mark"..v
	m.BackgroundColor3 = Color3.fromRGB(255,255,255)
	m.BorderSizePixel = 0
	m.Size = UDim2.new(0,1,1,0)
	m.AnchorPoint = Vector2.new(0.5,0.5)
	m.Position = UDim2.new(v/100, 0, 0.5, 0)
	m.Parent = bloodFrame
end
local blockFrame=Instance.new("Frame",statsHolder);blockFrame.Name="BlockFrame";blockFrame.Position=UDim2.new(0,0,0,30);blockFrame.Size=UDim2.new(0,370,0,3);blockFrame.BackgroundColor3=Color3.fromRGB(39,4,4);blockFrame.BorderSizePixel=0;blockFrame.Visible=true;local blockBar=Instance.new("Frame",blockFrame);blockBar.Name="BlockBar";blockBar.Size=UDim2.new(1,0,1,0);blockBar.BackgroundColor3=Color3.fromRGB(255,255,255);local staminaFrame=Instance.new("Frame",statsHolder);staminaFrame.Name="StaminaFrame";staminaFrame.Position=UDim2.fromOffset(0,35);staminaFrame.Size=UDim2.new(0,308,0,28);staminaFrame.BackgroundColor3=Color3.fromRGB(39,4,4);staminaFrame.BorderSizePixel=2;local staminaBar=Instance.new("Frame",staminaFrame);staminaBar.Name="StaminaBar";staminaBar.Size=UDim2.new(1,0,1,0);staminaBar.BackgroundColor3=Color3.fromRGB(100,200,255);local staminaText=Instance.new("TextLabel",staminaFrame);staminaText.Name="StaminaText";staminaText.Size=UDim2.new(1,0,1,0);staminaText.BackgroundTransparency=1;staminaText.Text="100";staminaText.Font=Enum.Font.SourceSansBold;staminaText.TextSize=14;staminaText.TextColor3=Color3.fromRGB(255,255,255);staminaText.TextXAlignment=Enum.TextXAlignment.Left;local sp=Instance.new("UIPadding",staminaText);sp.PaddingLeft=UDim.new(0,5);local dashLineSize=UDim2.new(0,5,0,28);local leftDashLine=Instance.new("Frame",statsHolder);leftDashLine.Name="LeftDashLine";leftDashLine.Position=UDim2.fromOffset(315,35);leftDashLine.Size=dashLineSize;leftDashLine.BackgroundColor3=Color3.fromRGB(39,4,4);leftDashLine.BorderSizePixel=0;local leftDashFill=Instance.new("Frame",leftDashLine);leftDashFill.Name="LeftDashFill";leftDashFill.Size=UDim2.new(1,0,1,0);leftDashFill.Position=UDim2.new(0,0,1,0);leftDashFill.AnchorPoint=Vector2.new(0,1);leftDashFill.BackgroundColor3=Color3.fromRGB(200,200,200);local rightDashLine=Instance.new("Frame",statsHolder);rightDashLine.Name="RightDashLine";rightDashLine.Position=UDim2.fromOffset(327,35);rightDashLine.Size=dashLineSize;rightDashLine.BackgroundColor3=Color3.fromRGB(39,4,4);rightDashLine.BorderSizePixel=0;local rightDashFill=Instance.new("Frame",rightDashLine);rightDashFill.Name="RightDashFill";rightDashFill.Size=UDim2.new(1,0,1,0);rightDashFill.Position=UDim2.new(0,0,1,0);rightDashFill.AnchorPoint=Vector2.new(0,1);rightDashFill.BackgroundColor3=Color3.fromRGB(200,200,200);local thirdDashLine=Instance.new("Frame",statsHolder);thirdDashLine.Name="ThirdDashLine";thirdDashLine.Position=UDim2.fromOffset(339,35);thirdDashLine.Size=dashLineSize;thirdDashLine.BackgroundColor3=Color3.fromRGB(39,4,4);thirdDashLine.BorderSizePixel=0;thirdDashLine.Visible=false;local thirdDashFill=Instance.new("Frame",thirdDashLine);thirdDashFill.Name="ThirdDashFill";thirdDashFill.Size=UDim2.new(1,0,1,0);thirdDashFill.Position=UDim2.new(0,0,1,0);thirdDashFill.AnchorPoint=Vector2.new(0,1);thirdDashFill.BackgroundColor3=Color3.fromRGB(200,200,200);

local initializeCharacter

initializeCharacter = function(character)
	character:WaitForChild("AppearanceLoaded")

	if Player:GetAttribute("InMenu") then
		print("[MovementSystem] Игрок в меню, инициализация отложена.")
		return
	end

	print("[MovementSystem] Сигнал от сервера получен. Инициализация системы движения.")
	StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType.Health, false)

	local Humanoid = character:WaitForChild("Humanoid")
	local DEFAULT_JUMP_POWER = Humanoid.JumpPower
	-- ИСПРАВЛЕНО: Убрано дублирование RootPart
	local RootPart = character:WaitForChild("HumanoidRootPart")
	local Torso = character:WaitForChild("Torso")
	local Animator = Humanoid:WaitForChild("Animator")
	
	-- Получаем MouseLockController для проверки ShiftLock
	local PlayerModule = Player.PlayerScripts:WaitForChild("PlayerModule")
	local CameraModule = PlayerModule:WaitForChild("CameraModule")
	local MouseLockController = CameraModule:WaitForChild("MouseLockController")
	
	local connections = {}

	local CONFIG = { 
		RUN_KEY = Enum.KeyCode.LeftShift, 
		DASH_KEY = Enum.KeyCode.Q,
		WALK_SPEED = 12, 
		RUN_SPEED = 30, 
		BACKWARD_SPEED_MODIFIER = 0.7, 
		BLOCK_SPEED_MODIFIER = 0.6, 
		MAX_STAMINA = 100, 
		STAMINA_DRAIN_RATE = 5, 
		STAMINA_REGEN_RATE = 15, 
		STAMINA_REGEN_DELAY = 3, 
		MAX_DASHES = 2, 
		DASH_SPEED_BOOST = 60, 
		DASH_DURATION = 0.25, 
		DASH_COOLDOWN = 0.5, 
		DASH_RECHARGE_TIME = 6,
		JUMP_ANIM_SLOWDOWN = true,
		JUMP_SLOWDOWN_SPEED = 0.05,
		JUMP_TRANSITION_SMOOTHNESS = 8,
		TILT_ANGLE = 3, 
		TILT_SPEED = 8,
		-- Параметры плавного поворота
		SMOOTH_ROTATION = true,
		ROTATION_SPEED = 8,
		ANIMATIONS = { 
			IDLE = { ID = "rbxassetid://122344034269838", Looped = true, Priority = Enum.AnimationPriority.Idle }, 
			WALK = { ID = "rbxassetid://90142289651087", Looped = true, Priority = Enum.AnimationPriority.Movement }, 
			RUN = { ID = "rbxassetid://95426357688204", Looped = true, Priority = Enum.AnimationPriority.Movement }, 
			WALK_BACKWARD = { ID = "rbxassetid://89030513429141", Looped = true, Priority = Enum.AnimationPriority.Movement }, 
			RUN_BACKWARD = { ID = "rbxassetid://86419221559890", Looped = true, Priority = Enum.AnimationPriority.Movement }, 
			DASH_FORWARD = { ID = "rbxassetid://114479628481720", Looped = false, Priority = Enum.AnimationPriority.Action }, 
			DASH_BACKWARD = { ID = "rbxassetid://88863604877193", Looped = false, Priority = Enum.AnimationPriority.Action },
			DASH_LEFT = { ID = "rbxassetid://84025384091978", Looped = false, Priority = Enum.AnimationPriority.Action }, 
			DASH_RIGHT = { ID = "rbxassetid://104381435385815", Looped = false, Priority = Enum.AnimationPriority.Action }
		} 
	}

	local animations = {}
	for name, data in pairs(CONFIG.ANIMATIONS) do 
		local anim = Instance.new("Animation")
		anim.AnimationId = data.ID
		local track = Animator:LoadAnimation(anim)
		track.Looped = data.Looped
		track.Priority = data.Priority
		animations[name] = track
	end

	if not character:GetAttribute("Stamina") then character:SetAttribute("Stamina", 100) end
	if not character:GetAttribute("IsBlocking") then character:SetAttribute("IsBlocking", false) end
	if not character:GetAttribute("IsStunned") then character:SetAttribute("IsStunned", false) end

	local isRunning = false
	local staminaRegenTimestamp = 0
	local currentDashes = CONFIG.MAX_DASHES
	local isDashing = false
	local dashCooldownUntil = 0
	local lastMovementState = nil
	local rechargeProgress = {first = 0, second = 0, third = 0, active = false}
	local lastRechargeTime = 0
	local currentTiltAngle = CFrame.Angles(0, 0, 0)
	local targetTiltAngle = CFrame.Angles(0, 0, 0)
	local isInAir = false
	local currentAnimSpeed = 1
	local targetAnimSpeed = 1
	local currentRotationCFrame = nil
	
	-- Коллапс: мягкое обездвиживание без регдолла
	local COLLAPSE = {
		prevSpeed = nil,
	}

	local function updateHealthUI() 
		if not playerStatsUI.Enabled then return end
		local ratio = Humanoid.Health / Humanoid.MaxHealth
		healthBar.Size = UDim2.new(ratio, 0, 1, 0)
		healthText.Text = math.floor(Humanoid.Health)
	end
	
	local function updateBloodUI()
		if not playerStatsUI.Enabled then return end
		local blood = (Player.Character and Player.Character:GetAttribute("Blood")) or 100
		if not statsHolder or not statsHolder:FindFirstChild("BloodFrame") then return end
		local bf = statsHolder.BloodFrame
		local bb = bf:FindFirstChild("BloodBar")
		if not bb then return end
		local ratio = math.clamp(blood/100,0,1)
		bb.Size = UDim2.new(ratio,0,1,0)
	end

	local function updateStaminaUI() 
		if not playerStatsUI.Enabled then return end
		local currentStamina = character:GetAttribute("Stamina")
		local ratio = currentStamina / CONFIG.MAX_STAMINA
		staminaBar.Size = UDim2.new(ratio, 0, 1, 0)
		staminaText.Text = math.floor(currentStamina)
	end

	local function updateBlockDurabilityUI() 
		if not playerStatsUI.Enabled then return end
		local currentDurability = character:GetAttribute("BlockDurability")
		local maxDurability = 40
		if not currentDurability then return end
		local ratio = currentDurability / maxDurability
		blockBar.Size = UDim2.new(ratio, 0, 1, 0)
	end

	local function updateDashUI() 
		if not playerStatsUI.Enabled then return end
		thirdDashLine.Visible = CONFIG.MAX_DASHES >= 3
		local fills = {leftDashFill, rightDashFill, thirdDashFill}
		local progressValues = {rechargeProgress.first, rechargeProgress.second, rechargeProgress.third}
		for i = 1, #fills do 
			if i <= currentDashes then 
				fills[i].Size = UDim2.new(1, 0, 1, 0) 
			elseif i == currentDashes + 1 then 
				fills[i].Size = UDim2.new(1, 0, progressValues[1] or 0, 0) 
			else 
				fills[i].Size = UDim2.new(1, 0, 0, 0) 
			end 
		end
	end

	local function updateMovementState() 
		if isDashing
			or character:GetAttribute("IsBlocking")
			or character:GetAttribute("IsStunned")
			or character:GetAttribute("IsCollapsed")   -- < ДОБАВЬ
			or Player:GetAttribute("InMenu")
		then
			return
		end

		local moveDirection = RootPart.CFrame:VectorToObjectSpace(Humanoid.MoveDirection)
		local moving = Humanoid.MoveDirection.Magnitude > 0.1
		local isMovingBackward = moveDirection.Z > 0.5

		local newState
		if not moving then 
			newState = "IDLE"
		else 
			if isRunning then 
				newState = isMovingBackward and "RUN_BACKWARD" or "RUN"
			else 
				newState = isMovingBackward and "WALK_BACKWARD" or "WALK"
			end 
		end

		if newState == lastMovementState then return end
		lastMovementState = newState

		for _, anim in pairs(animations) do 
			if anim.IsPlaying then 
				anim:Stop(0.1) 
			end 
		end

		if animations[newState] then 
			animations[newState]:Play(0.1) 
		end
	end
	
	local function applyCollapseState(on)
		if on then
			-- запомним скорость, чтобы корректно восстановить
			if COLLAPSE.prevSpeed == nil then
				COLLAPSE.prevSpeed = Humanoid.WalkSpeed
			end
			-- полная остановка и запрет прыжка
			Humanoid.WalkSpeed = 0
			Humanoid.Jump = false
			Humanoid.JumpPower = 0
			-- обнули инерцию, чтобы не «скользил»
			if RootPart and RootPart.AssemblyLinearVelocity then
				RootPart.AssemblyLinearVelocity = Vector3.new()
			end
		else
			-- восстановим базовый прыжок и скорость по текущему состоянию
			Humanoid.JumpPower = DEFAULT_JUMP_POWER
			-- пересчёт целевой скорости сделает твой Heartbeat-цикл; но если хотим сразу — мягко вернём
			local restore = COLLAPSE.prevSpeed or 12
			Humanoid.WalkSpeed = restore
			COLLAPSE.prevSpeed = nil
			Humanoid.JumpPower = DEFAULT_JUMP_POWER  -- < вернуть прыжок
			updateMovementState()
		end
	end

	local function getDashDirection() 
		local moveDir = Humanoid.MoveDirection
		if moveDir.Magnitude < 0.1 then 
			return "FORWARD" 
		end

		local lookVec, rightVec = RootPart.CFrame.LookVector, RootPart.CFrame.RightVector
		local forwardDot, rightDot = moveDir:Dot(lookVec), moveDir:Dot(rightVec)

		if math.abs(forwardDot) > math.abs(rightDot) then 
			return forwardDot > 0 and "FORWARD" or "BACKWARD"
		else 
			return rightDot > 0 and "RIGHT" or "LEFT"
		end
	end

	local function transferRechargeProgress() 
		if rechargeProgress.second > 0 then 
			rechargeProgress.first = rechargeProgress.second
			rechargeProgress.second = 0
			if rechargeProgress.third > 0 then 
				rechargeProgress.second = rechargeProgress.third
				rechargeProgress.third = 0 
			end 
		end
	end

	local function startRecharge() 
		if currentDashes >= CONFIG.MAX_DASHES or rechargeProgress.active then 
			return 
		end
		rechargeProgress.active = true
		lastRechargeTime = os.clock()
		if currentDashes < 2 and rechargeProgress.second > 0 then 
			transferRechargeProgress() 
		end
	end

	local function calculateJumpAnimSpeed()
		if not CONFIG.JUMP_ANIM_SLOWDOWN then 
			return 1 
		end

		local inAir = Humanoid.FloorMaterial == Enum.Material.Air

		if not inAir then
			isInAir = false
			return 1
		end

		isInAir = true
		local verticalVelocity = RootPart.AssemblyLinearVelocity.Y
		local maxJumpVelocity = 50
		local normalizedVelocity = math.clamp(math.abs(verticalVelocity) / maxJumpVelocity, 0, 1)
		local speedMultiplier = normalizedVelocity * (1 - CONFIG.JUMP_SLOWDOWN_SPEED) + CONFIG.JUMP_SLOWDOWN_SPEED

		return speedMultiplier
	end

	local function performDash()
		-- КРИТИЧНО: Проверка isDashing в начале для блокировки повторных вызовов
		if isDashing then
			return
		end

		if os.clock() < dashCooldownUntil 
			or currentDashes <= 0 
			or character:GetAttribute("IsBlocking") 
			or character:GetAttribute("IsStunned") 
			or Player:GetAttribute("InMenu")
			or character:GetAttribute("DashDisabledByBlood")
			or character:GetAttribute("IsCollapsed")
		then 
			return 
		end

		local direction = getDashDirection()
		local animationName = "DASH_" .. direction

		if not animations[animationName] then 
			return 
		end

		isDashing = true
		character:SetAttribute("IsDashing", true)

		-- Отключаем бег и прыжок на время дэша
		isRunning = false
		Humanoid.Jump = false
		local prevJumpPower = Humanoid.JumpPower
		Humanoid.JumpPower = 0
		updateMovementState()

		currentDashes = currentDashes - 1
		dashCooldownUntil = os.clock() + CONFIG.DASH_COOLDOWN

		for _, anim in pairs(animations) do 
			if anim.IsPlaying then 
				anim:Stop(0.05) 
			end 
		end

		animations[animationName]:Play(0.05)

		-- Определяем направление дэша
		local dashDirection
		if direction == "FORWARD" then
			dashDirection = RootPart.CFrame.LookVector
		elseif direction == "BACKWARD" then
			dashDirection = -RootPart.CFrame.LookVector
		elseif direction == "RIGHT" then
			dashDirection = RootPart.CFrame.RightVector
		elseif direction == "LEFT" then
			dashDirection = -RootPart.CFrame.RightVector
		else
			dashDirection = RootPart.CFrame.LookVector
		end

		-- КРИТИЧНО: Удаляем ВСЕ старые BodyVelocity перед созданием нового
		for _, child in pairs(RootPart:GetChildren()) do
			if child:IsA("BodyVelocity") then
				child:Destroy()
			end
		end

		local bodyVelocity = Instance.new("BodyVelocity")
		bodyVelocity.MaxForce = Vector3.new(1e5, 0, 1e5)
		bodyVelocity.Velocity = dashDirection * CONFIG.DASH_SPEED_BOOST
		bodyVelocity.Parent = RootPart

		task.delay(CONFIG.DASH_DURATION, function()
			-- Удаляем BodyVelocity
			if bodyVelocity and bodyVelocity.Parent then 
				bodyVelocity:Destroy() 
			end

			-- Дополнительно проверяем и удаляем любые оставшиеся
			for _, child in pairs(RootPart:GetChildren()) do
				if child:IsA("BodyVelocity") then
					child:Destroy()
				end
			end

			task.wait(0.05)

			isDashing = false

			-- Восстанавливаем WalkSpeed
			local moveDirection = RootPart.CFrame:VectorToObjectSpace(Humanoid.MoveDirection)
			local targetSpeed = isRunning and CONFIG.RUN_SPEED or CONFIG.WALK_SPEED
			local finalSpeed = targetSpeed

			if moveDirection.Z > 0.5 then 
				finalSpeed = finalSpeed * CONFIG.BACKWARD_SPEED_MODIFIER 
			end
			if character:GetAttribute("IsBlocking") then 
				finalSpeed = finalSpeed * CONFIG.BLOCK_SPEED_MODIFIER 
			end

			Humanoid.WalkSpeed = finalSpeed

			-- КРИТИЧНО: Ждём стабилизации MoveDirection после дэша
			task.wait(0.15) -- Увеличена задержка для стабилизации физики

			-- Принудительно проверяем состояние движения и запускаем правильную анимацию
			local isMoving = Humanoid.MoveDirection.Magnitude > 0.1
			local moveDir = RootPart.CFrame:VectorToObjectSpace(Humanoid.MoveDirection)
			local isMovingBackward = moveDir.Z > 0.5

			-- Останавливаем все анимации дэша
			for name, anim in pairs(animations) do
				if name:match("DASH_") and anim.IsPlaying then
					anim:Stop(0.1)
				end
			end

			-- Принудительно запускаем правильную анимацию
			if isMoving then
				local animName
				if isRunning then
					animName = isMovingBackward and "RUN_BACKWARD" or "RUN"
				else
					animName = isMovingBackward and "WALK_BACKWARD" or "WALK"
				end

				if animations[animName] then
					animations[animName]:Play(0.15)
					-- Восстанавливаем скорость анимации если она была замедлена
					animations[animName]:AdjustSpeed(1)
				end
				lastMovementState = animName
			else
				-- Если не двигается - IDLE
				animations.IDLE:Play(0.15)
				lastMovementState = "IDLE"
			end

			-- Если игрок двигается, принудительно восстанавливаем скорость анимации
			if Humanoid.MoveDirection.Magnitude > 0.1 then
				for name, track in pairs(animations) do
					if track.IsPlaying and (name == "WALK" or name == "RUN" or name == "WALK_BACKWARD" or name == "RUN_BACKWARD") then
						track:AdjustSpeed(1) -- Возвращаем нормальную скорость
					end
				end
			end
			
			isDashing = false
			character:SetAttribute("IsDashing", false)
		end)

		updateDashUI()
		startRecharge()
	end

	table.insert(connections, RunService.Heartbeat:Connect(function(deltaTime)
		if character:GetAttribute("IsStunned")
			or character:GetAttribute("IsCollapsed")    -- < ДОБАВЬ
			or Player:GetAttribute("InMenu")
		then
			return
		end

		-- НОВЫЙ КОД: Наклон через Waist Motor6D (визуально, без физики) - ДЛЯ R15
		local upperTorso = character:FindFirstChild("UpperTorso")
		local waist = RootPart:FindFirstChild("Waist") or (upperTorso and upperTorso:FindFirstChild("Waist"))
		if waist and waist:IsA("Motor6D") then
			-- Сохраняем оригинальный C0 при первом запуске
			if not waist:GetAttribute("OriginalC0Set") then
				waist:SetAttribute("OriginalC0Set", true)
				waist:SetAttribute("OrigC0_PosX", waist.C0.Position.X)
				waist:SetAttribute("OrigC0_PosY", waist.C0.Position.Y)
				waist:SetAttribute("OrigC0_PosZ", waist.C0.Position.Z)
				local x, y, z = waist.C0:ToEulerAnglesXYZ()
				waist:SetAttribute("OrigC0_RotX", x)
				waist:SetAttribute("OrigC0_RotY", y)
				waist:SetAttribute("OrigC0_RotZ", z)
			end

			-- Вычисляем целевой наклон
			local targetWaistTilt = 0
			if not isDashing and Humanoid.MoveDirection.Magnitude > 0.1 then
				local moveDir = RootPart.CFrame:VectorToObjectSpace(Humanoid.MoveDirection)
				local rightDot = moveDir.X

				-- Только боковой наклон (влево/вправо)
				if math.abs(rightDot) > 0.5 then
					if rightDot > 0 then
						targetWaistTilt = -CONFIG.TILT_ANGLE -- Вправо
					else
						targetWaistTilt = CONFIG.TILT_ANGLE -- Влево
					end
				end
			end

			-- Плавная интерполяция
			local currentWaistTilt = waist:GetAttribute("CurrentTilt") or 0
			currentWaistTilt = currentWaistTilt + (targetWaistTilt - currentWaistTilt) * math.min(1, deltaTime * CONFIG.TILT_SPEED)
			waist:SetAttribute("CurrentTilt", currentWaistTilt)

			-- Применяем наклон к оригинальному C0
			if math.abs(currentWaistTilt) > 0.001 then
				local origPos = Vector3.new(
					waist:GetAttribute("OrigC0_PosX"),
					waist:GetAttribute("OrigC0_PosY"),
					waist:GetAttribute("OrigC0_PosZ")
				)
				local origRot = CFrame.Angles(
					waist:GetAttribute("OrigC0_RotX"),
					waist:GetAttribute("OrigC0_RotY"),
					waist:GetAttribute("OrigC0_RotZ")
				)

				-- Применяем наклон (только Roll - вокруг оси Z)
				local tiltRot = CFrame.Angles(0, 0, math.rad(currentWaistTilt))
				waist.C0 = CFrame.new(origPos) * origRot * tiltRot
			else
				-- Возвращаем в оригинальное положение
				local origPos = Vector3.new(
					waist:GetAttribute("OrigC0_PosX"),
					waist:GetAttribute("OrigC0_PosY"),
					waist:GetAttribute("OrigC0_PosZ")
				)
				local origRot = CFrame.Angles(
					waist:GetAttribute("OrigC0_RotX"),
					waist:GetAttribute("OrigC0_RotY"),
					waist:GetAttribute("OrigC0_RotZ")
				)
				waist.C0 = CFrame.new(origPos) * origRot
			end
		end

		if character:GetAttribute("IsStunned") or Player:GetAttribute("InMenu") then 
			return 
		end

		local currentStamina = character:GetAttribute("Stamina")

		if isRunning and Humanoid.MoveDirection.Magnitude > 0 and not character:GetAttribute("IsBlocking") and currentStamina > 0 then
			local newStamina = math.max(0, currentStamina - CONFIG.STAMINA_DRAIN_RATE * deltaTime)
			character:SetAttribute("Stamina", newStamina)
			if newStamina <= 0 then
				isRunning = false
				staminaRegenTimestamp = os.clock() + CONFIG.STAMINA_REGEN_DELAY
				updateMovementState()
			end
		elseif currentStamina < CONFIG.MAX_STAMINA and os.clock() >= staminaRegenTimestamp then
			local newStamina = math.min(CONFIG.MAX_STAMINA, currentStamina + CONFIG.STAMINA_REGEN_RATE * deltaTime)
			character:SetAttribute("Stamina", newStamina)
		end

		if rechargeProgress.active and currentDashes < CONFIG.MAX_DASHES then
			local elapsed = os.clock() - lastRechargeTime
			local progress = elapsed / CONFIG.DASH_RECHARGE_TIME
			if currentDashes == 0 then
				rechargeProgress.first = math.min(1, progress)
				if rechargeProgress.first >= 1 then
					currentDashes = 1
					rechargeProgress.first = 0
					lastRechargeTime = os.clock()
					if currentDashes < CONFIG.MAX_DASHES then
						transferRechargeProgress()
					else
						rechargeProgress.active = false
					end
				end
			elseif currentDashes == 1 then
				if rechargeProgress.second > 0 then
					rechargeProgress.first = math.min(1, progress)
				else
					rechargeProgress.first = math.min(1, progress)
				end
				if rechargeProgress.first >= 1 then
					currentDashes = 2
					rechargeProgress.first = 0
					lastRechargeTime = os.clock()
					rechargeProgress.active = false
					transferRechargeProgress()
				end
			end
			updateDashUI()
		end

		local moveDirection = RootPart.CFrame:VectorToObjectSpace(Humanoid.MoveDirection)
		local targetSpeed = isRunning and CONFIG.RUN_SPEED or CONFIG.WALK_SPEED
		local finalSpeed = targetSpeed

		if moveDirection.Z > 0.5 then 
			finalSpeed = finalSpeed * CONFIG.BACKWARD_SPEED_MODIFIER 
		end
		if character:GetAttribute("IsBlocking") then 
			finalSpeed = finalSpeed * CONFIG.BLOCK_SPEED_MODIFIER 
		end
		
		-- === BLOOD modifiers ===
		local blood = character:GetAttribute("Blood") or 100
		local speedMult, jumpMult = 1.0, 1.0
		if blood < 25 then
			speedMult = 0.75   -- ?25%
			jumpMult  = 0.60   -- ?40%
		elseif blood < 50 then
			speedMult = 0.90   -- ?10%
			jumpMult  = 0.85   -- ?15%
		end
		finalSpeed = finalSpeed * speedMult
		-- применим JumpPower множитель мягко: таргет на основе дефолта
		local targetJump = DEFAULT_JUMP_POWER * jumpMult
		if math.abs(Humanoid.JumpPower - targetJump) > 0.5 then
			Humanoid.JumpPower = targetJump
		end

		-- Дэш запрещён при <25
		character:SetAttribute("DashDisabledByBlood", blood < 25)

		-- Обновляем WalkSpeed только если не в процессе дэша
		if not isDashing then
			Humanoid.WalkSpeed = finalSpeed
		end

		-- Замедление анимации при прыжке
		if CONFIG.JUMP_ANIM_SLOWDOWN then
			targetAnimSpeed = calculateJumpAnimSpeed()
			currentAnimSpeed = currentAnimSpeed + (targetAnimSpeed - currentAnimSpeed) * math.min(1, deltaTime * CONFIG.JUMP_TRANSITION_SMOOTHNESS)

			for name, track in pairs(animations) do
				if track.IsPlaying and (name == "WALK" or name == "RUN" or name == "WALK_BACKWARD" or name == "RUN_BACKWARD") then
					track:AdjustSpeed(currentAnimSpeed)
				end
			end
		end

		-- Плавный поворот (ВСЕГДА активен)
		if CONFIG.SMOOTH_ROTATION then
			-- ОТКЛЮЧАЕМ AutoRotate навсегда
			if Humanoid.AutoRotate then
				Humanoid.AutoRotate = false
			end

			local isShiftLockEnabled = UserInputService.MouseBehavior == Enum.MouseBehavior.LockCenter
			local targetCFrame = nil

			if not isDashing then
				if isShiftLockEnabled then
					-- С ShiftLock: поворот за камерой
					local camera = workspace.CurrentCamera
					local cameraLook = camera.CFrame.LookVector * Vector3.new(1, 0, 1)

					if cameraLook.Magnitude > 0.1 then
						targetCFrame = CFrame.lookAt(RootPart.Position, RootPart.Position + cameraLook)
					end
				else
					-- БЕЗ ShiftLock: поворот по направлению движения
					if Humanoid.MoveDirection.Magnitude > 0.1 then
						local moveLook = Humanoid.MoveDirection * Vector3.new(1, 0, 1)
						targetCFrame = CFrame.lookAt(RootPart.Position, RootPart.Position + moveLook)
					end
				end
			end

			-- Применяем плавный поворот
			if targetCFrame then
				if not currentRotationCFrame then
					currentRotationCFrame = RootPart.CFrame
				end

				local alpha = math.min(1, deltaTime * CONFIG.ROTATION_SPEED)
				currentRotationCFrame = currentRotationCFrame:Lerp(targetCFrame, alpha)
				RootPart.CFrame = CFrame.new(RootPart.Position) * (currentRotationCFrame - currentRotationCFrame.Position)
			else
				currentRotationCFrame = RootPart.CFrame
			end
		end

		-- Наклон персонажа при движении (R6)
		if CONFIG.TILT_ANGLE > 0 and not isDashing then
			local rootJoint = RootPart:FindFirstChild("RootJoint")

			if rootJoint then
				-- Сохраняем оригинальный C0 только один раз
				if not rootJoint:GetAttribute("OriginalC0Saved") then
					rootJoint:SetAttribute("OriginalC0Saved", true)
					local origC0 = rootJoint.C0
					rootJoint:SetAttribute("OrigC0_X", origC0.X)
					rootJoint:SetAttribute("OrigC0_Y", origC0.Y)
					rootJoint:SetAttribute("OrigC0_Z", origC0.Z)
					local x, y, z = origC0:ToEulerAnglesXYZ()
					rootJoint:SetAttribute("OrigC0_RX", x)
					rootJoint:SetAttribute("OrigC0_RY", y)
					rootJoint:SetAttribute("OrigC0_RZ", z)
				end

				local moveDir = RootPart.CFrame:VectorToObjectSpace(Humanoid.MoveDirection)
				local isMoving = Humanoid.MoveDirection.Magnitude > 0.1

				-- Восстанавливаем оригинальный C0
				local origPos = Vector3.new(
					rootJoint:GetAttribute("OrigC0_X"),
					rootJoint:GetAttribute("OrigC0_Y"),
					rootJoint:GetAttribute("OrigC0_Z")
				)
				local origRot = CFrame.Angles(
					rootJoint:GetAttribute("OrigC0_RX"),
					rootJoint:GetAttribute("OrigC0_RY"),
					rootJoint:GetAttribute("OrigC0_RZ")
				)
				local originalC0 = CFrame.new(origPos) * origRot

				if isMoving then
					local tiltZ = -moveDir.X * math.rad(CONFIG.TILT_ANGLE)
					local tiltX = moveDir.Z * math.rad(CONFIG.TILT_ANGLE)
					local tiltCFrame = CFrame.Angles(tiltX, 0, tiltZ)

					rootJoint.C0 = tiltCFrame * originalC0
				else
					rootJoint.C0 = originalC0
				end
			end
		end
	end))

	table.insert(connections, UserInputService.InputBegan:Connect(function(input, gp) 
		if gp or Player:GetAttribute("InMenu") then 
			return 
		end
		
		-- Блокируем прыжок в коллапсе
		if input.KeyCode == Enum.KeyCode.Space then
			if character:GetAttribute("IsCollapsed") then
				-- гасим попытку прыжка
				Humanoid.Jump = false
				return
			end
		end

		if input.KeyCode == CONFIG.RUN_KEY then 
			if not character:GetAttribute("IsBlocking")
				and not character:GetAttribute("IsStunned")
				and not character:GetAttribute("IsChargingHeavy")
				and character:GetAttribute("Stamina") > 0
				and not character:GetAttribute("IsCollapsed")    -- < ДОБАВЬ ЭТО
			then 
				isRunning = true
				updateMovementState() 
			end 

		elseif input.KeyCode == CONFIG.DASH_KEY then
			performDash() 
		end 
	end))

	table.insert(connections, UserInputService.InputEnded:Connect(function(input) 
		if Player:GetAttribute("InMenu") then 
			return 
		end
		if input.KeyCode == CONFIG.RUN_KEY then 
			if isRunning then 
				isRunning = false
				staminaRegenTimestamp = os.clock() + CONFIG.STAMINA_REGEN_DELAY
				updateMovementState() 
			end 
		end 
	end))

	table.insert(connections, character:GetAttributeChangedSignal("Stamina"):Connect(updateStaminaUI))
	table.insert(connections, character:GetAttributeChangedSignal("Blood"):Connect(updateBloodUI))
	table.insert(connections, Humanoid.HealthChanged:Connect(updateHealthUI))
	table.insert(connections, Humanoid:GetPropertyChangedSignal("MoveDirection"):Connect(updateMovementState))
	table.insert(connections, character:GetAttributeChangedSignal("BlockDurability"):Connect(updateBlockDurabilityUI))
	table.insert(connections, character:GetAttributeChangedSignal("IsBlocking"):Connect(updateMovementState))
	-- при изменении IsCollapsed
	table.insert(connections, character:GetAttributeChangedSignal("IsCollapsed"):Connect(function()
		local collapsed = character:GetAttribute("IsCollapsed")
		applyCollapseState(collapsed)
	end))

	-- при старте (первичное применение, если уже <7)
	applyCollapseState(character:GetAttribute("IsCollapsed") == true)
	table.insert(connections, character:GetAttributeChangedSignal("Blood"):Connect(function()
		local blood = character:GetAttribute("Blood") or 100

	end))
	table.insert(connections, character:GetAttributeChangedSignal("IsStunned"):Connect(function()
		local stunned = character:GetAttribute("IsStunned")
		if stunned then
			-- Полная остановка
			Humanoid.WalkSpeed = 0
			Humanoid.Jump = false
			Humanoid.JumpPower = 0
			-- Сброс текущей скорости
			if RootPart and RootPart.AssemblyLinearVelocity then
				RootPart.AssemblyLinearVelocity = Vector3.new()
			end
		else
			-- Восстановим способность прыгать и двинемся по текущему состоянию
			Humanoid.JumpPower = DEFAULT_JUMP_POWER
			-- Пересчёт анимаций/скорости согласно текущему состоянию
			updateMovementState()
		end
	end))
	table.insert(connections, character.Destroying:Connect(function() 
		print("[MovementSystem] Персонаж уничтожен, отключаю все соединения.")

		-- Очищаем BodyGyro
		local bodyGyro = RootPart:FindFirstChild("SmoothRotationGyro")
		if bodyGyro then
			bodyGyro:Destroy()
		end

		-- ИСПРАВЛЕНО: Восстанавливаем RootJoint в оригинальное положение (R6)
		local rootJoint = RootPart:FindFirstChild("RootJoint")
		if rootJoint and rootJoint:IsA("Motor6D") then
			-- Восстанавливаем стандартное значение для R6
			rootJoint.C0 = CFrame.new(0, 0, 0, -1, 0, 0, 0, 0, 1, 0, 1, 0)
		end
		if rootJoint and rootJoint:IsA("Motor6D") and rootJoint:GetAttribute("OriginalC0Set") then
			local origPos = Vector3.new(
				rootJoint:GetAttribute("OrigC0_X"),
				rootJoint:GetAttribute("OrigC0_Y"),
				rootJoint:GetAttribute("OrigC0_Z")
			)
			local origRot = CFrame.Angles(
				rootJoint:GetAttribute("OrigC0_RotX"),
				rootJoint:GetAttribute("OrigC0_RotY"),
				rootJoint:GetAttribute("OrigC0_RotZ")
			)
			rootJoint.C0 = CFrame.new(origPos) * origRot  -- Это правильно для восстановления
		end

		for _, connection in ipairs(connections) do 
			connection:Disconnect() 
		end 
	end))

	animations.IDLE:Play()
	playerStatsUI.Enabled = not Player:GetAttribute("InMenu")
	if playerStatsUI.Enabled then
		updateHealthUI()
		updateBloodUI()
		updateStaminaUI()
		updateDashUI()
		updateBlockDurabilityUI()
	end
	
	local initialBlood = character:GetAttribute("Blood") or 100
	if initialBlood < 7 then  end

end

local function onCharacterReady()
	if not Player.Character then return end
	print("[MovementSystem] Character is ready. Waiting for 'InMenu' attribute to be false.")

	local function onStateChange()
		if not Player.Character then return end
		if Player:GetAttribute("InMenu") == false then
			print("[MovementSystem] 'InMenu' is now false. Initializing movement.")
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