-- PlayerConnectionManager (Script в ServerScriptService) - v6.0 (С Collision управлением)
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local MenuManager = require(ServerScriptService:WaitForChild("MenuManagerModule"))
local HitboxManager = require(ServerScriptService:WaitForChild("HitboxManagerModule"))
local DataManager = require(ServerScriptService:WaitForChild("DataManager"))

local Events = ReplicatedStorage:WaitForChild("Events")
local MoveItemEvent = Events:WaitForChild("MoveItemEvent")
local PlayerActionsEvent = Events:WaitForChild("PlayerActionsEvent")
local CharacterReadyEvent = Events:WaitForChild("CharacterReadyEvent")
local LoadPlayerMenuDataEvent = Events:WaitForChild("LoadPlayerMenuData") 
local LoadInventoryDataEvent = Events:WaitForChild("LoadInventoryDataEvent")

local menuSpawn = workspace:WaitForChild("MenuScene"):WaitForChild("MenuSpawn")
local gameSpawn = workspace:WaitForChild("GameSpawn")
local MenuMannequins = workspace:WaitForChild("Menu"):WaitForChild("MenuMannequins")

-- =================================================================
-- НОВАЯ ФУНКЦИЯ: Установка Collision Group для персонажа
-- =================================================================
local function setCollisionGroup(character)
	for _, descendant in ipairs(character:GetDescendants()) do
		if descendant:IsA("BasePart") then
			descendant.CollisionGroup = "Characters"
		end
	end
end

local function setupCharacterAppearance(character)
	local player = Players:GetPlayerFromCharacter(character)
	if not player then return end

	local playerData = DataManager.GetData(player)
	if not playerData then return end

	-- ? УСТАНОВКА COLLISION GROUP
	setCollisionGroup(character)

	if player:GetAttribute("InMenu") then
		print("[PCM] Загрузка персонажа в МЕНЮ для " .. player.Name)
		MenuManager.ProcessCharacter(character, nil)
	else
		print("[PCM] Загрузка персонажа в ИГРУ для " .. player.Name)

		-- ? БЕРЁМ ПЕРСОНАЖА ИЗ СЕССИОННЫХ ДАННЫХ
		local currentSlot = playerData.CurrentCharacterSlot
		local characterData

		if currentSlot and playerData.Characters and playerData.Characters[currentSlot] then
			characterData = playerData.Characters[currentSlot]
		else
			-- запасной вариант, если по какой-то причине нет данных
			characterData = MenuManager.GetCharacterToLoad(player.UserId)
		end

		MenuManager.ProcessCharacter(character, characterData)

		-- Отправляем данные инвентаря, экипировки и хотбара клиенту
		LoadInventoryDataEvent:FireClient(player, {
			Inventory = playerData.Inventory,
			Equipment = playerData.Equipment,
			MoneySlot = playerData.MoneySlot,  -- ? ДОБАВЛЕНО
			Hotbar = playerData.Hotbar
		})

		-- Инициализируем атрибуты хотбара для персонажа
		local leftItemID = playerData.Hotbar and playerData.Hotbar.LeftHand and playerData.Hotbar.LeftHand.ItemID or ""
		local rightItemID = playerData.Hotbar and playerData.Hotbar.RightHand and playerData.Hotbar.RightHand.ItemID or ""

		character:SetAttribute("HotbarLeftHand", leftItemID)
		character:SetAttribute("HotbarRightHand", rightItemID)

		print("[PCM] Initialized hotbar attributes: Left='" .. leftItemID .. "' Right='" .. rightItemID .. "'")

		-- Экипируем оружие если оно есть в хотбаре
		local WeaponManager = require(ServerScriptService:WaitForChild("WeaponManager"))

		if playerData.Hotbar.RightHand then
			if not playerData.Hotbar.LeftHand or playerData.Hotbar.RightHand.UniqueID ~= playerData.Hotbar.LeftHand.UniqueID then
				WeaponManager.EquipWeaponToHand(player, playerData.Hotbar.RightHand.ItemID, "RightHand")
			end
		end

		-- ? ПРИНУДИТЕЛЬНО ОБНОВЛЯЕМ АТРИБУТЫ ПОСЛЕ ЗАГРУЗКИ
		task.wait(0.1)
		character:SetAttribute("HotbarLeftHand", leftItemID)
		character:SetAttribute("HotbarRightHand", rightItemID)
		print("[PCM] ? Force-updated attributes after spawn")
	end

	HitboxManager.SetupForCharacter(character)
	CharacterReadyEvent:FireClient(player)
end

-- Эта функция вызывается один раз, когда игрок заходит на сервер
local function onPlayerAdded(player)
	-- 1. Загружаем данные игрока из DataStore
	local playerData = DataManager.LoadData(player)

	-- 2. Обновляем вид манекенов на основе загруженных данных
	if playerData and playerData.Characters then
		for i = 1, 3 do
			local slotStr = tostring(i)
			local mannequin = MenuMannequins:FindFirstChild("Slot"..slotStr.."_Mannequin")
			if mannequin and playerData.Characters[slotStr] then
				MenuManager.ProcessCharacter(mannequin, playerData.Characters[slotStr])
			end
		end
	end

	-- 3. Отправляем данные клиенту для построения UI
	LoadPlayerMenuDataEvent:FireClient(player, playerData)

	-- 4. Устанавливаем начальные атрибуты и подключаем обработчик
	player:SetAttribute("InMenu", true)
	player.RespawnLocation = menuSpawn
	player.CharacterAppearanceLoaded:Connect(setupCharacterAppearance)

	-- 5. Загружаем самую первую модель персонажа (в меню)
	player:LoadCharacter()
end

-- Этот обработчик срабатывает при нажатии кнопки "Play"
PlayerActionsEvent.OnServerEvent:Connect(function(player, action, slotIndex)
	if action == "RequestCharacterLoad" then
		-- 1) переключаем активного персонажа и его инвентарь
		DataManager.SetCurrentCharacterSlot(player, slotIndex)

		-- 2) готовим внешность/характеристики
		MenuManager.PrepareCharacterToLoad(player, slotIndex)

		player:SetAttribute("InMenu", false)
		player.RespawnLocation = gameSpawn -- или твой игровой спавн
		player:LoadCharacter()
	end
end)



-- =================================================================
-- COLLISION УПРАВЛЕНИЕ ДЛЯ NPC И СУЩЕСТВУЮЩИХ ПЕРСОНАЖЕЙ
-- =================================================================

-- Для NPC, которые уже есть или появятся в игре
workspace.DescendantAdded:Connect(function(descendant)
	if descendant:IsA("Model") and descendant:FindFirstChildOfClass("Humanoid") then
		-- Проверяем, не является ли это персонажем игрока
		if not Players:GetPlayerFromCharacter(descendant) then
			setCollisionGroup(descendant)
		end
	end
end)

-- Для всех существующих NPC в workspace
for _, descendant in ipairs(workspace:GetDescendants()) do
	if descendant:IsA("Model") and descendant:FindFirstChildOfClass("Humanoid") then
		if not Players:GetPlayerFromCharacter(descendant) then
			setCollisionGroup(descendant)
		end
	end
end

-- Подключаем всё к событиям
Players.PlayerAdded:Connect(onPlayerAdded)
for _, player in ipairs(Players:GetPlayers()) do
	task.spawn(onPlayerAdded, player)
end

MoveItemEvent.OnServerEvent:Connect(function(player, itemUniqueId, newPosition)
	print("!!! Сервер ПОЛУЧИЛ событие MoveItemEvent от", player.Name)
	DataManager.MoveItem(player, itemUniqueId, {X = newPosition.X, Y = newPosition.Y})
end)

print("[PlayerConnectionManager] ? Initialized with collision management")