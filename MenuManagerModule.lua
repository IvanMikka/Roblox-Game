-- MenuManagerModule (ModuleScript) - v8.2 (Защищенный)
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
local ServerScriptService = game:GetService("ServerScriptService")

local DataManager = require(ServerScriptService:WaitForChild("DataManager"))

local Events = ReplicatedStorage:WaitForChild("Events")
local MenuMannequins = workspace:WaitForChild("Menu"):WaitForChild("MenuMannequins")
local Config = require(ReplicatedStorage:WaitForChild("AssetsConfig"))
local LoadPlayerMenuDataEvent = Events:WaitForChild("LoadPlayerMenuData")
local DeleteCharacterEvent = Events:WaitForChild("DeleteCharacterEvent")

local MenuManager = {}
local charactersToLoad = {}

-- ProcessCharacter и GetCharacterToLoad остаются без изменений
function MenuManager.ProcessCharacter(character, state)
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	if not humanoid then return end
	local description = Instance.new("HumanoidDescription")
	description.HairAccessory = ""; description.FaceAccessory = ""; description.NeckAccessory = ""
	description.ShouldersAccessory = ""; description.FrontAccessory = ""; description.BackAccessory = ""
	description.WaistAccessory = ""; description.HatAccessory = ""
	description.Head = 0; description.Torso = 0; description.LeftArm = 0
	description.RightArm = 0; description.LeftLeg = 0; description.RightLeg = 0
	local bodyColor = Color3.fromRGB(196, 196, 196)
	description.HeadColor = bodyColor; description.TorsoColor = bodyColor
	description.LeftArmColor = bodyColor; description.RightArmColor = bodyColor
	description.LeftLegColor = bodyColor; description.RightLegColor = bodyColor
	if state and state.gender then
		local bodyPartIds = Config.BodyParts
		local clothingIds = Config.Clothing[state.gender]
		description.FaceAccessory = tostring(Config.BodyParts.FaceAccessory)
		description.Shirt = tonumber(clothingIds.ShirtTemplate:match("%d+"))
		description.Pants = tonumber(clothingIds.PantsTemplate:match("%d+"))
		description.Torso = (state.gender == "Male") and bodyPartIds.MaleTorso or bodyPartIds.FemaleTorso
		if state.hairIndex and Config.Hair[state.gender] and Config.Hair[state.gender][state.hairIndex] then
			description.HairAccessory = tostring(Config.Hair[state.gender][state.hairIndex])
		end
	end
	humanoid:ApplyDescription(description)
	if not character:FindFirstChild("AppearanceLoaded") then
		Instance.new("BoolValue", character).Name = "AppearanceLoaded"
	end
end
function MenuManager.GetCharacterToLoad(userId)
	if charactersToLoad[userId] then
		local data = charactersToLoad[userId]
		charactersToLoad[userId] = nil
		return data
	end
	return nil
end
-- =================================================================
-- ИЗМЕНЕНИЕ: "Пуленепробиваемая" версия функции
-- =================================================================
function MenuManager.PrepareCharacterToLoad(player, slotIndex)
	local playerData = DataManager.GetData(player)

	-- ДИАГНОСТИКА И ЗАЩИТА:
	if not playerData then
		warn("[MenuManager] ОШИБКА: Не удалось получить данные для " .. player.Name .. ". Персонаж будет стандартным.")
		charactersToLoad[player.UserId] = nil
		return
	end

	-- ЗАЩИТА №2: Если в данных почему-то нет таблицы Characters, игра не сломается.
	if not playerData.Characters then
		warn("[MenuManager] ПРЕДУПРЕЖДЕНИЕ: В данных игрока " .. player.Name .. " отсутствует таблица 'Characters'. Персонаж будет стандартным.")
		charactersToLoad[player.UserId] = nil
		return
	end

	-- Теперь код полностью безопасен
	local slotStr = tostring(slotIndex)
	if playerData.Characters[slotStr] then
		print("[MenuManager] Подготовка персонажа из слота " .. slotStr .. " для " .. player.Name)
		charactersToLoad[player.UserId] = playerData.Characters[slotStr]
	else
		print("[MenuManager] Данные в слоте " .. slotStr .. " не найдены. Подготовка стандартного персонажа.")
		charactersToLoad[player.UserId] = nil
	end
end

-- Обработчики событий остаются без изменений
Events.UpdateMannequin.OnServerEvent:Connect(function(player, slotIndex, state)
	local mannequin = MenuMannequins:FindFirstChild("Slot" .. slotIndex .. "_Mannequin")
	if mannequin then
		MenuManager.ProcessCharacter(mannequin, state)
	end
end)
Events.SaveCharacter.OnServerEvent:Connect(function(player, slotIndex, characterData)
	DataManager.SaveCharacter(player, slotIndex, characterData)
end)
DeleteCharacterEvent.OnServerEvent:Connect(function(player, slotIndex)
	DataManager.DeleteCharacter(player, slotIndex)
	local mannequin = MenuMannequins:FindFirstChild("Slot" .. slotIndex .. "_Mannequin")
	if mannequin then
		MenuManager.ProcessCharacter(mannequin, nil)
	end
	local updatedData = DataManager.GetData(player)
	if updatedData then
		LoadPlayerMenuDataEvent:FireClient(player, updatedData)
	end
end)

return MenuManager