-- EditorManager (ModuleScript) - v4.0 (Надежный ползунок вращения)
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")
local TweenService = game:GetService("TweenService")

local EditorManager = {}

local UI, Config, CameraManager
local Events = ReplicatedStorage:WaitForChild("Events")
local UpdateMannequinEvent = Events:WaitForChild("UpdateMannequin")
local SaveCharacterEvent = Events:WaitForChild("SaveCharacter")

local currentSlotIndex = nil
local activeMannequin = nil
local currentState = { gender = "Male", hairIndex = 1 }
local isDraggingSlider = false -- Переименовали для ясности
local editorStartCFrame = nil -- Будем использовать эту CFrame как основу для всех поворотов

-- Приватные функции (без изменений)
local function updateGenderVisuals() if not UI then return end; UI.genderText.Text = currentState.gender end
local function updateHairVisuals() if not UI or not Config.Hair[currentState.gender] then return end; local totalHair = #Config.Hair[currentState.gender]; UI.hairText.Text = currentState.hairIndex .. "/" .. totalHair end
local function updateMannequinAppearance() if not currentSlotIndex then return end; UpdateMannequinEvent:FireServer(currentSlotIndex, currentState) end
local function onGenderChanged() if currentState.gender == "Male" then currentState.gender = "Female" else currentState.gender = "Male" end; currentState.hairIndex = 1; updateGenderVisuals(); updateHairVisuals(); updateMannequinAppearance() end
local function onHairChanged(direction) local hairList = Config.Hair[currentState.gender]; if not hairList then return end; local totalHair = #hairList; currentState.hairIndex = currentState.hairIndex + direction; if currentState.hairIndex > totalHair then currentState.hairIndex = 1 elseif currentState.hairIndex < 1 then currentState.hairIndex = totalHair end; updateHairVisuals(); updateMannequinAppearance() end
local function onDoneClicked()
	if CameraManager.IsAnimating() or not currentSlotIndex then return end
	SaveCharacterEvent:FireServer(currentSlotIndex, currentState)
	CameraManager.TransitionFromEditor()
	EditorManager.Stop()
end
local function onBackClicked()
	if CameraManager.IsAnimating() then return end
	CameraManager.TransitionFromEditor()
	EditorManager.Reset()
end

-- ================== ПУБЛИЧНЫЕ ФУНКЦИИ ==================

function EditorManager.Start(slotIndex)
	currentSlotIndex = slotIndex
	activeMannequin = game.Workspace.Menu.MenuMannequins:FindFirstChild("Slot" .. slotIndex .. "_Mannequin")
	if activeMannequin and activeMannequin:FindFirstChild("HumanoidRootPart") then
		-- Запоминаем ИСХОДНОЕ положение манекена при входе в редактор
		editorStartCFrame = activeMannequin.HumanoidRootPart.CFrame
	end
	currentState.gender = "Male"; currentState.hairIndex = 1
	if UI.rotationSliderHandle then UI.rotationSliderHandle.Position = UDim2.fromScale(0.5, 0.5) end
	updateGenderVisuals(); updateHairVisuals(); updateMannequinAppearance()
end

function EditorManager.Stop()
	if activeMannequin and editorStartCFrame then
		local tweenInfo = TweenInfo.new(0.5, Enum.EasingStyle.Sine, Enum.EasingDirection.Out)
		TweenService:Create(activeMannequin.HumanoidRootPart, tweenInfo, {CFrame = editorStartCFrame}):Play()
	end
	currentSlotIndex = nil; activeMannequin = nil; editorStartCFrame = nil; isDraggingSlider = false
end

function EditorManager.Reset()
	if currentSlotIndex then UpdateMannequinEvent:FireServer(currentSlotIndex, nil) end
	EditorManager.Stop()
end

function EditorManager.Init(_UI, _Config, _CameraManager)
	UI = _UI; Config = _Config; CameraManager = _CameraManager

	UI.doneButton.MouseButton1Click:Connect(onDoneClicked)
	UI.backButton.MouseButton1Click:Connect(onBackClicked)

	UI.genderLeftArrow.MouseButton1Click:Connect(onGenderChanged)
	UI.genderRightArrow.MouseButton1Click:Connect(onGenderChanged)
	UI.hairLeftArrow.MouseButton1Click:Connect(function() onHairChanged(-1) end)
	UI.hairRightArrow.MouseButton1Click:Connect(function() onHairChanged(1) end)

	-- =================================================================
	-- НОВАЯ, УПРОЩЕННАЯ И НАДЕЖНАЯ ЛОГИКА ПОЛЗУНКА
	-- =================================================================
	if UI.rotationSliderHandle and UI.rotationSliderBar then
		local sliderHandle = UI.rotationSliderHandle
		local sliderBar = UI.rotationSliderBar

		sliderHandle.MouseButton1Down:Connect(function()
			isDraggingSlider = true
		end)

		UserInputService.InputEnded:Connect(function(input)
			if input.UserInputType == Enum.UserInputType.MouseButton1 then
				isDraggingSlider = false
			end
		end)

		UserInputService.InputChanged:Connect(function(input)
			if isDraggingSlider and input.UserInputType == Enum.UserInputType.MouseMovement then
				if not activeMannequin or not editorStartCFrame then return end

				-- 1. Определяем, где находится мышь относительно полосы слайдера
				local barStartPos = sliderBar.AbsolutePosition.X
				local barSize = sliderBar.AbsoluteSize.X
				local mouseX = UserInputService:GetMouseLocation().X
				local percentage = math.clamp((mouseX - barStartPos) / barSize, 0, 1)

				-- 2. Обновляем положение ползунка
				sliderHandle.Position = UDim2.fromScale(percentage, 0.5)

				-- 3. Рассчитываем угол поворота (от -180 до +180 градусов)
				local totalRotationDegrees = (percentage - 0.5) * 360

				-- 4. Применяем поворот к ИСХОДНОМУ положению манекена
				activeMannequin.HumanoidRootPart.CFrame = editorStartCFrame * CFrame.Angles(0, math.rad(totalRotationDegrees), 0)
			end
		end)
	end
end

return EditorManager