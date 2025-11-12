local Players = game:GetService("Players")

local START_BLOOD = 100
local REGEN_PERIOD = 1.5   -- сек
local REGEN_STEP = 1       -- +1 за тик

-- === BLEED CONFIG (форма "линейный градиент" от peak к 0, площадь = targetTotal) ===
local BLEED = {
	-- tier = {durationSec, targetTotal, peakPerSecForShape}
	[1] = {60,  15, 2}, -- 1 мин, снять 15, градиент 2>0 (будет масштабирован)
	[2] = {120, 50, 2},
	[3] = {180, 80, 4},
	[4] = {60, 100, 7},
	[5] = {30, 100, 7},
}

-- Активные кровотечения по персонажам
local activeBleeds = {}  -- [character] = { {tier=..., t=0, dur=..., peak=..., k=..., started=os.clock()}, ... }

local RunService = game:GetService("RunService")

-- ЕДИНЫЕ (глобальные для скрипта) переменные тикера кровотечений
local bleedTickerStarted = false
local bleedAcc = 0

local function startBleedTicker()
	if bleedTickerStarted then return end
	bleedTickerStarted = true

	RunService.Heartbeat:Connect(function(dt)
		bleedAcc += dt
		if bleedAcc < 1 then return end
		bleedAcc -= 1

		for char, list in pairs(activeBleeds) do
			if not char or not char.Parent then
				activeBleeds[char] = nil
			else
				local totalLoss = 0
				for _, b in ipairs(list) do
					if b.t < b.dur then
						local shape = 1 - (b.t / b.dur)
						local r = b.peak * b.k * math.max(0, shape)
						totalLoss += r
						b.t += 1
					end
				end
				-- очистить окончившиеся стаки
				for i = #list, 1, -1 do
					if list[i].t >= list[i].dur then table.remove(list, i) end
				end
				-- применить суммарные потери
				if totalLoss > 0 then
					local blood = char:GetAttribute("Blood") or START_BLOOD
					blood = math.max(0, blood - totalLoss)
					char:SetAttribute("Blood", blood)
				end
				-- флаг IsBleeding
				local on = (list and #list > 0) or false
				if char:GetAttribute("IsBleeding") ~= on then
					char:SetAttribute("IsBleeding", on)
				end
			end
		end
	end)
end

-- Подсчёт текущей скорости потери крови для одной записи bleed (на секунду)
local function bleedRateNow(b)
	-- линейный спад: rate(t) = peak*k*(1 - t/dur), t?[0,dur]
	if b.t >= b.dur then return 0 end
	local shape = math.max(0, 1 - (b.t / b.dur))
	return b.peak * b.k * shape
end

-- Поддержка атрибутов
local function setBleedingAttr(char)
	local list = activeBleeds[char]
	local on = (list and #list > 0) or false
	if char:GetAttribute("IsBleeding") ~= on then
		char:SetAttribute("IsBleeding", on)
	end
end

-- Публичный API для других серверных скриптов
_G.Blood = _G.Blood or {}
_G.Blood.ApplyBleed = function(targetChar, tier)
	if not targetChar or not targetChar.Parent then return end
	local cfg = BLEED[tier]
	if not cfg then return end

	activeBleeds[targetChar] = activeBleeds[targetChar] or {}

	-- если 5 стаков: выбросить самый "слабый и старый"
	local list = activeBleeds[targetChar]
	if #list >= 5 then
		-- найти минимальный tier в списке
		local minTier = math.huge
		for _,b in ipairs(list) do minTier = math.min(minTier, b.tier) end
		-- собрать кандидатов с этим tier
		local candidates = {}
		for i,b in ipairs(list) do
			if b.tier == minTier then table.insert(candidates, {idx=i, started=b.started}) end
		end
		-- среди кандидатов удалить самый старый (минимальный started)
		table.sort(candidates, function(a,b) return a.started < b.started end)
		table.remove(list, candidates[1].idx)
	end
	
	

	-- добавить новую запись
	local dur, total, peakShape = cfg[1], cfg[2], cfg[3]
	-- масштаб, чтобы площадь под треугольником = total: total = (peak* k * dur)/2 => k = 2*total/(peak*dur)
	local k = (peakShape > 0 and (2*total)/(peakShape*dur)) or 0
	table.insert(list, {
		tier = tier, t = 0, dur = dur, peak = peakShape, k = k, started = os.clock()
	})
	setBleedingAttr(targetChar)
	
	startBleedTicker()

end

local function applyCollapseFlags(char, blood)
	if not char then return end
	-- <7: коллапс (обездвижен), <=0: смерть
	char:SetAttribute("IsCollapsed", blood < 7)
	if blood <= 0 then
		local hum = char:FindFirstChildOfClass("Humanoid")
		if hum and hum.Health > 0 then hum:TakeDamage(hum.MaxHealth) end
	end
end

local function attachCharacter(plr, char)
	-- Инициализация атрибутов
	if char:GetAttribute("Blood") == nil then char:SetAttribute("Blood", START_BLOOD) end
	if char:GetAttribute("IsBleeding") == nil then char:SetAttribute("IsBleeding", false) end
	-- На всякий случай очищаем таблицу стаков для этого персонажа (новый инстанс)
	activeBleeds[char] = {}
	char:SetAttribute("Blood", START_BLOOD)
	char:SetAttribute("IsBleeding", false)

	applyCollapseFlags(char, char:GetAttribute("Blood"))

	-- Серверный реген крови
	task.spawn(function()
		while char.Parent do
			task.wait(REGEN_PERIOD)
			local bleeding = char:GetAttribute("IsBleeding")
			local blood = char:GetAttribute("Blood") or START_BLOOD
			if bleeding then continue end
			if blood < 100 then
				blood = math.min(100, blood + REGEN_STEP)
				char:SetAttribute("Blood", blood)
				applyCollapseFlags(char, blood)
			end
		end
	end)

	-- На всякий случай: при ручном изменении Blood где-то ещё
	char:GetAttributeChangedSignal("Blood"):Connect(function()
		local b = char:GetAttribute("Blood") or 0
		applyCollapseFlags(char, b)
	end)
	
	-- При удалении персонажа очищаем его кровотечения
	char.AncestryChanged:Connect(function(_, parent)
		if not parent then
			activeBleeds[char] = nil
		end
	end)

end

Players.PlayerAdded:Connect(function(plr)
	plr.CharacterAdded:Connect(function(char) attachCharacter(plr, char) end)
	if plr.Character then attachCharacter(plr, plr.Character) end
end)
