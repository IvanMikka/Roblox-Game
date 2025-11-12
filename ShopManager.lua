-- ShopManager (ModuleScript) - v1.0
-- Управляет внутриигровыми покупками
local MarketplaceService = game:GetService("MarketplaceService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Player = Players.LocalPlayer
local PurchaseSlotEvent = ReplicatedStorage:WaitForChild("Events"):WaitForChild("PurchaseSlotEvent")

local ShopManager = {}

-- =================================================================
-- ВАЖНО: Вставь сюда ID своих Developer Products
-- =================================================================
local PRODUCT_IDS = {
	["2"] = 3398269699, -- <-- ID продукта для слота 2
	["3"] = 3398270101  -- <-- ID продукта для слота 3
}

-- Функция, которая будет вызываться из Main.lua
function ShopManager.PurchaseSlot(slotIndex)
	local productId = PRODUCT_IDS[tostring(slotIndex)]
	if not productId or productId == 0 then
		warn("Неверный ID продукта для слота: " .. slotIndex)
		return
	end

	print("Попытка покупки продукта с ID: " .. productId)

	-- Показываем игроку стандартное окно покупки Roblox
	local success, message = pcall(function()
		MarketplaceService:PromptProductPurchase(Player, productId)
	end)

	if not success then
		warn("Ошибка при вызове окна покупки: " .. message)
	end
end

return ShopManager