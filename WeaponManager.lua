-- WeaponManager (ModuleScript в ServerScriptService) - v3.0 (Оптимизированная версия)
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ItemsConfig = require(ReplicatedStorage:WaitForChild("ItemsConfig"))

local WeaponManager = {}

-- =================================================================
-- КОНФИГУРАЦИЯ ОТЛАДКИ
-- =================================================================
local DEBUG_MODE = false -- Установи в true для диагностики

local function debugPrint(...)
	if DEBUG_MODE then
		print("[WeaponManager]", ...)
	end
end

-- =================================================================
-- ЭКИПИРОВКА ОРУЖИЯ
-- =================================================================
function WeaponManager.EquipWeaponToHand(player, itemID, hand)
	debugPrint("=== START EQUIP ===")
	debugPrint("Player:", player.Name, "ItemID:", itemID, "Hand:", hand)

	local character = player.Character
	if not character then 
		warn("[WeaponManager] Character not found for player:", player.Name)
		return 
	end

	local config = ItemsConfig[itemID]
	if not config then 
		warn("[WeaponManager] Config not found for:", itemID)
		return 
	end

	if not config.WeaponModel then
		debugPrint("Item has no WeaponModel defined:", itemID)
		return
	end

	local weaponsFolder = ReplicatedStorage:FindFirstChild("Weapons")
	if not weaponsFolder then
		warn("[WeaponManager] Weapons folder not found in ReplicatedStorage")
		return
	end

	local weaponModel = weaponsFolder:FindFirstChild(config.WeaponModel)
	if not weaponModel then
		warn("[WeaponManager] Weapon model not found:", config.WeaponModel)
		if DEBUG_MODE then
			print("[WeaponManager] Available weapons:")
			for _, child in ipairs(weaponsFolder:GetChildren()) do
				print("  -", child.Name, child.ClassName)
			end
		end
		return
	end

	-- Удаляем существующее оружие если есть
	local existingWeapon = character:FindFirstChild("Equipped_" .. hand)
	if existingWeapon then
		existingWeapon:Destroy()
		debugPrint("Removed old weapon from", hand)
	end

	-- Клонируем новое оружие
	local clonedWeapon = weaponModel:Clone()
	clonedWeapon.Name = "Equipped_" .. hand

	-- Находим руку персонажа
	local handPart
	if hand == "LeftHand" then
		handPart = character:FindFirstChild("Left Arm") or character:FindFirstChild("LeftHand")
	else
		handPart = character:FindFirstChild("Right Arm") or character:FindFirstChild("RightHand")
	end

	if not handPart then
		warn("[WeaponManager] Hand part not found for:", hand)
		if DEBUG_MODE then
			print("[WeaponManager] Character parts:")
			for _, part in ipairs(character:GetChildren()) do
				if part:IsA("BasePart") then
					print("  -", part.Name)
				end
			end
		end
		clonedWeapon:Destroy()
		return
	end

	-- Находим Handle оружия
	local handle = clonedWeapon:FindFirstChild("Handle")
	if not handle then
		warn("[WeaponManager] Handle not found in weapon model:", config.WeaponModel)
		if DEBUG_MODE then
			print("[WeaponManager] Weapon children:")
			for _, child in ipairs(clonedWeapon:GetChildren()) do
				print("  -", child.Name, child.ClassName)
			end
		end
		clonedWeapon:Destroy()
		return
	end

	-- Создаем Motor6D для прикрепления оружия
	local grip = Instance.new("Motor6D")
	grip.Name = "RightGrip"
	grip.Part0 = handPart
	grip.Part1 = handle
	grip.C0 = CFrame.new(0, -1, 0) * CFrame.Angles(math.rad(270), 0, 0)
	grip.C1 = CFrame.new()
	grip.Parent = handPart

	clonedWeapon.Parent = character

	debugPrint("? SUCCESS! Equipped", itemID, "to", hand)
	debugPrint("=== END EQUIP ===")
end

-- =================================================================
-- СНЯТИЕ ОРУЖИЯ
-- =================================================================
function WeaponManager.UnequipWeaponFromHand(player, hand)
	local character = player.Character
	if not character then return end

	-- Удаляем оружие
	local weapon = character:FindFirstChild("Equipped_" .. hand)
	if weapon then
		weapon:Destroy()
		debugPrint("Unequipped weapon from", hand)
	end

	-- КРИТИЧНО: Удаляем Motor6D из руки
	local handPart
	if hand == "LeftHand" then
		handPart = character:FindFirstChild("Left Arm") or character:FindFirstChild("LeftHand")
	else
		handPart = character:FindFirstChild("Right Arm") or character:FindFirstChild("RightHand")
	end

	if handPart then
		local grip = handPart:FindFirstChild("RightGrip")
		if grip then
			grip:Destroy()
			debugPrint("Removed grip from", hand)
		end
	end
end

function WeaponManager.UnequipAllWeapons(player)
	WeaponManager.UnequipWeaponFromHand(player, "LeftHand")
	WeaponManager.UnequipWeaponFromHand(player, "RightHand")
	debugPrint("Unequipped all weapons for", player.Name)
end

debugPrint("? Initialized | Debug mode:", DEBUG_MODE and "ON" or "OFF")

return WeaponManager