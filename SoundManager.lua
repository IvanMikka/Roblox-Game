-- SoundManager (ModuleScript в ServerScriptService)
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local SoundEvent = ReplicatedStorage:WaitForChild("Events"):WaitForChild("SoundEvent")

local SoundManager = {}

local SOUND_BROADCAST_RADIUS = 60

--[[
	Проигрывает звук для всех игроков в радиусе от источника.
	- soundName: Название звука (ключ из таблицы SOUND_IDS в CombatSystemClient).
	- sourcePart: Часть, от которой будет исходить звук (например, Torso атакующего).
]]
function SoundManager.broadcastSound(soundName, sourcePart)
	if not sourcePart then return end

	local sourcePos = sourcePart.Position
	for _, player in ipairs(Players:GetPlayers()) do
		local character = player.Character
		if character and character.PrimaryPart then
			local distance = (character.PrimaryPart.Position - sourcePos).Magnitude
			if distance <= SOUND_BROADCAST_RADIUS then
				SoundEvent:FireClient(player, soundName, sourcePart)
			end
		end
	end
end

return SoundManager