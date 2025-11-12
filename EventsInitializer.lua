-- EventsInitializer (Script в ServerScriptService)
-- ÷ентрализованное создание всех игровых событий
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Events = ReplicatedStorage:WaitForChild("Events")

local eventsToCreate = {
	-- Equipment Events
	"EquipItemEvent",
	"UnequipItemEvent", 
	"SwapEquipmentEvent",

	-- Hotbar Events
	"MoveItemFromHotbarEvent",
	"MoveItemToHotbarEvent",
	"SwapHotbarSlotsEvent",
	"MoveHotbarToEquipmentEvent",
	"MoveEquipmentToHotbarEvent",
	"SwapHotbarAndEquipmentEvent",  -- ? ƒќЅј¬№
	
	-- Inventory Events
	"DropItemEvent",
	"DropFromSlotEvent",
	"SplitItemStackEvent",
	"MoveItemEvent",
	"StackItemsEvent",
	"MoveItemToSlotEvent",

	-- Money Events
	"UnequipMoneyEvent",
	"StartMoneyDragEvent",
	"CancelMoneyDragEvent",
	"FinishMoneyDragEvent"
}

for _, eventName in ipairs(eventsToCreate) do
	if not Events:FindFirstChild(eventName) then
		local event = Instance.new("RemoteEvent")
		event.Name = eventName
		event.Parent = Events
		print("[EventsInitializer] Created:", eventName)
	else
		print("[EventsInitializer] Already exists:", eventName)
	end
end

print("[EventsInitializer] ? All events initialized successfully")