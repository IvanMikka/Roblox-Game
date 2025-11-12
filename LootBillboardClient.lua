-- LootBillboardClient.lua (LocalScript в StarterPlayerScripts)

local Players = game:GetService("Players")
local ProximityPromptService = game:GetService("ProximityPromptService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local HttpService = game:GetService("HttpService")

local player = Players.LocalPlayer
local ItemsConfig = require(ReplicatedStorage:WaitForChild("ItemsConfig"))

-- Получаем модель лута и BasePart по промпту
local function getLootBagFromPrompt(prompt: ProximityPrompt)
	local model = prompt:FindFirstAncestorOfClass("Model")
	if not model then return nil, nil end

	local lootContainer = workspace:FindFirstChild("LootContainer")
	if not lootContainer or not model:IsDescendantOf(lootContainer) then
		return nil, nil
	end

	local basePart = model:FindFirstChild("BasePart", true)
	if not basePart then return nil, nil end

	return model, basePart
end

-- Строим текст с названием и содержимым рюкзака
local function buildLootText(lootBag: Model)
	local itemID = lootBag:GetAttribute("ItemID")
	local amount = lootBag:GetAttribute("Amount") or 1
	if not itemID then return nil end

	local cfg = ItemsConfig[itemID]
	local itemName = (cfg and cfg.Name) or itemID

	local lines = {}
	table.insert(lines, string.format("%s (x%d)", itemName, amount))

	local backpackJson = lootBag:GetAttribute("BackpackData")
	if backpackJson then
		local ok, decoded = pcall(HttpService.JSONDecode, HttpService, backpackJson)
		if ok and type(decoded) == "table" then
			local items = decoded.Items or decoded.items or decoded
			if items and #items > 0 then
				table.insert(lines, "")
				table.insert(lines, "Содержимое:")

				local maxLines = 5
				local count = 0
				for _, it in ipairs(items) do
					local icfg = ItemsConfig[it.ItemID]
					local name = (icfg and icfg.Name) or it.ItemID
					local amt = it.Amount or 1
					table.insert(lines, string.format("• %s x%d", name, amt))
					count += 1
					if count >= maxLines then
						if #items > maxLines then
							table.insert(lines, "...")
						end
						break
					end
				end
			else
				table.insert(lines, "")
				table.insert(lines, "Пустой рюкзак")
			end
		end
	end

	return table.concat(lines, "\n")
end

-- Создаём / находим BillboardGui над мешком
local function getOrCreateBillboard(basePart: BasePart)
	local billboard = basePart:FindFirstChild("LootBillboard") :: BillboardGui?
	if billboard then
		return billboard,
		billboard:FindFirstChild("Frame") and billboard.Frame:FindFirstChild("InfoLabel")
	end

	billboard = Instance.new("BillboardGui")
	billboard.Name = "LootBillboard"
	billboard.Adornee = basePart
	billboard.AlwaysOnTop = true
	billboard.Size = UDim2.new(0, 260, 0, 90) -- компактный прямоугольник
	billboard.StudsOffset = Vector3.new(0, 3, 0) -- висит над мешком
	billboard.Enabled = false
	billboard.Parent = basePart

	local frame = Instance.new("Frame")
	frame.Name = "Frame"
	frame.Size = UDim2.new(1, 0, 1, 0)
	frame.BackgroundColor3 = Color3.fromRGB(10, 10, 10)
	frame.BackgroundTransparency = 0.25
	frame.BorderSizePixel = 0
	frame.Parent = billboard

	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 8)
	corner.Parent = frame

	local stroke = Instance.new("UIStroke")
	stroke.Thickness = 1
	stroke.Color = Color3.fromRGB(255, 255, 255)
	stroke.Transparency = 0.4
	stroke.Parent = frame

	-- Левая часть: белая E и слово LOOT
	local keyLabel = Instance.new("TextLabel")
	keyLabel.Name = "KeyLabel"
	keyLabel.Parent = frame
	keyLabel.Size = UDim2.new(0, 40, 0, 40)
	keyLabel.Position = UDim2.new(0, 8, 0, 8)
	keyLabel.BackgroundTransparency = 1
	keyLabel.Font = Enum.Font.GothamBold
	keyLabel.Text = "E"
	keyLabel.TextSize = 32
	keyLabel.TextColor3 = Color3.new(1, 1, 1)
	keyLabel.TextStrokeTransparency = 0.1
	keyLabel.TextStrokeColor3 = Color3.new(0, 0, 0)

	local actionLabel = Instance.new("TextLabel")
	actionLabel.Name = "ActionLabel"
	actionLabel.Parent = frame
	actionLabel.Size = UDim2.new(0, 40, 0, 20)
	actionLabel.Position = UDim2.new(0, 8, 0, 48)
	actionLabel.BackgroundTransparency = 1
	actionLabel.Font = Enum.Font.Gotham
	actionLabel.Text = "LOOT"
	actionLabel.TextSize = 14
	actionLabel.TextColor3 = Color3.fromRGB(220, 220, 220)
	actionLabel.TextStrokeTransparency = 0.5

	-- Правая часть: текст
	local info = Instance.new("TextLabel")
	info.Name = "InfoLabel"
	info.Parent = frame
	info.Size = UDim2.new(1, -60, 1, -16)
	info.Position = UDim2.new(0, 56, 0, 8)
	info.BackgroundTransparency = 1
	info.Font = Enum.Font.Gotham
	info.TextSize = 14
	info.TextColor3 = Color3.fromRGB(235, 235, 235)
	info.TextXAlignment = Enum.TextXAlignment.Left
	info.TextYAlignment = Enum.TextYAlignment.Top
	info.TextWrapped = true
	info.Text = ""

	return billboard, info
end

local currentPrompt: ProximityPrompt? = nil

local function showForPrompt(prompt: ProximityPrompt)
	local lootBag, basePart = getLootBagFromPrompt(prompt)
	if not lootBag or not basePart then
		return
	end

	local billboard, infoLabel = getOrCreateBillboard(basePart)
	if not billboard or not infoLabel then return end

	local text = buildLootText(lootBag)
	if not text then return end

	infoLabel.Text = text
	billboard.Enabled = true

	currentPrompt = prompt
end

local function hideForPrompt(prompt: ProximityPrompt)
	if currentPrompt ~= prompt then return end
	local lootBag, basePart = getLootBagFromPrompt(prompt)
	if not lootBag or not basePart then
		currentPrompt = nil
		return
	end

	local billboard = basePart:FindFirstChild("LootBillboard") :: BillboardGui?
	if billboard then
		billboard.Enabled = false
	end

	currentPrompt = nil
end

-- Подписка на события промптов
ProximityPromptService.PromptShown:Connect(function(prompt, inputType)
	showForPrompt(prompt)
end)

ProximityPromptService.PromptHidden:Connect(function(prompt)
	hideForPrompt(prompt)
end)

ProximityPromptService.PromptTriggered:Connect(function(prompt)
	hideForPrompt(prompt)
end)
