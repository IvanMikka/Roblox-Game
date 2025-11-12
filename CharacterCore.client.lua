-- StarterPlayerScripts/CharacterCore.client.lua
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local CoreShared = require(ReplicatedStorage:WaitForChild("CharacterCore.shared"))
local player = Players.LocalPlayer
local state = CoreShared.new()

-- Удобные геттеры/сеттеры для других локальных скриптов
local CoreClient = {}

function CoreClient.AttachCharacter(char)
	-- Синхронизируем существующие атрибуты в локальное состояние
	local function syncAttr(name, flag)
		local v = char:GetAttribute(name)
		if v ~= nil then CoreShared.setFlag(state, flag, v) end
		char:GetAttributeChangedSignal(name):Connect(function()
			CoreShared.setFlag(state, flag, char:GetAttribute(name))
		end)
	end

	syncAttr("IsBlocking", "isBlocking")
	syncAttr("IsStunned",  "isStunned")
	syncAttr("IsChargingHeavy", "isChargingHeavy")

	-- Активная правая рука (для клиента: помогает выбирать профиль анимаций/ударов)
	local function syncRight()
		local id = char:GetAttribute("HotbarRightHand")
		CoreShared.setActiveRight(state, id)
	end
	syncRight()
	char:GetAttributeChangedSignal("HotbarRightHand"):Connect(syncRight)
end

function CoreClient.Can(action)
	return CoreShared.can(state, action)
end

function CoreClient.BeginAttack(opts) -- opts.recovery
	CoreShared.beginAttack(state, opts)
	-- На клиенте флаг IsAttacking дублировать не обязательно, но можно для визуала
	-- (не трогаем атрибуты, их ставит сервер или существующие скрипты)
end

function CoreClient.EndAttack()
	CoreShared.endAttack(state)
end

function CoreClient.InLockout()
	return CoreShared.inLockout(state)
end

function CoreClient.ActiveRight()
	return CoreShared.getActiveRight(state)
end

-- Экспортируем в _G для простого подключения из существующих скриптов
_G.CharacterCoreClient = CoreClient

-- Привязка к персонажу
player.CharacterAdded:Connect(CoreClient.AttachCharacter)
if player.Character then CoreClient.AttachCharacter(player.Character) end
