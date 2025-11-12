-- ReplicatedStorage/StatusTabsUI.lua (DEBUG)
-- ПРАВЫЙ КРАЙ, без таймеров. Пишет подробные логи.

local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")
local RunService = game:GetService("RunService")

local DEBUG = true
local function log(...)
	if DEBUG then print("[StatusTabsUI]", ...) end
end
local function warnlog(...)
	warn("[StatusTabsUI]", ...)
end

local M = {}

-- === LAYOUT ===
local TAB_SIZE = UDim2.new(0, 252, 0, 60)

-- Важно: POS2 и POS3 ДОЛЖНЫ быть < 1, иначе таб не виден.
local POS1 = UDim2.new(2, 0, 0.043, 0)  -- off-screen to the right
local POS2 = UDim2.new(1.12, 0, 0.043, 0) -- auto slide-in on appear
local POS3 = UDim2.new(1, 0, 0.043, 0)    -- further in on hover

local BASE_Y = 0.043
local ROW_STEP = 0.086

local ICON_POS  = UDim2.new(0.02, 0, 0.09, 0)
local ICON_SIZE = UDim2.new(0, 50, 0, 50)

local DETAIL_POS  = UDim2.new(0.338, 0, 0.09, 0)
local DETAIL_SIZE = UDim2.new(0, 159, 0, 49)

local APPEAR_TWEEN = TweenInfo.new(0.35, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
local HOVER_TWEEN  = TweenInfo.new(0.25, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)

local WOBBLE_TIME = 0.45
local WOBBLE_PIX  = 6

local TAB_COLOR  = Color3.fromRGB(38, 38, 38)
local TAB_ALPHA  = 0.45
local TEXT_WHITE = Color3.new(1,1,1)
local TEXT_BLACK = Color3.new(0,0,0)

-- STATE
local screenGui = nil
local tabs = {}   -- [key] = {root, icon, details, isHover}
local order = {}

local function ensureGui(player)
	if screenGui then return end
	screenGui = Instance.new("ScreenGui")
	screenGui.Name = "StatusTabs"
	screenGui.IgnoreGuiInset = true
	screenGui.ResetOnSpawn = false
	screenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
	screenGui.Parent = player:WaitForChild("PlayerGui")
	log("ScreenGui created & parented to PlayerGui")
end

local function withStroke(label)
	label.TextColor3 = TEXT_WHITE
	label.TextStrokeColor3 = TEXT_BLACK
	label.TextStrokeTransparency = 0
end

local function findIndex(t, val)
	for i, v in ipairs(t) do if v == val then return i end end
	return nil
end

local function layoutTabs()
	for i, key in ipairs(order) do
		local tab = tabs[key]
		if tab and tab.root and tab.root.Parent then
			local y = BASE_Y + (i - 1) * ROW_STEP
			local target = tab.isHover and UDim2.new(POS3.X.Scale, POS3.X.Offset, y, 0)
				or  UDim2.new(POS2.X.Scale, POS2.X.Offset, y, 0)
			TweenService:Create(tab.root, APPEAR_TWEEN, { Position = target }):Play()
			log(("layout %s -> y=%.3f pos=(%.3f, %d)"):format(key, y, target.X.Scale, target.X.Offset))
		end
	end
end

local function wobble(tab)
	local root = tab.root
	local base = root.Position
	local t0 = os.clock()
	local conn; conn = RunService.Heartbeat:Connect(function()
		local dt = os.clock() - t0
		if dt >= WOBBLE_TIME then
			root.Position = base
			conn:Disconnect()
			return
		end
		local k = math.sin((dt / WOBBLE_TIME) * math.pi)
		local off = math.floor(WOBBLE_PIX * k)
		root.Position = UDim2.new(base.X.Scale, base.X.Offset + off, base.Y.Scale, base.Y.Offset)
	end)
end

local function buildTab(key, name, desc, iconId)
	log("buildTab:", key, name)
	local tab = { isHover = false }

	local root = Instance.new("Frame")
	root.Name = "Tab_" .. key
	root.Size = TAB_SIZE
	root.AnchorPoint = Vector2.new(1, 0) -- ПРАВЫЙ край
	root.Position = POS1
	root.BackgroundColor3 = TAB_COLOR
	root.BackgroundTransparency = TAB_ALPHA
	root.Active = true
	root.ClipsDescendants = true
	root.ZIndex = 10

	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 10)
	corner.Parent = root

	local icon = Instance.new("ImageLabel")
	icon.Name = "Icon"
	icon.BackgroundTransparency = 1
	icon.Image = iconId or ""
	icon.Size = ICON_SIZE
	icon.Position = ICON_POS
	icon.ZIndex = root.ZIndex + 1
	icon.Parent = root

	local details = Instance.new("TextLabel")
	details.Name = "Details"
	details.BackgroundTransparency = 1
	details.TextXAlignment = Enum.TextXAlignment.Left
	details.TextYAlignment = Enum.TextYAlignment.Top
	details.Font = Enum.Font.Gotham
	details.TextSize = 18
	withStroke(details)
	details.Size = DETAIL_SIZE
	details.Position = DETAIL_POS
	details.ZIndex = root.ZIndex + 1
	details.TextWrapped = true
	details.Visible = true
	details.Parent = root

	root.MouseEnter:Connect(function()
		local idx = findIndex(order, key)
		if not idx then return end
		local y = BASE_Y + (idx - 1) * ROW_STEP
		tab.isHover = true
		local target = UDim2.new(POS3.X.Scale, POS3.X.Offset, y, 0)
		TweenService:Create(root, HOVER_TWEEN, { Position = target }):Play()
		log("hover ->", key, ("pos=(%.3f,%d)"):format(target.X.Scale, target.X.Offset))
	end)

	root.MouseLeave:Connect(function()
		local idx = findIndex(order, key)
		if not idx then return end
		local y = BASE_Y + (idx - 1) * ROW_STEP
		tab.isHover = false
		local target = UDim2.new(POS2.X.Scale, POS2.X.Offset, y, 0)
		TweenService:Create(root, HOVER_TWEEN, { Position = target }):Play()
		log("unhover ->", key, ("pos=(%.3f,%d)"):format(target.X.Scale, target.X.Offset))
	end)

	tab.root = root
	tab.icon = icon
	tab.details = details
	return tab
end

-- PUBLIC
-- data: { name? = string, description? = string, iconId? = string }
function M.Show(player, key, data)
	if (POS2.X.Scale >= 1) then
		warnlog("POS2.X.Scale >= 1 > таб будет невидим! Сейчас:", POS2.X.Scale)
	end
	if (POS3.X.Scale >= 1) then
		warnlog("POS3.X.Scale >= 1 > таб не уйдёт внутрь при ховере. Сейчас:", POS3.X.Scale)
	end

	ensureGui(player)
	local name = (data and data.name) or key
	local desc = (data and data.description) or ""
	local iconId = (data and data.iconId) or ""

	if not tabs[key] then
		tabs[key] = buildTab(key, name, desc, iconId)
		table.insert(order, key)
		tabs[key].root.Parent = screenGui

		local idx = #order
		local y = BASE_Y + (idx - 1) * ROW_STEP
		tabs[key].root.Position = UDim2.new(POS1.X.Scale, POS1.X.Offset, y, 0)
		local target = UDim2.new(POS2.X.Scale, POS2.X.Offset, y, 0)
		TweenService:Create(tabs[key].root, APPEAR_TWEEN, { Position = target }):Play()
		log(("SHOW '%s' at y=%.3f > slide POS1->POS2 (%.3f>%.3f)"):format(key, y, POS1.X.Scale, POS2.X.Scale))
		wobble(tabs[key])
	else
		-- обновить иконку при повторном Show
		tabs[key].icon.Image = iconId
		log("REFRESH icon for", key)
	end

	local text = (desc ~= "" and (name .. " — " .. desc)) or name
	tabs[key].details.Text = text
	layoutTabs()
end

function M.Hide(key)
	local tab = tabs[key]
	if not tab then return end
	log("HIDE", key)

	local t = TweenService:Create(tab.root, APPEAR_TWEEN, { Position = POS1 })
	t.Completed:Connect(function()
		if tab.root and tab.root.Parent then tab.root:Destroy() end
	end)
	t:Play()

	tabs[key] = nil
	local idx = findIndex(order, key)
	if idx then table.remove(order, idx) end
	layoutTabs()
end

return M
