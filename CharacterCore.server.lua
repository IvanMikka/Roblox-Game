-- ServerScriptService/CharacterCore.server.lua
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local CoreShared = require(ReplicatedStorage:WaitForChild("CharacterCore.shared"))
local serverState = {} -- [player] = CoreShared.new()

local CoreServer = {}

local function get(plr)
	serverState[plr] = serverState[plr] or CoreShared.new()
	return serverState[plr]
end

function CoreServer.AttachCharacter(plr, char)
	-- на старте сбрасываем флаги в валидное состо€ние
	char:SetAttribute("IsBlocking", char:GetAttribute("IsBlocking") or false)
	char:SetAttribute("IsStunned", char:GetAttribute("IsStunned") or false)
	char:SetAttribute("IsChargingHeavy", false)
	-- lockout только в серверном state (без атрибута)
end

function CoreServer.Can(plr, action)
	return CoreShared.can(get(plr), action)
end

function CoreServer.BeginAttack(plr, opts)
	local s = get(plr)
	CoreShared.beginAttack(s, opts)
	-- дублировать атрибут IsAttacking не будем Ч у теб€ его нет в использовании; хватает lockout и текущих флагов
end

function CoreServer.EndAttack(plr)
	CoreShared.endAttack(get(plr))
end

function CoreServer.SetFlag(plr, char, attr, value)
	-- ≈дина€ точка записи серверных флагов
	if attr == "IsBlocking" or attr == "IsStunned" or attr == "IsChargingHeavy" then
		char:SetAttribute(attr, value and true or false)
	end
	CoreShared.setFlag(get(plr), attr == "IsBlocking" and "isBlocking"
		or attr == "IsStunned" and "isStunned"
		or attr == "IsChargingHeavy" and "isChargingHeavy", value)
end

function CoreServer.SetLockout(plr, seconds)
	CoreShared.setLockout(get(plr), seconds)
end

_G.CharacterCoreServer = CoreServer

Players.PlayerAdded:Connect(function(plr)
	plr.CharacterAdded:Connect(function(char)
		CoreServer.AttachCharacter(plr, char)
	end)
end)
