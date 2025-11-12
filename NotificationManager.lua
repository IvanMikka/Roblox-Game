-- NotificationManager (ModuleScript) - v2.0
local TweenService = game:GetService("TweenService")
local NotificationManager = {}

local UI = nil
local activeNotifications = {}

function NotificationManager:ShowNotification(message, duration)
	duration = duration or 5

	-- Если такое уведомление уже активно, сбрасываем его
	if activeNotifications[message] then
		local existing = activeNotifications[message]
		existing.Tween:Cancel() -- Отменяем старую анимацию
		existing.Instance:Destroy() -- Уничтожаем старый объект
		activeNotifications[message] = nil
	end

	local newNotif = UI.Game.NotificationTemplate:Clone()
	newNotif.Message.Text = message
	newNotif.Visible = true
	newNotif.Parent = UI.Game.NotificationContainer

	local timerBar = newNotif.TimerBar
	local tween = TweenService:Create(timerBar, TweenInfo.new(duration, Enum.EasingStyle.Linear), {Size = UDim2.new(0, 0, 0, 3)})

	activeNotifications[message] = { Instance = newNotif, Tween = tween }

	tween:Play()
	tween.Completed:Connect(function()
		if activeNotifications[message] == existing then
			activeNotifications[message] = nil
		end
		newNotif:Destroy()
	end)
end

function NotificationManager:Init(_UI)
	UI = _UI
end

return NotificationManager