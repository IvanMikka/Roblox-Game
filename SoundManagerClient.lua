-- SoundManagerClient (ModuleScript)
local SoundManager = {}

local function createSound(id, looped, volume)
	local sound = Instance.new("Sound")
	sound.SoundId = "rbxassetid://" .. id
	sound.Looped = looped or false
	sound.Volume = volume or 0.8
	return sound
end

SoundManager.AmbientMusic1 = createSound("1838457617", true, 0.7)
SoundManager.AmbientMusic2 = createSound("5270218400", true, 0.7)
SoundManager.LightSwitchOn = createSound("156221488")
SoundManager.CurtainOpen = createSound("9114020474")
SoundManager.ButtonHover = createSound("9080070218")
SoundManager.StartGameClick = createSound("136442624750684")
SoundManager.SlotHoverEnter = createSound("9120484699")
SoundManager.SlotHoverLeave = createSound("6593042054")

function SoundManager.Init(parent)
	for name, sound in pairs(SoundManager) do
		if typeof(sound) == "Instance" then
			sound.Parent = parent
		end
	end
end

return SoundManager