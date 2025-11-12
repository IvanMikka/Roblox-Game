-- ReplicatedStorage/CharacterCore.shared.lua
local Core = {}

function Core.new()
	return {
		activeRight = nil,          -- ID предмета в правой руке (для удобства клиента)
		isAttacking = false,        -- единый флаг «идёт атака»
		isBlocking  = false,        -- состояние блока (читается движением/боем)
		isStunned   = false,        -- оглушение
		isChargingHeavy = false,    -- подготовка тяжёлой атаки
		lockoutUntil = 0,           -- жёсткий лок-аут (например, во время анимации удара/дэша)
	}
end

local function now() return os.clock() end

function Core.setActiveRight(state, itemId)
	state.activeRight = itemId
end

function Core.getActiveRight(state)
	return state.activeRight
end

function Core.setLockout(state, seconds)
	state.lockoutUntil = math.max(state.lockoutUntil or 0, now() + (seconds or 0))
end

function Core.inLockout(state)
	return now() < (state.lockoutUntil or 0)
end

function Core.setFlag(state, key, value)
	state[key] = value and true or false
end

function Core.can(state, action)
	-- Без сложной логики: только базовые гейты
	if action == "Light" or action == "Heavy" then
		if state.isStunned or state.isBlocking or Core.inLockout(state) then return false end
		return true
	elseif action == "BlockStart" then
		if state.isStunned or Core.inLockout(state) then return false end
		return true
	elseif action == "BlockEnd" then
		return true
	elseif action == "SwapRight" then
		if state.isAttacking then return false end
		return true
	else
		-- по умолчанию разрешаем
		return true
	end
end

-- Хелперы для начала/завершения атаки без стамины
function Core.beginAttack(state, opts)
	state.isAttacking = true
	if opts and opts.recovery then
		Core.setLockout(state, opts.recovery)
	end
end

function Core.endAttack(state)
	state.isAttacking = false
end

return Core