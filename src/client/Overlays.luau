local TweenService = game:GetService("TweenService")

local Overlays = {}

local gameOverOverlay, restartCountdownLabel
local victoryOverlay
local notificationFrame, notificationTitle, notificationWord, notificationHint

function Overlays.create(screenGui)
	gameOverOverlay = Instance.new("Frame")
	gameOverOverlay.Name = "GameOverOverlay"
	gameOverOverlay.Size = UDim2.new(1, 0, 0, 100)
	gameOverOverlay.Position = UDim2.new(0, 0, 0.35, 0)
	gameOverOverlay.BackgroundColor3 = Color3.fromRGB(60, 20, 20)
	gameOverOverlay.BackgroundTransparency = 0.2
	gameOverOverlay.BorderSizePixel = 0
	gameOverOverlay.Visible = false
	gameOverOverlay.ZIndex = 100
	gameOverOverlay.Parent = screenGui

	local gameOverLabel = Instance.new("TextLabel")
	gameOverLabel.Size = UDim2.new(1, 0, 0.6, 0)
	gameOverLabel.BackgroundTransparency = 1
	gameOverLabel.Text = "CORE DESTROYED"
	gameOverLabel.TextColor3 = Color3.fromRGB(255, 100, 100)
	gameOverLabel.Font = Enum.Font.GothamBold
	gameOverLabel.TextSize = 36
	gameOverLabel.Parent = gameOverOverlay

	restartCountdownLabel = Instance.new("TextLabel")
	restartCountdownLabel.Size = UDim2.new(1, 0, 0.4, 0)
	restartCountdownLabel.Position = UDim2.new(0, 0, 0.6, 0)
	restartCountdownLabel.BackgroundTransparency = 1
	restartCountdownLabel.Text = "Restarting in 10..."
	restartCountdownLabel.TextColor3 = Color3.fromRGB(200, 200, 200)
	restartCountdownLabel.Font = Enum.Font.Gotham
	restartCountdownLabel.TextSize = 20
	restartCountdownLabel.Parent = gameOverOverlay

	victoryOverlay = Instance.new("Frame")
	victoryOverlay.Name = "VictoryOverlay"
	victoryOverlay.Size = UDim2.new(1, 0, 0, 100)
	victoryOverlay.Position = UDim2.new(0, 0, 0.35, 0)
	victoryOverlay.BackgroundColor3 = Color3.fromRGB(20, 60, 40)
	victoryOverlay.BackgroundTransparency = 0.2
	victoryOverlay.BorderSizePixel = 0
	victoryOverlay.Visible = false
	victoryOverlay.ZIndex = 100
	victoryOverlay.Parent = screenGui

	local victoryLabel = Instance.new("TextLabel")
	victoryLabel.Size = UDim2.new(1, 0, 1, 0)
	victoryLabel.BackgroundTransparency = 1
	victoryLabel.Text = "VICTORY!"
	victoryLabel.TextColor3 = Color3.fromRGB(100, 255, 150)
	victoryLabel.Font = Enum.Font.GothamBold
	victoryLabel.TextSize = 48
	victoryLabel.Parent = victoryOverlay

	notificationFrame = Instance.new("Frame")
	notificationFrame.Name = "NotificationFrame"
	notificationFrame.Size = UDim2.new(0, 400, 0, 100)
	notificationFrame.Position = UDim2.new(0.5, -200, 0, 60)
	notificationFrame.BackgroundColor3 = Color3.fromRGB(30, 50, 30)
	notificationFrame.BackgroundTransparency = 0.1
	notificationFrame.BorderSizePixel = 0
	notificationFrame.Visible = false
	notificationFrame.ZIndex = 200
	notificationFrame.Parent = screenGui

	local notificationCorner = Instance.new("UICorner")
	notificationCorner.CornerRadius = UDim.new(0, 10)
	notificationCorner.Parent = notificationFrame

	local notificationStroke = Instance.new("UIStroke")
	notificationStroke.Color = Color3.fromRGB(100, 255, 100)
	notificationStroke.Thickness = 2
	notificationStroke.Parent = notificationFrame

	notificationTitle = Instance.new("TextLabel")
	notificationTitle.Size = UDim2.new(1, 0, 0, 30)
	notificationTitle.Position = UDim2.new(0, 0, 0, 8)
	notificationTitle.BackgroundTransparency = 1
	notificationTitle.Text = "NEW WORD UNLOCKED!"
	notificationTitle.TextColor3 = Color3.fromRGB(255, 220, 100)
	notificationTitle.Font = Enum.Font.GothamBold
	notificationTitle.TextSize = 18
	notificationTitle.ZIndex = 201
	notificationTitle.Parent = notificationFrame

	notificationWord = Instance.new("TextLabel")
	notificationWord.Size = UDim2.new(1, 0, 0, 35)
	notificationWord.Position = UDim2.new(0, 0, 0, 35)
	notificationWord.BackgroundTransparency = 1
	notificationWord.Text = ""
	notificationWord.TextColor3 = Color3.fromRGB(100, 255, 100)
	notificationWord.Font = Enum.Font.Code
	notificationWord.TextSize = 28
	notificationWord.ZIndex = 201
	notificationWord.Parent = notificationFrame

	notificationHint = Instance.new("TextLabel")
	notificationHint.Size = UDim2.new(1, -20, 0, 20)
	notificationHint.Position = UDim2.new(0, 10, 0, 72)
	notificationHint.BackgroundTransparency = 1
	notificationHint.Text = ""
	notificationHint.TextColor3 = Color3.fromRGB(180, 180, 180)
	notificationHint.Font = Enum.Font.Gotham
	notificationHint.TextSize = 12
	notificationHint.ZIndex = 201
	notificationHint.Parent = notificationFrame
end

function Overlays.showNotification(title, word, hint, duration, isError)
	notificationTitle.Text = title or "NEW WORD UNLOCKED!"
	notificationWord.Text = word or ""
	notificationHint.Text = hint or ""
	notificationFrame.Visible = true

	if isError then
		notificationFrame.BackgroundColor3 = Color3.fromRGB(60, 30, 30)
		notificationWord.TextColor3 = Color3.fromRGB(255, 100, 100)
		local stroke = notificationFrame:FindFirstChildOfClass("UIStroke")
		if stroke then stroke.Color = Color3.fromRGB(255, 100, 100) end
	else
		notificationFrame.BackgroundColor3 = Color3.fromRGB(30, 50, 30)
		notificationWord.TextColor3 = Color3.fromRGB(100, 255, 100)
		local stroke = notificationFrame:FindFirstChildOfClass("UIStroke")
		if stroke then stroke.Color = Color3.fromRGB(100, 255, 100) end
	end

	notificationFrame.Position = UDim2.new(0.5, -200, 0, -100)
	local tweenIn = TweenService:Create(
		notificationFrame,
		TweenInfo.new(0.5, Enum.EasingStyle.Back, Enum.EasingDirection.Out),
		{ Position = UDim2.new(0.5, -200, 0, 60) }
	)
	tweenIn:Play()

	task.delay(duration or 5, function()
		local tweenOut = TweenService:Create(
			notificationFrame,
			TweenInfo.new(0.3, Enum.EasingStyle.Quad, Enum.EasingDirection.In),
			{ Position = UDim2.new(0.5, -200, 0, -100) }
		)
		tweenOut:Play()
		tweenOut.Completed:Wait()
		notificationFrame.Visible = false
	end)
end

function Overlays.updateGameState(phase, restartTime)
	if phase == "GAMEOVER" then
		gameOverOverlay.Visible = true
		victoryOverlay.Visible = false
		restartCountdownLabel.Text = "Restarting in " .. math.ceil(restartTime or 0) .. "..."
	elseif phase == "VICTORY" then
		gameOverOverlay.Visible = false
		victoryOverlay.Visible = true
	else
		gameOverOverlay.Visible = false
		victoryOverlay.Visible = false
	end
end

return Overlays
