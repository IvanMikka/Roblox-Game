-- Main (LocalScript) - v15.1 (Финальная модульная структура)
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")
local RunService = game:GetService("RunService")
local StarterGui = game:GetService("StarterGui")
local TweenService = game:GetService("TweenService")
local ContextActionService = game:GetService("ContextActionService")
local Workspace = workspace

local Player = Players.LocalPlayer
local PlayerGui = Player:WaitForChild("PlayerGui")

-- Загружаем события
local Events = ReplicatedStorage:WaitForChild("Events")
local LoadInventoryDataEvent = Events:WaitForChild("LoadInventoryDataEvent")
local PlayerActionsEvent = Events:WaitForChild("PlayerActionsEvent")
local LoadPlayerMenuDataEvent = Events:WaitForChild("LoadPlayerMenuData")
local DeleteCharacterEvent = Events:WaitForChild("DeleteCharacterEvent")

-- Загружаем конфиги и модули-менеджеры
local AssetsConfig = require(ReplicatedStorage:WaitForChild("AssetsConfig"))
local UIManager = require(script.Parent.UIManager)
local CameraManager = require(script.Parent.CameraManager)
local SoundManager = require(script.Parent.SoundManagerClient)
local EditorManager = require(script.Parent.EditorManager)
local ShopManager = require(script.Parent.ShopManager)
local InventoryManager = require(script.Parent.InventoryManager) -- <-- Наш новый модуль
local NotificationManager = require(script.Parent.NotificationManager)

-- Создаем UI и инициализируем все модули
local UI = UIManager.CreateAll(PlayerGui)
SoundManager.Init(UI.Menu.menuScreenGui)
CameraManager.Init(UI, SoundManager, Player, StarterGui, PlayerActionsEvent, PlayerGui)
EditorManager.Init(UI.Menu, AssetsConfig, CameraManager)
InventoryManager:Init(UI, PlayerGui) -- <-- Инициализируем менеджер инвентаря
NotificationManager:Init(UI)

-- Устанавливаем начальное состояние игры
Player:SetAttribute("InMenu", true)
Players.CharacterAutoLoads = false
StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType.All, false)

-- Локальные переменные для логики меню
local slotData = {}
local isLoading = { Value = true }
local deleteConfirmationState = {}

-- =============================================================================
-- РАЗДЕЛ 1: ОПРЕДЕЛЕНИЕ ФУНКЦИЙ МЕНЮ
-- =============================================================================

local function renderAllSlots()
	for i = 1, 3 do
		local data = slotData[tostring(i)]
		if not data then continue end
		local uiSlot = UI.Menu.slotUI[i]
		if not uiSlot then continue end

		deleteConfirmationState[i].isWaitingForConfirm = false
		if deleteConfirmationState[i].timeoutTimer then
			task.cancel(deleteConfirmationState[i].timeoutTimer)
			deleteConfirmationState[i].timeoutTimer = nil
		end
		uiSlot.DeleteButton.Text = "Delete"

		if uiSlot.PurchaseButton then
			uiSlot.PurchaseButton.Visible = not data.unlocked
		end
		if uiSlot.CreateButton and uiSlot.DeleteButton then
			uiSlot.CreateButton.Visible = data.unlocked
			uiSlot.DeleteButton.Visible = data.unlocked
			if data.characterExists then
				uiSlot.CreateButton.Text = "Play"
				uiSlot.DeleteButton.Active = true
				uiSlot.DeleteButton.BackgroundColor3 = Color3.fromRGB(170, 0, 0)
			else
				uiSlot.CreateButton.Text = "Create"
				uiSlot.DeleteButton.Active = false
				uiSlot.DeleteButton.BackgroundColor3 = Color3.fromRGB(90, 0, 0)
			end
		end
	end
end

-- =============================================================================
-- РАЗДЕЛ 2: ПОДКЛЮЧЕНИЕ СОБЫТИЙ И ГЛАВНОЙ ЛОГИКИ
-- =============================================================================

-- Когда сервер присылает данные инвентаря, передаем их в InventoryManager для отрисовки
LoadInventoryDataEvent.OnClientEvent:Connect(function(data)
	InventoryManager:Render(data.Inventory, data.Equipment, data.MoneySlot, data.Hotbar)
end)

-- Когда сервер присылает данные для меню, отрисовываем слоты
LoadPlayerMenuDataEvent.OnClientEvent:Connect(function(playerData)
	for i = 1, 3 do
		local slotStr = tostring(i)
		slotData[slotStr] = {
			unlocked = table.find(playerData.UnlockedSlots, slotStr) ~= nil,
			characterExists = playerData.Characters[slotStr] ~= nil
		}
	end
	renderAllSlots()
end)

-- Подключения кнопок меню
local ShowNotificationEvent = Events:WaitForChild("ShowNotificationEvent")
ShowNotificationEvent.OnClientEvent:Connect(function(message, duration)
	NotificationManager:ShowNotification(message, duration)
end)
local function handleHover(slotIndex, isHovering) local currentSlotData = slotData[tostring(slotIndex)] if currentSlotData and currentSlotData.unlocked and not CameraManager.IsAnimating() then local lightModel = workspace.Menu.Theater:FindFirstChild("SvetSlot" .. slotIndex) if lightModel then local spotLight = lightModel:FindFirstChildWhichIsA("SpotLight", true) if spotLight then spotLight.Enabled = true; local tweenInfo = TweenInfo.new(0.1); local targetBrightness = isHovering and 6 or 0; TweenService:Create(spotLight, tweenInfo, {Brightness = targetBrightness}):Play() end end if isHovering then if not SoundManager.SlotHoverEnter.IsPlaying then SoundManager.SlotHoverEnter:Play() end else if not SoundManager.SlotHoverLeave.IsPlaying then SoundManager.SlotHoverLeave:Play() end end end end
local function handleCreateOrSelect(slotIndex) if CameraManager.IsAnimating() then return end local currentSlotData = slotData[tostring(slotIndex)] if not currentSlotData or not currentSlotData.unlocked then return end if currentSlotData.characterExists then CameraManager.StartGame(slotIndex) else CameraManager.TransitionToEditor(slotIndex); EditorManager.Start(slotIndex) end end
UI.Menu.chooseCharacterImageButton.MouseButton1Click:Connect(function() CameraManager.TransitionToCharacterSelect() end); UI.Menu.chooseCharacterImageButton.MouseEnter:Connect(function() UI.Menu.chooseCharacterImageButton.Image = UI.Menu.IMAGE_HOVER; SoundManager.ButtonHover:Play() end); UI.Menu.chooseCharacterImageButton.MouseLeave:Connect(function() UI.Menu.chooseCharacterImageButton.Image = UI.Menu.IMAGE_NORMAL end);
UI.Menu.skipButton.MouseButton1Click:Connect(function() if isLoading.Value then CameraManager.TransitionToMainMenu(isLoading) end end); UI.Menu.skipButton.MouseEnter:Connect(function() SoundManager.ButtonHover:Play() end); UI.Menu.backButton.MouseButton1Click:Connect(function() EditorManager.Reset() CameraManager.TransitionFromEditor() end);
UI.Menu.backButton.MouseEnter:Connect(function() SoundManager.ButtonHover:Play() end)
for i=1,3 do local uiSlot=UI.Menu.slotUI[i] deleteConfirmationState[i]={isWaitingForConfirm=false,timeoutTimer=nil} uiSlot.Zone.MouseEnter:Connect(function() handleHover(i,true) end) uiSlot.Zone.MouseLeave:Connect(function() handleHover(i,false) end) uiSlot.CreateButton.MouseButton1Click:Connect(function() handleCreateOrSelect(i) end) uiSlot.CreateButton.MouseEnter:Connect(function() SoundManager.ButtonHover:Play() end) uiSlot.DeleteButton.MouseButton1Click:Connect(function() local state=deleteConfirmationState[i] if not uiSlot.DeleteButton.Active then return end if state.isWaitingForConfirm then if state.timeoutTimer then task.cancel(state.timeoutTimer) state.timeoutTimer=nil end state.isWaitingForConfirm=false DeleteCharacterEvent:FireServer(i) else state.isWaitingForConfirm=true uiSlot.DeleteButton.Text="Are you sure?" uiSlot.DeleteButton.Active=false uiSlot.DeleteButton.BackgroundColor3=Color3.fromRGB(90,0,0) task.delay(4,function() if state.isWaitingForConfirm then uiSlot.DeleteButton.Active=true uiSlot.DeleteButton.BackgroundColor3=Color3.fromRGB(170,0,0) end end) state.timeoutTimer=task.delay(10,function() if state.isWaitingForConfirm then state.isWaitingForConfirm=false uiSlot.DeleteButton.Text="Delete" state.timeoutTimer=nil end end) end end) uiSlot.DeleteButton.MouseEnter:Connect(function() if uiSlot.DeleteButton.Active then SoundManager.ButtonHover:Play() end end) if uiSlot.PurchaseButton then uiSlot.PurchaseButton.MouseButton1Click:Connect(function() ShopManager.PurchaseSlot(i) end) uiSlot.PurchaseButton.MouseEnter:Connect(function() SoundManager.ButtonHover:Play() end) end end

-- Главный цикл управления состоянием и камерой
local inventoryOpen = false; local INVENTORY_ACTION = "ToggleInventory"; local CAMERA_SINK_ACTION = "SinkCameraInput"; local function sinkInput() return Enum.ContextActionResult.Sink end; local function handleInventoryAction(actionName, inputState, inputObject) if inputState == Enum.UserInputState.Begin then inventoryOpen = not inventoryOpen; UI.Game.InventoryCanvas.Visible = inventoryOpen; if Player.Character then local humanoid = Player.Character:FindFirstChildOfClass("Humanoid"); Player.Character:SetAttribute("InInventory", inventoryOpen); if humanoid then humanoid:SetStateEnabled(Enum.HumanoidStateType.Jumping, not inventoryOpen) end end; if inventoryOpen then ContextActionService:BindActionAtPriority(CAMERA_SINK_ACTION, sinkInput, false, Enum.ContextActionPriority.High.Value + 1, Enum.UserInputType.MouseButton2) else ContextActionService:UnbindAction(CAMERA_SINK_ACTION) end end; return Enum.ContextActionResult.Sink end; local function bindInventoryKey() ContextActionService:BindActionAtPriority(INVENTORY_ACTION, handleInventoryAction, false, Enum.ContextActionPriority.High.Value, Enum.KeyCode.I) end; local function unbindInventoryKey() ContextActionService:UnbindAction(INVENTORY_ACTION) end
Player:GetAttributeChangedSignal("InMenu"):Connect(function() local inMenu = Player:GetAttribute("InMenu"); if inMenu then unbindInventoryKey(); inventoryOpen = false; if UI.Game and UI.Game.gameHudGui then UI.Game.gameHudGui.Enabled = false end else StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType.All, true); StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType.PlayerList, false); bindInventoryKey(); if UI.Game and UI.Game.gameHudGui then UI.Game.gameHudGui.Enabled = true end end end)
Player.CharacterAdded:Connect(function(character) if Player:GetAttribute("InMenu") then character:WaitForChild("Humanoid"):SetStateEnabled(Enum.HumanoidStateType.Jumping, false) end end)
RunService:BindToRenderStep("MenuCameraControl", Enum.RenderPriority.Camera.Value + 1, function() if Player:GetAttribute("InMenu") then Workspace.CurrentCamera.CameraType = Enum.CameraType.Scriptable; if not CameraManager.IsCameraTweening() then Workspace.CurrentCamera.CFrame = CameraManager.GetCurrentCameraTarget() end else Workspace.CurrentCamera.CameraType = Enum.CameraType.Custom; if Player.Character and Player.Character:FindFirstChild("Humanoid") then Workspace.CurrentCamera.CameraSubject = Player.Character.Humanoid end; RunService:UnbindFromRenderStep("MenuCameraControl") end end)

-- Логика запуска и загрузки
task.spawn(function()
	CameraManager.InitLights()
	for i = 1, 3 do
		local mannequin = workspace.Menu.MenuMannequins:FindFirstChild("Slot" .. i .. "_Mannequin")
		if mannequin and mannequin:FindFirstChildOfClass("Humanoid") then
			local humanoid = mannequin:FindFirstChildOfClass("Humanoid")
			humanoid.DisplayName = " "
			local animation = Instance.new("Animation")

			-- Берем уникальную анимацию для каждого слота из конфига
			local animationId = AssetsConfig.MannequinAnimations["Slot" .. i]
			animation.AnimationId = animationId

			local animationTrack = humanoid:LoadAnimation(animation)
			animationTrack:Play()
			CameraManager.RegisterAnimationTrack(i, animationTrack)
		end
	end
	local limiterConnection = UI.Menu.loadingFill:GetPropertyChangedSignal("Size"):Connect(function() local barSizeX = UI.Menu.loadingBarContainer.AbsoluteSize.X; local fillScaleX = UI.Menu.loadingFill.Size.X.Scale; local limiterWidth = UI.Menu.limiterRight.AbsoluteSize.X; local newXOffset = (barSizeX * fillScaleX) - (limiterWidth / 2); UI.Menu.limiterRight.Position = UDim2.new(0, newXOffset, 0.5, 0) end)
	local loadingTween = TweenService:Create(UI.Menu.loadingFill, TweenInfo.new(6, Enum.EasingStyle.Linear), {Size = UDim2.new(1, 0, 1, 0)})
	loadingTween:Play()
	task.wait(6.1)
	limiterConnection:Disconnect()
	if isLoading.Value then
		task.wait(2)
		CameraManager.TransitionToMainMenu(isLoading)
	end
end)