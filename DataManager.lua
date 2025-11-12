-- DataManager (ModuleScript) - v4.2 (Полностью исправленная версия)
local DataStoreService = game:GetService("DataStoreService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local HttpService = game:GetService("HttpService")

-- ? ШАГ 1: Получаем папку Events
local Events = ReplicatedStorage:WaitForChild("Events")

-- ? ШАГ 2: Объявляем ВСЕ события ГЛОБАЛЬНО
local ShowNotificationEvent = Events:WaitForChild("ShowNotificationEvent")
local LoadPlayerMenuDataEvent = Events:WaitForChild("LoadPlayerMenuData")
local LoadInventoryDataEvent = Events:WaitForChild("LoadInventoryDataEvent")
local MoveItemEvent = Events:WaitForChild("MoveItemEvent")
local StackItemsEvent = Events:WaitForChild("StackItemsEvent")
local MoveItemToSlotEvent = Events:WaitForChild("MoveItemToSlotEvent")
local EquipItemEvent = Events:WaitForChild("EquipItemEvent")

-- Функция для отправки уведомлений
local function sendNotification(player, message, duration)
	ShowNotificationEvent:FireClient(player, message, duration or 3)
end

-- ? ШАГ 3: Загружаем модули
local ItemsConfig = require(ReplicatedStorage:WaitForChild("ItemsConfig"))
local function getEquippedBackpack(data)
	if not data or not data.Equipment then return nil end

	for slotName, item in pairs(data.Equipment) do
		if item and item.ItemID then
			local cfg = ItemsConfig[item.ItemID]
			if cfg and cfg.ExpansionSize then
				return item, slotName, cfg
			end
		end
	end

	return nil
end
local InventoryController = require(script.Parent:WaitForChild("InventoryController"))

-- Нормализация содержимого рюкзака: гарантируем GridSize, Position и без пересечений
local function sanitizeBackpackInventory(rawInv, backpackCfg)
	if not rawInv or type(rawInv) ~= "table" then return nil end

	-- поддержка обоих форматов: {GridSize, Items} и просто массив предметов
	local itemsArray = rawInv.Items or rawInv.items or rawInv
	if not itemsArray or type(itemsArray) ~= "table" then
		return nil
	end

	-- размер сетки
	local gridSize = rawInv.GridSize
	if not gridSize or not gridSize.X or not gridSize.Y then
		if backpackCfg and backpackCfg.ExpansionSize then
			gridSize = {
				X = backpackCfg.ExpansionSize.X,
				Y = backpackCfg.ExpansionSize.Y
			}
		else
			gridSize = {X = 4, Y = 4}
		end
	end

	local cleanItems = {}

	local function placeItem(item)
		if not item or not item.ItemID then return end

		local cfg = ItemsConfig[item.ItemID]
		local sizeCfg = item.GridSize or (cfg and cfg.GridSize) or {X = 1, Y = 1}
		local itemSize = {
			X = sizeCfg.X or sizeCfg.x or 1,
			Y = sizeCfg.Y or sizeCfg.y or 1
		}

		-- возможный формат позиции после JSONDecode: {X=...,Y=...} или { [1]=X, [2]=Y }
		local pos = item.Position
		if pos and not pos.X and pos[1] and pos[2] then
			pos = {X = pos[1], Y = pos[2]}
		end

		local placed = false
		if pos and pos.X and pos.Y then
			if InventoryController.canPlaceItem(cleanItems, itemSize, pos, gridSize, item.UniqueID) then
				item.Position = {X = pos.X, Y = pos.Y}
				item.GridSize = itemSize
				table.insert(cleanItems, item)
				placed = true
			end
		end

		if not placed then
			local freePos = InventoryController.findFirstAvailableSlot(cleanItems, itemSize, gridSize)
			if freePos then
				item.Position = {X = freePos.X, Y = freePos.Y}
				item.GridSize = itemSize
				table.insert(cleanItems, item)
			else
				warn("[DataManager] No space in backpack for item:", item.ItemID)
			end
		end
	end

	for _, it in ipairs(itemsArray) do
		placeItem(it)
	end

	return {
		GridSize = gridSize,
		Items = cleanItems
	}
end

local playerDataStore = DataStoreService:GetDataStore("PlayerData_V28")
local DataManager = {}
local playerSessionData = {}

local function deepCopy(tbl)
	if type(tbl) ~= "table" then return tbl end
	local copy = {}
	for k, v in pairs(tbl) do
		copy[k] = deepCopy(v)
	end
	return copy
end

local function updateHotbarAttributes(player)
	if not player.Character then 
		warn("[DataManager] Cannot update attributes - character not found")
		return 
	end

	local data = playerSessionData[player.UserId]
	if not data or not data.Hotbar then
		warn("[DataManager] Cannot update attributes - data not found")
		return
	end

	local leftItemID = data.Hotbar.LeftHand and data.Hotbar.LeftHand.ItemID or ""
	local rightItemID = data.Hotbar.RightHand and data.Hotbar.RightHand.ItemID or ""

	player.Character:SetAttribute("HotbarLeftHand", leftItemID)
	player.Character:SetAttribute("HotbarRightHand", rightItemID)

	print(string.format("[DataManager] ? Attributes updated: Left='%s' Right='%s'", leftItemID, rightItemID))
end

local function findItemAtPosition(items, position, itemToIgnoreId)
	for _, item in ipairs(items) do
		if item.UniqueID ~= itemToIgnoreId then
			local x, y = item.Position.X, item.Position.Y
			local sizeX, sizeY = item.GridSize.X, item.GridSize.Y
			if position.X >= x and position.X < x + sizeX and position.Y >= y and position.Y < y + sizeY then
				return item
			end
		end
	end
	return nil
end

local function getDefaultData()
	return {
		UnlockedSlots = {"1"},
		Characters = { ["1"] = nil, ["2"] = nil, ["3"] = nil },

		-- ?? добавляем
		CurrentCharacterSlot = nil,

		Equipment = {
			Armor = nil,
			Clothing = nil,
			Accessory1 = nil,
			Accessory2 = nil,
			Accessory3 = nil
		},
		Hotbar = { LeftHand = nil, RightHand = nil },
		MoneySlot = nil,
		Inventory = {
			GridSize = { X = 8, Y = 10 },
			Items = {}
		},
	}
end

local function syncActiveToCurrentCharacter(player)
	local data = playerSessionData[player.UserId]
	if not data then return end

	local slot = data.CurrentCharacterSlot
	if not slot then return end

	local char = data.Characters[slot]
	if not char then return end

	-- просто добавляем/обновляем поля внутри char
	char.Inventory = deepCopy(data.Inventory)
	char.Equipment = deepCopy(data.Equipment)
	char.Hotbar   = deepCopy(data.Hotbar)
	char.MoneySlot = deepCopy(data.MoneySlot)
end

function DataManager.SetCurrentCharacterSlot(player, slotIndex)
	local data = playerSessionData[player.UserId]
	if not data then return end

	local newSlot = tostring(slotIndex)
	if data.CurrentCharacterSlot == newSlot then return end

	-- 1. Сохраняем активного персонажа
	if data.CurrentCharacterSlot then
		syncActiveToCurrentCharacter(player)
	end

	data.CurrentCharacterSlot = newSlot

	-- 2. Загружаем данные выбранного персонажа
	local char = data.Characters[newSlot]

	if char then
		-- если у персонажа уже есть свои данные – берём их
		data.Inventory = deepCopy(char.Inventory or getDefaultData().Inventory)
		data.Equipment = deepCopy(char.Equipment or getDefaultData().Equipment)
		data.Hotbar    = deepCopy(char.Hotbar or getDefaultData().Hotbar)
		data.MoneySlot = deepCopy(char.MoneySlot or nil)
	else
		-- новый персонаж – чистый инвентарь
		local def = getDefaultData()
		data.Inventory = deepCopy(def.Inventory)
		data.Equipment = deepCopy(def.Equipment)
		data.Hotbar    = deepCopy(def.Hotbar)
		data.MoneySlot = nil
	end
end



function DataManager.LoadData(player)
	local userId = player.UserId
	local success, data = pcall(function()
		return playerDataStore:GetAsync(userId)
	end)

	if success and data then
		-- ? ИСПРАВЛЕНИЕ: Конвертируем таблицы обратно в Vector2
		if data.InventorySize and type(data.InventorySize) == "table" then
			data.InventorySize = Vector2.new(data.InventorySize.X, data.InventorySize.Y)
		end
		
		-- ? ИСПРАВЛЕНИЕ: Чистим битые предметы без Position
		if data.Inventory then
			-- Проверяем формат данных
			if type(data.Inventory) == "table" and data.Inventory.Items then
				-- Новый формат - чистим битые предметы
				local cleanItems = {}
				for _, item in ipairs(data.Inventory.Items) do
					if item.Position and item.GridSize then
						if type(item.Position) == "table" then
							item.Position = {X = item.Position.X, Y = item.Position.Y}
						end
						if type(item.GridSize) == "table" then
							item.GridSize = {X = item.GridSize.X, Y = item.GridSize.Y}
						end
						table.insert(cleanItems, item)
					end
				end
				data.Inventory.Items = cleanItems
			else
				-- Старый формат - конвертируем
				local cleanItems = {}
				for _, item in ipairs(data.Inventory) do
					if item.Position and item.GridSize then
						if type(item.Position) == "table" then
							item.Position = {X = item.Position.X, Y = item.Position.Y}
						end
						if type(item.GridSize) == "table" then
							item.GridSize = {X = item.GridSize.X, Y = item.GridSize.Y}
						end
						table.insert(cleanItems, item)
					end
				end

				data.Inventory = {
					GridSize = data.InventorySize or {X = 8, Y = 10},
					Items = cleanItems
				}
			end
		else
			data.Inventory = {
				GridSize = {X = 8, Y = 10},
				Items = {}
			}
		end
		
		playerSessionData[userId] = data
		--print("[DataManager] ? Data loaded for " .. player.Name)
		return data
	else
		warn("[DataManager] Could not load data for " .. player.Name .. ", creating default data")

		local defaultData = {
			UnlockedSlots = {"1"},
			Characters = {},
			Inventory = {
				GridSize = {X = 8, Y = 10},
				Items = {}
			},
			Equipment = {
				Head = nil,
				Torso = nil,
				Armor = nil,
				Accessory = nil
			},
			MoneySlot = nil,

			Hotbar = {
				LeftHand = nil,
				RightHand = nil
			},

			-- ? ДОБАВЛЕНО: текущий выбранный слот персонажа
			CurrentCharacterSlot = "1",

			InventorySize = {X = 8, Y = 10}
		}

		playerSessionData[userId] = defaultData
		return defaultData
	end
end
function DataManager.GetData(player) return playerSessionData[player.UserId] end

-- Рекурсивная функция для очистки данных от недопустимых типов
local function cleanDataForSave(data)
	if type(data) ~= "table" then
		-- Конвертируем Vector2
		if typeof(data) == "Vector2" then
			return {X = data.X, Y = data.Y}
		end
		-- Удаляем недопустимые типы
		if typeof(data) == "Instance" or typeof(data) == "CFrame" or typeof(data) == "Vector3" then
			return nil
		end
		return data
	end

	local cleaned = {}
	for key, value in pairs(data) do
		local cleanedKey = key
		local cleanedValue = value

		-- Очищаем ключ
		if type(key) == "table" or typeof(key) == "Instance" then
			warn("[DataManager] Invalid key type found, skipping:", typeof(key))
			continue
		end

		-- Очищаем значение
		if type(value) == "table" then
			cleanedValue = cleanDataForSave(value)
		elseif typeof(value) == "Vector2" then
			cleanedValue = {X = value.X, Y = value.Y}
		elseif typeof(value) == "Vector3" then
			cleanedValue = {X = value.X, Y = value.Y, Z = value.Z}
		elseif typeof(value) == "Instance" or typeof(value) == "CFrame" then
			warn("[DataManager] Invalid value type found, removing:", typeof(value))
			cleanedValue = nil
		end

		if cleanedValue ~= nil then
			cleaned[cleanedKey] = cleanedValue
		end
	end

	return cleaned
end

-- Функция для проверки данных на валидность
local function debugDataStructure(data, path)
	path = path or "root"

	if type(data) ~= "table" then
		local dataType = typeof(data)
		if dataType ~= "string" and dataType ~= "number" and dataType ~= "boolean" and data ~= nil then
			warn(string.format("[DEBUG] Invalid type at %s: %s", path, dataType))
			return false
		end
		return true
	end

	for key, value in pairs(data) do
		local keyType = typeof(key)
		if keyType ~= "string" and keyType ~= "number" then
			warn(string.format("[DEBUG] Invalid key type at %s: %s", path, keyType))
			return false
		end

		local newPath = path .. "." .. tostring(key)
		if not debugDataStructure(value, newPath) then
			return false
		end
	end

	return true
end

function DataManager.SaveData(player)
	local userId = player.UserId
	local data = playerSessionData[userId]

	if not data then
		warn("[DataManager] No session data found for " .. player.Name)
		return
	end

	-- ?? КРИТИЧНО: перед сохранением запишем активный инвентарь в текущего персонажа
	syncActiveToCurrentCharacter(player)

	-- Глубокая очистка данных
	local dataToSave = cleanDataForSave(data)

	-- ОТЛАДКА: Проверяем структуру
	--print("[DataManager] Checking data structure before save...")
	debugDataStructure(dataToSave)

	-- Попытка сохранить через HttpService для теста
	local HttpService = game:GetService("HttpService")
	local testSuccess, testErr = pcall(function()
		local json = HttpService:JSONEncode(dataToSave)
		--print("[DataManager] JSON encode successful, length:", #json)
	end)

	if not testSuccess then
		warn("[DataManager] JSON encode failed:", testErr)
		warn("[DataManager] Data dump:")
		print(dataToSave)
		return
	end

	local success, err = pcall(function()
		playerDataStore:SetAsync(userId, dataToSave)
	end)

	if success then
		--print("[DataManager] ? Data saved for " .. player.Name)
	else
		warn("[DataManager] ? Failed to save data for " .. player.Name .. ": " .. tostring(err))
	end
end



local function generateUniqueID() return string.format("%x",math.random(1,2^31-1)).."-"..string.format("%x",math.random(1,2^31-1)) end

local function ensureInventoryStructure(data)
	if not data.Inventory then
		data.Inventory = {
			GridSize = {X = 8, Y = 10},
			Items = {}
		}
	elseif not data.Inventory.Items then
		-- Старый формат - конвертируем
		local items = {}
		if type(data.Inventory) == "table" then
			items = data.Inventory
		end
		data.Inventory = {
			GridSize = data.InventorySize or {X = 8, Y = 10},
			Items = items
		}
	end
end

function DataManager.SplitItemStack(player, sourceItemUniqueId, amountToSplit)
	local data = playerSessionData[player.UserId]
	if not data or not data.Inventory or not data.Inventory.Items then return end
	amountToSplit = math.floor(amountToSplit)

	local sourceItem
	for _, item in ipairs(data.Inventory.Items) do
		if item.UniqueID == sourceItemUniqueId then
			sourceItem = item
			break
		end
	end

	if not sourceItem or not ItemsConfig[sourceItem.ItemID].IsStackable then return end
	if amountToSplit <= 0 or amountToSplit >= sourceItem.Amount then return end

	local itemSize = {X = sourceItem.GridSize.X, Y = sourceItem.GridSize.Y}
	local newPosition = InventoryController.findFirstAvailableSlot(data.Inventory.Items, itemSize, data.Inventory.GridSize)

	if not newPosition then
		warn("[DataManager] SplitItemStack: Нет места в инвентаре для нового стака.")
		return 
	end

	sourceItem.Amount = sourceItem.Amount - amountToSplit

	local newItem = {
		UniqueID = generateUniqueID(),
		ItemID = sourceItem.ItemID,
		Position = newPosition,
		Rotation = 0,
		GridSize = sourceItem.GridSize,
		Amount = amountToSplit
	}
	table.insert(data.Inventory.Items, newItem)

	local LoadInventoryDataEvent = ReplicatedStorage:WaitForChild("Events"):WaitForChild("LoadInventoryDataEvent")
	LoadInventoryDataEvent:FireClient(player, {
		Inventory = data.Inventory,
		Equipment = data.Equipment,
		MoneySlot = data.MoneySlot
	})
end

function DataManager.AddItem(player, itemId, amount)
	local itemConfig = ItemsConfig[itemId]
	if not itemConfig then return false, "Item does not exist" end
	local data = playerSessionData[player.UserId]
	if not data then return false, "Player data not found" end

	local itemSize = { X = itemConfig.GridSize.X, Y = itemConfig.GridSize.Y }
	local position = InventoryController.findFirstAvailableSlot(data.Inventory.Items, itemSize, data.Inventory.GridSize)

	if position then
		local newItem = {
			UniqueID = generateUniqueID(),
			ItemID = itemId,
			Position = position,
			Rotation = 0,
			GridSize = itemSize
		}
		if itemConfig.IsStackable then newItem.Amount = amount or 1 end
		table.insert(data.Inventory.Items, newItem)
		print(string.format("[DataManager] Предмет '%s' (x%d) добавлен для %s", itemId, amount or 1, player.Name))

		-- === ВОТ РЕШЕНИЕ: Отправляем обновление клиенту ===
		local LoadInventoryDataEvent = ReplicatedStorage.Events.LoadInventoryDataEvent
		LoadInventoryDataEvent:FireClient(player, {
			Inventory = data.Inventory,
			Equipment = data.Equipment,
			MoneySlot = data.MoneySlot,
			Hotbar = data.Hotbar
		})
		-- ===================================================

		return true, "Item added"
	else
		warn(string.format("[DataManager] Не удалось добавить '%s' для %s. Инвентарь полон!", itemId, player.Name))
		return false, "Inventory full"
	end
end

-- Проверяет, можно ли добавить предмет в хотбар
local function canFitInHotbar(playerData, itemConfig)
	local hotbar = playerData.Hotbar or {}
	local leftHand = hotbar.LeftHand
	local rightHand = hotbar.RightHand

	if itemConfig.IsTwoHanded then
		return (not leftHand or not leftHand.ItemID) and (not rightHand or not rightHand.ItemID)
	end

	return (not leftHand or not leftHand.ItemID) or (not rightHand or not rightHand.ItemID)
end

-- Добавляет предмет в первый свободный слот хотбара
local function addItemToHotbar(playerData, itemId, amount)
	local itemConfig = ItemsConfig[itemId]
	if not itemConfig then return false end

	local hotbar = playerData.Hotbar or {}
	local uniqueID = HttpService:GenerateGUID(false)

	local hotbarItem = {
		ItemID = itemId,
		Amount = amount,
		UniqueID = uniqueID,
		GridSize = itemConfig.GridSize and {X = itemConfig.GridSize.X, Y = itemConfig.GridSize.Y} or {X = 1, Y = 1} -- ? ДОБАВЛЕНО
	}

	if itemConfig.IsTwoHanded then
		hotbar.LeftHand = hotbarItem
		hotbar.RightHand = hotbarItem
		--print("[DataManager] Added two-handed item to hotbar:", itemId)
		return true
	end

	if not hotbar.RightHand or not hotbar.RightHand.ItemID then
		hotbar.RightHand = hotbarItem
		--print("[DataManager] Added item to RightHand:", itemId)
		return true
	elseif not hotbar.LeftHand or not hotbar.LeftHand.ItemID then
		hotbar.LeftHand = hotbarItem
		--print("[DataManager] Added item to LeftHand:", itemId)
		return true
	end

	return false
end

function DataManager.AttemptToPickupItem(player, itemId, amountToPickup, extraData)
	local playerData = DataManager.GetData(player)
	if not playerData then return 0 end

	local itemConfig = ItemsConfig[itemId]
	if not itemConfig then 
		warn("[DataManager] ItemConfig not found for:", itemId)
		return 0 
	end

	local itemSize = itemConfig.GridSize or Vector2.new(1, 1)
	local inventorySize = playerData.InventorySize or Vector2.new(8, 10)

	-- Проверяем, есть ли свободное место в инвентаре
	local inventoryItems = playerData.Inventory and playerData.Inventory.Items or {}
	local availableSlot = InventoryController.findFirstAvailableSlot(inventoryItems, itemSize, inventorySize)

	if not availableSlot then
		--print("[DataManager] No space in inventory for:", itemId)
		-- Пытаемся добавить в хотбар
		--print("[DataManager] Trying to add to hotbar:", itemId)

		if canFitInHotbar(playerData, itemConfig) then
			local success = addItemToHotbar(playerData, itemId, amountToPickup)

			if success then
				--DataManager.SaveData(player)

				-- ? КРИТИЧНО: Обновляем атрибуты персонажа
				local character = player.Character
				if character then
					local leftID = playerData.Hotbar.LeftHand and playerData.Hotbar.LeftHand.ItemID or ""
					local rightID = playerData.Hotbar.RightHand and playerData.Hotbar.RightHand.ItemID or ""

					character:SetAttribute("HotbarLeftHand", leftID)
					character:SetAttribute("HotbarRightHand", rightID)
					--print("[DataManager] Hotbar attributes updated")
				end

				-- ? ДОБАВЛЕНО: Отправляем данные клиенту
				LoadInventoryDataEvent:FireClient(player, {
					Inventory = playerData.Inventory,
					Equipment = playerData.Equipment,
					MoneySlot = playerData.MoneySlot,
					Hotbar = playerData.Hotbar
				})
				--print("[DataManager] Sent inventory update to client (hotbar)")

				return amountToPickup
			end
		end

		--print("[DataManager] Cannot pickup - inventory and hotbar are full")
		return 0
	end

	-- Создаём уникальный ID для предмета
	local uniqueID = HttpService:GenerateGUID(false)

	-- Создаём новый предмет с позицией
	local newItem = {
		ItemID = itemId,
		Amount = amountToPickup,
		Position = availableSlot,
		GridSize = itemSize,
		UniqueID = uniqueID
	}
	
	-- ?? Если это рюкзак, восстанавливаем его содержимое
	if extraData and type(extraData) == "table" and extraData.BackpackInventory then
		local backpackInv = sanitizeBackpackInventory(extraData.BackpackInventory, itemConfig)
		if backpackInv then
			newItem.BackpackInventory = backpackInv
		end
	end

	-- Добавляем в инвентарь
	if not playerData.Inventory then
		playerData.Inventory = {GridSize = inventorySize, Items = {}}
	elseif not playerData.Inventory.Items then
		playerData.Inventory = {GridSize = inventorySize, Items = playerData.Inventory}
	end
	table.insert(playerData.Inventory.Items, newItem)


	-- Сохраняем данные
	--DataManager.SaveData(player)

	-- ? ДОБАВЛЕНО: Отправляем данные клиенту
	LoadInventoryDataEvent:FireClient(player, {
		Inventory = playerData.Inventory,
		Equipment = playerData.Equipment,
		MoneySlot = playerData.MoneySlot,
		Hotbar = playerData.Hotbar
	})
	--print("[DataManager] Sent inventory update to client (inventory)")

	--print("[DataManager] Successfully picked up:", itemId, "Amount:", amountToPickup)

	return amountToPickup
end

function DataManager.MoveItem(player, itemUniqueId, newPosition)
	local data = playerSessionData[player.UserId]
	if not data then return end

	local itemToMove, itemToMoveIndex
	for i, item in ipairs(data.Inventory.Items) do
		if item.UniqueID == itemUniqueId then
			itemToMove = item
			itemToMoveIndex = i
			break
		end
	end

	if not itemToMove then return end

	-- 1. Пытаемся найти целевой предмет для объединения
	local targetItem = findItemAtPosition(data.Inventory.Items, newPosition, itemToMove.UniqueID)
	local config = ItemsConfig[itemToMove.ItemID]

	if targetItem and targetItem.ItemID == itemToMove.ItemID and config.IsStackable then
		-- 2. ЛОГИКА ОБЪЕДИНЕНИЯ СТАКОВ
		local spaceInTarget = config.MaxStack - targetItem.Amount
		if spaceInTarget > 0 then
			local amountToTransfer = math.min(itemToMove.Amount, spaceInTarget)

			targetItem.Amount = targetItem.Amount + amountToTransfer
			itemToMove.Amount = itemToMove.Amount - amountToTransfer

			print(string.format("[DataManager] Объединение стаков: %s (+%d) -> %s", itemToMove.ItemID, amountToTransfer, targetItem.ItemID))

			if itemToMove.Amount <= 0 then
				table.remove(data.Inventory.Items, itemToMoveIndex)
			end
		end
	else
		-- 3. ЛОГИКА ПЕРЕМЕЩЕНИЯ (стандартное поведение)
		local canPlace = InventoryController.canPlaceItem(data.Inventory.Items, itemToMove.GridSize, newPosition, data.Inventory.GridSize, itemToMove.UniqueID)
		if canPlace then
			itemToMove.Position = newPosition
			--print("[DataManager] Перемещение предмета", itemToMove.ItemID, "на", newPosition.X, newPosition.Y)
		else
			--print("[DataManager] Перемещение запрещено. Место занято.")
		end
	end

	-- 4. Отправляем клиенту обновленные данные в любом случае
	local LoadInventoryDataEvent = ReplicatedStorage.Events.LoadInventoryDataEvent
	LoadInventoryDataEvent:FireClient(player, { 
		Inventory = data.Inventory, 
		MoneySlot = data.MoneySlot, 
		Equipment = data.Equipment,
		Hotbar = data.Hotbar  -- ? ДОБАВЛЕНО
	})
end

function DataManager.MoveItemToBackpack(player, itemUniqueId, targetPosition)
	local data = playerSessionData[player.UserId]
	if not data then return end

	ensureInventoryStructure(data)

	local backpackItem, backpackSlotName, backpackCfg = getEquippedBackpack(data)
	if not backpackItem then
		sendNotification(player, "You have no backpack equipped", 3)
		return
	end

	-- Ищем предмет в обычном инвентаре
	local itemIndex, itemToStore
	for i, item in ipairs(data.Inventory.Items) do
		if item.UniqueID == itemUniqueId then
			itemIndex, itemToStore = i, item
			break
		end
	end

	if not itemToStore then
		sendNotification(player, "Item not found in inventory", 3)
		return
	end

	-- Рюкзак в рюкзак нельзя
	local itemCfg = ItemsConfig[itemToStore.ItemID]
	if itemCfg and itemCfg.ExpansionSize then
		sendNotification(player, "You cannot put a backpack into a backpack", 3)
		return
	end

	-- Инициализируем внутренний инвентарь рюкзака
	if not backpackItem.BackpackInventory then
		backpackItem.BackpackInventory = {
			GridSize = {
				X = backpackCfg.ExpansionSize.X,
				Y = backpackCfg.ExpansionSize.Y
			},
			Items = {}
		}
	end

	local backpackInv = backpackItem.BackpackInventory

	-- страховка для старых/битых данных
	local gridSize = backpackInv.GridSize or {
		X = backpackCfg.ExpansionSize.X,
		Y = backpackCfg.ExpansionSize.Y
	}
	backpackInv.GridSize = gridSize -- чтобы дальше всегда было корректно

	-- Приводим размер к таблице
	local sizeCfg = itemToStore.GridSize or (itemCfg and itemCfg.GridSize) or {X = 1, Y = 1}
	local itemSize = { X = sizeCfg.X, Y = sizeCfg.Y }

	local finalPos = nil

	-- Если пришла целевая позиция — сначала пытаемся поставить туда
	if targetPosition and targetPosition.X and targetPosition.Y then
		local canPlace = InventoryController.canPlaceItem(
			backpackInv.Items,
			itemSize,
			targetPosition,
			gridSize,
			itemToStore.UniqueID
		)

		if canPlace then
			finalPos = {X = targetPosition.X, Y = targetPosition.Y}
		end
	end

	-- Если не удалось — ищем первое свободное место
	if not finalPos then
		local freePos = InventoryController.findFirstAvailableSlot(backpackInv.Items, itemSize, gridSize)
		if not freePos then
			sendNotification(player, "No space in backpack", 3)
			return
		end
		finalPos = freePos
	end

	itemToStore.Position = {X = finalPos.X, Y = finalPos.Y}

	table.insert(backpackInv.Items, itemToStore)
	table.remove(data.Inventory.Items, itemIndex)

	-- Обновляем клиент
	LoadInventoryDataEvent:FireClient(player, {
		Inventory = data.Inventory,
		Equipment = data.Equipment,
		MoneySlot = data.MoneySlot,
		Hotbar = data.Hotbar
	})
end

function DataManager.MoveBackpackItem(player, itemUniqueId, newPosition)
	local data = playerSessionData[player.UserId]
	if not data then return end

	ensureInventoryStructure(data)

	local backpackItem, _, backpackCfg = getEquippedBackpack(data)
	if not backpackItem or not backpackItem.BackpackInventory then return end

	local backpackInv = backpackItem.BackpackInventory
	local items = backpackInv.Items or {}
	local gridSize = backpackInv.GridSize or backpackCfg.ExpansionSize

	-- Находим сам предмет
	local itemToMove, itemIndex
	for i, item in ipairs(items) do
		if item.UniqueID == itemUniqueId then
			itemToMove = item
			itemIndex = i
			break
		end
	end
	if not itemToMove then return end

	local cfg = ItemsConfig[itemToMove.ItemID]
	local sizeCfg = itemToMove.GridSize or (cfg and cfg.GridSize) or {X = 1, Y = 1}
	local itemSize = {X = sizeCfg.X, Y = sizeCfg.Y}

	-- Возможное объединение стаков внутри рюкзака
	local targetItem = findItemAtPosition(items, newPosition, itemToMove.UniqueID)
	if targetItem and cfg and cfg.IsStackable and targetItem.ItemID == itemToMove.ItemID then
		local spaceInTarget = cfg.MaxStack - (targetItem.Amount or 0)
		if spaceInTarget > 0 then
			local amountToTransfer = math.min(itemToMove.Amount or 1, spaceInTarget)
			targetItem.Amount = (targetItem.Amount or 0) + amountToTransfer
			itemToMove.Amount = (itemToMove.Amount or 1) - amountToTransfer

			if (itemToMove.Amount or 0) <= 0 then
				table.remove(items, itemIndex)
			end
		end
	else
		local canPlace = InventoryController.canPlaceItem(
			items,
			itemSize,
			newPosition,
			gridSize,
			itemToMove.UniqueID
		)

		if canPlace then
			itemToMove.Position = {X = newPosition.X, Y = newPosition.Y}
		end
	end

	LoadInventoryDataEvent:FireClient(player, {
		Inventory = data.Inventory,
		Equipment = data.Equipment,
		MoneySlot = data.MoneySlot,
		Hotbar = data.Hotbar
	})
end

function DataManager.MoveItemFromBackpack(player, itemUniqueId, newPosition)
	local data = playerSessionData[player.UserId]
	if not data then return end

	ensureInventoryStructure(data)

	local backpackItem, _, backpackCfg = getEquippedBackpack(data)
	if not backpackItem or not backpackItem.BackpackInventory then return end

	local backpackInv = backpackItem.BackpackInventory
	local items = backpackInv.Items or {}
	local gridSize = data.Inventory.GridSize

	-- Находим предмет в рюкзаке
	local itemToMove, itemIndex
	for i, item in ipairs(items) do
		if item.UniqueID == itemUniqueId then
			itemToMove = item
			itemIndex = i
			break
		end
	end
	if not itemToMove then return end

	local cfg = ItemsConfig[itemToMove.ItemID]
	local sizeCfg = itemToMove.GridSize or (cfg and cfg.GridSize) or {X = 1, Y = 1}
	local itemSize = {X = sizeCfg.X, Y = sizeCfg.Y}

	-- 1) пробуем объединить стак с предметом в инвентаре под курсором
	local targetItem = findItemAtPosition(data.Inventory.Items, newPosition, itemToMove.UniqueID)

	if targetItem and cfg and cfg.IsStackable and targetItem.ItemID == itemToMove.ItemID then
		local spaceInTarget = cfg.MaxStack - (targetItem.Amount or 0)
		if spaceInTarget > 0 then
			local amountToTransfer = math.min(itemToMove.Amount or 1, spaceInTarget)
			targetItem.Amount = (targetItem.Amount or 0) + amountToTransfer
			itemToMove.Amount = (itemToMove.Amount or 1) - amountToTransfer

			if (itemToMove.Amount or 0) <= 0 then
				table.remove(items, itemIndex)
			end
		end
	else
		-- 2) обычное перемещение в сетку инвентаря
		local canPlace = InventoryController.canPlaceItem(
			data.Inventory.Items,
			itemSize,
			newPosition,
			gridSize,
			itemToMove.UniqueID
		)

		if canPlace then
			itemToMove.Position = {X = newPosition.X, Y = newPosition.Y}
			table.insert(data.Inventory.Items, itemToMove)
			table.remove(items, itemIndex)
		else
			-- если не влезло, просто ничего не меняем
			return
		end
	end

	LoadInventoryDataEvent:FireClient(player, {
		Inventory = data.Inventory,
		Equipment = data.Equipment,
		MoneySlot = data.MoneySlot,
		Hotbar = data.Hotbar
	})
end

function DataManager.MoveItemBetweenSlotAndInventory(player, itemUniqueId, targetContainer, sourceContainer, newPosition)
	local data = playerSessionData[player.UserId]
	if not data then return end
	
	ensureInventoryStructure(data)

	local moneyConfig = ItemsConfig["Money"]
	local MONEY_SLOT_LIMIT = 1024

	if sourceContainer == "Inventory" and targetContainer == "MoneySlot" then
		-- Логика: ИЗ ИНВЕНТАРЯ -> В СЛОТ ДЕНЕГ
		local itemToMove
		local itemIndex
		for i, item in ipairs(data.Inventory.Items) do
			if item.UniqueID == itemUniqueId then
				itemToMove = item
				itemIndex = i
				break
			end
		end

		if not itemToMove or itemToMove.ItemID ~= "Money" then return end

		if not data.MoneySlot then
			-- Слот пуст - проверяем не превышает ли лимит
			if itemToMove.Amount <= MONEY_SLOT_LIMIT then
				data.MoneySlot = itemToMove
				table.remove(data.Inventory.Items, itemIndex)
				--print("[DataManager] Money moved to slot. Amount:", itemToMove.Amount)
			else
				-- Превышает лимит - кладём максимум, остаток остаётся
				local overflow = itemToMove.Amount - MONEY_SLOT_LIMIT
				data.MoneySlot = {
					ItemID = "Money",
					Amount = MONEY_SLOT_LIMIT
				}
				itemToMove.Amount = overflow
				sendNotification(player, string.format("Money slot full! %d credits remain in inventory", overflow), 3)
				--print("[DataManager] Money slot full. Remaining in inventory:", overflow)
			end
		else
			-- Слот занят, стакаем
			local currentAmountInSlot = data.MoneySlot.Amount
			local amountToAdd = itemToMove.Amount
			local newTotal = currentAmountInSlot + amountToAdd

			if newTotal <= MONEY_SLOT_LIMIT then
				data.MoneySlot.Amount = newTotal
				table.remove(data.Inventory.Items, itemIndex)
				--print("[DataManager] Money stacked in slot. Total:", data.MoneySlot.Amount)
			else
				local overflow = newTotal - MONEY_SLOT_LIMIT
				data.MoneySlot.Amount = MONEY_SLOT_LIMIT
				itemToMove.Amount = overflow
				sendNotification(player, string.format("Money slot full! %d credits remain in inventory", overflow), 3)
				--print("[DataManager] Money slot full. Remaining in inventory:", overflow)
			end
		end

	elseif sourceContainer == "MoneySlot" and targetContainer == "Inventory" then
		-- Логика: ИЗ СЛОТА ДЕНЕГ -> В ИНВЕНТАРЬ
		if not data.MoneySlot or not newPosition then return end

		local canPlace = InventoryController.canPlaceItem(data.Inventory.Items, moneyConfig.GridSize, newPosition, data.Inventory.GridSize)
		if not canPlace then
			--print("[DataManager] Перемещение денег запрещено. Место занято.")
			-- Возвращаем данные клиенту, чтобы предмет "вернулся" на место
		else
			local amountToMove = math.min(data.MoneySlot.Amount, moneyConfig.MaxStack)

			local newItem = {
				UniqueID = generateUniqueID(),
				ItemID = "Money",
				Position = newPosition,
				Rotation = 0,
				GridSize = moneyConfig.GridSize,
				Amount = amountToMove
			}
			table.insert(data.Inventory.Items, newItem)

			data.MoneySlot.Amount = data.MoneySlot.Amount - amountToMove
			if data.MoneySlot.Amount <= 0 then
				data.MoneySlot = nil
			end
		end
	end

	-- Отправляем обновленные данные клиенту в любом случае
	local LoadInventoryDataEvent = ReplicatedStorage.Events.LoadInventoryDataEvent
	LoadInventoryDataEvent:FireClient(player, { 
		Inventory = data.Inventory, 
		MoneySlot = data.MoneySlot,
		Hotbar = data.Hotbar  -- ? ДОБАВЬ ЭТО
	})
end

function DataManager.DropItem(player, itemUniqueId, fromSlot)
	local Debris = game:GetService("Debris")
	local data = playerSessionData[player.UserId]
	if not data then return end
	
	ensureInventoryStructure(data)

	local itemToDrop, itemIndex

	-- Если указан слот - берем оттуда
	if fromSlot then
		if fromSlot == "Money" then
			itemToDrop = data.Equipment.Money
			if itemToDrop then
				-- Для денег выбрасываем 256 или все что есть
				local dropAmount = math.min(itemToDrop.Amount or 1, 256)
				local newItem = {
					UniqueID = generateUniqueID(),
					ItemID = "Money",
					Amount = dropAmount,
					GridSize = {X = 1, Y = 1}
				}

				itemToDrop.Amount = (itemToDrop.Amount or 1) - dropAmount
				if itemToDrop.Amount <= 0 then
					data.Equipment.Money = nil
				end

				itemToDrop = newItem
			end
		elseif string.find(fromSlot, "Accessory") then
			itemToDrop = data.Equipment[fromSlot]
			data.Equipment[fromSlot] = nil
		elseif fromSlot == "LeftHand" or fromSlot == "RightHand" then
			itemToDrop = data.Hotbar[fromSlot]
			if itemToDrop then
				local config = ItemsConfig[itemToDrop.ItemID]
				if config and config.IsTwoHanded then
					data.Hotbar.LeftHand = nil
					data.Hotbar.RightHand = nil
				else
					data.Hotbar[fromSlot] = nil
				end
			end
		else
			itemToDrop = data.Equipment[fromSlot]
			data.Equipment[fromSlot] = nil
		end
	else
		-- Из инвентаря
		local dropFromBackpack = false
		local backpackRef = nil

		for i, item in ipairs(data.Inventory.Items) do
			if item.UniqueID == itemUniqueId then
				itemIndex = i
				itemToDrop = item
				break
			end
		end

		if not itemToDrop then
			-- пробуем найти в рюкзаке
			local backpackItem = getEquippedBackpack(data)
			if backpackItem and backpackItem.BackpackInventory and backpackItem.BackpackInventory.Items then
				local bItems = backpackItem.BackpackInventory.Items
				backpackRef = backpackItem
				for i, item in ipairs(bItems) do
					if item.UniqueID == itemUniqueId then
						itemIndex = i
						itemToDrop = item
						dropFromBackpack = true
						break
					end
				end
			end
		end

		if itemIndex then
			if dropFromBackpack and backpackRef and backpackRef.BackpackInventory then
				table.remove(backpackRef.BackpackInventory.Items, itemIndex)
			else
				table.remove(data.Inventory.Items, itemIndex)
			end
		end
	end

	if not itemToDrop then return end

	-- Создаем лут в мире
	local character = player.Character
	if not character or not character.PrimaryPart then return end

	local lootContainer = workspace:FindFirstChild("LootContainer") or Instance.new("Folder", workspace)
	lootContainer.Name = "LootContainer"

	local dropCFrame = character.PrimaryPart.CFrame * CFrame.new(0, 0, -3)

	-- ИСПРАВЛЕНИЕ: Проверяем есть ли кастомная модель
	local config = ItemsConfig[itemToDrop.ItemID]
	local modelToClone

	if config and config.Model then
		-- Ищем кастомную модель в Lootables
		local lootablesFolder = ReplicatedStorage:FindFirstChild("Lootables")
		if lootablesFolder then
			modelToClone = lootablesFolder:FindFirstChild(config.Model)
			if modelToClone then
				print("[DropItem] Using custom model:", config.Model)
			else
				warn("[DropItem] Custom model not found:", config.Model)
			end
		end
	end

	-- Если кастомная модель не найдена, используем DefaultLootBag
	if not modelToClone then
		modelToClone = ReplicatedStorage.Lootables.DefaultLootBag
		print("[DropItem] Using DefaultLootBag")
	end

	if modelToClone then
		local itemModel = modelToClone:Clone()
		itemModel:SetPrimaryPartCFrame(dropCFrame)
		itemModel.Parent = lootContainer
		itemModel:SetAttribute("ItemID", itemToDrop.ItemID)
		itemModel:SetAttribute("Amount", itemToDrop.Amount or 1)

		-- ?? Если дропаем рюкзак с содержимым – сериализуем нормализованный инвентарь
		if itemToDrop.BackpackInventory then
			local cfg = ItemsConfig[itemToDrop.ItemID]
			local sanitized = sanitizeBackpackInventory(itemToDrop.BackpackInventory, cfg)

			if sanitized then
				local ok, json = pcall(HttpService.JSONEncode, HttpService, sanitized)
				if ok then
					itemModel:SetAttribute("BackpackData", json)
				else
					warn("[DropItem] Failed to JSONEncode BackpackInventory for", itemToDrop.ItemID, json)
				end
			end
		end

		local basePart = itemModel:FindFirstChild("BasePart", true)
		if basePart then
			local prompt = basePart:FindFirstChildOfClass("ProximityPrompt")
			if prompt then
				local itemName = config.Name or itemToDrop.ItemID
				prompt.ObjectText = string.format("%s (%d)", itemName, itemToDrop.Amount or 1)
			end
		end

		Debris:AddItem(itemModel, 300)
	end

	-- Отправляем обновление
	LoadInventoryDataEvent:FireClient(player, {
		Inventory = data.Inventory,
		Equipment = data.Equipment,
		Hotbar = data.Hotbar
	})

	local ShowNotificationEvent = ReplicatedStorage.Events:WaitForChild("ShowNotificationEvent")
	ShowNotificationEvent:FireClient(player, string.format("Dropped %s", ItemsConfig[itemToDrop.ItemID].Name))
end

function DataManager.MoveItemToHotbar(player, itemUniqueId, slotName)
	local data = playerSessionData[player.UserId]
	if not data or not data.Inventory or not data.Hotbar then 
		warn("[DataManager] Missing data for MoveItemToHotbar")
		return 
	end

	--print("[DataManager] MoveItemToHotbar called. Item:", itemUniqueId, "Slot:", slotName)

	-- Пытаемся найти предмет в инвентаре, а если нет – вытаскиваем из рюкзака
	local itemToMove, itemIndex = nil, nil
	for i, item in ipairs(data.Inventory.Items) do
		if item.UniqueID == itemUniqueId then
			itemToMove = item
			itemIndex = i
			break
		end
	end

	if not itemToMove then
		-- пробуем взять из рюкзака
		local backpackItem, _, backpackCfg = getEquippedBackpack(data)
		if backpackItem and backpackItem.BackpackInventory and backpackItem.BackpackInventory.Items then
			local bItems = backpackItem.BackpackInventory.Items
			for i, item in ipairs(bItems) do
				if item.UniqueID == itemUniqueId then
					local cfg = ItemsConfig[item.ItemID]
					local sizeCfg = item.GridSize or (cfg and cfg.GridSize) or {X = 1, Y = 1}
					local itemSize = {X = sizeCfg.X, Y = sizeCfg.Y}

					local newPos = InventoryController.findFirstAvailableSlot(
						data.Inventory.Items,
						itemSize,
						data.Inventory.GridSize
					)

					if not newPos then
						sendNotification(player, "No space in inventory to move from backpack", 3)
						return
					end

					item.Position = {X = newPos.X, Y = newPos.Y}
					table.insert(data.Inventory.Items, item)
					table.remove(bItems, i)

					itemToMove = item
					itemIndex = #data.Inventory.Items
					break
				end
			end
		end
	end

	if not itemToMove then 
		warn("[DataManager] Item not found for MoveItemToHotbar:", itemUniqueId)
		return 
	end


	-- 1. Находим предмет в инвентаре
	local itemToMove, itemIndex = nil, nil
	for i, item in ipairs(data.Inventory.Items) do
		if item.UniqueID == itemUniqueId then
			itemToMove = item
			itemIndex = i
			break
		end
	end

	if not itemToMove then 
		warn("[DataManager] Item not found in inventory:", itemUniqueId)
		return 
	end

	local config = ItemsConfig[itemToMove.ItemID]
	if not config then
		warn("[DataManager] Item config not found for:", itemToMove.ItemID)
		return
	end

	--print("[DataManager] Moving item", itemToMove.ItemID, "to hotbar slot", slotName)

	-- ==== ИСПРАВЛЕНИЕ: Проверяем двуручное оружие ====
	if config.IsTwoHanded then
		-- Двуручное оружие занимает оба слота
		if data.Hotbar.LeftHand or data.Hotbar.RightHand then
			sendNotification(player, "Two-handed items require both hands to be empty", 3)
			--print("[DataManager] Both hands must be free for two-handed item")

			-- Возвращаем все что было в руках обратно в инвентарь
			if data.Hotbar.LeftHand then
				local oldItem = data.Hotbar.LeftHand
				-- Проверяем что это не тот же самый двуручный предмет
				if oldItem ~= data.Hotbar.RightHand then
					local itemSize = {
						X = ItemsConfig[oldItem.ItemID].GridSize.X,
						Y = ItemsConfig[oldItem.ItemID].GridSize.Y
					}
					local newPos = InventoryController.findFirstAvailableSlot(
						data.Inventory.Items, itemSize, data.Inventory.GridSize
					)
					if newPos then
						oldItem.Position = newPos
						table.insert(data.Inventory.Items, oldItem)
					end
				end
			end

			if data.Hotbar.RightHand and data.Hotbar.RightHand ~= data.Hotbar.LeftHand then
				local oldItem = data.Hotbar.RightHand
				local itemSize = {
					X = ItemsConfig[oldItem.ItemID].GridSize.X,
					Y = ItemsConfig[oldItem.ItemID].GridSize.Y
				}
				local newPos = InventoryController.findFirstAvailableSlot(
					data.Inventory.Items, itemSize, data.Inventory.GridSize
				)
				if newPos then
					oldItem.Position = newPos
					table.insert(data.Inventory.Items, oldItem)
				end
			end
		end

		-- Занимаем оба слота одним предметом
		data.Hotbar.LeftHand = itemToMove
		data.Hotbar.RightHand = itemToMove
		table.remove(data.Inventory.Items, itemIndex)
		--print("[DataManager] Two-handed item placed in both slots")

	else
		-- ==== ИСПРАВЛЕНИЕ: Проверяем не занята ли другая рука двуручным оружием ====
		local otherSlot = slotName == "LeftHand" and "RightHand" or "LeftHand"
		local otherItem = data.Hotbar[otherSlot]

		if otherItem then
			local otherConfig = ItemsConfig[otherItem.ItemID]
			if otherConfig and otherConfig.IsTwoHanded then
				-- В другой руке двуручное оружие! Удаляем его из ОБЕИХ рук
				--print("[DataManager] Removing two-handed item from both hands")

				local itemSize = {
					X = otherConfig.GridSize.X,
					Y = otherConfig.GridSize.Y
				}
				local newPos = InventoryController.findFirstAvailableSlot(
					data.Inventory.Items, itemSize, data.Inventory.GridSize
				)

				if newPos then
					otherItem.Position = newPos
					table.insert(data.Inventory.Items, otherItem)
					data.Hotbar.LeftHand = nil
					data.Hotbar.RightHand = nil
				else
					sendNotification(player, "No space in inventory", 3)
					return
				end
			end
		end

		-- Обычный предмет
		local currentItem = data.Hotbar[slotName]

		if currentItem then
			-- Если предметы одинаковые, отменяем
			if currentItem.UniqueID == itemToMove.UniqueID then
				--print("[DataManager] Same item, canceling")
				return
			end

			-- Проверяем можно ли вернуть старый предмет на место нового
			local canSwap = InventoryController.canPlaceItem(
				data.Inventory.Items,
				currentItem.GridSize,
				itemToMove.Position,
				data.Inventory.GridSize,
				itemToMove.UniqueID
			)

			if canSwap then
				-- Меняем местами
				--print("[DataManager] Swapping items")
				currentItem.Position = itemToMove.Position
				table.remove(data.Inventory.Items, itemIndex)
				table.insert(data.Inventory.Items, currentItem)
				data.Hotbar[slotName] = itemToMove
			else
				-- Ищем свободное место для старого предмета
				local itemSize = {
					X = ItemsConfig[currentItem.ItemID].GridSize.X,
					Y = ItemsConfig[currentItem.ItemID].GridSize.Y
				}
				local newPos = InventoryController.findFirstAvailableSlot(
					data.Inventory.Items, itemSize, data.Inventory.GridSize
				)

				if not newPos then
					sendNotification(player, "No space to swap items", 3)
					return
				end

				currentItem.Position = newPos
				table.remove(data.Inventory.Items, itemIndex)
				table.insert(data.Inventory.Items, currentItem)
				data.Hotbar[slotName] = itemToMove
			end
		else
			-- Слот пустой, просто помещаем
			data.Hotbar[slotName] = itemToMove
			table.remove(data.Inventory.Items, itemIndex)
		end

		--print("[DataManager] Item placed in slot", slotName)
	end



	-- Отправляем обновленные данные клиенту
	local LoadInventoryDataEvent = ReplicatedStorage.Events.LoadInventoryDataEvent
	-- ? УСТАНАВЛИВАЕМ АТРИБУТЫ (ОБЯЗАТЕЛЬНО ПЕРЕД FireClient!)
	if player.Character then
		local leftItemID = data.Hotbar.LeftHand and data.Hotbar.LeftHand.ItemID or ""
		local rightItemID = data.Hotbar.RightHand and data.Hotbar.RightHand.ItemID or ""

		player.Character:SetAttribute("HotbarLeftHand", leftItemID)
		player.Character:SetAttribute("HotbarRightHand", rightItemID)

		--print("[DataManager] Set attributes: Left='" .. leftItemID .. "' Right='" .. rightItemID .. "'")
	end

	-- Отправляем обновленные данные клиенту
	-- ? ОБНОВЛЯЕМ АТРИБУТЫ
	updateHotbarAttributes(player)

	-- Отправляем обновленные данные клиенту
	LoadInventoryDataEvent:FireClient(player, {
		Inventory = data.Inventory,
		Equipment = data.Equipment,
		MoneySlot = data.MoneySlot,
		Hotbar = data.Hotbar
	})

	--print("[DataManager] Hotbar update sent to client")

	-- ? Экипируем оружие
	local WeaponManager = require(script.Parent:WaitForChild("WeaponManager"))
	local handForModel = (config.IsTwoHanded and "RightHand") or slotName
	WeaponManager.EquipWeaponToHand(player, itemToMove.ItemID, handForModel)
end

function DataManager.MoveItemFromHotbar(player, hand, targetPosition)
	local playerData = DataManager.GetData(player)
	if not playerData then return false end

	local itemToMove = playerData.Hotbar[hand]
	if not itemToMove then
		warn("[DataManager] No item in slot:", hand)
		return false
	end

	-- Берем GridSize из ItemsConfig
	local itemConfig = ItemsConfig[itemToMove.ItemID]
	
	local isTwoHanded = itemConfig and itemConfig.IsTwoHanded

	-- Если это двуручный предмет, сразу чистим вторую руку,
	-- чтобы не осталось висячей ссылки на тот же самый объект
	if isTwoHanded then
		local otherHand = (hand == "LeftHand") and "RightHand" or "LeftHand"
		if playerData.Hotbar[otherHand] == itemToMove then
			playerData.Hotbar[otherHand] = nil
		end
	end
	
	if not itemConfig then
		warn("[DataManager] ItemConfig not found for:", itemToMove.ItemID)
		return false
	end

	-- Конвертируем в таблицы для InventoryController
	local itemSizeVec = itemConfig.GridSize or Vector2.new(1, 1)
	local itemSize = {X = itemSizeVec.X, Y = itemSizeVec.Y}

	local inventorySizeVec = playerData.InventorySize or Vector2.new(8, 10)
	local inventorySize = {X = inventorySizeVec.X, Y = inventorySizeVec.Y}

	-- Получаем массив предметов
	local items = playerData.Inventory.Items or playerData.Inventory

	-- Если передана конкретная позиция - используем её
	if targetPosition then
		-- Проверяем можно ли разместить в эту позицию
		if not InventoryController.canPlaceItem(items, itemSize, targetPosition, inventorySize) then
			warn("[DataManager] Cannot place item at target position")
			sendNotification(player, "Cannot place item here", 3)
			return false
		end

		-- Используем целевую позицию
		itemToMove.Position = {X = targetPosition.X, Y = targetPosition.Y}
	else
		-- Ищем первое свободное место
		local availableSlot = InventoryController.findFirstAvailableSlot(items, itemSize, inventorySize)

		if not availableSlot then
			warn("[DataManager] No space in inventory")
			sendNotification(player, "Not enough space in inventory", 3)
			return false
		end

		itemToMove.Position = {X = availableSlot.X, Y = availableSlot.Y}
	end

	-- Добавляем GridSize
	itemToMove.GridSize = {X = itemSize.X, Y = itemSize.Y}

	-- Вставляем в правильное место
	if playerData.Inventory.Items then
		table.insert(playerData.Inventory.Items, itemToMove)
	else
		table.insert(playerData.Inventory, itemToMove)
	end

	if isTwoHanded then
		-- двуручный: гарантированно чистим обе руки
		playerData.Hotbar.LeftHand = nil
		playerData.Hotbar.RightHand = nil
	else
		-- обычный: чистим только ту руку, откуда вынесли
		playerData.Hotbar[hand] = nil
	end

	-- Обновляем атрибуты персонажа
	local character = player.Character
	if character then
		local leftID = playerData.Hotbar.LeftHand and playerData.Hotbar.LeftHand.ItemID or ""
		local rightID = playerData.Hotbar.RightHand and playerData.Hotbar.RightHand.ItemID or ""
		character:SetAttribute("HotbarLeftHand", leftID)
		character:SetAttribute("HotbarRightHand", rightID)
	end

	-- Снять модельку из руки
	local WeaponManager = require(script.Parent:WaitForChild("WeaponManager"))
	local handToUnequip = (isTwoHanded and "RightHand") or hand
	WeaponManager.UnequipWeaponFromHand(player, handToUnequip)

	--DataManager.SaveData(player)

	-- Отправляем обновленные данные клиенту
	LoadInventoryDataEvent:FireClient(player, {
		Inventory = playerData.Inventory,
		Equipment = playerData.Equipment,
		MoneySlot = playerData.MoneySlot,
		Hotbar = playerData.Hotbar
	})
	return true
end

function DataManager.MoveHotbarToEquipment(player, hotbarSlot, equipmentSlot)
	local playerData = DataManager.GetData(player)
	if not playerData then return false end

	--print("[DataManager] Moving from hotbar", hotbarSlot, "to equipment", equipmentSlot)

	local itemToMove = playerData.Hotbar[hotbarSlot]
	if not itemToMove then
		warn("[DataManager] No item in hotbar slot:", hotbarSlot)
		return false
	end

	local itemConfig = ItemsConfig[itemToMove.ItemID]
	if not itemConfig then
		warn("[DataManager] ItemConfig not found")
		return false
	end

	-- Проверка совместимости слота
	local isValidSlot = false
	if equipmentSlot:match("^Accessory%d$") and itemConfig.EquipSlot == "Accessory" then
		isValidSlot = true
	elseif equipmentSlot == itemConfig.EquipSlot then
		isValidSlot = true
	end

	if not isValidSlot then
		warn("[DataManager] Item cannot be equipped in this slot")
		sendNotification(player, "Cannot equip item here", 3)
		return false
	end

	-- Если слот занят, возвращаем предмет в инвентарь
	if playerData.Equipment[equipmentSlot] then
		local oldItem = playerData.Equipment[equipmentSlot]
		local itemSizeVec = itemConfig.GridSize or Vector2.new(1, 1)
		local itemSize = {X = itemSizeVec.X, Y = itemSizeVec.Y}
		local inventorySizeVec = playerData.InventorySize or Vector2.new(8, 10)
		local inventorySize = {X = inventorySizeVec.X, Y = inventorySizeVec.Y}
		local items = playerData.Inventory.Items or playerData.Inventory

		local availableSlot = InventoryController.findFirstAvailableSlot(items, itemSize, inventorySize)
		if not availableSlot then
			warn("[DataManager] No space for replaced item")
			sendNotification(player, "No space in inventory", 3)
			return false
		end

		oldItem.Position = {X = availableSlot.X, Y = availableSlot.Y}
		oldItem.GridSize = {X = itemSize.X, Y = itemSize.Y}

		if playerData.Inventory.Items then
			table.insert(playerData.Inventory.Items, oldItem)
		else
			table.insert(playerData.Inventory, oldItem)
		end
	end

	-- Экипируем из хотбара
	playerData.Equipment[equipmentSlot] = itemToMove
	playerData.Hotbar[hotbarSlot] = nil

	-- Обновляем атрибуты
	if player.Character then
		local leftID = playerData.Hotbar.LeftHand and playerData.Hotbar.LeftHand.ItemID or ""
		local rightID = playerData.Hotbar.RightHand and playerData.Hotbar.RightHand.ItemID or ""
		player.Character:SetAttribute("HotbarLeftHand", leftID)
		player.Character:SetAttribute("HotbarRightHand", rightID)
	end

	--DataManager.SaveData(player)

	LoadInventoryDataEvent:FireClient(player, {
		Inventory = playerData.Inventory,
		Equipment = playerData.Equipment,
		MoneySlot = playerData.MoneySlot,
		Hotbar = playerData.Hotbar
	})

	--print("[DataManager] Item moved from hotbar to equipment")
	return true
end

function DataManager.MoveEquipmentToHotbar(player, equipmentSlot, hotbarSlot)
	local playerData = DataManager.GetData(player)
	if not playerData then return false end

	--print("[DataManager] Moving from equipment", equipmentSlot, "to hotbar", hotbarSlot)

	local itemToMove = playerData.Equipment[equipmentSlot]
	if not itemToMove then
		warn("[DataManager] No item in equipment slot:", equipmentSlot)
		return false
	end

	local itemConfig = ItemsConfig[itemToMove.ItemID]
	if not itemConfig then
		warn("[DataManager] ItemConfig not found")
		return false
	end

	-- Если слот хотбара занят, возвращаем предмет в инвентарь
	if playerData.Hotbar[hotbarSlot] then
		local oldItem = playerData.Hotbar[hotbarSlot]
		local itemSizeVec = ItemsConfig[oldItem.ItemID].GridSize or Vector2.new(1, 1)
		local itemSize = {X = itemSizeVec.X, Y = itemSizeVec.Y}
		local inventorySizeVec = playerData.InventorySize or Vector2.new(8, 10)
		local inventorySize = {X = inventorySizeVec.X, Y = inventorySizeVec.Y}
		local items = playerData.Inventory.Items or playerData.Inventory

		local availableSlot = InventoryController.findFirstAvailableSlot(items, itemSize, inventorySize)
		if not availableSlot then
			warn("[DataManager] No space for replaced item")
			sendNotification(player, "No space in inventory", 3)
			return false
		end

		oldItem.Position = {X = availableSlot.X, Y = availableSlot.Y}
		oldItem.GridSize = {X = itemSize.X, Y = itemSize.Y}

		if playerData.Inventory.Items then
			table.insert(playerData.Inventory.Items, oldItem)
		else
			table.insert(playerData.Inventory, oldItem)
		end
	end

	-- Перемещаем в хотбар
	if itemConfig.IsTwoHanded then
		-- Проверяем что оба слота свободны
		if playerData.Hotbar.LeftHand or playerData.Hotbar.RightHand then
			warn("[DataManager] Both hands must be free for two-handed weapon")
			sendNotification(player, "Both hands must be free", 3)
			return false
		end
		playerData.Hotbar.LeftHand = itemToMove
		playerData.Hotbar.RightHand = itemToMove
	else
		playerData.Hotbar[hotbarSlot] = itemToMove
	end

	playerData.Equipment[equipmentSlot] = nil

	-- Обновляем атрибуты
	if player.Character then
		local leftID = playerData.Hotbar.LeftHand and playerData.Hotbar.LeftHand.ItemID or ""
		local rightID = playerData.Hotbar.RightHand and playerData.Hotbar.RightHand.ItemID or ""
		player.Character:SetAttribute("HotbarLeftHand", leftID)
		player.Character:SetAttribute("HotbarRightHand", rightID)
	end

	--DataManager.SaveData(player)

	LoadInventoryDataEvent:FireClient(player, {
		Inventory = playerData.Inventory,
		Equipment = playerData.Equipment,
		MoneySlot = playerData.MoneySlot,
		Hotbar = playerData.Hotbar
	})
	
	local WeaponManager = require(script.Parent:WaitForChild("WeaponManager"))
	local cfg = ItemsConfig[itemToMove.ItemID]
	if cfg and cfg.WeaponModel then
		local handForModel = (cfg.IsTwoHanded and "RightHand") or hotbarSlot
		WeaponManager.EquipWeaponToHand(player, itemToMove.ItemID, handForModel)
	end

	--print("[DataManager] Item moved from equipment to hotbar")
	return true
end

function DataManager.SwapHotbarAndEquipment(player, hotbarSlot, equipmentSlot)
	local playerData = DataManager.GetData(player)
	if not playerData then return false end

	--print("[DataManager] Swapping hotbar", hotbarSlot, "with equipment", equipmentSlot)

	local hotbarItem = playerData.Hotbar[hotbarSlot]
	local equipmentItem = playerData.Equipment[equipmentSlot]

	if not hotbarItem or not equipmentItem then
		warn("[DataManager] One or both slots are empty, cannot swap")
		return false
	end

	-- Проверяем совместимость
	local hotbarConfig = ItemsConfig[hotbarItem.ItemID]
	local equipConfig = ItemsConfig[equipmentItem.ItemID]

	if not hotbarConfig or not equipConfig then
		warn("[DataManager] Config not found")
		return false
	end

	-- Проверяем что предмет из хотбара может быть в этом слоте экипировки
	local canHotbarGoToEquip = false
	if equipmentSlot:match("^Accessory%d$") and hotbarConfig.EquipSlot == "Accessory" then
		canHotbarGoToEquip = true
	elseif equipmentSlot == hotbarConfig.EquipSlot then
		canHotbarGoToEquip = true
	end

	if not canHotbarGoToEquip then
		warn("[DataManager] Item from hotbar cannot be equipped in", equipmentSlot)
		sendNotification(player, "Cannot equip item in this slot", 3)
		return false
	end

	-- Меняем местами
	playerData.Hotbar[hotbarSlot] = equipmentItem
	playerData.Equipment[equipmentSlot] = hotbarItem

	-- Обновляем атрибуты
	if player.Character then
		local leftID = playerData.Hotbar.LeftHand and playerData.Hotbar.LeftHand.ItemID or ""
		local rightID = playerData.Hotbar.RightHand and playerData.Hotbar.RightHand.ItemID or ""
		player.Character:SetAttribute("HotbarLeftHand", leftID)
		player.Character:SetAttribute("HotbarRightHand", rightID)
	end

	--DataManager.SaveData(player)

	LoadInventoryDataEvent:FireClient(player, {
		Inventory = playerData.Inventory,
		Equipment = playerData.Equipment,
		MoneySlot = playerData.MoneySlot,
		Hotbar = playerData.Hotbar
	})

	--print("[DataManager] Items swapped successfully")
	return true
end

function DataManager.SwapHotbarSlots(player, slot1, slot2)
	local data = playerSessionData[player.UserId]
	if not data or not data.Hotbar then return end

	--print("[DataManager] Swapping hotbar slots:", slot1, "<->", slot2)

	local item1 = data.Hotbar[slot1]
	local item2 = data.Hotbar[slot2]

	-- ? ПРОВЕРКА НА ДВУРУЧНОЕ ОРУЖИЕ
	local config1 = item1 and ItemsConfig[item1.ItemID]
	local config2 = item2 and ItemsConfig[item2.ItemID]

	-- Если любой из предметов двуручный - блокируем обмен
	if (config1 and config1.IsTwoHanded) or (config2 and config2.IsTwoHanded) then
		--print("[DataManager] Cannot swap - two-handed weapon detected")
		sendNotification(player, "Cannot swap two-handed weapons", 3)

		-- Возвращаем данные для восстановления UI
		LoadInventoryDataEvent:FireClient(player, {
			Inventory = data.Inventory,
			Equipment = data.Equipment,
			MoneySlot = data.MoneySlot,
			Hotbar = data.Hotbar
		})
		return
	end

	-- Простой обмен местами
	data.Hotbar[slot1] = item2
	data.Hotbar[slot2] = item1

	-- ? ОБНОВЛЯЕМ АТРИБУТЫ
	updateHotbarAttributes(player)

	-- Переэкипируем оружие
	local WeaponManager = require(script.Parent:WaitForChild("WeaponManager"))

	-- Убираем старое оружие
	WeaponManager.UnequipWeaponFromHand(player, slot1)
	WeaponManager.UnequipWeaponFromHand(player, slot2)

	-- Экипируем новое
	local function equipVisual(item, targetHand)
		if not item then return end
		local cfg = ItemsConfig[item.ItemID]
		local hand = (cfg and cfg.IsTwoHanded) and "RightHand" or targetHand
		WeaponManager.EquipWeaponToHand(player, item.ItemID, hand)
	end

	equipVisual(item2, slot1)
	equipVisual(item1, slot2)

	-- Отправляем обновление
	LoadInventoryDataEvent:FireClient(player, {
		Inventory = data.Inventory,
		Equipment = data.Equipment,
		MoneySlot = data.MoneySlot,
		Hotbar = data.Hotbar
	})

	--print("[DataManager] Hotbar slots swapped successfully")
end


function DataManager.StackItems(player, sourceItemId, targetItemId)
	local data = playerSessionData[player.UserId]
	if not data then return end

	local sourceItem, sourceIndex
	local targetItem, targetIndex

	for i, item in ipairs(data.Inventory.Items) do
		if item.UniqueID == sourceItemId then
			sourceItem = item
			sourceIndex = i
		elseif item.UniqueID == targetItemId then
			targetItem = item
			targetIndex = i
		end
	end

	-- Проверяем, что оба предмета найдены, стакаются и одного типа
	if not sourceItem or not targetItem or sourceItem.ItemID ~= targetItem.ItemID then return end
	local config = ItemsConfig[sourceItem.ItemID]
	if not config or not config.IsStackable then return end

	-- Логика слияния
	local spaceInTarget = config.MaxStack - targetItem.Amount
	if spaceInTarget <= 0 then return end -- В целевом стаке нет места

	local amountToTransfer = math.min(sourceItem.Amount, spaceInTarget)

	targetItem.Amount = targetItem.Amount + amountToTransfer
	sourceItem.Amount = sourceItem.Amount - amountToTransfer

	-- Если исходный стак опустел, удаляем его
	if sourceItem.Amount <= 0 then
		table.remove(data.Inventory.Items, sourceIndex)
	end

	-- Отправляем обновленные данные клиенту
	local LoadInventoryDataEvent = ReplicatedStorage.Events.LoadInventoryDataEvent
	LoadInventoryDataEvent:FireClient(player, { 
		Inventory = data.Inventory, 
		MoneySlot = data.MoneySlot,
		Hotbar = data.Hotbar  -- ? ДОБАВЬ ЭТО
	})
end

function DataManager.SaveCharacter(player, slotIndex, characterData)
	local data = playerSessionData[player.UserId]
	if not data or not data.Characters then return end

	local slotStr = tostring(slotIndex)

	-- Проверяем, что слот открыт
	local isUnlocked = false
	for _, unlockedSlot in ipairs(data.UnlockedSlots) do
		if unlockedSlot == slotStr then
			isUnlocked = true
			break
		end
	end
	if not isUnlocked then return end

	-- Берём старого персонажа, если он уже был
	local oldChar = data.Characters[slotStr] or {}

	-- Копируем новые визуальные данные из редактора
	local newChar = deepCopy(characterData)

	-- ? Сохраняем его ИНВЕНТАРЬ/ЭКИП/ДЕНЬГИ/ХОТБАР, если они уже были у персонажа
	newChar.Inventory = deepCopy(oldChar.Inventory)
	newChar.Equipment = deepCopy(oldChar.Equipment)
	newChar.MoneySlot = deepCopy(oldChar.MoneySlot)
	newChar.Hotbar    = deepCopy(oldChar.Hotbar)

	-- Если слот был пустой – всё это останется nil, и позже
	-- SetCurrentCharacterSlot выдаст ему чистый инвентарь по getDefaultData()

	data.Characters[slotStr] = newChar

	LoadPlayerMenuDataEvent:FireClient(player, data)
end

function DataManager.DeleteCharacter(player,slotIndex) local data=playerSessionData[player.UserId] local slotStr=tostring(slotIndex) if not data or not data.Characters or not data.Characters[slotStr]then return end data.Characters[slotStr]=nil end

local MarketplaceService = game:GetService("MarketplaceService")

-- ID продукта > НОМЕР слота
local PRODUCT_IDS_TO_SLOTS = {
	[3398269699] = "2", -- продукт слота 2
	[3398270101] = "3", -- продукт слота 3
}

local function processReceipt(receiptInfo)
	local userId = receiptInfo.PlayerId
	local productId = receiptInfo.ProductId
	local player = Players:GetPlayerByUserId(userId)
	if not player then 
		return Enum.ProductPurchaseDecision.NotProcessedYet 
	end

	local slotToUnlock = PRODUCT_IDS_TO_SLOTS[productId]
	if not slotToUnlock then
		return Enum.ProductPurchaseDecision.PurchaseGranted
	end

	local data = playerSessionData[userId]
	if data and not table.find(data.UnlockedSlots, slotToUnlock) then
		table.insert(data.UnlockedSlots, slotToUnlock)
		LoadPlayerMenuDataEvent:FireClient(player, data)
	end

	return Enum.ProductPurchaseDecision.PurchaseGranted
end

MarketplaceService.ProcessReceipt = processReceipt

Players.PlayerRemoving:Connect(function(player)
	--print("[DataManager] Player leaving, saving data for:", player.Name)
	DataManager.SaveData(player)  -- Используем функцию с очисткой!
	playerSessionData[player.UserId] = nil
end)

function DataManager.UnequipItem(player, slotName, newPosition)
	local data = playerSessionData[player.UserId]
	if not data or not data.Equipment then 
		warn("[DataManager] UnequipItem: Missing data")
		return 
	end

	--print("[DataManager] UnequipItem called. Slot:", slotName, "NewPosition:", newPosition)

	local item = data.Equipment[slotName]
	if not item then 
		warn("[DataManager] UnequipItem: No item in slot:", slotName)
		return 
	end

	local config = ItemsConfig[item.ItemID]
	if not config then
		warn("[DataManager] UnequipItem: No config for item:", item.ItemID)
		return
	end

	-- Убираем предмет из слота экипировки
	data.Equipment[slotName] = nil
	--print("[DataManager] Item removed from equipment slot:", slotName)

	-- Если указана позиция - помещаем в конкретное место
	if newPosition then
		local canPlace = InventoryController.canPlaceItem(
			data.Inventory.Items, 
			item.GridSize, 
			newPosition, 
			data.Inventory.GridSize
		)

		if canPlace then
			item.Position = newPosition
			table.insert(data.Inventory.Items, item)
			--print("[DataManager] Item placed at specific position:", newPosition.X, newPosition.Y)
		else
			-- Если не можем поместить в указанное место, ищем любое свободное
			local autoPos = InventoryController.findFirstAvailableSlot(
				data.Inventory.Items, 
				item.GridSize, 
				data.Inventory.GridSize
			)

			if autoPos then
				item.Position = autoPos
				table.insert(data.Inventory.Items, item)
				--print("[DataManager] Item auto-placed at:", autoPos.X, autoPos.Y)
			else
				-- Возвращаем обратно в экипировку если нет места
				data.Equipment[slotName] = item
				warn("[DataManager] No space in inventory! Item returned to equipment")

				ShowNotificationEvent:FireClient(player, "Inventory is full!", 3)
			end
		end
	else
		-- Если позиция не указана - автоматически ищем место
		local autoPos = InventoryController.findFirstAvailableSlot(
			data.Inventory.Items, 
			item.GridSize, 
			data.Inventory.GridSize
		)

		if autoPos then
			item.Position = autoPos
			table.insert(data.Inventory.Items, item)
			--print("[DataManager] Item auto-placed at:", autoPos.X, autoPos.Y)
		else
			-- Возвращаем обратно в экипировку если нет места
			data.Equipment[slotName] = item
			warn("[DataManager] No space in inventory! Item returned to equipment")

			ShowNotificationEvent:FireClient(player, "Inventory is full!", 3)
		end
	end

	-- Отправляем обновленные данные клиенту
	LoadInventoryDataEvent:FireClient(player, {
		Inventory = data.Inventory,
		Equipment = data.Equipment,
		MoneySlot = data.MoneySlot,
		Hotbar = data.Hotbar
	})

	--print("[DataManager] UnequipItem completed")
end

function DataManager.DropFromSlot(player, slotType, slotName)
	local data = playerSessionData[player.UserId]
	if not data then return end

	local itemToDrop
	local Debris = game:GetService("Debris")

	-- Определяем откуда дропаем
	if slotType == "Money" or slotName == "Money" then
		-- Специальная обработка для денег
		if not data.MoneySlot or not data.MoneySlot.Amount or data.MoneySlot.Amount <= 0 then
			warn("[DataManager] No money to drop")
			return
		end

		local dropAmount = math.min(data.MoneySlot.Amount, 256)
		itemToDrop = {
			ItemID = "Money",
			Amount = dropAmount
		}

		data.MoneySlot.Amount = data.MoneySlot.Amount - dropAmount
		if data.MoneySlot.Amount <= 0 then
			data.MoneySlot = nil
		end

	elseif slotType == "Equipment" then
		itemToDrop = data.Equipment[slotName]
		if itemToDrop then
			data.Equipment[slotName] = nil
		end
	elseif slotType == "Hotbar" then
		itemToDrop = data.Hotbar[slotName]
		if itemToDrop then
			-- Для двуручного оружия
			local config = ItemsConfig[itemToDrop.ItemID]
			if config and config.IsTwoHanded then
				data.Hotbar.LeftHand = nil
				data.Hotbar.RightHand = nil
			else
				data.Hotbar[slotName] = nil
			end

			-- Снимаем оружие с персонажа
			local WeaponManager = require(script.Parent:WaitForChild("WeaponManager"))
			local cfg = itemToDrop and ItemsConfig[itemToDrop.ItemID]
			local handToUnequip = (cfg and cfg.IsTwoHanded) and "RightHand" or slotName
			WeaponManager.UnequipWeaponFromHand(player, handToUnequip)

			-- Обновляем атрибуты персонажа
			if player.Character then
				local leftItemID = data.Hotbar.LeftHand and data.Hotbar.LeftHand.ItemID or ""
				local rightItemID = data.Hotbar.RightHand and data.Hotbar.RightHand.ItemID or ""
				player.Character:SetAttribute("HotbarLeftHand", leftItemID)
				player.Character:SetAttribute("HotbarRightHand", rightItemID)
			end
		end
	end

	if not itemToDrop then return end

	-- Создаем лут в мире (используем существующую логику из DropItem)
	local character = player.Character
	if not character or not character.PrimaryPart then return end

	local lootContainer = workspace:FindFirstChild("LootContainer") or Instance.new("Folder", workspace)
	lootContainer.Name = "LootContainer"

	local dropCFrame = character.PrimaryPart.CFrame * CFrame.new(0, 0, -3)

	-- Создаем модель лута
	local modelToClone = ReplicatedStorage.Lootables.DefaultLootBag
	if modelToClone then
		local itemModel = modelToClone:Clone()
		itemModel:SetPrimaryPartCFrame(dropCFrame)
		itemModel.Parent = lootContainer

		itemModel:SetAttribute("ItemID", itemToDrop.ItemID)
		itemModel:SetAttribute("Amount", itemToDrop.Amount or 1)

		-- ?? ЕСЛИ ЭТО РЮКЗАК — СЕРИАЛИЗУЕМ ЕГО СОДЕРЖИМОЕ
		if itemToDrop.BackpackInventory then
			local ok, json = pcall(HttpService.JSONEncode, HttpService, itemToDrop.BackpackInventory)
			if ok then
				itemModel:SetAttribute("BackpackData", json)
			else
				warn("[DropFromSlot] Failed to JSONEncode BackpackInventory for", itemToDrop.ItemID, json)
			end
		end

		-- Обновляем ProximityPrompt
		local prompt = itemModel:FindFirstChild("BasePart", true):FindFirstChildOfClass("ProximityPrompt")
		if prompt then
			local itemName = ItemsConfig[itemToDrop.ItemID].Name or itemToDrop.ItemID
			prompt.ObjectText = string.format("%s (%d)", itemName, itemToDrop.Amount or 1)
		end

		Debris:AddItem(itemModel, 300)
	end

	-- Отправляем обновление клиенту
	LoadInventoryDataEvent:FireClient(player, {
		Inventory = data.Inventory,
		Equipment = data.Equipment,
		MoneySlot = data.MoneySlot,
		Hotbar = data.Hotbar
	})

	--DataManager.SaveData(player)

	local itemName = ItemsConfig[itemToDrop.ItemID].Name or itemToDrop.ItemID
	sendNotification(player, string.format("Dropped %s", itemName), 3)
	--print("[DataManager] Dropped", itemName, "from", slotType or "Unknown", slotName or "")
end


function DataManager.EquipItem(player, itemUniqueId, targetSlotOverride)
	--print("[DataManager] === EquipItem START ===")
	--print("[DataManager] Player:", player.Name, "ItemID:", itemUniqueId)

	local data = playerSessionData[player.UserId]
	if not data or not data.Inventory or not data.Equipment then
		warn("[DataManager] Missing player data")
		return
	end
	
	ensureInventoryStructure(data)
	
	-- Если предмет лежит в рюкзаке, сначала перемещаем его в инвентарь
	do
		local backpackItem, _, backpackCfg = getEquippedBackpack(data)
		if backpackItem and backpackItem.BackpackInventory and backpackItem.BackpackInventory.Items then
			local bItems = backpackItem.BackpackInventory.Items
			for i, item in ipairs(bItems) do
				if item.UniqueID == itemUniqueId then
					local cfg = ItemsConfig[item.ItemID]
					local sizeCfg = item.GridSize or (cfg and cfg.GridSize) or {X = 1, Y = 1}
					local itemSize = {X = sizeCfg.X, Y = sizeCfg.Y}

					local newPos = InventoryController.findFirstAvailableSlot(
						data.Inventory.Items,
						itemSize,
						data.Inventory.GridSize
					)

					if not newPos then
						sendNotification(player, "No space in inventory to equip from backpack", 3)
						return
					end

					item.Position = {X = newPos.X, Y = newPos.Y}
					table.insert(data.Inventory.Items, item)
					table.remove(bItems, i)
					break
				end
			end
		end
	end

	-- Находим предмет в инвентаре
	local itemToEquip, itemIndex = nil, nil
	for i, item in ipairs(data.Inventory.Items) do
		if item.UniqueID == itemUniqueId then
			itemToEquip = item
			itemIndex = i
			break
		end
	end

	if not itemToEquip then
		warn("[DataManager] Item not found:", itemUniqueId)
		return
	end

	--print("[DataManager] ? Found item:", itemToEquip.ItemID)

	local config = ItemsConfig[itemToEquip.ItemID]
	if not config then
		warn("[DataManager] Config not found for:", itemToEquip.ItemID)
		return
	end

	--print("[DataManager] ? Config found")

	if not config.EquipSlot then
		warn("[DataManager] Item is not equippable:", itemToEquip.ItemID)
		return
	end

	--print("[DataManager] ? EquipSlot:", config.EquipSlot)

	-- Определяем целевой слот
	local targetSlotName
	if targetSlotOverride then
		targetSlotName = targetSlotOverride
	else
		if config.EquipSlot == "Accessory" then
			-- Для аксессуаров ищем первый свободный слот
			for i = 1, 3 do
				local slotName = "Accessory" .. i
				if not data.Equipment[slotName] then
					targetSlotName = slotName
					break
				end
			end
			if not targetSlotName then
				targetSlotName = "Accessory1" -- По умолчанию первый слот
			end
		else
			targetSlotName = config.EquipSlot
		end
	end

	--print("[DataManager] Target slot:", targetSlotName)

	-- ? ВАЛИДАЦИЯ: Проверяем соответствие типа предмета целевому слоту
	local function isValidSlotForItem(itemEquipSlot, targetSlot)
		-- Для аксессуаров
		if targetSlot:match("^Accessory%d$") then
			return itemEquipSlot == "Accessory"
		end

		-- Для остальных слотов - прямое совпадение
		if targetSlot == "Armor" then
			return itemEquipSlot == "Armor"
		elseif targetSlot == "Clothing" then
			return itemEquipSlot == "Clothing"
		elseif targetSlot == "Money" then
			return itemEquipSlot == "Money"
		end

		return false
	end

	-- Проверяем валидность
	if not isValidSlotForItem(config.EquipSlot, targetSlotName) then
		warn("[DataManager] ? Cannot equip", itemToEquip.ItemID, "to slot", targetSlotName)
		warn("[DataManager] Item requires slot type:", config.EquipSlot, "but target is:", targetSlotName)
		sendNotification(player, "This item cannot be equipped in this slot", 3)
		return
	end

	--print("[DataManager] ? Slot validation passed")
	
	-- === ОГРАНИЧЕНИЕ: ТОЛЬКО 1 РЮКЗАК В АКСЕССУАРАХ ===
	local isBackpack = config.ExpansionSize ~= nil

	if isBackpack and targetSlotName:match("^Accessory%d$") then
		for i = 1, 3 do
			local slotName = "Accessory" .. i

			-- Проверяем ТОЛЬКО другие слоты аксессуаров
			if slotName ~= targetSlotName then
				local equipped = data.Equipment[slotName]
				if equipped and equipped.ItemID then
					local eqConfig = ItemsConfig[equipped.ItemID]
					if eqConfig and eqConfig.ExpansionSize then
						--print("[DataManager] ? Attempt to equip second backpack in accessories")
						sendNotification(player, "The backpack is already equipped with accessories", 3)
						return
					end
				end
			end
		end
	end


	-- ---- СПЕЦИАЛЬНАЯ ЛОГИКА ДЛЯ ДЕНЕГ ----
	if itemToEquip.ItemID == "Money" and targetSlotName == "Money" then
		local MAX_MONEY_STACK = 1024
		local currentlyEquippedItem = data.Equipment.Money

		-- Специальная логика для денег
		if config.EquipSlot == "Money" then
			local MONEY_SLOT_LIMIT = 1024

			if data.MoneySlot then
				-- Слот занят - складываем с проверкой лимита
				local currentAmount = data.MoneySlot.Amount
				local amountToAdd = itemToEquip.Amount
				local newTotal = currentAmount + amountToAdd

				if newTotal <= MONEY_SLOT_LIMIT then
					-- Всё влезает
					data.MoneySlot.Amount = newTotal
					table.remove(data.Inventory.Items, itemIndex)
					--print("[DataManager] Money stacked. Total:", data.MoneySlot.Amount)
				else
					-- Превышает лимит - кладём сколько влезает, остаток остаётся
					local overflow = newTotal - MONEY_SLOT_LIMIT
					data.MoneySlot.Amount = MONEY_SLOT_LIMIT
					itemToEquip.Amount = overflow
					sendNotification(player, string.format("Money slot full! %d credits remain in inventory", overflow), 3)
					--print("[DataManager] Money slot full. Remaining in inventory:", overflow)
				end
			else
				-- Слот пуст - проверяем не превышает ли лимит
				if itemToEquip.Amount <= MONEY_SLOT_LIMIT then
					data.MoneySlot = itemToEquip
					table.remove(data.Inventory.Items, itemIndex)
					--print("[DataManager] Money placed in slot. Amount:", itemToEquip.Amount)
				else
					-- Превышает лимит - кладём максимум, остаток остаётся
					local overflow = itemToEquip.Amount - MONEY_SLOT_LIMIT
					data.MoneySlot = {
						ItemID = "Money",
						Amount = MONEY_SLOT_LIMIT
					}
					itemToEquip.Amount = overflow
					sendNotification(player, string.format("Money slot full! %d credits remain in inventory", overflow), 3)
					--print("[DataManager] Money slot full. Remaining in inventory:", overflow)
				end
			end

			-- ? КРИТИЧНО: Отправляем обновление с MoneySlot!
			LoadInventoryDataEvent:FireClient(player, {
				Inventory = data.Inventory,
				Equipment = data.Equipment,
				MoneySlot = data.MoneySlot,  -- < Убедись что это есть!
				Hotbar = data.Hotbar
			})

			--print("[DataManager] === EquipItem END (Money) ===")
			return  -- < ВАЖНО: Выходим здесь для денег
		end
		-- ---- ОБЫЧНАЯ ЛОГИКА ДЛЯ ОСТАЛЬНЫХ ПРЕДМЕТОВ ----
	else
		local currentlyEquippedItem = data.Equipment[targetSlotName]

		if currentlyEquippedItem then
			-- Меняем местами
			--print("[DataManager] Slot occupied, swapping...")
			local originalPosition = itemToEquip.Position

			local canPlace = InventoryController.canPlaceItem(
				data.Inventory.Items,
				currentlyEquippedItem.GridSize,
				originalPosition,
				data.Inventory.GridSize,
				itemToEquip.UniqueID
			)

			if canPlace then
				table.remove(data.Inventory.Items, itemIndex)
				currentlyEquippedItem.Position = originalPosition
				table.insert(data.Inventory.Items, currentlyEquippedItem)
				data.Equipment[targetSlotName] = itemToEquip
				--print("[DataManager] ? Items swapped successfully")
			else
				-- Ищем новое место
				local newPos = InventoryController.findFirstAvailableSlot(
					data.Inventory.Items,
					currentlyEquippedItem.GridSize,
					data.Inventory.GridSize
				)

				if newPos then
					table.remove(data.Inventory.Items, itemIndex)
					currentlyEquippedItem.Position = newPos
					table.insert(data.Inventory.Items, currentlyEquippedItem)
					data.Equipment[targetSlotName] = itemToEquip
					--print("[DataManager] ? Found new position for old item")
				else
					sendNotification(player, "No space in inventory for swap", 3)
					return
				end
			end
		else
			-- Слот пустой
			--print("[DataManager] Slot empty, equipping...")
			data.Equipment[targetSlotName] = itemToEquip
			table.remove(data.Inventory.Items, itemIndex)
			--print("[DataManager] ? Item equipped successfully")
		end
	end

	-- Отправляем обновление
	LoadInventoryDataEvent:FireClient(player, {
		Inventory = data.Inventory,
		Equipment = data.Equipment,
		MoneySlot = data.MoneySlot,  -- ? ДОБАВЛЕНО
		Hotbar = data.Hotbar
	})

	--print("[DataManager] === EquipItem END ===")
end

function DataManager.UnequipMoney(player)
	local data = playerSessionData[player.UserId]
	if not data or not data.MoneySlot or not data.MoneySlot.Amount or data.MoneySlot.Amount <= 0 then
		warn("[DataManager] No money in slot for player:", player.Name)
		sendNotification(player, "Money slot is empty", 3)
		return
	end

	local WITHDRAW_AMOUNT = 256
	local amountToWithdraw = math.min(data.MoneySlot.Amount, WITHDRAW_AMOUNT)

	local position = InventoryController.findFirstAvailableSlot(
		data.Inventory.Items, 
		{X = 1, Y = 1}, 
		data.Inventory.GridSize
	)

	if not position then
		sendNotification(player, "Inventory is full", 3)
		return
	end

	local newMoneyStack = {
		UniqueID = generateUniqueID(),
		ItemID = "Money",
		GridSize = {X = 1, Y = 1},
		Amount = amountToWithdraw,
		Position = position,
		Rotation = 0
	}

	table.insert(data.Inventory.Items, newMoneyStack)

	data.MoneySlot.Amount = data.MoneySlot.Amount - amountToWithdraw
	if data.MoneySlot.Amount <= 0 then
		data.MoneySlot = nil
	end

	LoadInventoryDataEvent:FireClient(player, {
		Inventory = data.Inventory,
		Equipment = data.Equipment,
		MoneySlot = data.MoneySlot,
		Hotbar = data.Hotbar
	})

	sendNotification(player, string.format("Withdrew %d credits", amountToWithdraw), 3)
	--DataManager.SaveData(player)
	--print("[DataManager] Withdrawn", amountToWithdraw, "credits from MoneySlot")
end

function DataManager.StartMoneyDrag(player)
	local data = playerSessionData[player.UserId]
	if not data or not data.MoneySlot or not data.MoneySlot.Amount or data.MoneySlot.Amount <= 0 then
		warn("[DataManager] Cannot drag - no money in slot")
		return
	end

	local WITHDRAW_AMOUNT = 256
	local amountToDrag = math.min(data.MoneySlot.Amount, WITHDRAW_AMOUNT)

	data.MoneySlot.Amount = data.MoneySlot.Amount - amountToDrag
	if data.MoneySlot.Amount <= 0 then
		data.MoneySlot = nil
	end

	local draggedMoney = {
		UniqueID = generateUniqueID(),
		ItemID = "Money",
		GridSize = {X = 1, Y = 1},
		Amount = amountToDrag,
		Rotation = 0,
		IsDragging = true
	}

	LoadInventoryDataEvent:FireClient(player, {
		Inventory = data.Inventory,
		Equipment = data.Equipment,
		MoneySlot = data.MoneySlot,
		Hotbar = data.Hotbar,
		DraggedMoney = draggedMoney
	})

	--print("[DataManager] Started dragging", amountToDrag, "credits from MoneySlot")
	return draggedMoney
end

function DataManager.CancelMoneyDrag(player, draggedMoneyData)
	local data = playerSessionData[player.UserId]
	if not data or not draggedMoneyData then return end

	if not data.MoneySlot then
		data.MoneySlot = {
			ItemID = "Money",
			Amount = 0
		}
	end

	data.MoneySlot.Amount = data.MoneySlot.Amount + draggedMoneyData.Amount

	LoadInventoryDataEvent:FireClient(player, {
		Inventory = data.Inventory,
		Equipment = data.Equipment,
		MoneySlot = data.MoneySlot,
		Hotbar = data.Hotbar
	})

	--print("[DataManager] Cancelled money drag, returned", draggedMoneyData.Amount, "to slot")
end

function DataManager.FinishMoneyDrag(player, draggedMoneyData, targetPosition)
	local data = playerSessionData[player.UserId]
	if not data or not draggedMoneyData or not targetPosition then return end

	local canPlace = InventoryController.canPlaceItem(
		data.Inventory.Items,
		{X = 1, Y = 1},
		targetPosition,
		data.Inventory.GridSize
	)

	if canPlace then
		local newMoneyStack = {
			UniqueID = generateUniqueID(),
			ItemID = "Money",
			GridSize = {X = 1, Y = 1},
			Amount = draggedMoneyData.Amount,
			Position = targetPosition,
			Rotation = 0
		}

		table.insert(data.Inventory.Items, newMoneyStack)
		--print("[DataManager] Placed", draggedMoneyData.Amount, "credits in inventory at", targetPosition.X, targetPosition.Y)
	else
		DataManager.CancelMoneyDrag(player, draggedMoneyData)
		sendNotification(player, "Cannot place item here", 3)
	end

	LoadInventoryDataEvent:FireClient(player, {
		Inventory = data.Inventory,
		Equipment = data.Equipment,
		MoneySlot = data.MoneySlot,
		Hotbar = data.Hotbar
	})

	--DataManager.SaveData(player)
end


function DataManager.SwapEquipmentSlots(player, slot1, slot2)
	local data = playerSessionData[player.UserId]
	if not data or not data.Equipment then return end

	--print("[DataManager] Swapping equipment slots:", slot1, "<->", slot2)

	local item1 = data.Equipment[slot1]
	local item2 = data.Equipment[slot2]

	-- ? ВАЛИДАЦИЯ: Проверяем соответствие типа предмета целевому слоту
	local function isValidSlotForItem(itemEquipSlot, targetSlot)
		if not itemEquipSlot or not targetSlot then return false end

		-- Для аксессуаров
		if targetSlot:match("^Accessory%d$") then
			return itemEquipSlot == "Accessory"
		end

		-- Для остальных слотов - прямое совпадение
		if targetSlot == "Armor" then
			return itemEquipSlot == "Armor"
		elseif targetSlot == "Clothing" then
			return itemEquipSlot == "Clothing"
		elseif targetSlot == "Money" then
			return itemEquipSlot == "Money"
		end

		return false
	end

	-- Если один слот пустой - просто перемещаем
	if item1 and not item2 then
		local config1 = ItemsConfig[item1.ItemID]
		if not isValidSlotForItem(config1.EquipSlot, slot2) then
			warn("[DataManager] ? Cannot move", item1.ItemID, "from", slot1, "to", slot2)
			sendNotification(player, "This item cannot be equipped in this slot", 3)
			return
		end

		data.Equipment[slot2] = item1
		data.Equipment[slot1] = nil
		--print("[DataManager] ? Moved item from", slot1, "to", slot2)

	elseif item2 and not item1 then
		local config2 = ItemsConfig[item2.ItemID]
		if not isValidSlotForItem(config2.EquipSlot, slot1) then
			warn("[DataManager] ? Cannot move", item2.ItemID, "from", slot2, "to", slot1)
			sendNotification(player, "This item cannot be equipped in this slot", 3)
			return
		end

		data.Equipment[slot1] = item2
		data.Equipment[slot2] = nil
		--print("[DataManager] ? Moved item from", slot2, "to", slot1)

	elseif item1 and item2 then
		-- Оба слота заняты - проверяем возможность обмена
		local config1 = ItemsConfig[item1.ItemID]
		local config2 = ItemsConfig[item2.ItemID]

		if not isValidSlotForItem(config1.EquipSlot, slot2) or not isValidSlotForItem(config2.EquipSlot, slot1) then
			warn("[DataManager] ? Cannot swap - incompatible equipment types")
			warn("[DataManager]", item1.ItemID, "requires", config1.EquipSlot, "but slot2 is", slot2)
			warn("[DataManager]", item2.ItemID, "requires", config2.EquipSlot, "but slot1 is", slot1)
			sendNotification(player, "Cannot swap - incompatible item types", 3)
			return
		end

		data.Equipment[slot1] = item2
		data.Equipment[slot2] = item1
		--print("[DataManager] ? Swapped items between slots")
	else
		--print("[DataManager] Both slots are empty")
		return
	end

	-- Отправляем обновление
	LoadInventoryDataEvent:FireClient(player, {
		Inventory = data.Inventory,
		Equipment = data.Equipment,
		MoneySlot = data.MoneySlot,  -- ? ДОБАВЛЕНО
		Hotbar = data.Hotbar
	})
end

function DataManager.SwapEquipment(player, slot1, slot2)
	local data = playerSessionData[player.UserId]
	if not data or not data.Equipment then return end

	--print("[DataManager] Swapping equipment slots:", slot1, "<->", slot2)

	local item1 = data.Equipment[slot1]
	local item2 = data.Equipment[slot2]

	-- Проверяем что оба предмета существуют
	if not item1 or not item2 then
		warn("[DataManager] Cannot swap - one or both slots are empty")
		return
	end

	local config1 = ItemsConfig[item1.ItemID]
	local config2 = ItemsConfig[item2.ItemID]

	-- Проверяем что предметы могут быть в этих слотах
	local function canEquipInSlot(config, slotName)
		if not config or not config.EquipSlot then return false end

		if config.EquipSlot == "Accessory" then
			return slotName:match("Accessory%d+")
		else
			return config.EquipSlot == slotName
		end
	end

	if not canEquipInSlot(config1, slot2) or not canEquipInSlot(config2, slot1) then
		--print("[DataManager] Cannot swap - incompatible equipment types")
		sendNotification(player, "Cannot swap these items", 3)

		LoadInventoryDataEvent:FireClient(player, {
			Inventory = data.Inventory,
			Equipment = data.Equipment,
			MoneySlot = data.MoneySlot,
			Hotbar = data.Hotbar
		})
		return
	end

	-- Меняем местами
	data.Equipment[slot1] = item2
	data.Equipment[slot2] = item1

	-- Отправляем обновление
	LoadInventoryDataEvent:FireClient(player, {
		Inventory = data.Inventory,
		Equipment = data.Equipment,
		MoneySlot = data.MoneySlot,
		Hotbar = data.Hotbar
	})

	--print("[DataManager] Equipment slots swapped successfully")
end

-- Подключаем события в самом конце файла
-- Подключаем все события
local MoveItemEvent = Events:WaitForChild("MoveItemEvent", 5)
if MoveItemEvent then
	MoveItemEvent.OnServerEvent:Connect(DataManager.MoveItem)
	--print("[DataManager] MoveItemEvent connected")
end

local StackItemsEvent = Events:WaitForChild("StackItemsEvent", 5)
if StackItemsEvent then
	StackItemsEvent.OnServerEvent:Connect(DataManager.StackItems)
	--print("[DataManager] StackItemsEvent connected")
end

-- ? ДОБАВЬ ЭТО ЕСЛИ ЕГО НЕТ
local EquipItemEvent = Events:WaitForChild("EquipItemEvent", 5)
if EquipItemEvent then
	EquipItemEvent.OnServerEvent:Connect(DataManager.EquipItem)
	--print("[DataManager] EquipItemEvent connected")
else
	warn("[DataManager] ?? EquipItemEvent not found!")
end

local MoveItemToSlotEvent = Events:WaitForChild("MoveItemToSlotEvent", 5)
if MoveItemToSlotEvent then
	MoveItemToSlotEvent.OnServerEvent:Connect(DataManager.MoveItemBetweenSlotAndInventory)
	--print("[DataManager] MoveItemToSlotEvent connected")
end

local MoveItemToHotbarEvent = Events:WaitForChild("MoveItemToHotbarEvent", 5)
if MoveItemToHotbarEvent then
	MoveItemToHotbarEvent.OnServerEvent:Connect(DataManager.MoveItemToHotbar)
	--print("[DataManager] MoveItemToHotbarEvent connected")
end

local MoveItemFromHotbarEvent = Events:WaitForChild("MoveItemFromHotbarEvent", 5)
if MoveItemFromHotbarEvent then
	MoveItemFromHotbarEvent.OnServerEvent:Connect(DataManager.MoveItemFromHotbar)
	--print("[DataManager] MoveItemFromHotbarEvent connected")
end

local SwapHotbarSlotsEvent = Events:WaitForChild("SwapHotbarSlotsEvent", 5)
if SwapHotbarSlotsEvent then
	SwapHotbarSlotsEvent.OnServerEvent:Connect(DataManager.SwapHotbarSlots)
	--print("[DataManager] SwapHotbarSlotsEvent connected")
end

local UnequipItemEvent = Events:WaitForChild("UnequipItemEvent", 5)
if UnequipItemEvent then
	UnequipItemEvent.OnServerEvent:Connect(DataManager.UnequipItem)
	--print("[DataManager] UnequipItemEvent connected")
end

local SwapEquipmentEvent = Events:WaitForChild("SwapEquipmentEvent", 5)
if SwapEquipmentEvent then
	SwapEquipmentEvent.OnServerEvent:Connect(DataManager.SwapEquipmentSlots)
end

local DropItemEvent = Events:WaitForChild("DropItemEvent", 5)
if DropItemEvent then
	DropItemEvent.OnServerEvent:Connect(DataManager.DropItem)
	--print("[DataManager] DropItemEvent connected")
end

local DropFromSlotEvent = Events:WaitForChild("DropFromSlotEvent", 5)
if DropFromSlotEvent then
	DropFromSlotEvent.OnServerEvent:Connect(DataManager.DropFromSlot)
	--print("[DataManager] DropFromSlotEvent connected")
end

local UnequipMoneyEvent = Events:WaitForChild("UnequipMoneyEvent", 5)
if UnequipMoneyEvent then
	UnequipMoneyEvent.OnServerEvent:Connect(DataManager.UnequipMoney)
	--print("[DataManager] UnequipMoneyEvent connected")
end

local StartMoneyDragEvent = Events:WaitForChild("StartMoneyDragEvent", 5)
if StartMoneyDragEvent then
	StartMoneyDragEvent.OnServerEvent:Connect(DataManager.StartMoneyDrag)
	--print("[DataManager] StartMoneyDragEvent connected")
end

local CancelMoneyDragEvent = Events:WaitForChild("CancelMoneyDragEvent", 5)
if CancelMoneyDragEvent then
	CancelMoneyDragEvent.OnServerEvent:Connect(DataManager.CancelMoneyDrag)
	--print("[DataManager] CancelMoneyDragEvent connected")
end

local FinishMoneyDragEvent = Events:WaitForChild("FinishMoneyDragEvent", 5)
if FinishMoneyDragEvent then
	FinishMoneyDragEvent.OnServerEvent:Connect(DataManager.FinishMoneyDrag)
	--print("[DataManager] FinishMoneyDragEvent connected")
end

local MoveHotbarToEquipmentEvent = Events:WaitForChild("MoveHotbarToEquipmentEvent", 5)
if MoveHotbarToEquipmentEvent then
	MoveHotbarToEquipmentEvent.OnServerEvent:Connect(DataManager.MoveHotbarToEquipment)
	--print("[DataManager] MoveHotbarToEquipmentEvent connected")
end


local MoveEquipmentToHotbarEvent = Events:WaitForChild("MoveEquipmentToHotbarEvent", 5)
if MoveEquipmentToHotbarEvent then
	MoveEquipmentToHotbarEvent.OnServerEvent:Connect(DataManager.MoveEquipmentToHotbar)
	--print("[DataManager] MoveEquipmentToHotbarEvent connected")
end

local SwapHotbarAndEquipmentEvent = Events:WaitForChild("SwapHotbarAndEquipmentEvent", 5)
if SwapHotbarAndEquipmentEvent then
	SwapHotbarAndEquipmentEvent.OnServerEvent:Connect(DataManager.SwapHotbarAndEquipment)
	--print("[DataManager] SwapHotbarAndEquipmentEvent connected")
end

local MoveItemToBackpackEvent = Events:WaitForChild("MoveItemToBackpackEvent", 5)
if MoveItemToBackpackEvent then
	MoveItemToBackpackEvent.OnServerEvent:Connect(DataManager.MoveItemToBackpack)
	--print("[DataManager] MoveItemToBackpackEvent connected")
end

local MoveBackpackItemEvent = Events:WaitForChild("MoveBackpackItemEvent", 5)
if MoveBackpackItemEvent then
	MoveBackpackItemEvent.OnServerEvent:Connect(DataManager.MoveBackpackItem)
	--print("[DataManager] MoveBackpackItemEvent connected")
end

local MoveItemFromBackpackEvent = Events:WaitForChild("MoveItemFromBackpackEvent", 5)
if MoveItemFromBackpackEvent then
	MoveItemFromBackpackEvent.OnServerEvent:Connect(DataManager.MoveItemFromBackpack)
	--print("[DataManager] MoveItemFromBackpackEvent connected")
end

return DataManager