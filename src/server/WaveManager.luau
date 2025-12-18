local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local PythonTD = ReplicatedStorage:WaitForChild("PythonTD")
local Config = require(PythonTD.Config)

local WaveManager = {}

local GROUND_Y = Config.PLATFORM_Y

local deps = nil
local EnemyManager = nil

local onWaveStartCallback = nil
local onRestartCallback = nil

local state = {
	phase = "LOBBY",
	waveNumber = 0,
	coreHp = 1000,
	coreMaxHp = 1000,
	corePosition = nil,
	coreModel = nil,
	power = 1,
	enemiesRemaining = 0,
	enemiesSpawned = 0,
	enemiesTotal = 0,
	spawnQueue = {},
	readyPlayers = {},
	restartTimeRemaining = 0,
	waveStartTime = 0,
}

local playerScrap = {}
local playerDamage = {}

local POWER_COSTS = {100, 200, 400, 800, 1600, 3200}

local coreHitEvent = nil
local playerReadyEvent = nil
local waveStateEvent = nil
local lastBroadcast = 0

function WaveManager.generateWave(waveNum)
	local composition = {}
	local baseCount = 10 + waveNum * 5
	local enemyCount = math.floor(baseCount * (0.8 + math.random() * 0.4))
	local interval = math.max(0.3, 1 - waveNum * 0.05)

	local availableTypes = {"Zombie"}
	if waveNum >= 2 then table.insert(availableTypes, "Runner") end
	if waveNum >= 3 then table.insert(availableTypes, "Tank") end

	for i = 1, enemyCount do
		table.insert(composition, {
			type = availableTypes[math.random(#availableTypes)],
			delay = (i - 1) * interval + math.random() * 0.2,
		})
	end

	local bossCount = math.min(8, math.floor(waveNum / 2) + 1)
	local lastDelay = #composition > 0 and composition[#composition].delay or 0
	for i = 1, bossCount do
		table.insert(composition, {
			type = "Boss",
			delay = lastDelay + 2 + (i - 1) * 2,
		})
	end

	return composition
end

function WaveManager.init(dependencies)
	deps = dependencies

	local PythonTD = ReplicatedStorage:WaitForChild("PythonTD")
	playerReadyEvent = PythonTD:WaitForChild("PlayerReady")
	waveStateEvent = PythonTD:WaitForChild("WaveState")

	coreHitEvent = PythonTD:FindFirstChild("CoreHit")
	if not coreHitEvent then
		coreHitEvent = Instance.new("RemoteEvent")
		coreHitEvent.Name = "CoreHit"
		coreHitEvent.Parent = PythonTD
	end

	playerReadyEvent.OnServerEvent:Connect(function(player)
		WaveManager.playerReady(player.UserId)
	end)

	Players.PlayerAdded:Connect(function(player)
		WaveManager.initPlayerScrap(player.UserId)
	end)

	for _, player in ipairs(Players:GetPlayers()) do
		WaveManager.initPlayerScrap(player.UserId)
	end

	Players.PlayerRemoving:Connect(function(player)
		state.readyPlayers[player.UserId] = nil
	end)
end

function WaveManager.initPlayerScrap(playerId)
	if not playerScrap[playerId] then
		playerScrap[playerId] = deps.Config.STARTING_SCRAP or 250
	end
end

function WaveManager.setEnemyManager(enemyMgr)
	EnemyManager = enemyMgr
end

function WaveManager.createGateVisuals(gates)
	local corePos = state.corePosition
	if not corePos then return end

	for i, gate in ipairs(gates) do
		local model = Instance.new("Model")
		model.Name = "Gate_" .. i

		local dx = corePos.x - gate.x
		local dz = corePos.z - gate.z
		local angleToCore = math.atan2(dx, dz)

		local gatePos = Vector3.new(gate.x, GROUND_Y, gate.z)
		local gateCFrame = CFrame.new(gatePos) * CFrame.Angles(0, angleToCore, 0)

		local frameColor = Color3.fromRGB(80, 80, 80)
		local neonColor = Color3.fromRGB(255, 50, 50)

		local leftPillar = Instance.new("Part")
		leftPillar.Size = Vector3.new(2, 12, 2)
		leftPillar.CFrame = gateCFrame * CFrame.new(-4, 6, 0)
		leftPillar.Anchored = true
		leftPillar.Material = Enum.Material.Metal
		leftPillar.Color = frameColor
		leftPillar.Parent = model

		local leftStripe = Instance.new("Part")
		leftStripe.Size = Vector3.new(0.5, 10, 2.1)
		leftStripe.CFrame = leftPillar.CFrame
		leftStripe.Anchored = true
		leftStripe.CanCollide = false
		leftStripe.Material = Enum.Material.Neon
		leftStripe.Color = neonColor
		leftStripe.Parent = model

		local rightPillar = Instance.new("Part")
		rightPillar.Size = Vector3.new(2, 12, 2)
		rightPillar.CFrame = gateCFrame * CFrame.new(4, 6, 0)
		rightPillar.Anchored = true
		rightPillar.Material = Enum.Material.Metal
		rightPillar.Color = frameColor
		rightPillar.Parent = model

		local rightStripe = Instance.new("Part")
		rightStripe.Size = Vector3.new(0.5, 10, 2.1)
		rightStripe.CFrame = rightPillar.CFrame
		rightStripe.Anchored = true
		rightStripe.CanCollide = false
		rightStripe.Material = Enum.Material.Neon
		rightStripe.Color = neonColor
		rightStripe.Parent = model

		local top = Instance.new("Part")
		top.Size = Vector3.new(12, 2, 3)
		top.CFrame = gateCFrame * CFrame.new(0, 13, 0)
		top.Anchored = true
		top.Material = Enum.Material.Metal
		top.Color = frameColor
		top.Parent = model

		local field = Instance.new("Part")
		field.Name = "Field"
		field.Size = Vector3.new(6, 10, 0.2)
		field.CFrame = gateCFrame * CFrame.new(0, 7, 0)
		field.Anchored = true
		field.CanCollide = false
		field.Material = Enum.Material.ForceField
		field.Color = neonColor
		field.Transparency = 0.5
		field.Parent = model

		local bb = Instance.new("BillboardGui")
		bb.Size = UDim2.new(0, 100, 0, 50)
		bb.StudsOffset = Vector3.new(0, 8, 0)
		bb.AlwaysOnTop = true
		bb.Parent = top

		local txt = Instance.new("TextLabel")
		txt.Size = UDim2.fromScale(1, 1)
		txt.BackgroundTransparency = 1
		txt.Text = "GATE " .. i
		txt.TextColor3 = neonColor
		txt.Font = Enum.Font.Code
		txt.TextSize = 20
		txt.Parent = bb

		model.Parent = workspace
	end
end

function WaveManager.createCore(position)
	state.corePosition = position
	state.coreHp = state.coreMaxHp

	local model = Instance.new("Model")
	model.Name = "CoreModel"

	local base = Instance.new("Part")
	base.Name = "Base"
	base.Shape = Enum.PartType.Cylinder
	base.Size = Vector3.new(1, 12, 12)
	base.Position = Vector3.new(position.x, GROUND_Y + 0.5, position.z)
	base.Orientation = Vector3.new(0, 0, 90)
	base.Anchored = true
	base.Material = Enum.Material.Metal
	base.Color = Color3.fromRGB(50, 50, 60)
	base.Parent = model

	local core = Instance.new("Part")
	core.Name = "Core"
	core.Size = Vector3.new(4, 4, 4)
	core.Position = Vector3.new(position.x, GROUND_Y + 8, position.z)
	core.Anchored = true
	core.CanCollide = true
	core.Material = Enum.Material.Neon
	core.Color = Color3.fromRGB(0, 255, 255)
	core.Shape = Enum.PartType.Ball
	core.Transparency = 0.2
	core.Parent = model

	local mesh = Instance.new("SpecialMesh")
	mesh.MeshType = Enum.MeshType.FileMesh
	mesh.MeshId = "rbxassetid://9756362"
	mesh.Scale = Vector3.new(4, 8, 4)
	mesh.Parent = core

	local attachment = Instance.new("Attachment", core)
	local particles = Instance.new("ParticleEmitter")
	particles.Texture = "rbxassetid://243098098"
	particles.Color = ColorSequence.new(Color3.fromRGB(0, 255, 255))
	particles.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.5), NumberSequenceKeypoint.new(1, 0) })
	particles.Lifetime = NumberRange.new(1, 2)
	particles.Rate = 20
	particles.Speed = NumberRange.new(2, 4)
	particles.SpreadAngle = Vector2.new(360, 360)
	particles.Parent = attachment

	local floatInfo = TweenInfo.new(2, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true)
	local floatGoal = { Position = core.Position + Vector3.new(0, 1.5, 0) }
	TweenService:Create(core, floatInfo, floatGoal):Play()

	task.spawn(function()
		while core and core.Parent do
			core.CFrame = core.CFrame * CFrame.Angles(0, math.rad(1), 0)
			local hpRatio = state.coreHp / state.coreMaxHp
			if hpRatio > 0.5 then
				core.Color = Color3.fromRGB(0, 255, 255)
			elseif hpRatio > 0.25 then
				core.Color = Color3.fromRGB(255, 200, 100)
			else
				core.Color = Color3.fromRGB(255, 100, 100)
			end
			task.wait(0.02)
		end
	end)

	model.Parent = workspace
	state.coreModel = model
end

function WaveManager.damageCore(amount)
	if state.phase == "GAMEOVER" then return end

	state.coreHp = math.max(0, state.coreHp - amount)

	for _, player in ipairs(Players:GetPlayers()) do
		coreHitEvent:FireClient(player, {
			damage = amount,
			currentHp = state.coreHp,
			maxHp = state.coreMaxHp,
		})
	end

	if state.coreHp <= 0 then
		WaveManager.gameOver()
	end
end

function WaveManager.getCorePosition()
	return state.corePosition
end

function WaveManager.getCoreHp()
	return state.coreHp, state.coreMaxHp
end

function WaveManager.resetCoreVisual()
	if state.coreModel then
		local core = state.coreModel:FindFirstChild("Core")
		if core then
			core.Color = Color3.fromRGB(0, 255, 255)
			core.Transparency = 0.2
		end
	end
end

function WaveManager.setPhase(newPhase)
	state.phase = newPhase
	if newPhase == "COMBAT" then
		WaveManager.startWave()
	end
end

function WaveManager.getPhase()
	return state.phase
end

function WaveManager.playerReady(userId)
	state.readyPlayers[userId] = true
	if state.phase == "LOBBY" then
		WaveManager.setPhase("COMBAT")
	end
end

function WaveManager.setOnWaveStart(callback)
	onWaveStartCallback = callback
end

function WaveManager.setOnRestart(callback)
	onRestartCallback = callback
end

function WaveManager.startWave()
	state.waveNumber = state.waveNumber + 1

	if onWaveStartCallback then
		onWaveStartCallback(state.waveNumber)
	end

	local playerCount = #Players:GetPlayers()
	local playerMultiplier = 1 + (playerCount - 1) * 0.5
	local waveMultiplier = 1 + (state.waveNumber - 1) * 0.1

	if EnemyManager then
		EnemyManager.setNewGamePlusMultiplier(waveMultiplier)
		EnemyManager.setWave(state.waveNumber)
	end

	local waveComposition = WaveManager.generateWave(state.waveNumber)

	state.spawnQueue = {}
	state.enemiesSpawned = 0
	state.enemiesRemaining = 0

	for _, enemy in ipairs(waveComposition) do
		local count = enemy.type ~= "Boss" and math.ceil(playerMultiplier) or 1
		for i = 1, count do
			table.insert(state.spawnQueue, {
				type = enemy.type,
				gate = 1,
				delay = enemy.delay + (i - 1) * 0.3,
			})
		end
	end

	table.sort(state.spawnQueue, function(a, b) return a.delay < b.delay end)

	state.waveStartTime = tick()
	state.enemiesTotal = #state.spawnQueue
	state.enemiesRemaining = state.enemiesTotal
end

function WaveManager.onEnemyKilled(killerOwnerId)
	state.enemiesRemaining = state.enemiesRemaining - 1

	if killerOwnerId then
		WaveManager.addScrap(killerOwnerId, deps.Config.SCRAP_ASSIST_BONUS or 5)
	end

	if state.enemiesRemaining <= 0 and state.enemiesSpawned >= state.enemiesTotal then
		WaveManager.waveComplete()
	end
end

function WaveManager.onEnemyReachedCore()
	state.enemiesRemaining = state.enemiesRemaining - 1

	if state.enemiesRemaining <= 0 and state.enemiesSpawned >= state.enemiesTotal then
		WaveManager.waveComplete()
	end
end

function WaveManager.waveComplete()
	local bonus = deps.Config.WAVE_BONUS_BASE + state.waveNumber * 25
	for _, player in ipairs(Players:GetPlayers()) do
		WaveManager.addScrap(player.UserId, bonus)
	end
	WaveManager.startWave()
end

function WaveManager.addScrap(playerId, amount)
	playerScrap[playerId] = (playerScrap[playerId] or 0) + amount
end

function WaveManager.removeScrap(playerId, amount)
	if (playerScrap[playerId] or 0) >= amount then
		playerScrap[playerId] = playerScrap[playerId] - amount
		return true
	end
	return false
end

function WaveManager.getScrap(playerId)
	return playerScrap[playerId] or 0
end

function WaveManager.addDamage(playerId, amount)
	if playerId then
		playerDamage[playerId] = (playerDamage[playerId] or 0) + amount
	end
end

function WaveManager.getDamage(playerId)
	return playerDamage[playerId] or 0
end

function WaveManager.getAllDamage()
	return playerDamage
end

function WaveManager.getPower()
	return state.power
end

function WaveManager.getPowerCost()
	return POWER_COSTS[state.power] or (state.power * 1000)
end

function WaveManager.buyPower(playerId)
	local cost = WaveManager.getPowerCost()
	if WaveManager.removeScrap(playerId, cost) then
		state.power = state.power + 1
		return true, state.power
	end
	return false, "Not enough scrap"
end

function WaveManager.gameOver()
	state.phase = "GAMEOVER"
	state.restartTimeRemaining = 10
end

function WaveManager.restart()
	if EnemyManager then
		EnemyManager.clear()
		EnemyManager.setNewGamePlusMultiplier(1)
	end

	if deps.Interpreters then
		deps.Interpreters.destroyAllUnits()
	end

	if deps.ScrapManager then
		deps.ScrapManager.clear()
	end

	state.phase = "LOBBY"
	state.waveNumber = 0
	state.coreHp = state.coreMaxHp
	state.readyPlayers = {}
	state.spawnQueue = {}
	state.enemiesRemaining = 0
	state.enemiesSpawned = 0
	state.enemiesTotal = 0
	state.power = 1

	playerScrap = {}
	playerDamage = {}
	for _, player in ipairs(Players:GetPlayers()) do
		WaveManager.initPlayerScrap(player.UserId)
	end

	WaveManager.resetCoreVisual()

	if onRestartCallback then
		onRestartCallback()
	end

	WaveManager.broadcastState()
end

function WaveManager.update(dt)
	if state.phase == "COMBAT" then
		local elapsed = tick() - state.waveStartTime

		while #state.spawnQueue > 0 and state.spawnQueue[1].delay <= elapsed do
			local spawn = table.remove(state.spawnQueue, 1)
			if EnemyManager then
				EnemyManager.spawn(spawn.type, spawn.gate, deps)
				state.enemiesSpawned = state.enemiesSpawned + 1
			end
		end

		lastBroadcast = lastBroadcast + dt
		if lastBroadcast >= 0.5 then
			lastBroadcast = 0
			WaveManager.broadcastState()
		end
	elseif state.phase == "GAMEOVER" then
		local prevSecond = math.ceil(state.restartTimeRemaining)
		state.restartTimeRemaining = state.restartTimeRemaining - dt
		local newSecond = math.ceil(state.restartTimeRemaining)

		if newSecond ~= prevSecond and state.restartTimeRemaining > 0 then
			WaveManager.broadcastState()
		end

		if state.restartTimeRemaining <= 0 then
			WaveManager.restart()
		end
	end
end

function WaveManager.broadcastState()
	local damageBoard = {}
	for _, p in ipairs(Players:GetPlayers()) do
		table.insert(damageBoard, {
			userId = p.UserId,
			name = p.Name,
			damage = playerDamage[p.UserId] or 0,
		})
	end
	table.sort(damageBoard, function(a, b) return a.damage > b.damage end)

	for _, player in ipairs(Players:GetPlayers()) do
		local stateData = {
			phase = state.phase,
			waveNumber = state.waveNumber,
			coreHp = state.coreHp,
			coreMaxHp = state.coreMaxHp,
			restartTimeRemaining = state.restartTimeRemaining,
			enemiesRemaining = state.enemiesRemaining,
			enemiesTotal = state.enemiesTotal,
			scrap = playerScrap[player.UserId] or 0,
			power = state.power,
			damageBoard = damageBoard,
		}
		waveStateEvent:FireClient(player, stateData)
	end
end

function WaveManager.getState()
	return state
end

return WaveManager
