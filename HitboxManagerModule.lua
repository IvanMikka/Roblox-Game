-- HitboxManagerModule (ModuleScript) - v9.1 (Исправлено обнаружение)
local HitboxManager = {}

local HITBOX_CONFIG = {
	{ Name = "HeadHitbox",     Size = Vector3.new(1.2, 1.2, 1.2), Offset = CFrame.new(0, 1.5, 0), MeleeMultiplier = 1.5, ShotMultiplier = 2.0 },
	{ Name = "TorsoHitbox",    Size = Vector3.new(2.2, 2.2, 1.2), Offset = CFrame.new(0, 0, 0), MeleeMultiplier = 1.0, ShotMultiplier = 1.0 },
	{ Name = "LeftArmHitbox",  Size = Vector3.new(1, 2, 1),       Offset = CFrame.new(-1.5, 0, 0), MeleeMultiplier = 0.8, ShotMultiplier = 0.8 },
	{ Name = "RightArmHitbox", Size = Vector3.new(1, 2, 1),       Offset = CFrame.new(1.5, 0, 0), MeleeMultiplier = 0.8, ShotMultiplier = 0.8 },
	{ Name = "LeftLegHitbox",  Size = Vector3.new(1, 2, 1),       Offset = CFrame.new(-0.5, -2, 0), MeleeMultiplier = 0.7, ShotMultiplier = 0.7 },
	{ Name = "RightLegHitbox", Size = Vector3.new(1, 2, 1),       Offset = CFrame.new(0.5, -2, 0), MeleeMultiplier = 0.7, ShotMultiplier = 0.7 }
}

local function createHitbox(character, properties)
	local rootPart = character:WaitForChild("HumanoidRootPart")
	if not rootPart then return nil end

	local part = Instance.new("Part")
	part.Name = properties.Name
	part.Size = properties.Size
	part.Transparency = 0.7 
	part.Color = Color3.fromRGB(0, 255, 255)
	part.Material = Enum.Material.ForceField
	part.CanCollide = false

	-- =======================================================
	-- ИЗМЕНЕНИЕ ЗДЕСЬ:
	-- Разрешаем "радарам" (Raycast, GetPartBoundsInBox) видеть этот хитбокс.
	part.CanQuery = true 
	-- =======================================================

	part.CanTouch = false 
	part.Anchored = false
	part.Massless = true

	part:SetAttribute("DamageMultiplierMelee", properties.MeleeMultiplier or 1)
	part:SetAttribute("DamageMultiplierShot", properties.ShotMultiplier or 1)

	local weld = Instance.new("Weld")
	weld.Part0 = rootPart
	weld.Part1 = part
	weld.C0 = properties.Offset
	weld.Parent = part
	return part
end

function HitboxManager.SetupForCharacter(character)
	if not character or not character:FindFirstChild("Humanoid") or character:FindFirstChild("HitboxContainer") then return end
	print("[HitboxManager] Создание хитбоксов для", character.Name)

	local container = Instance.new("Model")
	container.Name = "HitboxContainer"

	for _, properties in ipairs(HITBOX_CONFIG) do
		local hitbox = createHitbox(character, properties)
		if hitbox then hitbox.Parent = container end
	end

	container.Parent = character
end

-- Этот блок не трогаем, он правильно отслеживает появление персонажей
local function initialize()
	for _, descendant in ipairs(workspace:GetDescendants()) do
		if descendant:IsA("Model") and descendant:FindFirstChildOfClass("Humanoid") then
			task.spawn(HitboxManager.SetupForCharacter, descendant)
		end
	end

	workspace.DescendantAdded:Connect(function(descendant)
		if descendant:IsA("Model") and descendant:FindFirstChildOfClass("Humanoid") then
			task.wait()
			HitboxManager.SetupForCharacter(descendant)
		end
	end)
end

initialize()

return HitboxManager