-- InventoryController (ModuleScript в ServerScriptService) - v2.0 (Работает с таблицами)
local InventoryController = {}

function InventoryController.canPlaceItem(items, itemSize, position, gridSize, itemToIgnore)
	if position.X < 1 or position.Y < 1 then return false end
	if (position.X + itemSize.X - 1) > gridSize.X then return false end
	if (position.Y + itemSize.Y - 1) > gridSize.Y then return false end

	local newItemRect = {
		x1 = position.X, y1 = position.Y,
		x2 = position.X + itemSize.X - 1, y2 = position.Y + itemSize.Y - 1
	}

	for _, existingItem in pairs(items) do
		
		-- Пропускаем битые предметы без Position
		if not existingItem.Position then
			warn("[InventoryController] Found item without Position:", existingItem.ItemID or "unknown")
			continue
		end
		
		if not (itemToIgnore and existingItem.UniqueID == itemToIgnore) then
			local existingItemRect = {
				x1 = existingItem.Position.X, y1 = existingItem.Position.Y,
				x2 = existingItem.Position.X + existingItem.GridSize.X - 1,
				y2 = existingItem.Position.Y + existingItem.GridSize.Y - 1
			}
			if (newItemRect.x1 <= existingItemRect.x2 and newItemRect.x2 >= existingItemRect.x1) and
				(newItemRect.y1 <= existingItemRect.y2 and newItemRect.y2 >= existingItemRect.y1) then
				return false
			end
		end
	end
	return true
end

function InventoryController.findFirstAvailableSlot(items, itemSize, gridSize)
	for y = 1, gridSize.Y do
		for x = 1, gridSize.X do
			local currentPosition = {X = x, Y = y} -- **ИЗМЕНЕНО:** Возвращаем таблицу
			if InventoryController.canPlaceItem(items, itemSize, currentPosition, gridSize) then
				return currentPosition
			end
		end
	end
	return nil
end

return InventoryController