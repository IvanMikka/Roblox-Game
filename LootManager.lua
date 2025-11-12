-- LootManager (Script в ServerScriptService)
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local DataManager = require(script.Parent:WaitForChild("DataManager"))
local ItemsConfig = require(ReplicatedStorage:WaitForChild("ItemsConfig"))
local ShowNotificationEvent = ReplicatedStorage.Events:WaitForChild("ShowNotificationEvent")
local HttpService = game:GetService("HttpService")
local PhysicsService = game:GetService("PhysicsService")

local LOOT_GROUP = "Loot"
local lootContainer = workspace:FindFirstChild("Lootables") or workspace:FindFirstChild("LootContainer")
if not lootContainer then
	lootContainer = Instance.new("Folder")
	lootContainer.Name = "LootContainer"
	lootContainer.Parent = workspace
end

----------------------------------------------------------------
-- DEBUG
----------------------------------------------------------------
local DEBUG_MODE = false

local function debugPrint(...)
	if DEBUG_MODE then
		print("[LootManager]", ...)
	end
end

----------------------------------------------------------------
-- АНТИ-ДЮП: ЛОКИ НА МЕШКИ
----------------------------------------------------------------
local activeLootLocks = {} -- [lootBag] = true пока идёт обработка

----------------------------------------------------------------
-- СЕРВЕРНОЕ ОТКЛЮЧЕНИЕ СТАНДАРТНОГО ПРОМПТА
----------------------------------------------------------------
local function updatePromptTextFromLootBag(lootBag)
	local basePart = lootBag:FindFirstChild("BasePart", true)
	if not basePart then return end

	local prompt = basePart:FindFirstChildOfClass("ProximityPrompt")
	if not prompt then return end

	-- Полностью отключаем стандартный пузырь – рисуем свой BillboardGui на клиенте
	prompt.Style = Enum.ProximityPromptStyle.Custom
	prompt.ActionText = ""
	prompt.ObjectText = ""
end

----------------------------------------------------------------
-- ОБРАБОТКА ПОДБОРА ЛУТА
----------------------------------------------------------------
local function setLootCollisionGroupForModel(model: Model)
	for _, d in ipairs(model:GetDescendants()) do
		if d:IsA("BasePart") then
			-- СНИМАЕМ ЯКОРЬ и даём физике работать
			d.Anchored = false
			d.Massless = false
			d.CanCollide = true
			d.CanQuery  = true
			d.CanTouch  = true

			-- Коллиз. группа
			PhysicsService:SetPartCollisionGroup(d, LOOT_GROUP)
		end
	end
	-- Новые детали внутри модели — тоже разанкорим/пометим
	model.DescendantAdded:Connect(function(d)
		if d:IsA("BasePart") then
			d.Anchored = false
			d.Massless = false
			d.CanCollide = true
			d.CanQuery  = true
			d.CanTouch  = true
			PhysicsService:SetPartCollisionGroup(d, LOOT_GROUP)
		end
	end)

	-- Сервер владеет физикой: падение будет стабильным
	if model.PrimaryPart then
		model.PrimaryPart:SetNetworkOwner(nil)
	end
end


local function onLootTriggered(player, lootBag)
	if not player or not lootBag or not lootBag.Parent then return end

	-- ?? Анти-дюп: если уже обрабатываем этот мешок – игнорим повторные триггеры
	if activeLootLocks[lootBag] then
		debugPrint("Duplicate trigger ignored for", lootBag.Name)
		return
	end
	activeLootLocks[lootBag] = true

	local basePart = lootBag:FindFirstChild("BasePart", true)
	local prompt = basePart and basePart:FindFirstChildOfClass("ProximityPrompt")
	if prompt then
		prompt.Enabled = false -- на время обработки E не работает
	end

	local itemID = lootBag:GetAttribute("ItemID")
	local amount = lootBag:GetAttribute("Amount")

	if not itemID or not amount or amount <= 0 then
		debugPrint("Invalid loot attributes for", lootBag.Name, itemID, amount)
		activeLootLocks[lootBag] = nil
		if prompt then prompt.Enabled = true end
		return
	end

	local cfg = ItemsConfig[itemID]
	local itemName = cfg and cfg.Name or itemID

	-- Доп. данные для рюкзака
	local extraData = nil
	local backpackJson = lootBag:GetAttribute("BackpackData")
	if backpackJson then
		local ok, decoded = pcall(HttpService.JSONDecode, HttpService, backpackJson)
		if ok and type(decoded) == "table" then
			extraData = { BackpackInventory = decoded }
		else
			warn("[LootManager] Failed to decode BackpackData for loot:", lootBag.Name, backpackJson)
		end
	end

	-- Пытаемся добавить в инвентарь
	local amountPickedUp = DataManager.AttemptToPickupItem(player, itemID, amount, extraData)

	-- Ничего не подобрали (инвентарь полон и т.п.)
	if not amountPickedUp or amountPickedUp <= 0 then
		ShowNotificationEvent:FireClient(player, "Инвентарь переполнен.")
		debugPrint("Pickup failed for", itemName)

		activeLootLocks[lootBag] = nil
		if prompt then prompt.Enabled = true end
		return
	end

	local newAmount = amount - amountPickedUp

	-- Всё забрали – уничтожаем мешок
	if newAmount <= 0 then
		debugPrint("Picked full stack", itemName, "x", amountPickedUp)
		ShowNotificationEvent:FireClient(player, string.format("Picked up %s (x%d)", itemName, amountPickedUp))

		lootBag:Destroy()
		activeLootLocks[lootBag] = nil
		-- prompt умирает вместе с моделью
		return
	end

	-- Частичный подбор – обновляем количество и снова разрешаем E
	lootBag:SetAttribute("Amount", newAmount)
	debugPrint("Partial pickup", itemName, "picked", amountPickedUp, "left", newAmount)
	ShowNotificationEvent:FireClient(player, string.format("Added %s (x%d) to your inventory.", itemName, amountPickedUp))

	activeLootLocks[lootBag] = nil
	if prompt then
		prompt.Enabled = true
	end
	updatePromptTextFromLootBag(lootBag) -- просто гарантируем Style = Custom
end

----------------------------------------------------------------
-- ИНИЦИАЛИЗАЦИЯ МЕШКА
----------------------------------------------------------------
local function setupNewLootBag(lootBag)
	if not lootBag:IsA("Model") then return end
	
	setLootCollisionGroupForModel(lootBag)

	local basePart = lootBag:FindFirstChild("BasePart", true)
	if not basePart then
		debugPrint("No BasePart in loot model", lootBag.Name)
		return
	end

	local prompt = basePart:FindFirstChildOfClass("ProximityPrompt")
	if not prompt then
		debugPrint("No ProximityPrompt in loot model", lootBag.Name)
		return
	end

	-- Отключаем стандартный пузырь
	prompt.Style = Enum.ProximityPromptStyle.Custom
	prompt.ActionText = ""
	prompt.ObjectText = ""

	-- Чтобы не вешать обработчик дважды
	if prompt:GetAttribute("LootConnected") then
		return
	end
	prompt:SetAttribute("LootConnected", true)

	prompt.Triggered:Connect(function(p)
		onLootTriggered(p, lootBag)
	end)
	
	debugPrint("Setup loot bag", lootBag.Name)
end

----------------------------------------------------------------
-- СТАРТОВАЯ ИНИЦИАЛИЗАЦИЯ
----------------------------------------------------------------
for _, child in ipairs(lootContainer:GetChildren()) do
	setupNewLootBag(child)
end

lootContainer.ChildAdded:Connect(function(child)
	setupNewLootBag(child)
end)

print("[LootManager] ? Initialized | Debug mode:", DEBUG_MODE and "ON" or "OFF")
