-- InventoryManager (ModuleScript) - v9.0 (FIXED: Equipment & Money dragging)

local UserInputService = game:GetService("UserInputService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Events = ReplicatedStorage:WaitForChild("Events")
local ItemsConfig = require(ReplicatedStorage:WaitForChild("ItemsConfig"))

local EquipItemEvent = Events:WaitForChild("EquipItemEvent")
local DropItemEvent = Events:WaitForChild("DropItemEvent")
local SplitItemStackEvent = Events:WaitForChild("SplitItemStackEvent")
local MoveItemEvent = Events:WaitForChild("MoveItemEvent")
local MoveItemToHotbarEvent = Events:WaitForChild("MoveItemToHotbarEvent")
local MoveItemFromHotbarEvent = Events:WaitForChild("MoveItemFromHotbarEvent")
local UnequipItemEvent = Events:WaitForChild("UnequipItemEvent")
local SwapEquipmentEvent = Events:WaitForChild("SwapEquipmentEvent")
local LoadInventoryDataEvent = Events:WaitForChild("LoadInventoryDataEvent")
local MoveItemToSlotEvent = Events:WaitForChild("MoveItemToSlotEvent") -- Для денег

local InventoryManager = {}

local UI = nil
local PlayerGui = nil
local itemIconCache = {}
local hotbarIconCache = {}
local equipmentIconCache = {}
local moneyIconCache = nil
local moneyIconCache = nil
local isContextMenuOpen = false
local ignoreNextInput = false
local isDragging = false
local draggedItemData = nil
local ghostIcon = nil
local dropIndicator = nil
local dragOffset = Vector2.new(0,0)
local isMouseAnchoredToCenter = false
local currentIndicatorGridPos = nil
local currentInventoryData = nil
local currentEquipmentData = nil
local currentMoneyData = nil
local currentHotbarData = nil
local BACKPACK_CELL_SIZE = 48
local BACKPACK_CELL_PADDING = 2
local currentIndicatorInBackpack = false

local function getEquippedBackpackClient()
	if not currentEquipmentData then return nil end

	for i = 1, 3 do
		local slotName = "Accessory" .. i
		local item = currentEquipmentData[slotName]
		if item and item.ItemID then
			local cfg = ItemsConfig[item.ItemID]
			if cfg and cfg.ExpansionSize then
				return item, slotName, cfg
			end
		end
	end
end

local function clearBackpackPreview()
	if not UI or not UI.Game or not UI.Game.ContextMenu then return end
	local menu = UI.Game.ContextMenu
	local existing = menu:FindFirstChild("BackpackPreview")
	if existing then existing:Destroy() end
end

local function showBackpackPreviewForItem(itemData)
	clearBackpackPreview()
	if not itemData or not itemData.BackpackInventory then return end

	local backpackInv = itemData.BackpackInventory
	if not backpackInv.Items or #backpackInv.Items == 0 then return end

	local menu = UI.Game.ContextMenu

	local container = Instance.new("Frame")
	container.Name = "BackpackPreview"
	container.Parent = menu
	container.BackgroundTransparency = 1
	container.Size = UDim2.new(1, -8, 0, 24)
	container.Position = UDim2.new(0, 4, 0, 4)
	container.ZIndex = menu.ZIndex + 1   -- <=== ВАЖНО

	local layout = Instance.new("UIListLayout")
	layout.FillDirection = Enum.FillDirection.Horizontal
	layout.HorizontalAlignment = Enum.HorizontalAlignment.Left
	layout.VerticalAlignment = Enum.VerticalAlignment.Center
	layout.Padding = UDim.new(0, 2)
	layout.Parent = container
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(function()
		container.Size = UDim2.new(1, -8, 0, layout.AbsoluteContentSize.Y)
	end)

	for _, innerItem in ipairs(backpackInv.Items) do
		local cfg = ItemsConfig[innerItem.ItemID]
		if cfg then
			local icon = Instance.new("ImageLabel")
			icon.BackgroundTransparency = 1
			icon.Size = UDim2.fromOffset(20, 20)
			icon.Image = cfg.HotbarIcon or cfg.GridIcon
			icon.Parent = container
			icon.ZIndex = container.ZIndex + 1   -- <=== тоже выше фона
		end
	end

	return container
end



-- Вспомогательные функции для контекстного меню
function InventoryManager:closeContextMenu()
	if not isContextMenuOpen then return end
	isContextMenuOpen = false
	if UI.Game.ContextMenu then UI.Game.ContextMenu.Visible = false end
	if UI.Game.SplitStackPrompt and UI.Game.SplitStackPrompt.Prompt then
		UI.Game.SplitStackPrompt.Prompt.Visible = false
	end
	if UI.Game.ContextMenu then
		clearBackpackPreview()  -- <===
		for _, child in ipairs(UI.Game.ContextMenu:GetChildren()) do
			if child:IsA("GuiButton") then child:Destroy() end
		end
	end
end

local function createContextMenuButton(text, callback)
	local button = Instance.new("TextButton")
	button.Name = text
	button.Parent = UI.Game.ContextMenu
	button.Size = UDim2.new(1, 0, 0, 25)
	button.BackgroundColor3 = Color3.fromRGB(40, 40, 40)
	button.BackgroundTransparency = 0.1
	button.TextColor3 = Color3.fromRGB(255, 255, 255)
	button.TextTransparency = 0
	button.TextStrokeTransparency = 1
	button.ZIndex = UI.Game.ContextMenu.ZIndex + 1
	button.Font = Enum.Font.SourceSans
	button.TextSize = 16
	button.Text = "  " .. text
	button.TextXAlignment = Enum.TextXAlignment.Left
	button.MouseEnter:Connect(function() button.BackgroundColor3 = Color3.fromRGB(70, 70, 70) end)
	button.MouseLeave:Connect(function() button.BackgroundColor3 = Color3.fromRGB(40, 40, 40) end)
	button.MouseButton1Click:Connect(callback)
	return button
end

local function handleSplitStack(itemData, clickPosition)
	local prompt = UI.Game.SplitStackPrompt.Prompt
	local textBox = UI.Game.SplitStackPrompt.Input
	local okButton = UI.Game.SplitStackPrompt.Button
	prompt.Position = UDim2.fromOffset(clickPosition.X, clickPosition.Y - 48)
	prompt.Visible = true
	textBox.Text = ""
	textBox:CaptureFocus()
	local connection
	connection = okButton.MouseButton1Click:Connect(function()
		local amount = tonumber(textBox.Text)
		if amount and amount > 0 and amount < itemData.Amount then
			SplitItemStackEvent:FireServer(itemData.UniqueID, amount)
		end
		if connection then connection:Disconnect() end
		InventoryManager:closeContextMenu()
	end)
end

-- Контекстное меню для хотбара
function InventoryManager:openHotbarContextMenu(itemData, slotName, clickPosition)
	if isContextMenuOpen then self:closeContextMenu() end
	isContextMenuOpen = true

	local config = ItemsConfig[itemData.ItemID]
	local buttonCount = 0

	-- Превью содержимого, если это рюкзак
	if config and config.ExpansionSize then
		showBackpackPreviewForItem(itemData)
	end

	local function addButton(name, callback) 
		createContextMenuButton(name, callback)
		buttonCount = buttonCount + 1 
	end

	addButton("Remove", function()
		print("[Context] Removing item from hotbar slot:", slotName)
		MoveItemFromHotbarEvent:FireServer(slotName, nil)
		self:closeContextMenu()
	end)

	addButton("Drop", function()
		print("[Context] Dropping item from hotbar slot:", slotName)
		local DropFromSlotEvent = Events:WaitForChild("DropFromSlotEvent")
		DropFromSlotEvent:FireServer("Hotbar", slotName)
		self:closeContextMenu()
	end)

	local menu = UI.Game.ContextMenu
	local baseHeight = (buttonCount * 25) + (buttonCount * 2) + 8
	local extra = menu:FindFirstChild("BackpackPreview") and 28 or 0
	menu.Size = UDim2.fromOffset(150, baseHeight + extra)
	menu.Position = UDim2.fromOffset(clickPosition.X, clickPosition.Y - 48)
	menu.Visible = true
	ignoreNextInput = true
end

-- ИСПРАВЛЕННОЕ контекстное меню для экипировки
function InventoryManager:openEquipmentContextMenu(itemData, slotName, clickPosition)
	if isContextMenuOpen then self:closeContextMenu() end
	isContextMenuOpen = true

	local config = ItemsConfig[itemData.ItemID]
	local buttonCount = 0

	-- Если это рюкзак, показываем превью его содержимого над кнопками
	if config and config.ExpansionSize then
		showBackpackPreviewForItem(itemData)
	end

	local function addButton(name, callback) 
		createContextMenuButton(name, callback)
		buttonCount = buttonCount + 1 
	end

	-- Кнопка "Pick up" - взять в руки (только для оружия)
	if config.WeaponModel then
		addButton("Pick up", function()
			print("[Equipment Context] Pick up weapon from slot", slotName)

			UnequipItemEvent:FireServer(slotName, nil)
			task.wait(0.1)

			local targetSlot = nil
			if not UI.Game.HotbarSlots.RightHand:FindFirstChildOfClass("ImageLabel") or 
				#UI.Game.HotbarSlots.RightHand:GetChildren() <= 1 then
				targetSlot = "RightHand"
			elseif not UI.Game.HotbarSlots.LeftHand:FindFirstChildOfClass("ImageLabel") or
				#UI.Game.HotbarSlots.LeftHand:GetChildren() <= 1 then
				targetSlot = "LeftHand"
			end

			if targetSlot then
				MoveItemToHotbarEvent:FireServer(itemData.UniqueID, targetSlot)
			end

			self:closeContextMenu()
		end)
	end

	-- Кнопка "Unequip" - снять экипировку
	addButton("Unequip", function()
		print("[Equipment Context] Unequipping item from", slotName)
		UnequipItemEvent:FireServer(slotName, nil)
		self:closeContextMenu()
	end)

	-- Кнопка "Drop" - выбросить напрямую
	addButton("Drop", function()
		print("[Equipment Context] Dropping item from", slotName)
		local DropFromSlotEvent = Events:WaitForChild("DropFromSlotEvent")
		DropFromSlotEvent:FireServer("Equipment", slotName)
		self:closeContextMenu()
	end)
	
	local menu = UI.Game.ContextMenu
	if buttonCount > 0 then
		local baseHeight = (buttonCount * 25) + ((buttonCount) * 2) + 8
		local extra = menu:FindFirstChild("BackpackPreview") and 28 or 0
		menu.Size = UDim2.fromOffset(150, baseHeight + extra)
		menu.Position = UDim2.fromOffset(clickPosition.X, clickPosition.Y - 48)
		menu.Visible = true
		ignoreNextInput = true
	else
		isContextMenuOpen = false
	end

end

-- Контекстное меню для инвентаря
function InventoryManager:openContextMenu(itemData, clickPosition, fromBackpack)
	if isContextMenuOpen then self:closeContextMenu() end
	isContextMenuOpen = true
	local config = ItemsConfig[itemData.ItemID]
	local buttonCount = 0
	
	-- Если это рюкзак, показываем превью его содержимого над кнопками
	if config and config.ExpansionSize then
		showBackpackPreviewForItem(itemData)
	end

	local function addButton(name, callback) 
		createContextMenuButton(name, callback)
		buttonCount = buttonCount + 1 
	end

	-- Кнопка "Pick up" только для оружия
	if config.WeaponModel then
		addButton("Pick up", function()
			print("[Context] Pick up weapon", itemData.ItemID)

			local targetSlot = nil
			if not UI.Game.HotbarSlots.RightHand:FindFirstChildOfClass("ImageLabel") or 
				#UI.Game.HotbarSlots.RightHand:GetChildren() <= 1 then
				targetSlot = "RightHand"
			elseif not UI.Game.HotbarSlots.LeftHand:FindFirstChildOfClass("ImageLabel") or
				#UI.Game.HotbarSlots.LeftHand:GetChildren() <= 1 then
				targetSlot = "LeftHand"
			end

			if targetSlot then
				if config.IsTwoHanded then
					local leftEmpty = #UI.Game.HotbarSlots.LeftHand:GetChildren() <= 1
					local rightEmpty = #UI.Game.HotbarSlots.RightHand:GetChildren() <= 1

					if leftEmpty and rightEmpty then
						targetSlot = "LeftHand"
					else
						Events:WaitForChild("ShowNotificationEvent"):FireServer("Two-handed items require both hands to be empty")
						self:closeContextMenu()
						return
					end
				end

				MoveItemToHotbarEvent:FireServer(itemData.UniqueID, targetSlot)
			else
				Events:WaitForChild("ShowNotificationEvent"):FireServer("Both hands are full")
			end

			self:closeContextMenu()
		end)
	end

	-- Кнопка Equip только для экипируемых предметов (НЕ оружия)
	if config.EquipSlot and not config.WeaponModel then 
		addButton("Equip", function() 
			print("[Context] Equip item", itemData.ItemID)
			EquipItemEvent:FireServer(itemData.UniqueID)
			self:closeContextMenu()
		end)
	end

	if config.IsStackable and itemData.Amount > 1 then 
		addButton("Split", function() 
			UI.Game.ContextMenu.Visible = false
			handleSplitStack(itemData, clickPosition) 
		end)
	end

	addButton("Drop", function() 
		DropItemEvent:FireServer(itemData.UniqueID)
		self:closeContextMenu()
	end)

	-- Кнопка "Store in backpack" (если есть надетый рюкзак)
	local backpackItem = getEquippedBackpackClient()
	if backpackItem and not fromBackpack then
		local cfg2 = ItemsConfig[itemData.ItemID]
		-- Не показываем кнопку для самого рюкзака
		if not (cfg2 and cfg2.ExpansionSize) then
			addButton("Store in backpack", function()
				local ev = Events:WaitForChild("MoveItemToBackpackEvent")
				ev:FireServer(itemData.UniqueID)
				self:closeContextMenu()
			end)
		end
	end

	local menu = UI.Game.ContextMenu
	if buttonCount > 0 then
		local baseHeight = (buttonCount * 25) + ((buttonCount) * 2) + 8
		local extra = menu:FindFirstChild("BackpackPreview") and 28 or 0
		menu.Size = UDim2.fromOffset(150, baseHeight + extra)
		menu.Position = UDim2.fromOffset(clickPosition.X, clickPosition.Y - 48)
		menu.Visible = true
		ignoreNextInput = true
	else
		isContextMenuOpen = false
	end
end

-- Начало перетаскивания из инвентаря
local function onDragBegan(itemData, originalIcon)
	if isDragging or isContextMenuOpen then return end
	isDragging = true
	isMouseAnchoredToCenter = false
	draggedItemData = itemData
	draggedItemData.FromHotbar = nil
	draggedItemData.FromEquipment = nil
	draggedItemData.FromMoney = nil
	draggedItemData.FromBackpack = nil
	
	draggedItemData._sourceIcon = originalIcon

	local mousePos = UserInputService:GetMouseLocation()
	dragOffset = mousePos - originalIcon.AbsolutePosition
	originalIcon.Visible = false

	ghostIcon = Instance.new("ImageLabel")
	ghostIcon.Name = "GhostIcon"
	ghostIcon.Image = originalIcon.Image
	ghostIcon.Size = UDim2.fromOffset(originalIcon.AbsoluteSize.X, originalIcon.AbsoluteSize.Y)
	ghostIcon.BackgroundTransparency = 1
	ghostIcon.ImageTransparency = 0.4
	ghostIcon.ZIndex = 200
	ghostIcon.Position = UDim2.fromOffset(mousePos.X - dragOffset.X, mousePos.Y - dragOffset.Y)
	ghostIcon.Parent = UI.Game.gameHudGui

	dropIndicator = Instance.new("Frame")
	dropIndicator.Name = "DropIndicator"
	dropIndicator.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
	dropIndicator.BackgroundTransparency = 0.7
	dropIndicator.ZIndex = 5
	dropIndicator.BorderSizePixel = 0
	dropIndicator.Size = ghostIcon.Size
	dropIndicator.Visible = false
	dropIndicator.Parent = UI.Game.ItemContainer
end

local function onBackpackDragBegan(itemData, originalIcon)
	if isDragging or isContextMenuOpen then return end
	isDragging = true
	isMouseAnchoredToCenter = false
	draggedItemData = itemData
	draggedItemData.FromHotbar = nil
	draggedItemData.FromEquipment = nil
	draggedItemData.FromMoney = nil
	draggedItemData.FromBackpack = true
	
	draggedItemData._sourceIcon = originalIcon

	local mousePos = UserInputService:GetMouseLocation()
	dragOffset = mousePos - originalIcon.AbsolutePosition
	originalIcon.Visible = false

	ghostIcon = Instance.new("ImageLabel")
	ghostIcon.Name = "GhostIcon"
	ghostIcon.Image = originalIcon.Image
	ghostIcon.Size = UDim2.fromOffset(originalIcon.AbsoluteSize.X, originalIcon.AbsoluteSize.Y)
	ghostIcon.BackgroundTransparency = 1
	ghostIcon.ImageTransparency = 0.4
	ghostIcon.ZIndex = 200
	ghostIcon.Position = UDim2.fromOffset(mousePos.X - dragOffset.X, mousePos.Y - dragOffset.Y)
	ghostIcon.Parent = UI.Game.gameHudGui

	dropIndicator = Instance.new("Frame")
	dropIndicator.Name = "DropIndicator"
	dropIndicator.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
	dropIndicator.BackgroundTransparency = 0.7
	dropIndicator.ZIndex = 5
	dropIndicator.BorderSizePixel = 0
	dropIndicator.Size = ghostIcon.Size
	dropIndicator.Visible = false
	dropIndicator.Parent = UI.Game.ItemContainer
end

-- Начало перетаскивания из хотбара
local function onHotbarDragBegan(itemData, originalIcon, slotName)
	if isDragging or isContextMenuOpen then return end
	isDragging = true
	isMouseAnchoredToCenter = true
	draggedItemData = itemData
	draggedItemData.FromHotbar = slotName
	draggedItemData.FromEquipment = nil
	draggedItemData.FromMoney = nil
	draggedItemData.FromBackpack = nil

	local mousePos = UserInputService:GetMouseLocation()
	originalIcon.Visible = false

	ghostIcon = Instance.new("ImageLabel")
	ghostIcon.Name = "GhostIcon"
	ghostIcon.Image = originalIcon.Image
	ghostIcon.Size = UDim2.fromOffset(64, 64)
	ghostIcon.BackgroundTransparency = 1
	ghostIcon.ImageTransparency = 0.4
	ghostIcon.ZIndex = 200
	ghostIcon.Position = UDim2.fromOffset(mousePos.X - 32, mousePos.Y - 32)
	ghostIcon.Parent = UI.Game.gameHudGui

	dropIndicator = Instance.new("Frame")
	dropIndicator.Name = "DropIndicator"
	dropIndicator.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
	dropIndicator.BackgroundTransparency = 0.7
	dropIndicator.ZIndex = 5
	dropIndicator.BorderSizePixel = 0
	dropIndicator.Visible = false
	dropIndicator.Parent = UI.Game.ItemContainer
end

-- Начало перетаскивания из экипировки
local function onEquipmentDragBegan(itemData, originalIcon, slotName)
	if isDragging or isContextMenuOpen then return end
	isDragging = true
	isMouseAnchoredToCenter = true
	draggedItemData = itemData
	draggedItemData.FromEquipment = slotName
	draggedItemData.FromHotbar = nil
	draggedItemData.FromMoney = nil
	draggedItemData.FromBackpack = nil

	local mousePos = UserInputService:GetMouseLocation()
	originalIcon.Visible = false

	ghostIcon = Instance.new("ImageLabel")
	ghostIcon.Name = "GhostIcon"
	ghostIcon.Image = originalIcon.Image
	ghostIcon.Size = UDim2.fromOffset(64, 64)
	ghostIcon.BackgroundTransparency = 1
	ghostIcon.ImageTransparency = 0.4
	ghostIcon.ZIndex = 200
	ghostIcon.Position = UDim2.fromOffset(mousePos.X - 32, mousePos.Y - 32)
	ghostIcon.Parent = UI.Game.gameHudGui

	dropIndicator = Instance.new("Frame")
	dropIndicator.Name = "DropIndicator"
	dropIndicator.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
	dropIndicator.BackgroundTransparency = 0.7
	dropIndicator.ZIndex = 5
	dropIndicator.BorderSizePixel = 0
	dropIndicator.Visible = false
	dropIndicator.Parent = UI.Game.ItemContainer
end

-- Начало перетаскивания денег
local function onMoneyDragBegan(itemData, originalIcon)
	if isDragging or isContextMenuOpen then return end

	local StartMoneyDragEvent = Events:WaitForChild("StartMoneyDragEvent")
	StartMoneyDragEvent:FireServer()

	isDragging = true
	isMouseAnchoredToCenter = true
	draggedItemData = {
		ItemID = "Money",
		Amount = math.min(itemData.Amount, 256),
		GridSize = {X = 1, Y = 1},
		FromMoney = true
	}
	
	draggedItemData.FromBackpack = nil

	local mousePos = UserInputService:GetMouseLocation()

	ghostIcon = Instance.new("ImageLabel")
	ghostIcon.Name = "GhostIcon"
	ghostIcon.Image = originalIcon.Image
	ghostIcon.Size = UDim2.fromOffset(48, 48)
	ghostIcon.BackgroundTransparency = 1
	ghostIcon.ImageTransparency = 0.4
	ghostIcon.ZIndex = 200
	ghostIcon.Position = UDim2.fromOffset(mousePos.X - 24, mousePos.Y - 24)
	ghostIcon.Parent = UI.Game.gameHudGui

	local amountLabel = Instance.new("TextLabel")
	amountLabel.Name = "AmountLabel"
	amountLabel.Parent = ghostIcon
	amountLabel.BackgroundTransparency = 1
	amountLabel.Position = UDim2.new(0, 2, 1, -18)
	amountLabel.Size = UDim2.new(1, -4, 0, 16)
	amountLabel.Font = Enum.Font.SourceSansBold
	amountLabel.Text = tostring(draggedItemData.Amount)
	amountLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
	amountLabel.TextSize = 14
	amountLabel.TextXAlignment = Enum.TextXAlignment.Right
	amountLabel.TextStrokeTransparency = 0.5
	amountLabel.ZIndex = ghostIcon.ZIndex + 1

	dropIndicator = Instance.new("Frame")
	dropIndicator.Name = "DropIndicator"
	dropIndicator.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
	dropIndicator.BackgroundTransparency = 0.7
	dropIndicator.ZIndex = 5
	dropIndicator.BorderSizePixel = 0
	dropIndicator.Visible = false
	dropIndicator.Parent = UI.Game.ItemContainer
end

-- ИСПРАВЛЕННАЯ функция окончания перетаскивания
-- ИСПРАВЛЕННАЯ функция окончания перетаскивания
local function onDragEnded()
	if not isDragging then return end

	local mousePos = UserInputService:GetMouseLocation()
	print("[Drag] Ending drag at position:", mousePos.X, mousePos.Y)

	-- если true – не удаляем ghostIcon сразу, ждём прихода данных от сервера
	local keepGhost = false

	-- БЛОК 1: Перетаскивание из слота денег
	if draggedItemData.FromMoney then
		print("[Drag] Money from MoneySlot")

		if currentIndicatorGridPos then
			print("[Drag] Placing money in inventory at", currentIndicatorGridPos.X, currentIndicatorGridPos.Y)
			local FinishMoneyDragEvent = Events:WaitForChild("FinishMoneyDragEvent")
			FinishMoneyDragEvent:FireServer(draggedItemData, currentIndicatorGridPos)
			keepGhost = true
		else
			print("[Drag] Cancelled money drag - returning to slot")
			local CancelMoneyDragEvent = Events:WaitForChild("CancelMoneyDragEvent")
			CancelMoneyDragEvent:FireServer(draggedItemData)
		end

		-- БЛОК 2: Перетаскивание из экипировки
	elseif draggedItemData.FromEquipment then
		print("[Drag] Item from equipment slot:", draggedItemData.FromEquipment)
		local shouldRestoreEquipmentIcon = true

		-- Проверяем попадание в сетку инвентаря
		if currentIndicatorGridPos then
			print("[Drag] Moving from equipment to inventory grid")
			UnequipItemEvent:FireServer(draggedItemData.FromEquipment, currentIndicatorGridPos)
			shouldRestoreEquipmentIcon = false
			keepGhost = true
		else
			local handled = false

			-- Проверяем попадание в хотбар
			for slotName, slotFrame in pairs(UI.Game.HotbarSlots) do
				if (slotName == "LeftHand" or slotName == "RightHand") and slotFrame and slotFrame.Parent then
					local pos = slotFrame.AbsolutePosition
					local size = slotFrame.AbsoluteSize
					local buffer = 40

					if mousePos.X >= (pos.X - buffer) and mousePos.X <= (pos.X + size.X + buffer) and
						mousePos.Y >= (pos.Y - buffer) and mousePos.Y <= (pos.Y + size.Y + buffer) then

						local isSlotOccupied = currentHotbarData and currentHotbarData[slotName] ~= nil

						if isSlotOccupied then
							print("[Drag] ? Swapping equipment with hotbar slot:", slotName)
							local SwapHotbarAndEquipmentEvent = Events:WaitForChild("SwapHotbarAndEquipmentEvent")
							SwapHotbarAndEquipmentEvent:FireServer(slotName, draggedItemData.FromEquipment)
						else
							print("[Drag] ? Moving from equipment to hotbar:", slotName)
							local MoveEquipmentToHotbarEvent = Events:WaitForChild("MoveEquipmentToHotbarEvent")
							MoveEquipmentToHotbarEvent:FireServer(draggedItemData.FromEquipment, slotName)
						end
						handled = true
						shouldRestoreEquipmentIcon = false
						keepGhost = true
						break
					end
				end
			end

			-- Проверяем попадание в другой слот экипировки
			if not handled then
				for slotName, slotFrame in pairs(UI.Game.EquipmentSlots) do
					if slotName ~= draggedItemData.FromEquipment then
						local pos = slotFrame.AbsolutePosition
						local size = slotFrame.AbsoluteSize
						local offsetY = 35
						local adjustedPosY = pos.Y + offsetY
						local buffer = 20

						if mousePos.X >= (pos.X - buffer) and mousePos.X <= (pos.X + size.X + buffer) and
							mousePos.Y >= (adjustedPosY - buffer) and mousePos.Y <= (adjustedPosY + size.Y + buffer) then
							print("[Drag] Swapping equipment slots:", draggedItemData.FromEquipment, "->", slotName)
							SwapEquipmentEvent:FireServer(draggedItemData.FromEquipment, slotName)
							handled = true
							shouldRestoreEquipmentIcon = false
							keepGhost = true
							break
						end
					end
				end
			end

			if not handled then
				print("[Drag] No valid drop target for equipment")
			end
		end

		if equipmentIconCache[draggedItemData.FromEquipment] then
			equipmentIconCache[draggedItemData.FromEquipment].Icon.Visible = shouldRestoreEquipmentIcon
		end

		-- БЛОК 3: Перетаскивание из хотбара
	elseif draggedItemData.FromHotbar then
		print("[Drag] Item from hotbar slot:", draggedItemData.FromHotbar)
		local shouldRestoreHotbarIcon = true

		-- Проверяем попадание в сетку инвентаря
		if currentIndicatorGridPos then
			print("[Drag] Moving from hotbar to inventory grid")
			MoveItemFromHotbarEvent:FireServer(draggedItemData.FromHotbar, currentIndicatorGridPos)
			shouldRestoreHotbarIcon = false
			keepGhost = true
		else
			local handled = false

			-- Проверяем попадание в слоты экипировки
			local config = ItemsConfig[draggedItemData.ItemID]
			if config and config.EquipSlot then
				local validSlots = {}

				if config.EquipSlot == "Accessory" then
					validSlots = {"Accessory1", "Accessory2", "Accessory3"}
				elseif config.EquipSlot == "Money" then
					validSlots = {"Money"}
				else
					validSlots = {config.EquipSlot}
				end

				print("[Drag] Checking equipment slots for hotbar item. Valid:", table.concat(validSlots, ", "))

				for _, slotName in ipairs(validSlots) do
					local slotFrame = slotName == "Money" and UI.Game.MoneySlot or UI.Game.EquipmentSlots[slotName]

					if slotFrame and slotFrame.Parent then
						local pos = slotFrame.AbsolutePosition
						local size = slotFrame.AbsoluteSize
						local offsetY = 35
						local adjustedPosY = pos.Y + offsetY
						local buffer = 20

						if mousePos.X >= (pos.X - buffer) and mousePos.X <= (pos.X + size.X + buffer) and
							mousePos.Y >= (adjustedPosY - buffer) and mousePos.Y <= (adjustedPosY + size.Y + buffer) then

							local isSlotOccupied = currentEquipmentData and currentEquipmentData[slotName] ~= nil

							if isSlotOccupied then
								print("[Drag] ? Swapping hotbar with equipment slot:", slotName)
								local SwapHotbarAndEquipmentEvent = Events:WaitForChild("SwapHotbarAndEquipmentEvent")
								SwapHotbarAndEquipmentEvent:FireServer(draggedItemData.FromHotbar, slotName)
							else
								print("[Drag] ? Moving from hotbar to equipment slot:", slotName)
								local MoveHotbarToEquipmentEvent = Events:WaitForChild("MoveHotbarToEquipmentEvent")
								MoveHotbarToEquipmentEvent:FireServer(draggedItemData.FromHotbar, slotName)
							end
							handled = true
							shouldRestoreHotbarIcon = false
							keepGhost = true
							break
						end
					end
				end
			end

			-- Если не попали в экипировку, проверяем другой слот хотбара
			if not handled then
				for slotName, slotFrame in pairs(UI.Game.HotbarSlots) do
					if slotName ~= draggedItemData.FromHotbar and 
						(slotName == "LeftHand" or slotName == "RightHand") then

						local pos = slotFrame.AbsolutePosition
						local size = slotFrame.AbsoluteSize
						local buffer = 40

						if mousePos.X >= (pos.X - buffer) and mousePos.X <= (pos.X + size.X + buffer) and
							mousePos.Y >= (pos.Y - buffer) and mousePos.Y <= (pos.Y + size.Y + buffer) then

							print("[Drag] ? Swapping hotbar slots:", draggedItemData.FromHotbar, "->", slotName)
							local SwapHotbarSlotsEvent = Events:WaitForChild("SwapHotbarSlotsEvent")
							if SwapHotbarSlotsEvent then
								SwapHotbarSlotsEvent:FireServer(draggedItemData.FromHotbar, slotName)
								handled = true
								shouldRestoreHotbarIcon = false
								keepGhost = true
							end
							break
						end
					end
				end
			end

			if not handled then
				print("[Drag] No valid drop target, returning to original slot")
			end
		end

		if hotbarIconCache[draggedItemData.FromHotbar] then
			hotbarIconCache[draggedItemData.FromHotbar].Icon.Visible = shouldRestoreHotbarIcon
		end

		-- БЛОК 4: Перетаскивание из инвентаря / рюкзака
	else
		print("[Drag] Item from inventory")
		local shouldRestoreIcon = true

		-- Проверяем попадание в хотбар
		local droppedOnHotbar = false

		for slotName, slotFrame in pairs(UI.Game.HotbarSlots) do
			if (slotName == "LeftHand" or slotName == "RightHand") and slotFrame and slotFrame.Parent then
				local pos = slotFrame.AbsolutePosition
				local size = slotFrame.AbsoluteSize

				local buffer = 30
				if mousePos.X >= (pos.X - buffer) and mousePos.X <= (pos.X + size.X + buffer) and
					mousePos.Y >= (pos.Y - buffer) and mousePos.Y <= (pos.Y + size.Y + buffer) then
					print("[Drag] Dropped on hotbar slot:", slotName)
					MoveItemToHotbarEvent:FireServer(draggedItemData.UniqueID, slotName)
					droppedOnHotbar = true
					shouldRestoreIcon = false
					break
				end
			end
		end

		-- Проверяем попадание в слоты экипировки
		if not droppedOnHotbar then
			local config = ItemsConfig[draggedItemData.ItemID]

			print("[Drag] Checking equipment slots. Item config:", config and "exists" or "missing")
			if config then
				print("[Drag] EquipSlot:", config.EquipSlot)
			end

			if config and config.EquipSlot then
				local validSlots = {}

				if config.EquipSlot == "Accessory" then
					validSlots = {"Accessory1", "Accessory2", "Accessory3"}
				elseif config.EquipSlot == "Money" then
					validSlots = {"Money"}
				else
					validSlots = {config.EquipSlot}
				end

				print("[Drag] Valid slots:", table.concat(validSlots, ", "))

				for _, slotName in ipairs(validSlots) do
					local slotFrame = nil
					if slotName == "Money" then
						slotFrame = UI.Game.MoneySlot
					else
						slotFrame = UI.Game.EquipmentSlots[slotName]
					end

					if slotFrame and slotFrame.Parent then
						local pos = slotFrame.AbsolutePosition
						local size = slotFrame.AbsoluteSize

						local offsetY = 35
						local adjustedPosY = pos.Y + offsetY

						print(string.format("[Drag] Checking slot %s: pos(%d,%d) adjusted(%d,%d) size(%d,%d) mouse(%d,%d)",
							slotName, pos.X, pos.Y, pos.X, adjustedPosY, size.X, size.Y, mousePos.X, mousePos.Y))

						local buffer = 20
						if mousePos.X >= (pos.X - buffer) and mousePos.X <= (pos.X + size.X + buffer) and
							mousePos.Y >= (adjustedPosY - buffer) and mousePos.Y <= (adjustedPosY + size.Y + buffer) then

							print("[Drag] ? HIT! Dropped on equipment slot:", slotName)

							if EquipItemEvent then
								print("[Drag] Firing EquipItemEvent with ItemID:", draggedItemData.UniqueID, "to slot:", slotName)
								EquipItemEvent:FireServer(draggedItemData.UniqueID, slotName)
								droppedOnHotbar = true
								shouldRestoreIcon = false
							else
								warn("[Drag] ?? EquipItemEvent not found!")
							end
							break
						end
					else
						warn("[Drag] Slot frame not found for:", slotName)
					end
				end
			else
				print("[Drag] Item has no EquipSlot defined")
			end
		end

		-- Попадание в сетку инвентаря / рюкзака
		if not droppedOnHotbar and currentIndicatorGridPos then
			if currentIndicatorInBackpack then
				if draggedItemData.FromBackpack then
					print("[Drag] Moving item INSIDE backpack to", currentIndicatorGridPos.X, currentIndicatorGridPos.Y)
					local ev = Events:WaitForChild("MoveBackpackItemEvent")
					ev:FireServer(draggedItemData.UniqueID, currentIndicatorGridPos)
					shouldRestoreIcon = false
				else
					print("[Drag] Moving item INTO backpack at", currentIndicatorGridPos.X, currentIndicatorGridPos.Y)
					local ev = Events:WaitForChild("MoveItemToBackpackEvent")
					ev:FireServer(draggedItemData.UniqueID, currentIndicatorGridPos)
					shouldRestoreIcon = false
				end
			else
				if draggedItemData.FromBackpack then
					print("[Drag] Moving item FROM backpack to inventory at", currentIndicatorGridPos.X, currentIndicatorGridPos.Y)
					local ev = Events:WaitForChild("MoveItemFromBackpackEvent")
					ev:FireServer(draggedItemData.UniqueID, currentIndicatorGridPos)
					shouldRestoreIcon = false
				else
					print("[Drag] Moving within inventory grid")
					MoveItemEvent:FireServer(draggedItemData.UniqueID, currentIndicatorGridPos)
					shouldRestoreIcon = false
				end
			end
		end

		-- Финальная обработка иконки ТОЛЬКО для инвентаря/рюкзака
		if not draggedItemData.FromHotbar and not draggedItemData.FromEquipment and not draggedItemData.FromMoney then
			print(
				("[Drag] Final icon handling: shouldRestoreIcon=%s, FromBackpack=%s")
					:format(tostring(shouldRestoreIcon), tostring(draggedItemData.FromBackpack))
			)

			local srcIcon = draggedItemData._sourceIcon
			if shouldRestoreIcon then
				if srcIcon and srcIcon.Parent then
					srcIcon.Visible = true
				else
					print("[Drag][WARN] Source icon missing while shouldRestoreIcon = true")
				end
				keepGhost = false
			else
				-- ничего не делаем с srcIcon: он будет пересоздан при следующем Render,
				-- а ghostIcon останется висеть до прихода данных
				keepGhost = true
			end
		end
	end

	-- Очистка состояния перетаскивания
	isDragging = false
	draggedItemData = nil
	currentIndicatorGridPos = nil
	currentIndicatorInBackpack = false

	-- dropIndicator нам больше не нужен
	if dropIndicator then dropIndicator:Destroy(); dropIndicator = nil end

	-- ghostIcon:
	--  • если перетаскивание отменено / ничего не произошло > уничтожаем сразу
	--  • если была успешная операция > оставляем, пока не придут новые данные от сервера
	if not keepGhost then
		if ghostIcon then ghostIcon:Destroy(); ghostIcon = nil end
	end
end

function InventoryManager:openContextMenuForSlot(itemData, clickPosition, slotType, slotName)
	if isContextMenuOpen then self:closeContextMenu() end
	isContextMenuOpen = true

	local config = ItemsConfig[itemData.ItemID]
	local buttonCount = 0

	local function addButton(name, callback) 
		createContextMenuButton(name, callback)
		buttonCount = buttonCount + 1 
	end

	-- Для денег в слоте
	if slotName == "Money" then
		addButton("Withdraw 256", function()
			local UnequipMoneyEvent = Events:WaitForChild("UnequipMoneyEvent")
			UnequipMoneyEvent:FireServer()
			self:closeContextMenu()
		end)
	else
		-- Unequip для обычных предметов
		addButton("Unequip", function()
			local UnequipItemEvent = Events:WaitForChild("UnequipItemEvent")
			UnequipItemEvent:FireServer(slotName)
			self:closeContextMenu()
		end)
	end

	-- Drop всегда доступен
	addButton("Drop", function()
		local DropFromSlotEvent = Events:WaitForChild("DropFromSlotEvent")
		DropFromSlotEvent:FireServer(slotType, slotName)
		self:closeContextMenu()
	end)

	-- Показываем меню
	local menu = UI.Game.ContextMenu
	if buttonCount > 0 then
		menu.Size = UDim2.fromOffset(150, (buttonCount * 25) + ((buttonCount) * 2) + 8)
		menu.Position = UDim2.fromOffset(clickPosition.X, clickPosition.Y - 48)
		menu.Visible = true
		ignoreNextInput = true
	end
end

function InventoryManager:openContextMenuForHotbar(itemData, clickPosition, slotName)
	if isContextMenuOpen then self:closeContextMenu() end
	isContextMenuOpen = true

	local buttonCount = 0
	local function addButton(name, callback) 
		createContextMenuButton(name, callback)
		buttonCount = buttonCount + 1 
	end

	-- Drop из хотбара
	addButton("Drop", function()
		DropItemEvent:FireServer(itemData.UniqueID, slotName)
		self:closeContextMenu()
	end)

	-- Показываем меню
	local menu = UI.Game.ContextMenu
	menu.Size = UDim2.fromOffset(150, (buttonCount * 25) + 8)
	menu.Position = UDim2.fromOffset(clickPosition.X, clickPosition.Y - 48)
	menu.Visible = true
	ignoreNextInput = true
end

-- Функция создания иконки
local function renderItemIcon(itemData, container)
	local config = ItemsConfig[itemData.ItemID]
	if not config then return end

	local icon = Instance.new("ImageLabel")
	icon.Name = itemData.ItemID
	icon.BackgroundTransparency = 1
	icon.Parent = container

	local containerName = container.Name
	if containerName == "ItemContainer" or containerName == "BackpackGridBackground" then
		icon.Image = config.GridIcon
		icon.ZIndex = 10
		local sizeX = (itemData.GridSize.X * 48) + ((itemData.GridSize.X - 1) * 2)
		local sizeY = (itemData.GridSize.Y * 48) + ((itemData.GridSize.Y - 1) * 2)
		local posX = (itemData.Position.X - 1) * 50
		local posY = (itemData.Position.Y - 1) * 50
		icon.Size = UDim2.fromOffset(sizeX, sizeY)
		icon.Position = UDim2.fromOffset(posX, posY)
	elseif containerName == "LeftHandSlot" or containerName == "RightHandSlot" then
		icon.Image = config.HotbarIcon or config.GridIcon
		icon.ZIndex = 60
		icon.Size = UDim2.fromOffset(64, 64)
		icon.Position = UDim2.fromOffset(3, 3)
		icon.AnchorPoint = Vector2.new(0, 0)

		if config.IsTwoHanded then
			local twoHandedLabel = Instance.new("TextLabel")
			twoHandedLabel.Name = "TwoHandedIndicator"
			twoHandedLabel.Parent = icon
			twoHandedLabel.Size = UDim2.new(1, 0, 0.2, 0)
			twoHandedLabel.Position = UDim2.new(0, 0, 0.8, 0)
			twoHandedLabel.BackgroundTransparency = 0.5
			twoHandedLabel.BackgroundColor3 = Color3.fromRGB(50, 50, 50)
			twoHandedLabel.Text = "2H"
			twoHandedLabel.TextColor3 = Color3.fromRGB(255, 200, 0)
			twoHandedLabel.TextScaled = true
			twoHandedLabel.Font = Enum.Font.SourceSansBold
			twoHandedLabel.ZIndex = icon.ZIndex + 2
		end
	elseif containerName:match("Accessory%d+Slot") or containerName == "ArmorSlot" or containerName == "ClothingSlot" or containerName == "MoneySlot" then
		icon.Image = config.HotbarIcon or config.GridIcon
		icon.ZIndex = 10
		icon.Size = UDim2.fromScale(0.9, 0.9)
		icon.Position = UDim2.fromScale(0.05, 0.05)
	else
		icon.Image = config.HotbarIcon or config.GridIcon
		icon.ZIndex = 10
		icon.Size = UDim2.fromScale(0.9, 0.9)
		icon.Position = UDim2.fromScale(0.05, 0.05)
	end

	if config.IsStackable and itemData.Amount and itemData.Amount > 1 then
		local amountLabel = Instance.new("TextLabel")
		amountLabel.Name = "AmountLabel"
		amountLabel.Parent = icon
		amountLabel.BackgroundTransparency = 1
		amountLabel.Position = UDim2.new(0, 2, 1, -18)
		amountLabel.Size = UDim2.new(1, -4, 0, 16)
		amountLabel.Font = Enum.Font.SourceSansBold
		amountLabel.Text = tostring(itemData.Amount)
		amountLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
		amountLabel.TextSize = 14
		amountLabel.TextXAlignment = Enum.TextXAlignment.Right
		amountLabel.TextStrokeTransparency = 0.5
		amountLabel.ZIndex = icon.ZIndex + 1
	end

	-- Подключаем события в зависимости от типа контейнера
	if containerName == "LeftHandSlot" or containerName == "RightHandSlot" then
		-- ДЛЯ ХОТБАРА
		local slotName = containerName == "LeftHandSlot" and "LeftHand" or "RightHand"
		hotbarIconCache[slotName] = {Icon = icon, Data = itemData}

		icon.InputBegan:Connect(function(input)
			if isContextMenuOpen then return end
			if input.UserInputType == Enum.UserInputType.MouseButton1 then
				onHotbarDragBegan(itemData, icon, slotName)
			elseif input.UserInputType == Enum.UserInputType.MouseButton2 then
				InventoryManager:openHotbarContextMenu(itemData, slotName, UserInputService:GetMouseLocation())
			end
		end)

	elseif containerName:match("Accessory%d+Slot") or containerName == "ArmorSlot" or containerName == "ClothingSlot" then
		-- ДЛЯ ЭКИПИРОВКИ
		local slotName = containerName:gsub("Slot", "")
		equipmentIconCache[slotName] = {Icon = icon, Data = itemData}

		icon.InputBegan:Connect(function(input)
			if isContextMenuOpen then return end
			if input.UserInputType == Enum.UserInputType.MouseButton1 then
				onEquipmentDragBegan(itemData, icon, slotName)
			elseif input.UserInputType == Enum.UserInputType.MouseButton2 then
				InventoryManager:openEquipmentContextMenu(itemData, slotName, UserInputService:GetMouseLocation())
			end
		end)

	elseif containerName == "MoneySlot" then
		-- ДЛЯ ДЕНЕГ
		moneyIconCache = {Icon = icon, Data = itemData}

		icon.InputBegan:Connect(function(input)
			if isContextMenuOpen then return end
			if input.UserInputType == Enum.UserInputType.MouseButton1 then
				onMoneyDragBegan(itemData, icon)
			elseif input.UserInputType == Enum.UserInputType.MouseButton2 then
				InventoryManager:openContextMenuForSlot(itemData, UserInputService:GetMouseLocation(), "Money", "Money")
			end
		end)

	else
		-- ДЛЯ ИНВЕНТАРЯ И РЮКЗАКА
		local isBackpackGrid = (containerName == "BackpackGridBackground")

		if containerName == "ItemContainer" or isBackpackGrid then
			itemIconCache[itemData.UniqueID] = {Icon = icon, Data = itemData}
		end

		icon.InputBegan:Connect(function(input)
			if isContextMenuOpen then return end

			if input.UserInputType == Enum.UserInputType.MouseButton1 then
				if isBackpackGrid then
					onBackpackDragBegan(itemData, icon)
				else
					onDragBegan(itemData, icon)
				end
			elseif input.UserInputType == Enum.UserInputType.MouseButton2 then
				InventoryManager:openContextMenu(
					itemData,
					UserInputService:GetMouseLocation(),
					isBackpackGrid -- флаг "из рюкзака"
				)
			end
		end)
	end
end

-- ВИЗУАЛЬНАЯ СЕТКА РЮКЗАКА + ИКОНКИ ЕГО СОДЕРЖИМОГО
local function renderBackpackGrid(equipmentData)
	if not UI or not UI.Game then return end

	local inventoryCanvas = UI.Game.InventoryCanvas
	if not inventoryCanvas then return end

	local mainFrame = inventoryCanvas:FindFirstChild("MainFrame")
	if not mainFrame then return end

	-- Чистим старую сетку рюкзака
	for _, child in ipairs(mainFrame:GetChildren()) do
		if child.Name == "BackpackGridBackground" then
			child:Destroy()
		end
	end

	-- ищем надетый рюкзак по текущим данным
	local backpackItem, _, backpackCfg = getEquippedBackpackClient()
	if not backpackItem or not backpackCfg then return end

	-- размеры сетки рюкзака
	local gridSize = backpackItem.BackpackInventory
		and backpackItem.BackpackInventory.GridSize
		or backpackCfg.ExpansionSize

	if not gridSize then return end

	-- Берём фон основной сетки инвентаря
	local gridBackground = mainFrame:FindFirstChild("GridBackground")
	if not gridBackground then return end

	local cellSize = BACKPACK_CELL_SIZE
	local padding = BACKPACK_CELL_PADDING

	local gridWidthPx  = gridSize.X * cellSize + (gridSize.X - 1) * padding
	local gridHeightPx = gridSize.Y * cellSize + (gridSize.Y - 1) * padding

	-- Фон рюкзака
	local bg = Instance.new("Frame")
	bg.Name = "BackpackGridBackground"
	bg.Parent = mainFrame
	bg.BackgroundColor3 = Color3.fromRGB(10, 10, 10)
	bg.BackgroundTransparency = 0.5
	bg.BorderColor3 = Color3.fromRGB(60, 60, 60)
	bg.BorderSizePixel = 1
	bg.Size = UDim2.fromOffset(gridWidthPx, gridHeightPx)

	bg.AnchorPoint = Vector2.new(0, 0)

	local cellSize = BACKPACK_CELL_SIZE
	local padding = BACKPACK_CELL_PADDING
	local fiveCellsHeight = 5 * (cellSize + padding)

	bg.Position = UDim2.new(
		gridBackground.Position.X.Scale,
		gridBackground.Position.X.Offset - bg.Size.X.Offset - 25,           -- слева, отступ 25
		gridBackground.Position.Y.Scale,
		gridBackground.Position.Y.Offset - fiveCellsHeight                  -- подняли на 5 клеток
	)

	-- Внутренняя сетка клеток
	local inner = Instance.new("Frame")
	inner.Name = "BackpackGrid"
	inner.Parent = bg
	inner.BackgroundTransparency = 1
	inner.Size = UDim2.fromScale(1, 1)

	local uiGrid = Instance.new("UIGridLayout")
	uiGrid.CellSize = UDim2.fromOffset(cellSize, cellSize)
	uiGrid.CellPadding = UDim2.fromOffset(padding, padding)
	uiGrid.FillDirection = Enum.FillDirection.Horizontal
	uiGrid.SortOrder = Enum.SortOrder.LayoutOrder
	uiGrid.Parent = inner

	for y = 1, gridSize.Y do
		for x = 1, gridSize.X do
			local cell = Instance.new("Frame")
			cell.Name = ("BackpackCell_%d_%d"):format(x, y)
			cell.Parent = inner
			cell.BackgroundColor3 = Color3.fromRGB(35, 35, 35)
			cell.BorderColor3 = Color3.fromRGB(70, 70, 70)
			cell.BorderSizePixel = 1
		end
	end

	-- Рисуем предметы внутри рюкзака
	if backpackItem.BackpackInventory and backpackItem.BackpackInventory.Items then
		for _, item in ipairs(backpackItem.BackpackInventory.Items) do
			if item.Position and item.GridSize then
				-- используем общий рендер, но контейнер = фон рюкзака
				renderItemIcon(item, bg)
			end
		end
	end
end

-- Основная функция рендера
function InventoryManager:Render(inventoryData, equipmentData, moneyData, hotbarData)
	print("[Render] Starting render. Hotbar data:", hotbarData and "exists" or "missing")

	-- Очистка старых иконок инвентаря
	for _, data in pairs(itemIconCache) do 
		if data.Icon then data.Icon:Destroy() end 
	end
	itemIconCache = {}

	-- Очистка старых иконок хотбара
	for _, data in pairs(hotbarIconCache) do 
		if data.Icon then data.Icon:Destroy() end 
	end
	hotbarIconCache = {}

	-- Очистка старых иконок экипировки
	for _, data in pairs(equipmentIconCache) do 
		if data.Icon then data.Icon:Destroy() end 
	end
	equipmentIconCache = {}

	-- Очистка денег
	if moneyIconCache and moneyIconCache.Icon then
		moneyIconCache.Icon:Destroy()
	end
	moneyIconCache = nil

	-- Очищаем все дочерние элементы слотов хотбара
	for slotName, slotFrame in pairs(UI.Game.HotbarSlots) do
		if slotName == "LeftHand" or slotName == "RightHand" then
			for _, child in ipairs(slotFrame:GetChildren()) do
				if child:IsA("ImageLabel") and child.Name ~= "SlotLabel" then
					child:Destroy()
				end
			end
		end
	end

	-- Очищаем слоты экипировки
	for slotName, slotFrame in pairs(UI.Game.EquipmentSlots) do
		for _, child in ipairs(slotFrame:GetChildren()) do
			if child:IsA("ImageLabel") then
				child:Destroy()
			end
		end
	end

	-- Очищаем слот денег
	if UI.Game.MoneySlot then
		for _, child in ipairs(UI.Game.MoneySlot:GetChildren()) do
			if child:IsA("ImageLabel") then
				child:Destroy()
			end
		end
	end
	
	-- ?? ЖЁСТКАЯ ОЧИСТКА ВИЗУАЛА ИНВЕНТАРЯ (анти-фантом)
	local itemContainer = UI.Game.ItemContainer
	if itemContainer then
		for _, child in ipairs(itemContainer:GetChildren()) do
			if child:IsA("ImageLabel") then
				child:Destroy()
			end
		end
	end

	-- ?? На всякий случай чистим старые иконки внутри рюкзака, если фон ещё жив
	local invCanvas = UI.Game.InventoryCanvas
	if invCanvas and invCanvas:FindFirstChild("MainFrame") then
		local mainFrame = invCanvas.MainFrame
		local backpackBg = mainFrame:FindFirstChild("BackpackGridBackground")
		if backpackBg then
			for _, child in ipairs(backpackBg:GetChildren()) do
				if child:IsA("ImageLabel") then
					child:Destroy()
				end
			end
		end
	end

	-- Отрисовка инвентаря
	if inventoryData then
		-- Поддержка обоих форматов данных
		local items = inventoryData.Items or inventoryData
		if items and type(items) == "table" then
			print("[Render] Rendering", #items, "inventory items")
			for _, itemData in ipairs(items) do 
				if itemData and itemData.ItemID then
					renderItemIcon(itemData, UI.Game.ItemContainer)
				end
			end
		else
			print("[Render] No items to render in inventory")
		end
	else
		print("[Render] No inventory data provided")
	end

	-- Отрисовка экипировки
	if equipmentData then 
		for slotName, itemData in pairs(equipmentData) do 
			if itemData then 
				local slotUI = UI.Game.EquipmentSlots[slotName]
				if slotUI then 
					renderItemIcon(itemData, slotUI) 
				else
					-- Не выводим warning для старых слотов которые больше не используются
					if slotName ~= "Head" then
						warn("[Render] Slot UI not found for", slotName)
					end
				end 
			end 
		end 
	end

	-- Отрисовка денег (ОТДЕЛЬНО!)
	if moneyData then
		print("[Render] Rendering money:", moneyData.ItemID, "Amount:", moneyData.Amount)
		renderItemIcon(moneyData, UI.Game.MoneySlot)
	else
		print("[Render] No money data")
	end

	-- Отрисовка хотбара
	if hotbarData then
		print("[Render] Rendering hotbar items")
		for slotName, itemData in pairs(hotbarData) do
			if itemData then
				local slotUI = UI.Game.HotbarSlots[slotName]
				if slotUI then
					print("[Render] Adding", itemData.ItemID, "to", slotName)
					renderItemIcon(itemData, slotUI)
				else
					warn("[Render] Slot UI not found for", slotName)
				end
			end
		end
	else
		print("[Render] No hotbar data - slots will be empty")
	end
	-- Отрисовка дополнительного окна рюкзака (только визуал)
	renderBackpackGrid(equipmentData or currentEquipmentData or {})
end

local function onInventoryDataReceived(data)
	print("[InventoryManager] === DATA RECEIVED FROM SERVER ===")
	
	-- как только сервер прислал новые данные, убираем "застывший" призрак
	if ghostIcon then
		ghostIcon:Destroy()
		ghostIcon = nil
	end
	if dropIndicator then
		dropIndicator:Destroy()
		dropIndicator = nil
	end

	if not data then
		warn("[InventoryManager] ERROR: No data received!")
		return
	end

	-- Отладочный вывод структуры данных
	print("[InventoryManager] Data structure:")
	for key, value in pairs(data) do
		if type(value) == "table" then
			if key == "Inventory" then
				local itemCount = 0
				if value.Items then
					itemCount = #value.Items
				elseif type(value) == "table" then
					itemCount = #value
				end
				print("  Inventory:", itemCount, "items")

				-- Выводим первые 5 предметов для отладки
				local items = value.Items or value
				if items then
					for i = 1, math.min(5, #items) do
						local item = items[i]
						if item then
							print(string.format("    [%d] %s x%d", 
								i, 
								item.ItemID or "unknown", 
								item.Amount or 0
								))
						end
					end
					if #items > 5 then
						print("    ... and", #items - 5, "more items")
					end
				end
			elseif key == "MoneySlot" and value then
				print("  MoneySlot: Amount =", value.Amount or 0)
			elseif key == "Hotbar" and value then
				print("  Hotbar:")
				if value.LeftHand then
					print("    LeftHand:", value.LeftHand.ItemID)
				end
				if value.RightHand then
					print("    RightHand:", value.RightHand.ItemID)
				end
			else
				print("  ", key, "= table")
			end
		else
			print("  ", key, "=", tostring(value))
		end
	end

	-- Сохраняем данные с проверкой формата
	if data.Inventory then
		-- Поддержка двух форматов:
		-- Новый: {Items = {...}, GridSize = {...}}
		-- Старый: [{...}, {...}] (просто массив предметов)
		if data.Inventory.Items then
			currentInventoryData = data.Inventory
		else
			-- Преобразуем старый формат в новый
			currentInventoryData = {Items = data.Inventory}
		end
		print("[InventoryManager] Inventory data saved:", #(currentInventoryData.Items or {}), "items")
	else
		currentInventoryData = nil
		print("[InventoryManager] No inventory data in update")
	end

	-- Сохраняем остальные данные
	currentEquipmentData = data.Equipment
	currentMoneyData = data.MoneySlot
	currentHotbarData = data.Hotbar

	-- Проверяем наличие UI перед рендером
	if UI and UI.Game then
		print("[InventoryManager] Calling Render function...")
		InventoryManager:Render(currentInventoryData, currentEquipmentData, currentMoneyData, currentHotbarData)
	else
		warn("[InventoryManager] UI not ready, saving data for later render")
	end

	print("[InventoryManager] =====================================")
end

-- Инициализация
function InventoryManager:Init(_UI, _PlayerGui)
	UI = _UI
	PlayerGui = _PlayerGui

	print("[InventoryManager] Initializing...")
	
	LoadInventoryDataEvent.OnClientEvent:Connect(onInventoryDataReceived)
	print("[InventoryManager] ? Connected to LoadInventoryDataEvent")

	-- Если есть сохраненные данные, рендерим их
	if currentInventoryData or currentEquipmentData or currentMoneyData or currentHotbarData then
		print("[InventoryManager] Rendering saved data...")
		InventoryManager:Render(currentInventoryData, currentEquipmentData, currentMoneyData, currentHotbarData)
	end

	UserInputService.InputBegan:Connect(function(input)
		if isContextMenuOpen and (input.UserInputType == Enum.UserInputType.MouseButton1 or 
			input.UserInputType == Enum.UserInputType.MouseButton2) then
			if ignoreNextInput then
				ignoreNextInput = false
				return
			end
			local guisInPosition = PlayerGui:GetGuiObjectsAtPosition(input.Position.X, input.Position.Y)
			local clickedOnMenu = false
			for _, guiObject in ipairs(guisInPosition) do
				if guiObject:IsDescendantOf(UI.Game.ContextMenu) or 
					guiObject:IsDescendantOf(UI.Game.SplitStackPrompt.Prompt) then
					clickedOnMenu = true
					break
				end
			end
			if not clickedOnMenu then
				self:closeContextMenu()
			end
		end
	end)

	UserInputService.InputEnded:Connect(function(input) 
		if input.UserInputType == Enum.UserInputType.MouseButton1 and isDragging then 
			onDragEnded() 
		end 
	end)

	-- Обновление позиции при перетаскивании
	RunService.RenderStepped:Connect(function()
		if not isDragging then return end

		local mousePos = UserInputService:GetMouseLocation()
		local itemContainer = UI.Game.ItemContainer

		local isMouseInsideGrid = mousePos.X >= itemContainer.AbsolutePosition.X and
			mousePos.X <= itemContainer.AbsolutePosition.X + itemContainer.AbsoluteSize.X and
			mousePos.Y >= itemContainer.AbsolutePosition.Y and
			mousePos.Y <= itemContainer.AbsolutePosition.Y + itemContainer.AbsoluteSize.Y + 50

		if not isMouseInsideGrid then 
			isMouseAnchoredToCenter = true 
		end

		local backpackBg = UI.Game.InventoryCanvas.MainFrame:FindFirstChild("BackpackGridBackground")
		local isMouseInsideBackpack = false

		if backpackBg then
			isMouseInsideBackpack =
				mousePos.X >= backpackBg.AbsolutePosition.X and
				mousePos.X <= backpackBg.AbsolutePosition.X + backpackBg.AbsoluteSize.X and
				mousePos.Y >= backpackBg.AbsolutePosition.Y and
				mousePos.Y <= backpackBg.AbsolutePosition.Y + backpackBg.AbsoluteSize.Y
		end

		local verticalOffset = isMouseAnchoredToCenter and 48 or 0
		local config = ItemsConfig[draggedItemData.ItemID]

		-- 1) Над сеткой РЮКЗАКА (только предметы из инвентаря)
		if isMouseInsideBackpack 
			and not draggedItemData.FromHotbar 
			and not draggedItemData.FromEquipment 
			and not draggedItemData.FromMoney then

			local originalSize = config and (config.GridSize or draggedItemData.GridSize) or Vector2.new(1, 1)
			local pixelSizeX = (originalSize.X * 48) + ((originalSize.X - 1) * 2)
			local pixelSizeY = (originalSize.Y * 48) + ((originalSize.Y - 1) * 2)
			ghostIcon.Size = UDim2.fromOffset(pixelSizeX, pixelSizeY)
			dropIndicator.Size = ghostIcon.Size
			if config then
				ghostIcon.Image = config.GridIcon
			end

			if isMouseAnchoredToCenter then 
				dragOffset = ghostIcon.AbsoluteSize / 2 
			end

			local finalIconTopLeft = Vector2.new(mousePos.X - dragOffset.X, mousePos.Y - dragOffset.Y - verticalOffset)
			ghostIcon.Position = UDim2.fromOffset(finalIconTopLeft.X, finalIconTopLeft.Y)

			local relativePos = finalIconTopLeft - backpackBg.AbsolutePosition
			local cellStep = BACKPACK_CELL_SIZE + BACKPACK_CELL_PADDING
			local gridX = math.floor(relativePos.X / cellStep + 0.5) + 1
			local gridY = math.floor(relativePos.Y / cellStep + 0.5) + 1
			currentIndicatorGridPos = {X = gridX, Y = gridY}
			currentIndicatorInBackpack = true

			-- Переводим позицию индикатора в систему координат ItemContainer
			local indicatorWorldX = backpackBg.AbsolutePosition.X + (gridX - 1) * cellStep
			local indicatorWorldY = backpackBg.AbsolutePosition.Y + (gridY - 1) * cellStep
			local containerPos = itemContainer.AbsolutePosition
			dropIndicator.Position = UDim2.fromOffset(
				indicatorWorldX - containerPos.X,
				indicatorWorldY - containerPos.Y
			)
			dropIndicator.Visible = true

			-- 2) Над обычной сеткой инвентаря (из инвентаря/экипировки/денег)
		elseif isMouseInsideGrid and (not draggedItemData.FromHotbar or draggedItemData.FromEquipment or draggedItemData.FromMoney) then
			currentIndicatorInBackpack = false

			local originalSize = config and (config.GridSize or draggedItemData.GridSize) or Vector2.new(1, 1)
			local pixelSizeX = (originalSize.X * 48) + ((originalSize.X - 1) * 2)
			local pixelSizeY = (originalSize.Y * 48) + ((originalSize.Y - 1) * 2)
			ghostIcon.Size = UDim2.fromOffset(pixelSizeX, pixelSizeY)
			dropIndicator.Size = ghostIcon.Size
			if config then
				ghostIcon.Image = config.GridIcon
			end

			if isMouseAnchoredToCenter then 
				dragOffset = ghostIcon.AbsoluteSize / 2 
			end

			local finalIconTopLeft = Vector2.new(mousePos.X - dragOffset.X, mousePos.Y - dragOffset.Y - verticalOffset)
			ghostIcon.Position = UDim2.fromOffset(finalIconTopLeft.X, finalIconTopLeft.Y)

			local relativePos = finalIconTopLeft - itemContainer.AbsolutePosition
			local gridX = math.floor(relativePos.X / 50 + 0.5) + 1
			local gridY = math.floor(relativePos.Y / 50 + 0.5) + 1
			currentIndicatorGridPos = {X = gridX, Y = gridY}

			local indicatorPosX = (gridX - 1) * 50
			local indicatorPosY = (gridY - 1) * 50
			dropIndicator.Position = UDim2.fromOffset(indicatorPosX, indicatorPosY)
			dropIndicator.Visible = true

			-- 3) Над сеткой инвентаря, но предмет из хотбара
		elseif isMouseInsideGrid and draggedItemData.FromHotbar then
			currentIndicatorInBackpack = false

			local originalSize = config and (config.GridSize or Vector2.new(1, 1)) or Vector2.new(1, 1)
			local pixelSizeX = (originalSize.X * 48) + ((originalSize.X - 1) * 2)
			local pixelSizeY = (originalSize.Y * 48) + ((originalSize.Y - 1) * 2)
			ghostIcon.Size = UDim2.fromOffset(pixelSizeX, pixelSizeY)
			dropIndicator.Size = ghostIcon.Size
			if config then
				ghostIcon.Image = config.GridIcon
			end

			dragOffset = ghostIcon.AbsoluteSize / 2

			local finalIconTopLeft = Vector2.new(mousePos.X - dragOffset.X, mousePos.Y - dragOffset.Y - verticalOffset)
			ghostIcon.Position = UDim2.fromOffset(finalIconTopLeft.X, finalIconTopLeft.Y)

			local relativePos = finalIconTopLeft - itemContainer.AbsolutePosition
			local gridX = math.floor(relativePos.X / 50 + 0.5) + 1
			local gridY = math.floor(relativePos.Y / 50 + 0.5) + 1
			currentIndicatorGridPos = {X = gridX, Y = gridY}

			local indicatorPosX = (gridX - 1) * 50
			local indicatorPosY = (gridY - 1) * 50
			dropIndicator.Position = UDim2.fromOffset(indicatorPosX, indicatorPosY)
			dropIndicator.Visible = true

			-- 4) Вне всех сеток
		else
			currentIndicatorInBackpack = false

			ghostIcon.Size = UDim2.fromOffset(48, 48)
			if config then
				ghostIcon.Image = config.HotbarIcon or config.GridIcon
			end
			dragOffset = ghostIcon.AbsoluteSize / 2

			local finalIconTopLeft = Vector2.new(mousePos.X - dragOffset.X, mousePos.Y - dragOffset.Y - verticalOffset)
			ghostIcon.Position = UDim2.fromOffset(finalIconTopLeft.X, finalIconTopLeft.Y)
			dropIndicator.Visible = false
			currentIndicatorGridPos = nil
		end
	end)
end

return InventoryManager
