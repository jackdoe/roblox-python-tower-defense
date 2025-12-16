local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")
local RunService = game:GetService("RunService")
local SoundService = game:GetService("SoundService")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

local PythonTD = ReplicatedStorage:WaitForChild("PythonTD")
local Config = require(PythonTD.Config)
local SoundConfig = require(PythonTD.SoundConfig)

local MainIDE = require(script.Parent.UI.MainIDE)
local HUD = require(script.Parent.UI.HUD)
local Effects = require(script.Parent.Effects)
local GridNavigator = require(script.Parent.GridNavigator)

local ClientState = require(script.Parent.ClientState)
local PlacementSystem = require(script.Parent.PlacementSystem)
local Overlays = require(script.Parent.Overlays)
local HelpPanel = require(script.Parent.UI.HelpPanel)

local selectionRing = nil
local selectionRingTarget = nil
local selectionRingModel = nil

local RING_SIZE = {
	player = 6,
	bot = 6,
	gundam = 10,
}

local function createSelectionRing(ringType)
	if selectionRing then selectionRing:Destroy() end
	local size = RING_SIZE[ringType] or 6
	local ring = Instance.new("Part")
	ring.Name = "SelectionRing"
	ring.Shape = Enum.PartType.Cylinder
	ring.Size = Vector3.new(0.03, size, size)
	ring.Material = Enum.Material.SmoothPlastic
	ring.Color = Color3.fromRGB(80, 140, 180)
	ring.Anchored = true
	ring.CanCollide = false
	ring.CastShadow = false
	ring.Transparency = 0.7
	ring.CFrame = CFrame.new(0, -1000, 0) * CFrame.Angles(0, 0, math.rad(90))
	ring.Parent = workspace
	selectionRing = ring
	selectionRingModel = nil
	return ring
end

local function destroySelectionRing()
	if selectionRing then
		selectionRing:Destroy()
		selectionRing = nil
	end
	selectionRingTarget = nil
	selectionRingModel = nil
end

local function updateSelectionRing()
	if not selectionRingTarget or not selectionRing then return end

	local targetType = selectionRingTarget.type

	if targetType == "player" then
		local char = player.Character
		if char then
			local hrp = char:FindFirstChild("HumanoidRootPart")
			if hrp then
				selectionRing.CFrame = CFrame.new(hrp.Position.X, Config.PLATFORM_Y + 0.5, hrp.Position.Z) * CFrame.Angles(0, 0, math.rad(90))
			end
		end
		return
	end

	if selectionRingModel and selectionRingModel.Parent then
		local hrp = selectionRingModel:FindFirstChild("HumanoidRootPart") or selectionRingModel.PrimaryPart
		if hrp then
			selectionRing.CFrame = CFrame.new(hrp.Position.X, Config.PLATFORM_Y + 0.5, hrp.Position.Z) * CFrame.Angles(0, 0, math.rad(90))
		end
		return
	end

	local targetId = selectionRingTarget.id
	for _, obj in ipairs(workspace:GetDescendants()) do
		if not obj:IsA("Model") then continue end
		local objId = targetType == "gundam" and obj:GetAttribute("GundamId") or obj:GetAttribute("BotId")
		if objId ~= targetId then continue end
		selectionRingModel = obj
		local hrp = obj:FindFirstChild("HumanoidRootPart") or obj.PrimaryPart
		if hrp then
			selectionRing.CFrame = CFrame.new(hrp.Position.X, Config.PLATFORM_Y + 0.5, hrp.Position.Z) * CFrame.Angles(0, 0, math.rad(90))
		end
		return
	end
end

local runProgramEvent = PythonTD:WaitForChild("RunProgram")
local pauseProgramEvent = PythonTD:WaitForChild("PauseProgram")
local stepProgramEvent = PythonTD:WaitForChild("StepProgram")
local resetProgramEvent = PythonTD:WaitForChild("ResetProgram")
local stateUpdateEvent = PythonTD:WaitForChild("StateUpdate")
local attackHitEvent = PythonTD:WaitForChild("AttackHit")
local interpreterSyncEvent = PythonTD:WaitForChild("InterpreterSync")

local playerReadyEvent = PythonTD:WaitForChild("PlayerReady")
local waveStateEvent = PythonTD:WaitForChild("WaveState")
local gundamPlaceAtEvent = PythonTD:WaitForChild("GundamPlaceAt")
local gundamSellEvent = PythonTD:WaitForChild("GundamSell")
local enterBuildModeEvent = PythonTD:WaitForChild("EnterBuildMode")
local playerTeleportEvent = PythonTD:WaitForChild("PlayerTeleport")
local playerMoveCompleteEvent = PythonTD:WaitForChild("PlayerMoveComplete")

local gundamUpgradeEvent = PythonTD:WaitForChild("GundamUpgrade")

local requestStateEvent = PythonTD:WaitForChild("RequestState")

local botBuildEvent = PythonTD:WaitForChild("BotBuild")
local botSellEvent = PythonTD:WaitForChild("BotSell")
local buyPowerEvent = PythonTD:WaitForChild("BuyPower")
local depositEffectEvent = PythonTD:WaitForChild("DepositEffect")

local screenGui = Instance.new("ScreenGui")
screenGui.Name = "PythonTDGui"
screenGui.ResetOnSpawn = false
screenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
screenGui.IgnoreGuiInset = true
screenGui.Parent = playerGui

local ide, hud, helpPanel

helpPanel = HelpPanel.create(screenGui)

ide = MainIDE.create(screenGui, {
	onRun = function(pid)
		runProgramEvent:FireServer(ide:getText(), pid)
	end,
	onPause = function(pid)
		pauseProgramEvent:FireServer(pid)
	end,
	onStep = function(pid)
		stepProgramEvent:FireServer(ide:getText(), pid)
	end,
	onReset = function(pid)
		resetProgramEvent:FireServer(pid)
	end,
	onBuyCpu = function(pid)
		gundamUpgradeEvent:FireServer(pid, "cpu")
	end,
	onBuyRam = function(pid)
		gundamUpgradeEvent:FireServer(pid, "ram")
	end,
	onTabOpen = function(pid)
		local interpType = ide:getInterpreterType(pid)
		if interpType == "gundam" or interpType == "bot" or interpType == "player" then
			createSelectionRing(interpType)
			selectionRingTarget = { id = pid, type = interpType }
		else
			destroySelectionRing()
		end
	end,
	onTabClose = function(pid)
		destroySelectionRing()
		local interpType = ide:getInterpreterType(pid)
		if interpType == "gundam" then
			gundamSellEvent:FireServer(pid)
		elseif interpType == "bot" then
			botSellEvent:FireServer(pid)
		end
	end,
	onBuildBot = function()
		if ClientState.gundamPlacementMode then PlacementSystem.exitGundamMode() end
		if ClientState.botPlacementMode then
			PlacementSystem.exitBotMode()
		else
			PlacementSystem.enterBotMode(Overlays.showNotification)
		end
	end,
	onBuildGundam = function()
		if ClientState.botPlacementMode then PlacementSystem.exitBotMode() end
		if ClientState.gundamPlacementMode then
			PlacementSystem.exitGundamMode()
		else
			PlacementSystem.enterGundamMode(Overlays.showNotification)
		end
	end,
	onBuyPower = function(pid)
		buyPowerEvent:FireServer(pid)
	end,
	onHelp = function()
		helpPanel.toggle()
	end,
})

hud = HUD.create(screenGui, {
	onReady = function()
		playerReadyEvent:FireServer()
	end,
})

Overlays.create(screenGui)

local playerBillboard = nil
local playerCarryingLabel = nil
local playerCarryingBar = nil

local function createPlayerBillboard(character)
	if playerBillboard then playerBillboard:Destroy() end

	local head = character:WaitForChild("Head", 5)
	if not head then return end

	local billboard = Instance.new("BillboardGui")
	billboard.Name = "PlayerCarryingBillboard"
	billboard.Size = UDim2.new(0, 60, 0, 24)
	billboard.StudsOffset = Vector3.new(0, 2.5, 0)
	billboard.AlwaysOnTop = true
	billboard.Parent = head

	local bg = Instance.new("Frame")
	bg.Size = UDim2.new(1, 0, 1, 0)
	bg.BackgroundColor3 = Color3.fromRGB(20, 30, 40)
	bg.BackgroundTransparency = 0.3
	bg.BorderSizePixel = 0
	bg.Parent = billboard

	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 4)
	corner.Parent = bg

	local border = Instance.new("UIStroke")
	border.Color = Color3.fromRGB(255, 200, 50)
	border.Thickness = 1
	border.Parent = bg

	local label = Instance.new("TextLabel")
	label.Name = "CarryingLabel"
	label.Size = UDim2.new(1, 0, 0.55, 0)
	label.Position = UDim2.new(0, 0, 0, 2)
	label.BackgroundTransparency = 1
	label.Text = "0/5"
	label.TextColor3 = Color3.fromRGB(255, 200, 50)
	label.Font = Enum.Font.GothamBold
	label.TextSize = 10
	label.Parent = bg

	local barBg = Instance.new("Frame")
	barBg.Name = "BarBg"
	barBg.Size = UDim2.new(0.8, 0, 0.2, 0)
	barBg.Position = UDim2.new(0.1, 0, 0.65, 0)
	barBg.BackgroundColor3 = Color3.fromRGB(40, 40, 40)
	barBg.BorderSizePixel = 0
	barBg.Parent = bg

	local bar = Instance.new("Frame")
	bar.Name = "Bar"
	bar.Size = UDim2.new(0, 0, 1, 0)
	bar.BackgroundColor3 = Color3.fromRGB(255, 200, 50)
	bar.BorderSizePixel = 0
	bar.Parent = barBg

	playerBillboard = billboard
	playerCarryingLabel = label
	playerCarryingBar = bar
end

local function updatePlayerBillboard(carrying, maxCapacity)
	if not playerBillboard or not playerBillboard.Parent then
		local char = player.Character
		if char then createPlayerBillboard(char) end
	end
	if playerCarryingLabel then
		playerCarryingLabel.Text = carrying .. "/" .. maxCapacity
	end
	if playerCarryingBar then
		local ratio = carrying / maxCapacity
		playerCarryingBar.Size = UDim2.new(ratio, 0, 1, 0)
	end
end

player.CharacterAdded:Connect(function(character)
	createPlayerBillboard(character)
end)

if player.Character then
	createPlayerBillboard(player.Character)
end

local function updateAllEconomy()
	hud.updateEconomy(ClientState.currentScrap, ClientState.nextGundamCost, ClientState.nextBotCost)
	ide:updateEconomy(ClientState.nextBotCost, ClientState.nextGundamCost)
end

interpreterSyncEvent.OnClientEvent:Connect(function(payload)
	ide:sync(payload)
	ClientState.currentGundamCount, ClientState.currentBotCount = ide:getCounts()
	ClientState.nextGundamCost = ClientState.calculateGundamCost()
	ClientState.nextBotCost = ClientState.calculateBotCost()
	updateAllEconomy()
end)

stateUpdateEvent.OnClientEvent:Connect(function(state)
	if state.waveNumber then
		ClientState.currentPhase = state.phase or "LOBBY"
		hud.updateWave(state.waveNumber, state.enemiesRemaining or 0, state.enemiesTotal or 0)
		hud.updateCore(state.coreHp or 0, state.coreMaxHp or 1000)
		hud.updatePhase(state.phase or "LOBBY")
		ClientState.currentScrap = state.scrap or 0
		updateAllEconomy()
		Overlays.updateGameState(state.phase, state.restartTimeRemaining)
	end
	if state.scrapInventory ~= nil then
		updatePlayerBillboard(state.scrapInventory, state.maxCapacity or 5)
	end
end)

gundamPlaceAtEvent.OnClientEvent:Connect(function(success, result)
	if not success then
		Overlays.showNotification("BUILD FAILED", tostring(result), "", 3, true)
	elseif result and result.pid then
		task.delay(0.1, function()
			ide:openTab(result.pid)
		end)
	end
end)

botBuildEvent.OnClientEvent:Connect(function(success, result)
	if not success then
		Overlays.showNotification("BUILD FAILED", tostring(result), "", 3, true)
	elseif result and result.pid then
		task.delay(0.1, function()
			ide:openTab(result.pid)
		end)
	end
end)

waveStateEvent.OnClientEvent:Connect(function(state)
	ClientState.currentPhase = state.phase or "LOBBY"
	ClientState.currentScrap = state.scrap or 0
	hud.updateWave(state.waveNumber, state.enemiesRemaining or 0, state.enemiesTotal or 0)
	hud.updateCore(state.coreHp or 0, state.coreMaxHp or 1000)
	hud.updatePhase(state.phase or "LOBBY")
	updateAllEconomy()
	Overlays.updateGameState(state.phase, state.restartTimeRemaining)
end)

attackHitEvent.OnClientEvent:Connect(function(data)
	Effects.attackHit(data)
end)

depositEffectEvent.OnClientEvent:Connect(function(fromPos, toPos, amount)
	Effects.scrapDeposit(fromPos, toPos, amount)
end)

playerTeleportEvent.OnClientEvent:Connect(function(x, z)
	local char = player.Character
	if not char then
		playerMoveCompleteEvent:FireServer()
		return
	end
	local humanoid = char:FindFirstChild("Humanoid")
	local hrp = char:FindFirstChild("HumanoidRootPart")
	if not humanoid or not hrp then
		playerMoveCompleteEvent:FireServer()
		return
	end
	local endPos = Vector3.new(x, hrp.Position.Y, z)
	humanoid:MoveTo(endPos)
	humanoid.MoveToFinished:Once(function()
		playerMoveCompleteEvent:FireServer()
	end)
end)

gundamUpgradeEvent.OnClientEvent:Connect(function(success, result)
	if success then
		local upgradeSound = Instance.new("Sound")
		upgradeSound.SoundId = "rbxassetid://71764947817417"
		upgradeSound.Volume = 0.5
		upgradeSound.Parent = SoundService
		upgradeSound:Play()
		upgradeSound.Ended:Once(function()
			upgradeSound:Destroy()
		end)

		local currentPid = ide:getCurrentTabId()
		local interpType = ide:getInterpreterType(currentPid)
		local targetPos = nil

		if currentPid and interpType == "gundam" then
			for _, model in ipairs(workspace:GetDescendants()) do
				if model:IsA("Model") and model:GetAttribute("GundamId") == currentPid then
					local hrp = model:FindFirstChild("HumanoidRootPart") or model.PrimaryPart
					if hrp then targetPos = hrp.Position end
					break
				end
			end
		elseif currentPid and interpType == "bot" then
			for _, model in ipairs(workspace:GetDescendants()) do
				if model:IsA("Model") and model:GetAttribute("BotId") == currentPid then
					local hrp = model:FindFirstChild("HumanoidRootPart") or model.PrimaryPart
					if hrp then targetPos = hrp.Position end
					break
				end
			end
		elseif currentPid and interpType == "player" then
			local char = player.Character
			if char then
				local hrp = char:FindFirstChild("HumanoidRootPart")
				if hrp then targetPos = hrp.Position end
			end
		end

		if targetPos then
			Effects.gundamUpgrade(targetPos, 2)
		end

		if currentPid then
			task.delay(0.1, function()
				ide:recheckCompile(currentPid)
			end)
		end
	else
		Overlays.showNotification("UPGRADE FAILED", tostring(result), "", 3, true)
	end
end)

buyPowerEvent.OnClientEvent:Connect(function(success, result)
	if success then
		local upgradeSound = Instance.new("Sound")
		upgradeSound.SoundId = "rbxassetid://71764947817417"
		upgradeSound.Volume = 0.5
		upgradeSound.Parent = SoundService
		upgradeSound:Play()
		upgradeSound.Ended:Once(function()
			upgradeSound:Destroy()
		end)
	else
		Overlays.showNotification("UPGRADE FAILED", tostring(result), "", 3, true)
	end
end)

enterBuildModeEvent.OnClientEvent:Connect(function()
	PlacementSystem.enterGundamMode(Overlays.showNotification)
end)

local mouse = player:GetMouse()

RunService.RenderStepped:Connect(function(dt)
	updateSelectionRing()

	local mouseTarget = mouse.Hit
	if not mouseTarget then return end

	local x = math.floor(mouseTarget.Position.X + 0.5)
	local z = math.floor(mouseTarget.Position.Z + 0.5)

	if ClientState.gundamPlacementMode then
		ClientState.isGundamPlacementValid = PlacementSystem.updateGhostGundam(x, z)
	end

	if ClientState.botPlacementMode then
		ClientState.isBotPlacementValid = PlacementSystem.updateGhostBot(x, z)
	end
end)

local botAnimStates = {}
RunService.RenderStepped:Connect(function(dt)
	for _, obj in ipairs(workspace:GetDescendants()) do
		local botId = obj:GetAttribute("BotId")
		if not botId or not obj:IsA("Model") then continue end
		local hrp = obj:FindFirstChild("HumanoidRootPart") or obj.PrimaryPart
		if not hrp then continue end
		if not botAnimStates[botId] then
			botAnimStates[botId] = { animSpeed = 0, walkCycle = 0, lastX = hrp.Position.X, lastZ = hrp.Position.Z, facingAngle = 0 }
		end
		local animState = botAnimStates[botId]
		local baseY = obj:GetAttribute("BaseY") or 2.5

		local dx = hrp.Position.X - animState.lastX
		local dz = hrp.Position.Z - animState.lastZ
		local dist = math.sqrt(dx * dx + dz * dz)
		local isMoving = dist > 0.01

		if isMoving then
			animState.facingAngle = math.atan2(-dx, -dz)
		end

		animState.lastX = hrp.Position.X
		animState.lastZ = hrp.Position.Z

		local targetSpeed = isMoving and 12 or 0
		animState.animSpeed = animState.animSpeed + (targetSpeed - animState.animSpeed) * 5 * dt
		animState.walkCycle = animState.walkCycle + animState.animSpeed * dt
		local bounce = math.abs(math.sin(animState.walkCycle)) * 0.25
		local tilt = math.sin(animState.walkCycle * 0.5) * 0.12
		local lean = isMoving and -0.08 or 0
		hrp.CFrame = CFrame.new(hrp.Position.X, baseY + bounce, hrp.Position.Z)
			* CFrame.Angles(0, animState.facingAngle, 0)
			* CFrame.Angles(lean, 0, -tilt)
	end
end)

mouse.Button2Down:Connect(function()
	if ClientState.gundamPlacementMode then PlacementSystem.exitGundamMode() end
	if ClientState.botPlacementMode then PlacementSystem.exitBotMode() end
end)

mouse.Button1Down:Connect(function()
	if ClientState.gundamPlacementMode then
		if ClientState.isGundamPlacementValid then
			PlacementSystem.tryPlaceGundam(mouse, gundamPlaceAtEvent)
		else
			PlacementSystem.playErrorSound()
		end
		return
	end

	if ClientState.botPlacementMode then
		if ClientState.isBotPlacementValid then
			PlacementSystem.tryPlaceBot(mouse, botBuildEvent)
		else
			PlacementSystem.playErrorSound()
		end
		return
	end
end)

UserInputService.InputBegan:Connect(function(input, gameProcessed)
	if gameProcessed then return end

	if input.KeyCode == Enum.KeyCode.G then
		if ClientState.botPlacementMode then PlacementSystem.exitBotMode() end
		if ClientState.gundamPlacementMode then
			PlacementSystem.exitGundamMode()
		else
			PlacementSystem.enterGundamMode(Overlays.showNotification)
		end
	elseif input.KeyCode == Enum.KeyCode.B then
		if ClientState.gundamPlacementMode then PlacementSystem.exitGundamMode() end
		if ClientState.botPlacementMode then
			PlacementSystem.exitBotMode()
		else
			PlacementSystem.enterBotMode(Overlays.showNotification)
		end
	elseif input.KeyCode == Enum.KeyCode.Escape then
		if helpPanel.isVisible() then
			helpPanel.hide()
		elseif ClientState.gundamPlacementMode then
			PlacementSystem.exitGundamMode()
		elseif ClientState.botPlacementMode then
			PlacementSystem.exitBotMode()
		end
	end
end)

local function setupAmbientSound()
	local ambientGroup = Instance.new("SoundGroup")
	ambientGroup.Name = "AmbientGroup"
	ambientGroup.Volume = 1
	ambientGroup.Parent = SoundService

	local tracks = SoundConfig.Ambient and SoundConfig.Ambient.Tracks
	if tracks and #tracks > 0 then
		local volume = SoundConfig.Ambient.Volume or 0.3
		local ambientSound = Instance.new("Sound")
		ambientSound.Name = "AmbientSound"
		ambientSound.Volume = volume
		ambientSound.Looped = false
		ambientSound.SoundGroup = ambientGroup
		ambientSound.Parent = SoundService

		local function playRandomTrack()
			local trackId = tracks[math.random(1, #tracks)]
			ambientSound.SoundId = trackId
			if not ambientSound.IsLoaded then
				ambientSound.Loaded:Wait()
			end
			ambientSound:Play()
		end

		ambientSound.Ended:Connect(function()
			task.wait(1)
			playRandomTrack()
		end)

		playRandomTrack()
	end
end

GridNavigator.enable()
setupAmbientSound()
requestStateEvent:FireServer()
