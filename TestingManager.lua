-- TestingManager (Script в ServerScriptService) - v3.0
-- Централизованное управление всеми тестовыми функциями
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local DataManager = require(ServerScriptService:WaitForChild("DataManager"))
local ItemsConfig = require(ReplicatedStorage:WaitForChild("ItemsConfig"))

local TestingManager = {}

-- =================================================================
-- КОНФИГУРАЦИЯ ТЕСТОВ
-- =================================================================
local TEST_CONFIG = {
	-- Включить/выключить выдачу стартовых предметов
	GiveStarterItems = false,

	-- Стартовые предметы для новых игроков
	StarterItems = {
		-- { ItemID = "Money", Amount = 256 },
		-- { ItemID = "Sword", Amount = 1 },
		-- { ItemID = "Armor", Amount = 1 },
	},

	-- Включить/выключить спавн тестового лута
	SpawnTestLoot = true,

	-- Тестовые мешки с лутом
	TestLootBags = {
		{
			ItemID = "Money",
			Amount = 200,
			Position = Vector3.new(68, 0.5, -41)
		},
		{
		    ItemID = "Sword",
		    Amount = 1,
		    Position = Vector3.new(70, 0.5, -41)
		},
		{
			ItemID = "Armor",
			Amount = 1,
			Position = Vector3.new(72, 0.5, -41)
		},
		{
			ItemID = "Rifle",
			Amount = 1,
			Position = Vector3.new(74, 0.5, -41)
		},
		{
			ItemID = "Ammo",
			Amount = 40,
			Position = Vector3.new(76, 0.5, -41)
		},
		{
			ItemID = "CylinderHat",
			Amount = 1,
			Position = Vector3.new(78, 0.5, -41)
		},
		{
			ItemID = "Scarf",
			Amount = 1,
			Position = Vector3.new(80, 0.5, -41)
		},
		{
			ItemID = "Shield",
			Amount = 1,
			Position = Vector3.new(82, 0.5, -41)
		},
		{
			ItemID = "Pistol",
			Amount = 1,
			Position = Vector3.new(84, 0.5, -41)
		},
		{
			ItemID = "TravelSack",
			Amount = 1,
			Position = Vector3.new(86, 0.5, -41)
		},
		{
			ItemID = "SquireBackpack",
			Amount = 1,
			Position = Vector3.new(88, 0.5, -41)
		},
		{
			ItemID = "CombatPouchSystem",
			Amount = 1,
			Position = Vector3.new(90, 0.5, -41)
		},
		-- Можно добавить больше мешков:
		-- {
		--     ItemID = "Sword",
		--     Amount = 1,
		--     Position = Vector3.new(70, 0.5, -41)
		-- }
	}
}

-- =================================================================
-- ВЫДАЧА СТАРТОВЫХ ПРЕДМЕТОВ
-- =================================================================
local playersInitialized = {}

local function giveStarterItems(player)
	if not TEST_CONFIG.GiveStarterItems then return end
	if playersInitialized[player.UserId] then return end

	playersInitialized[player.UserId] = true
	task.wait(1) -- Ждем загрузки данных

	print("[TestingManager] Выдача стартовых предметов для " .. player.Name)

	for _, itemData in ipairs(TEST_CONFIG.StarterItems) do
		DataManager.AddItem(player, itemData.ItemID, itemData.Amount or 1)
		print("[TestingManager] Выдан предмет:", itemData.ItemID, "x" .. (itemData.Amount or 1))
	end
end

-- =================================================================
-- СОЗДАНИЕ ТЕСТОВОГО ЛУТА
-- =================================================================
local function spawnTestLoot()
	if not TEST_CONFIG.SpawnTestLoot then return end

	task.wait(1) -- Даем серверу секунду на загрузку

	print("[TestingManager] Создание тестовых мешков с лутом...")

	local lootContainer = workspace:FindFirstChild("LootContainer") or Instance.new("Folder", workspace)
	lootContainer.Name = "LootContainer"

	local modelToClone = ReplicatedStorage.Lootables:FindFirstChild("DefaultLootBag")
	if not modelToClone then
		warn("[TestingManager] Не найдена модель DefaultLootBag в ReplicatedStorage.Lootables!")
		return
	end

	for i, lootData in ipairs(TEST_CONFIG.TestLootBags) do
		local itemModel = modelToClone:Clone()
		itemModel:SetPrimaryPartCFrame(CFrame.new(lootData.Position))
		itemModel.Name = "TestLootBag_" .. i
		itemModel.Parent = lootContainer

		-- Назначаем Collision Group
		for _, part in ipairs(itemModel:GetDescendants()) do
			if part:IsA("BasePart") then
				part.CollisionGroup = "Loot"
			end
		end

		-- Сохраняем данные предмета
		itemModel:SetAttribute("ItemID", lootData.ItemID)
		itemModel:SetAttribute("Amount", lootData.Amount)

		-- Обновляем ProximityPrompt
		local prompt = itemModel:FindFirstChild("BasePart", true)
		if prompt then
			prompt = prompt:FindFirstChildOfClass("ProximityPrompt")
			if prompt then
				local itemName = ItemsConfig[lootData.ItemID].Name or lootData.ItemID
				prompt.ObjectText = string.format("%s (%d)", itemName, lootData.Amount)
			end
		end

		print("[TestingManager] Создан тестовый мешок:", lootData.ItemID, "x" .. lootData.Amount, "at", lootData.Position)
	end

	print("[TestingManager] ? Все тестовые мешки созданы")
end

-- =================================================================
-- ИНИЦИАЛИЗАЦИЯ
-- =================================================================
function TestingManager.Init()
	-- Инициализация стартовых предметов
	Players.PlayerAdded:Connect(function(player)
		if player.Character then
			giveStarterItems(player)
		end
		player.CharacterAdded:Connect(function()
			giveStarterItems(player)
		end)
	end)

	-- Спавн тестового лута
	spawnTestLoot()

	print("[TestingManager] ? Testing Manager initialized")
	print("[TestingManager] Starter Items:", TEST_CONFIG.GiveStarterItems and "ENABLED" or "DISABLED")
	print("[TestingManager] Test Loot:", TEST_CONFIG.SpawnTestLoot and "ENABLED" or "DISABLED")
end

-- Автоматический запуск
TestingManager.Init()

return TestingManager