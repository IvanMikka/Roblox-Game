-- UIManager (ModuleScript) - ¬≈–—»ﬂ 6.1 (»ÒÔ‡‚ÎÂÌ‡ Ó¯Ë·Í‡ ËÌËˆË‡ÎËÁ‡ˆËË)
local UIManager = {}

function UIManager.CreateAll(playerGui)

	-- =======================================================
	-- UI —»—“≈Ã€ Ã≈Õﬁ («¿√–”« ¿, ¬€¡Œ– œ≈–—ŒÕ¿∆¿, –≈ƒ¿ “Œ–)
	-- =======================================================
	local menuScreenGui = Instance.new("ScreenGui")
	menuScreenGui.Name = "MenuSystemUI"
	menuScreenGui.Parent = playerGui
	menuScreenGui.ResetOnSpawn = false
	menuScreenGui.IgnoreGuiInset = true

	local fadeFrame = Instance.new("Frame")
	fadeFrame.Name = "FadeFrame"
	fadeFrame.Parent = menuScreenGui
	fadeFrame.BackgroundColor3 = Color3.new(0, 0, 0)
	fadeFrame.Size = UDim2.fromScale(1, 1)
	fadeFrame.ZIndex = 100
	fadeFrame.BackgroundTransparency = 1

	local masterCanvas = Instance.new("CanvasGroup")
	masterCanvas.Name = "MasterCanvas"
	masterCanvas.Parent = menuScreenGui
	masterCanvas.BackgroundTransparency = 1
	masterCanvas.Size = UDim2.fromScale(1, 1)

	-- Loading Canvas
	local loadingCanvas = Instance.new("CanvasGroup")
	loadingCanvas.Name = "LoadingCanvas"
	loadingCanvas.Parent = masterCanvas
	loadingCanvas.BackgroundTransparency = 1
	loadingCanvas.Size = UDim2.fromScale(1, 1)

	local VERTICAL_ALIGN_Y = 0.9
	local loadingLabel = Instance.new("TextLabel")
	loadingLabel.Name = "LoadingLabel"
	loadingLabel.Parent = loadingCanvas
	loadingLabel.Font = Enum.Font.SourceSans
	loadingLabel.Text = "Loading..."
	loadingLabel.TextColor3 = Color3.new(1, 1, 1)
	loadingLabel.TextSize = 30
	loadingLabel.TextXAlignment = Enum.TextXAlignment.Left
	loadingLabel.BackgroundTransparency = 1
	loadingLabel.AnchorPoint = Vector2.new(0, 0.5)
	loadingLabel.Position = UDim2.new(0.25, 0, VERTICAL_ALIGN_Y, 0)
	loadingLabel.Size = UDim2.new(0.15, 0, 0.1, 0)

	local skipButton = Instance.new("ImageButton")
	skipButton.Name = "SkipButton"
	skipButton.Parent = loadingCanvas
	skipButton.Image = "rbxassetid://105209376744613"
	skipButton.Rotation = 180
	skipButton.BackgroundColor3 = Color3.new(1, 1, 1)
	skipButton.AnchorPoint = Vector2.new(1, 0.5)
	skipButton.Position = UDim2.new(0.75, 0, VERTICAL_ALIGN_Y, 0)
	skipButton.Size = UDim2.new(0, 44, 0, 37)

	local loadingBarContainer = Instance.new("Frame")
	loadingBarContainer.Name = "LoadingBarContainer"
	loadingBarContainer.Parent = loadingCanvas
	loadingBarContainer.BackgroundTransparency = 1
	loadingBarContainer.AnchorPoint = Vector2.new(0.5, 0.5)
	loadingBarContainer.Position = UDim2.new(0.5, 0, VERTICAL_ALIGN_Y, 0)
	loadingBarContainer.Size = UDim2.new(0.3, 0, 0, 5)

	local limiterLeft = Instance.new("Frame")
	limiterLeft.Parent = loadingBarContainer
	limiterLeft.BackgroundColor3 = Color3.new(1, 1, 1)
	limiterLeft.BorderSizePixel = 0
	limiterLeft.AnchorPoint = Vector2.new(0, 0.5)
	limiterLeft.Position = UDim2.fromScale(0, 0.5)
	limiterLeft.Size = UDim2.new(0, 2, 0, 15)

	local limiterRight = Instance.new("Frame")
	limiterRight.Parent = loadingBarContainer
	limiterRight.BackgroundColor3 = Color3.new(1, 1, 1)
	limiterRight.BorderSizePixel = 0
	limiterRight.AnchorPoint = Vector2.new(1, 0.5)
	limiterRight.Position = UDim2.fromScale(1, 0.5)
	limiterRight.Size = UDim2.new(0, 2, 0, 15)

	local loadingFill = Instance.new("Frame")
	loadingFill.Name = "LoadingFill"
	loadingFill.Parent = loadingBarContainer
	loadingFill.BackgroundColor3 = Color3.new(1, 1, 1)
	loadingFill.BorderSizePixel = 0
	loadingFill.Size = UDim2.fromScale(0, 1)

	-- Main Menu Canvas
	local mainMenuCanvas = Instance.new("CanvasGroup")
	mainMenuCanvas.Name = "MainMenuCanvas"
	mainMenuCanvas.Parent = masterCanvas
	mainMenuCanvas.BackgroundTransparency = 1
	mainMenuCanvas.Size = UDim2.fromScale(1, 1)
	mainMenuCanvas.GroupTransparency = 1
	mainMenuCanvas.Visible = false

	local IMAGE_NORMAL = "rbxassetid://112264901260864"
	local IMAGE_HOVER = "rbxassetid://134483088355989"
	local chooseCharacterImageButton = Instance.new("ImageButton")
	chooseCharacterImageButton.Name = "ChooseCharacterImageButton"
	chooseCharacterImageButton.Parent = mainMenuCanvas
	chooseCharacterImageButton.Image = IMAGE_NORMAL
	chooseCharacterImageButton.BackgroundTransparency = 1
	chooseCharacterImageButton.AnchorPoint = Vector2.new(0.5, 0.5)
	chooseCharacterImageButton.Position = UDim2.new(0.5, 71, 0.78, 0)
	chooseCharacterImageButton.Size = UDim2.new(0, 285, 0, 127)

	local aspectRatio = Instance.new("UIAspectRatioConstraint", chooseCharacterImageButton)
	aspectRatio.AspectRatio = 285 / 127

	-- Character Select Canvas
	local characterSelectCanvas = Instance.new("CanvasGroup")
	characterSelectCanvas.Name = "CharacterSelectCanvas"
	characterSelectCanvas.Parent = masterCanvas
	characterSelectCanvas.BackgroundTransparency = 1
	characterSelectCanvas.Size = UDim2.fromScale(1, 1)
	characterSelectCanvas.GroupTransparency = 1
	characterSelectCanvas.Visible = false

	local slotUI = {}
	local SLOT_CONFIG = {
		[1] = { Pos = UDim2.fromScale(0.5, 0.5) },
		[2] = { Pos = UDim2.fromScale(0.16, 0.5) },
		[3] = { Pos = UDim2.fromScale(0.84, 0.5) }
	}
	for i = 1, 3 do
		local config = SLOT_CONFIG[i]
		slotUI[i] = {}

		local zone = Instance.new("Frame")
		zone.Parent = characterSelectCanvas
		zone.AnchorPoint = Vector2.new(0.5, 0.5)
		zone.Position = config.Pos
		zone.Size = UDim2.new(0, 333, 1.0, 0)
		zone.BackgroundTransparency = 1
		zone.Active = true
		slotUI[i].Zone = zone

		local btnContainer = Instance.new("Frame")
		btnContainer.Name = "ButtonContainer"
		btnContainer.Parent = zone
		btnContainer.BackgroundTransparency = 1
		btnContainer.AnchorPoint = Vector2.new(0.5, 1)
		btnContainer.Position = UDim2.new(0.5, 0, 1, 120)
		btnContainer.Size = UDim2.fromScale(1, 0.4)
		slotUI[i].ButtonContainer = btnContainer

		local listLayout = Instance.new("UIListLayout")
		listLayout.Parent = btnContainer
		listLayout.Padding = UDim.new(0, 10)
		listLayout.SortOrder = Enum.SortOrder.LayoutOrder
		listLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center

		local function createButton(name, text, color)
			local btn = Instance.new("TextButton")
			btn.Parent = btnContainer
			btn.Name = name
			btn.Size = UDim2.new(0.6, 0, 0, 40)
			btn.BackgroundColor3 = color
			btn.Font = Enum.Font.Arcade
			btn.Text = text
			btn.TextColor3 = Color3.new(1, 1, 1)
			btn.TextSize = 31
			return btn
		end

		slotUI[i].CreateButton = createButton("CreateButton", "Create", Color3.fromRGB(85, 170, 0))
		slotUI[i].DeleteButton = createButton("DeleteButton", "Delete", Color3.fromRGB(170, 0, 0))
		if i > 1 then
			slotUI[i].PurchaseButton = createButton("PurchaseButton", "Purchase", Color3.fromRGB(97, 97, 97))
			slotUI[i].PurchaseButton.LayoutOrder = -1
		end
	end

	-- Editor Canvas
	local editorCanvas = Instance.new("CanvasGroup")
	editorCanvas.Name = "EditorCanvas"
	editorCanvas.Parent = masterCanvas
	editorCanvas.BackgroundTransparency = 1
	editorCanvas.Size = UDim2.fromScale(1, 1)
	editorCanvas.Visible = false
	editorCanvas.GroupTransparency = 1

	local editorPanel = Instance.new("ImageLabel")
	editorPanel.Name = "EditorPanel"
	editorPanel.Parent = editorCanvas
	editorPanel.Image = "rbxassetid://103820441793744"
	editorPanel.Size = UDim2.new(0, 572, 0, 763)
	editorPanel.Position = UDim2.new(0, -572, 0.025, 0)
	editorPanel.BackgroundTransparency = 1

	local function createEditorLabel(name, text, pos, size)
		local label = Instance.new("TextLabel", editorPanel)
		label.Name = name
		label.Text = text
		label.Position = pos
		label.Size = size
		label.Font = Enum.Font.SourceSans
		label.TextColor3 = Color3.new(1, 1, 1)
		label.BackgroundTransparency = 1
		label.TextSize = 45
		label.TextWrapped = true
		return label
	end

	local function createArrowButton(name, pos, rotation)
		local btn = Instance.new("ImageButton", editorPanel)
		btn.Name = name
		btn.Position = pos
		btn.Rotation = rotation or 0
		btn.Image = "rbxassetid://93412782386309"
		btn.BackgroundColor3 = Color3.new(1, 1, 1)
		btn.Size = UDim2.new(0, 50, 0, 50)
		return btn
	end

	local function createChoiceText(name, text, pos)
		local label = Instance.new("TextLabel", editorPanel)
		label.Name = name
		label.Text = text
		label.Position = pos
		label.Size = UDim2.new(0, 200, 0, 50)
		label.Font = Enum.Font.Arcade
		label.TextSize = 32
		label.TextColor3 = Color3.fromRGB(0, 0, 0)
		label.BackgroundColor3 = Color3.new(1, 1, 1)
		return label
	end

	local backButton = Instance.new("TextButton", editorPanel)
	backButton.Name = "BackButton"
	backButton.Size = UDim2.new(0, 200, 0, 50)
	backButton.Position = UDim2.new(0.07, 0, 0.882, 0)
	backButton.BackgroundColor3 = Color3.fromRGB(170, 0, 0)
	backButton.Font = Enum.Font.Arcade
	backButton.Text = "Back"
	backButton.TextColor3 = Color3.new(1, 1, 1)
	backButton.TextSize = 31

	local doneButton = Instance.new("TextButton", editorPanel)
	doneButton.Name = "DoneButton"
	doneButton.Size = UDim2.new(0, 200, 0, 50)
	doneButton.Position = UDim2.new(0.573, 0, 0.882, 0)
	doneButton.BackgroundColor3 = Color3.fromRGB(85, 170, 0)
	doneButton.Font = Enum.Font.Arcade
	doneButton.Text = "Done"
	doneButton.TextColor3 = Color3.new(1, 1, 1)
	doneButton.TextSize = 31

	local genderLabel = createEditorLabel("GenderLabel", "Choose a gender", UDim2.new(0.053, 0, 0.061, 0), UDim2.new(0, 298, 0, 62))
	local hairLabel = createEditorLabel("HairLabel", "Choose a hairstyle", UDim2.new(0.051, 0, 0.383, 0), UDim2.new(0, 298, 0, 62))
	local genderLeftArrow = createArrowButton("GenderLeftArrow", UDim2.new(0.054, 0, 0.246, 0), 180)
	local genderRightArrow = createArrowButton("GenderRightArrow", UDim2.new(0.623, 0, 0.246, 0))
	local genderText = createChoiceText("GenderText", "Male", UDim2.new(0.201, 0, 0.245, 0))
	local hairLeftArrow = createArrowButton("HairLeftArrow", UDim2.new(0.052, 0, 0.558, 0), 180)
	local hairRightArrow = createArrowButton("HairRightArrow", UDim2.new(0.623, 0, 0.557, 0))
	local hairText = createChoiceText("HairText", "1/17", UDim2.new(0.201, 0, 0.557, 0))

	local rotationSliderBar = Instance.new("Frame", editorCanvas)
	rotationSliderBar.Name = "RotationSliderBar"
	rotationSliderBar.BackgroundColor3 = Color3.new(1, 1, 1)
	rotationSliderBar.Position = UDim2.new(0.502, 0, 0.891, 0)
	rotationSliderBar.Size = UDim2.new(0, 580, 0, 3)
	rotationSliderBar.AnchorPoint = Vector2.new(0, 0.5)

	local rotationSliderHandle = Instance.new("TextButton", rotationSliderBar)
	rotationSliderHandle.Name = "RotationSliderHandle"
	rotationSliderHandle.BackgroundColor3 = Color3.new(1, 1, 1)
	rotationSliderHandle.Size = UDim2.new(0, 32, 0, 32)
	rotationSliderHandle.Text = ""
	rotationSliderHandle.AnchorPoint = Vector2.new(0.5, 0.5)
	rotationSliderHandle.Position = UDim2.fromScale(0.5, 0.5)

	-- =======================================================
	-- UI ƒÀﬂ »√–€ (HUD)
	-- =======================================================
	local gameHudGui = Instance.new("ScreenGui")
	gameHudGui.Name = "GameHudUI"
	gameHudGui.Parent = playerGui
	gameHudGui.ResetOnSpawn = false
	gameHudGui.Enabled = false

	local inventoryCanvas = Instance.new("Frame")
	inventoryCanvas.Name = "InventoryCanvas"
	inventoryCanvas.Parent = gameHudGui
	inventoryCanvas.BackgroundTransparency = 1
	inventoryCanvas.Size = UDim2.fromScale(1, 1)
	inventoryCanvas.Visible = false

	local mainFrame = Instance.new("ImageLabel")
	mainFrame.Name = "MainFrame"
	mainFrame.Parent = inventoryCanvas
	mainFrame.BackgroundColor3 = Color3.fromRGB(25, 25, 25)
	mainFrame.BackgroundTransparency = 0.1
	mainFrame.BorderSizePixel = 0
	mainFrame.AnchorPoint = Vector2.new(0.5, 0.5)
	mainFrame.Position = UDim2.new(0.5, 0, 0.5, -65)
	mainFrame.Size = UDim2.new(0, 800, 0, 600)

	-- Œ—ÕŒ¬Õ¿ﬂ —≈“ ¿ »Õ¬≈Õ“¿–ﬂ (—ƒ¬»Õ”“¿ ¬À≈¬Œ)
	local GRID_WIDTH, GRID_HEIGHT = 8, 10
	local CELL_SIZE, PADDING = 48, 2
	local gridPixelWidth = (GRID_WIDTH * CELL_SIZE) + ((GRID_WIDTH - 1) * PADDING)
	local gridPixelHeight = (GRID_HEIGHT * CELL_SIZE) + ((GRID_HEIGHT - 1) * PADDING)

	local gridBackground = Instance.new("Frame")
	gridBackground.Name = "GridBackground"
	gridBackground.Parent = mainFrame
	gridBackground.BackgroundTransparency = 0.5
	gridBackground.BackgroundColor3 = Color3.fromRGB(10, 10, 10)
	gridBackground.Position = UDim2.new(0.03, 0, 0.5, 0) -- < —‰‚ËÌÛÚÓ ‚ÎÂ‚Ó (·˚ÎÓ 0.05)
	gridBackground.AnchorPoint = Vector2.new(0, 0.5)
	gridBackground.Size = UDim2.fromOffset(gridPixelWidth, gridPixelHeight)
	gridBackground.ZIndex = 1

	local gridLayout = Instance.new("UIGridLayout")
	gridLayout.Parent = gridBackground
	gridLayout.CellPadding = UDim2.fromOffset(PADDING, PADDING)
	gridLayout.CellSize = UDim2.fromOffset(CELL_SIZE, CELL_SIZE)

	for i = 1, GRID_WIDTH * GRID_HEIGHT do
		local cell = Instance.new("Frame")
		cell.Name = "Cell"
		cell.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
		cell.BackgroundTransparency = 0.95
		cell.BorderSizePixel = 0
		cell.Parent = gridBackground
	end

	local itemContainer = Instance.new("Frame")
	itemContainer.Name = "ItemContainer"
	itemContainer.Parent = mainFrame
	itemContainer.BackgroundTransparency = 1
	itemContainer.Position = gridBackground.Position
	itemContainer.AnchorPoint = gridBackground.AnchorPoint
	itemContainer.Size = gridBackground.Size
	itemContainer.ZIndex = 2

	-- œ–¿¬¿ﬂ œ¿Õ≈À‹ (› »œ»–Œ¬ ¿ » ƒ≈Õ‹√»)
	local equipmentFrame = Instance.new("Frame")
	equipmentFrame.Name = "EquipmentFrame"
	equipmentFrame.Parent = mainFrame
	equipmentFrame.BackgroundTransparency = 1
	equipmentFrame.Position = UDim2.new(0.72, 0, 0.5, 0) -- ◊ÛÚ¸ Ô‡‚ÂÂ
	equipmentFrame.AnchorPoint = Vector2.new(0, 0.5)
	equipmentFrame.Size = UDim2.new(0, 180, 0, 550)

	local equipmentLayout = Instance.new("UIListLayout")
	equipmentLayout.Parent = equipmentFrame
	equipmentLayout.Padding = UDim.new(0, 12)
	equipmentLayout.HorizontalAlignment = Enum.HorizontalAlignment.Left
	equipmentLayout.VerticalAlignment = Enum.VerticalAlignment.Top

	-- ‘ÛÌÍˆËˇ ÒÓÁ‰‡ÌËˇ ÒÎÓÚ‡ Ò ÔÓ‰ÔËÒ¸˛
	local function createEquipmentSlotWithLabel(name, labelText)
		local container = Instance.new("Frame")
		container.Name = name .. "Container"
		container.Parent = equipmentFrame
		container.BackgroundTransparency = 1
		container.Size = UDim2.new(1, 0, 0, 70)

		local slot = Instance.new("ImageLabel")
		slot.Name = name .. "Slot"
		slot.BackgroundColor3 = Color3.fromRGB(10, 10, 10)
		slot.BackgroundTransparency = 0.5
		slot.BorderSizePixel = 2
		slot.BorderColor3 = Color3.fromRGB(60, 60, 60)
		slot.Size = UDim2.fromOffset(70, 70)
		slot.Position = UDim2.fromOffset(0, 0)
		slot.Parent = container

		local label = Instance.new("TextLabel")
		label.Name = "Label"
		label.Parent = container
		label.BackgroundTransparency = 1
		label.Position = UDim2.fromOffset(78, 0)
		label.Size = UDim2.new(1, -78, 1, 0)
		label.Font = Enum.Font.SourceSansBold
		label.Text = labelText
		label.TextColor3 = Color3.fromRGB(200, 200, 200)
		label.TextSize = 16
		label.TextXAlignment = Enum.TextXAlignment.Left
		label.TextYAlignment = Enum.TextYAlignment.Center
		label.TextWrapped = true

		return slot
	end

	local equipmentSlots = {}

	-- 6 —ÀŒ“Œ¬ — œŒƒœ»—ﬂÃ»
	equipmentSlots["Accessory1"] = createEquipmentSlotWithLabel("Accessory1", "Accessory 1")
	equipmentSlots["Accessory2"] = createEquipmentSlotWithLabel("Accessory2", "Accessory 2")
	equipmentSlots["Accessory3"] = createEquipmentSlotWithLabel("Accessory3", "Accessory 3")
	equipmentSlots["Armor"] = createEquipmentSlotWithLabel("Armor", "Armor")
	equipmentSlots["Clothing"] = createEquipmentSlotWithLabel("Clothing", "Clothing")

	-- —ÀŒ“ ƒ≈Õ≈√ (ÌÂÏÌÓ„Ó ÌËÊÂ, Ò ÓÚÒÚÛÔÓÏ)
	local moneySpacer = Instance.new("Frame")
	moneySpacer.Name = "MoneySpacer"
	moneySpacer.Parent = equipmentFrame
	moneySpacer.BackgroundTransparency = 1
	moneySpacer.Size = UDim2.new(1, 0, 0, 5)

	local moneyContainer = Instance.new("Frame")
	moneyContainer.Name = "MoneyContainer"
	moneyContainer.Parent = equipmentFrame
	moneyContainer.BackgroundTransparency = 1
	moneyContainer.Size = UDim2.new(1, 0, 0, 70)

	local moneySlot = Instance.new("ImageLabel")
	moneySlot.Name = "MoneySlot"
	moneySlot.Parent = moneyContainer
	moneySlot.BackgroundColor3 = Color3.fromRGB(40, 30, 10)
	moneySlot.BackgroundTransparency = 0.3
	moneySlot.BorderSizePixel = 2
	moneySlot.BorderColor3 = Color3.fromRGB(120, 100, 40)
	moneySlot.Size = UDim2.fromOffset(70, 70)
	moneySlot.Position = UDim2.fromOffset(0, 0)

	local moneyLabel = Instance.new("TextLabel")
	moneyLabel.Name = "Label"
	moneyLabel.Parent = moneyContainer
	moneyLabel.BackgroundTransparency = 1
	moneyLabel.Position = UDim2.fromOffset(78, 0)
	moneyLabel.Size = UDim2.new(1, -78, 1, 0)
	moneyLabel.Font = Enum.Font.SourceSansBold
	moneyLabel.Text = "Money"
	moneyLabel.TextColor3 = Color3.fromRGB(255, 215, 100)
	moneyLabel.TextSize = 16
	moneyLabel.TextXAlignment = Enum.TextXAlignment.Left
	moneyLabel.TextYAlignment = Enum.TextYAlignment.Center

	-- ’Œ“¡¿– (ÙËÍÒËÓ‚‡ÌÌÓÂ ‡ÒÔÓÎÓÊÂÌËÂ ‚ÌËÁÛ ˝Í‡Ì‡)
	local hotbarSlots = {}

	-- ÀÂ‚‡ˇ ÛÍ‡
	local leftHandSlot = Instance.new("ImageLabel")
	leftHandSlot.Name = "LeftHandSlot"
	leftHandSlot.Parent = gameHudGui -- œË‚ˇÁ˚‚‡ÂÏ Í gameHudGui, ÌÂ Í inventoryCanvas
	leftHandSlot.BackgroundColor3 = Color3.fromRGB(25, 25, 25)
	leftHandSlot.BackgroundTransparency = 0.1
	leftHandSlot.BorderSizePixel = 2
	leftHandSlot.BorderColor3 = Color3.fromRGB(100, 100, 100)
	leftHandSlot.Size = UDim2.fromOffset(70, 70)
	leftHandSlot.Position = UDim2.new(0.443, 0, 0.874, 0)
	leftHandSlot.ZIndex = 50

	-- œ‡‚‡ˇ ÛÍ‡
	local rightHandSlot = Instance.new("ImageLabel")
	rightHandSlot.Name = "RightHandSlot"
	rightHandSlot.Parent = gameHudGui
	rightHandSlot.BackgroundColor3 = Color3.fromRGB(25, 25, 25)
	rightHandSlot.BackgroundTransparency = 0.1
	rightHandSlot.BorderSizePixel = 2
	rightHandSlot.BorderColor3 = Color3.fromRGB(100, 100, 100)
	rightHandSlot.Size = UDim2.fromOffset(70, 70)
	rightHandSlot.Position = UDim2.new(0.51, 0, 0.874, 0)
	rightHandSlot.ZIndex = 50

	-- ƒÓÔÓÎÌËÚÂÎ¸Ì˚Â ÒÎÓÚ˚ ‰Îˇ ÏËÌË-ÔÂ‰ÏÂÚÓ‚
	local miniSlot1 = Instance.new("ImageLabel")
	miniSlot1.Name = "MiniSlot1"
	miniSlot1.Parent = gameHudGui
	miniSlot1.BackgroundColor3 = Color3.fromRGB(20, 20, 20)
	miniSlot1.BackgroundTransparency = 0.3
	miniSlot1.BorderSizePixel = 1
	miniSlot1.BorderColor3 = Color3.fromRGB(80, 80, 80)
	miniSlot1.Size = UDim2.fromOffset(50, 50)
	miniSlot1.Position = UDim2.new(0.395, 0, 0.874, 0)
	miniSlot1.ZIndex = 50
	miniSlot1.Visible = false

	local miniSlot2 = Instance.new("ImageLabel")
	miniSlot2.Name = "MiniSlot2"
	miniSlot2.Parent = gameHudGui
	miniSlot2.BackgroundColor3 = Color3.fromRGB(20, 20, 20)
	miniSlot2.BackgroundTransparency = 0.3
	miniSlot2.BorderSizePixel = 1
	miniSlot2.BorderColor3 = Color3.fromRGB(80, 80, 80)
	miniSlot2.Size = UDim2.fromOffset(50, 50)
	miniSlot2.Position = UDim2.new(0.575, 0, 0.874, 0)
	miniSlot2.ZIndex = 50
	miniSlot2.Visible = false

	-- ÃÂÚÍË ‰Îˇ Ë‰ÂÌÚËÙËÍ‡ˆËË
	local function addSlotLabel(slot, text)
		local label = Instance.new("TextLabel")
		label.Name = "SlotLabel"
		label.Parent = slot
		label.Size = UDim2.new(1, 0, 0.25, 0)
		label.Position = UDim2.new(0, 0, 0, 0)
		label.BackgroundTransparency = 0.8
		label.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
		label.Text = text
		label.TextColor3 = Color3.fromRGB(200, 200, 200)
		label.TextScaled = true
		label.Font = Enum.Font.SourceSans
		label.ZIndex = slot.ZIndex + 1
	end

	addSlotLabel(leftHandSlot, "L")
	addSlotLabel(rightHandSlot, "R")
	addSlotLabel(miniSlot1, "1")
	addSlotLabel(miniSlot2, "2")

	hotbarSlots.LeftHand = leftHandSlot
	hotbarSlots.RightHand = rightHandSlot
	hotbarSlots.Mini1 = miniSlot1
	hotbarSlots.Mini2 = miniSlot2

	-- ”·Ë‡ÂÏ ÚÂÒÚÓ‚˚Â ÍÌÓÔÍË
	
	-- ==================  ŒÕ“≈ —“ÕŒ≈ Ã≈Õﬁ ==================
	local contextMenu = Instance.new("Frame")
	contextMenu.Name = "ContextMenu"
	contextMenu.Parent = gameHudGui
	contextMenu.BackgroundTransparency = 0.1
	contextMenu.BackgroundColor3 = Color3.fromRGB(15, 15, 15)
	contextMenu.BorderSizePixel = 0
	contextMenu.Size = UDim2.fromOffset(150, 100) -- –‡ÁÏÂ ·Û‰ÂÚ ÏÂÌˇÚ¸Òˇ
	contextMenu.Visible = false
	contextMenu.ZIndex = 200 -- œÓ‚Âı ‚ÒÂ„Ó

	local listLayout = Instance.new("UIListLayout", contextMenu)
	listLayout.FillDirection = Enum.FillDirection.Vertical
	listLayout.SortOrder = Enum.SortOrder.LayoutOrder
	listLayout.Padding = UDim.new(0, 2)

	local corner = Instance.new("UICorner", contextMenu)
	corner.CornerRadius = UDim.new(0, 4)

	local padding = Instance.new("UIPadding", contextMenu)
	padding.PaddingTop = UDim.new(0, 4)
	padding.PaddingBottom = UDim.new(0, 4)
	padding.PaddingLeft = UDim.new(0, 4)
	padding.PaddingRight = UDim.new(0, 4)
	
	function UIManager.CreateNotificationUI(parent)
		local container = Instance.new("Frame")
		container.Name = "NotificationContainer"
		container.Parent = parent
		container.BackgroundTransparency = 1

		-- === »«Ã≈Õ≈Õ»≈ π1: ”ÏÂÌ¸¯‡ÂÏ ¯ËËÌÛ ‚ ‰‚‡ ‡Á‡ ===
		container.Size = UDim2.new(0.125, 0, 0.4, 0) -- ¡˚ÎÓ 0.25

		container.AnchorPoint = Vector2.new(1, 1) 
		container.Position = UDim2.new(1, -20, 1, -20)

		local listLayout = Instance.new("UIListLayout", container)
		listLayout.SortOrder = Enum.SortOrder.LayoutOrder
		listLayout.Padding = UDim.new(0, 5)

		-- === »«Ã≈Õ≈Õ»≈ π2: ÷ÂÌÚËÛÂÏ ‚ÒÂ Û‚Â‰ÓÏÎÂÌËˇ ===
		listLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center -- ¡˚ÎÓ Right

		listLayout.VerticalAlignment = Enum.VerticalAlignment.Bottom

		-- ÿ‡·ÎÓÌ ‰Îˇ Ó‰ÌÓ„Ó Û‚Â‰ÓÏÎÂÌËˇ
		local template = Instance.new("Frame")
		template.Name = "NotificationTemplate"
		template.BackgroundColor3 = Color3.fromRGB(40, 40, 40)
		template.BackgroundTransparency = 0.1
		template.Size = UDim2.new(1, 0, 0, 50)
		template.Visible = false
		template.Parent = container

		local corner = Instance.new("UICorner", template); corner.CornerRadius = UDim.new(0, 4)
		local padding = Instance.new("UIPadding", template); padding.PaddingLeft = UDim.new(0, 8); padding.PaddingRight = UDim.new(0, 8)

		local textLabel = Instance.new("TextLabel", template)
		textLabel.Name = "Message"
		textLabel.Size = UDim2.new(1, 0, 1, -5)
		textLabel.BackgroundTransparency = 1
		textLabel.Font = Enum.Font.SourceSans
		textLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
		textLabel.TextSize = 16
		textLabel.TextWrapped = true

		-- === »«Ã≈Õ≈Õ»≈ π3: ÷ÂÌÚËÛÂÏ Ò‡Ï ÚÂÍÒÚ ===
		textLabel.TextXAlignment = Enum.TextXAlignment.Center -- ¡˚ÎÓ Right

		local timerBar = Instance.new("Frame", template)
		timerBar.Name = "TimerBar"
		timerBar.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
		timerBar.BorderSizePixel = 0
		timerBar.Size = UDim2.new(1, 0, 0, 3)
		timerBar.Position = UDim2.new(0, 0, 1, -3)

		return container, template
	end
	
	function UIManager.CreateSplitStackPrompt(parent)
		local prompt = Instance.new("Frame")
		prompt.Name = "SplitStackPrompt"
		prompt.BackgroundColor3 = Color3.fromRGB(35, 35, 35)
		prompt.BorderSizePixel = 0
		prompt.Size = UDim2.fromOffset(150, 70)
		prompt.Visible = false
		prompt.ZIndex = 201

		local corner = Instance.new("UICorner", prompt)
		corner.CornerRadius = UDim.new(0, 4)

		local padding = Instance.new("UIPadding", prompt)
		padding.PaddingLeft = UDim.new(0, 8)
		padding.PaddingRight = UDim.new(0, 8)
		padding.PaddingTop = UDim.new(0, 8)
		padding.PaddingBottom = UDim.new(0, 8)

		local listLayout = Instance.new("UIListLayout", prompt)
		listLayout.Padding = UDim.new(0, 5)
		listLayout.SortOrder = Enum.SortOrder.LayoutOrder
		listLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center

		local textBox = Instance.new("TextBox")
		textBox.Name = "AmountInput"
		textBox.ZIndex = prompt.ZIndex + 1
		textBox.Parent = prompt
		textBox.Changed:Connect(function(property)
			if property == "Text" then
				-- «‡ÏÂÌˇÂÏ ‚ÒÂ Õ≈-ˆËÙ˚ Ì‡ ÔÛÒÚÛ˛ ÒÚÓÍÛ
				local sanitizedText = string.gsub(textBox.Text, "%D", "")
				if textBox.Text ~= sanitizedText then
					textBox.Text = sanitizedText
				end
			end
		end)
		textBox.LayoutOrder = 1
		textBox.BackgroundColor3 = Color3.fromRGB(15, 15, 15)
		textBox.BorderSizePixel = 0
		textBox.Size = UDim2.new(1, 0, 0, 25)
		textBox.Font = Enum.Font.SourceSans
		textBox.PlaceholderText = "Amount..."
		textBox.TextColor3 = Color3.fromRGB(255, 255, 255)
		textBox.TextSize = 14
		textBox.ClearTextOnFocus = false
		textBox.TextXAlignment = Enum.TextXAlignment.Center

		local okButton = Instance.new("TextButton")
		okButton.Name = "OkButton"
		okButton.ZIndex = prompt.ZIndex + 1
		okButton.Parent = prompt
		okButton.LayoutOrder = 2
		okButton.BackgroundColor3 = Color3.fromRGB(85, 170, 0)
		okButton.BorderSizePixel = 0
		okButton.Size = UDim2.new(1, 0, 0, 20)
		okButton.Font = Enum.Font.SourceSansBold
		okButton.Text = "Split"
		okButton.TextColor3 = Color3.fromRGB(255, 255, 255)
		okButton.TextSize = 14

		prompt.Parent = parent
		return {
			Prompt = prompt,
			Input = textBox,
			Button = okButton
		}
	end
	
	local notificationContainer, notificationTemplate = UIManager.CreateNotificationUI(gameHudGui)


	-- ================== ¬Œ«¬–¿Ÿ¿≈Ã¿ﬂ “¿¡À»÷¿ ==================
	return {
		Menu = {
			menuScreenGui = menuScreenGui,
			fadeFrame = fadeFrame,
			masterCanvas = masterCanvas,
			loadingCanvas = loadingCanvas,
			loadingFill = loadingFill,
			skipButton = skipButton,
			limiterLeft = limiterLeft,
			limiterRight = limiterRight,
			loadingBarContainer = loadingBarContainer,
			mainMenuCanvas = mainMenuCanvas,
			chooseCharacterImageButton = chooseCharacterImageButton,
			characterSelectCanvas = characterSelectCanvas,
			slotUI = slotUI,
			editorCanvas = editorCanvas,
			editorPanel = editorPanel,
			backButton = backButton,
			doneButton = doneButton,
			genderLabel = genderLabel,
			hairLabel = hairLabel,
			genderLeftArrow = genderLeftArrow,
			genderRightArrow = genderRightArrow,
			genderText = genderText,
			hairLeftArrow = hairLeftArrow,
			hairRightArrow = hairRightArrow,
			hairText = hairText,
			rotationSliderBar = rotationSliderBar,
			rotationSliderHandle = rotationSliderHandle,
			IMAGE_NORMAL = IMAGE_NORMAL,
			IMAGE_HOVER = IMAGE_HOVER
		},
		Game = {
			gameHudGui = gameHudGui,
			InventoryCanvas = inventoryCanvas,
			ItemContainer = itemContainer,
			EquipmentSlots = equipmentSlots,
			MoneySlot = moneySlot,
			HotbarFrame = hotbarFrame,
			HotbarSlots = hotbarSlots,
			ContextMenu = contextMenu,
			SplitStackPrompt = UIManager.CreateSplitStackPrompt(gameHudGui),
			-- ¿ ÚÂÔÂ¸ Ô‡‚ËÎ¸ÌÓ ‰Ó·‡‚ÎˇÂÏ Ëı ‚ Ú‡·ÎËˆÛ
			NotificationContainer = notificationContainer,
			NotificationTemplate = notificationTemplate
		}
	}
end

return UIManager