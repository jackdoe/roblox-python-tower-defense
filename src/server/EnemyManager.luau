local ServerStorage = game:GetService("ServerStorage")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local PythonTD = ReplicatedStorage:WaitForChild("PythonTD")
local Config = require(PythonTD.Config)

local PathMap = require(script.Parent.PathMap)

local EnemyManager = {}

local GROUND_Y = Config.PLATFORM_Y

local enemies = {}
local deps = nil
local WaveManager = nil

local GRID_CELL_SIZE = 20
local enemyGrid = {}
local MAX_SEARCH_RANGE = 300

local EnemyTypes = {
	Zombie = {
		name = "Zombie",
		modelName = "Zombie",
		hp = 45,
		speed = 7,
		damage = 10,
		scrap = 10,
		size = 1,
	},
	Runner = {
		name = "Runner",
		modelName = "Runner",
		hp = 25,
		speed = 14,
		damage = 5,
		scrap = 10,
		size = 0.8,
	},
	Tank = {
		name = "Tank",
		modelName = "Tank",
		hp = 300,
		speed = 4,
		damage = 30,
		scrap = 50,
		size = 1.5,
	},
	Boss = {
		name = "Boss",
		modelName = "Boss",
		hp = 1500,
		speed = 5,
		damage = 100,
		scrap = 100,
		size = 2.5,
	},
}

local WaveScaling = {
	hpPerWave = 0.25,
	damagePerWave = 0.10,
	sizePerWave = 0.05,
	speedPerWave = 0.02,
	maxSpeedMult = 2.5,
}

local currentWave = 1
local newGamePlusMultiplier = 1
local spawnGates = {}
local mapData = nil

local function getGridKey(x, z)
	local gx = math.floor(x / GRID_CELL_SIZE)
	local gz = math.floor(z / GRID_CELL_SIZE)
	return gx .. "_" .. gz
end

local function updateEnemyGridPosition(enemy, newX, newZ)
	local newKey = getGridKey(newX, newZ)

	if newKey ~= enemy.currentGridKey then
		if enemy.currentGridKey and enemyGrid[enemy.currentGridKey] then
			local cell = enemyGrid[enemy.currentGridKey]
			for i, e in ipairs(cell) do
				if e.id == enemy.id then
					table.remove(cell, i)
					if #cell == 0 then
						enemyGrid[enemy.currentGridKey] = nil
					end
					break
				end
			end
		end

		if not enemyGrid[newKey] then
			enemyGrid[newKey] = {}
		end
		table.insert(enemyGrid[newKey], enemy)
		enemy.currentGridKey = newKey
	end
end

local function removeEnemyFromGrid(enemy)
	if enemy.currentGridKey and enemyGrid[enemy.currentGridKey] then
		local cell = enemyGrid[enemy.currentGridKey]
		for i, e in ipairs(cell) do
			if e.id == enemy.id then
				table.remove(cell, i)
				if #cell == 0 then
					enemyGrid[enemy.currentGridKey] = nil
				end
				break
			end
		end
	end
	enemy.currentGridKey = nil
end

function EnemyManager.init(dependencies)
	deps = dependencies
end

function EnemyManager.setWaveManager(waveMgr)
	WaveManager = waveMgr
end

function EnemyManager.setSpawnGates(gates)
	spawnGates = gates
end

function EnemyManager.setWave(wave)
	currentWave = wave
end

function EnemyManager.setNewGamePlusMultiplier(mult)
	newGamePlusMultiplier = mult
end

local function getScaledStats(enemyType)
	local base = EnemyTypes[enemyType]
	if not base then return nil end

	local waveMult = 1 + (currentWave - 1) * WaveScaling.hpPerWave
	local damageMult = 1 + (currentWave - 1) * WaveScaling.damagePerWave
	local sizeMult = 1 + (currentWave - 1) * WaveScaling.sizePerWave
	local speedMult = math.min(WaveScaling.maxSpeedMult, 1 + (currentWave - 1) * WaveScaling.speedPerWave)

	return {
		name = base.name,
		modelName = base.modelName,
		hp = math.floor(base.hp * waveMult * newGamePlusMultiplier),
		speed = base.speed * speedMult,
		damage = math.floor(base.damage * damageMult * newGamePlusMultiplier),
		scrap = math.floor(base.scrap * (1 + (currentWave - 1) * 0.1)),
		size = base.size * sizeMult,
	}
end

local function getEnemyModelsFolder()
	return ServerStorage:FindFirstChild("Enemies") or ServerStorage:FindFirstChild("Monsters")
end

local function findModelInFolder(folder)
	local model = folder:FindFirstChild("Model")
	if model and model:IsA("Model") then return model end

	for _, child in ipairs(folder:GetChildren()) do
		if child:IsA("Model") and child:FindFirstChild("HumanoidRootPart") then
			return child
		end
	end

	if folder:FindFirstChild("HumanoidRootPart") then return folder end
	return nil
end

local function createSimpleEnemy(typeName, position, scaledType)
	local enemyType = scaledType or EnemyTypes[typeName]
	if not enemyType then return nil end

	local modelsFolder = getEnemyModelsFolder()
	local character = nil
	local sizeScale = enemyType.size or 1

	if modelsFolder then
		local modelFolder = modelsFolder:FindFirstChild(enemyType.modelName)
		if modelFolder then
			local sourceModel = findModelInFolder(modelFolder)
			if sourceModel then
				character = sourceModel:Clone()
				if sizeScale ~= 1 then
					character:ScaleTo(sizeScale)
				end
			end
		end
	end

	if not character then
		character = Instance.new("Model")
		character.Name = typeName

		local hrp = Instance.new("Part")
		hrp.Name = "HumanoidRootPart"
		hrp.Size = Vector3.new(2, 4, 2) * sizeScale
		hrp.Position = position
		hrp.Anchored = true
		hrp.CanCollide = false
		hrp.Material = Enum.Material.SmoothPlastic

		local waveTint = math.min(1, currentWave * 0.05)
		if typeName == "Zombie" then
			hrp.Color = Color3.fromRGB(100 + waveTint * 100, 150 - waveTint * 50, 100 - waveTint * 50)
		elseif typeName == "Runner" then
			hrp.Color = Color3.fromRGB(150 + waveTint * 50, 100 - waveTint * 30, 150 - waveTint * 50)
		elseif typeName == "Tank" then
			hrp.Color = Color3.fromRGB(100 + waveTint * 80, 100 - waveTint * 30, 150 - waveTint * 30)
		elseif typeName == "Boss" then
			hrp.Color = Color3.fromRGB(200 + waveTint * 55, 50, 50 + waveTint * 50)
		end

		hrp.Parent = character
		character.PrimaryPart = hrp
	end

	return character
end

function EnemyManager.spawn(typeName, gateIndex)
	local gate = spawnGates[gateIndex]
	if not gate then
		gate = spawnGates[1]
		if not gate then return nil end
	end

	local enemyType = getScaledStats(typeName)
	if not enemyType then return nil end

	local spawnX = gate.x + (math.random() - 0.5) * 6
	local spawnZ = gate.z + (math.random() - 0.5) * 6
	local spawnPos = Vector3.new(spawnX, GROUND_Y + 3, spawnZ)

	local character = createSimpleEnemy(typeName, spawnPos, enemyType)
	if not character then return nil end

	local hrp = character:FindFirstChild("HumanoidRootPart")
	if hrp then
		character:PivotTo(CFrame.new(spawnPos))
	end

	local humanoid = character:FindFirstChild("Humanoid")
	if humanoid then
		humanoid:SetStateEnabled(Enum.HumanoidStateType.FallingDown, false)
		humanoid:SetStateEnabled(Enum.HumanoidStateType.Running, false)
		humanoid:SetStateEnabled(Enum.HumanoidStateType.Climbing, false)
		humanoid:SetStateEnabled(Enum.HumanoidStateType.Ragdoll, false)
		humanoid:SetStateEnabled(Enum.HumanoidStateType.GettingUp, false)
		humanoid:SetStateEnabled(Enum.HumanoidStateType.Jumping, false)
		humanoid:SetStateEnabled(Enum.HumanoidStateType.Swimming, false)
		humanoid:SetStateEnabled(Enum.HumanoidStateType.Physics, false)
	end

	for _, part in ipairs(character:GetDescendants()) do
		if part:IsA("BasePart") then
			part.Anchored = true
			part.CanCollide = false
			part.CastShadow = false
			part.Massless = true
		end
	end

	character.Parent = workspace

	local isHunter = math.random() < 0.20

	local id = game:GetService("HttpService"):GenerateGUID()
	local enemy = {
		id = id,
		character = character,
		typeData = enemyType,
		typeName = typeName,
		hp = enemyType.hp,
		maxHp = enemyType.hp,
		speed = enemyType.speed,
		damage = enemyType.damage,
		scrap = enemyType.scrap,
		velocityX = 0,
		velocityZ = 0,
		time = math.random() * 10,
		baseY = GROUND_Y + 3,
		isHunter = isHunter,
		targetBotId = nil,
		lastAttackTime = 0,
		attackCooldown = 1.0,
		pathBias = (math.random() > 0.5) and 1 or -1,
	}

	if isHunter then
		for _, part in pairs(character:GetDescendants()) do
			if part:IsA("BasePart") then
				part.Color = Color3.fromRGB(150, 50, 200)
			end
		end
	end

	enemies[id] = enemy
	updateEnemyGridPosition(enemy, spawnX, spawnZ)
	character:SetAttribute("EnemyId", id)

	if deps.EntityRegistry then
		deps.EntityRegistry.register({
			id = id,
			isEnemy = true,
			isMonster = true,
			character = character,
			hp = enemy.hp,
			maxHp = enemy.maxHp,
		})
	end

	EnemyManager.createHpBar(enemy)

	return id
end

function EnemyManager.createHpBar(enemy)
	local character = enemy.character
	local hrp = character:FindFirstChild("HumanoidRootPart") or character.PrimaryPart
	if not hrp then return end

	local billboard = Instance.new("BillboardGui")
	billboard.Name = "EnemyHpBar"
	billboard.Size = UDim2.new(0, 60, 0, 10)
	billboard.StudsOffset = Vector3.new(0, 3 * (enemy.typeData.size or 1), 0)
	billboard.AlwaysOnTop = false
	billboard.MaxDistance = 50
	billboard.Parent = hrp

	local bgBar = Instance.new("Frame")
	bgBar.Name = "Background"
	bgBar.Size = UDim2.new(1, 0, 1, 0)
	bgBar.BackgroundColor3 = Color3.fromRGB(40, 40, 40)
	bgBar.BorderSizePixel = 0
	bgBar.Parent = billboard

	local bgCorner = Instance.new("UICorner")
	bgCorner.CornerRadius = UDim.new(0, 3)
	bgCorner.Parent = bgBar

	local hpBar = Instance.new("Frame")
	hpBar.Name = "HpBar"
	hpBar.Size = UDim2.new(1, 0, 1, 0)
	hpBar.BackgroundColor3 = Color3.fromRGB(255, 80, 80)
	hpBar.BorderSizePixel = 0
	hpBar.Parent = bgBar

	local hpCorner = Instance.new("UICorner")
	hpCorner.CornerRadius = UDim.new(0, 3)
	hpCorner.Parent = hpBar

	local nameLabel = Instance.new("TextLabel")
	nameLabel.Name = "NameLabel"
	nameLabel.Size = UDim2.new(1, 0, 0, 12)
	nameLabel.Position = UDim2.new(0, 0, 0, -14)
	nameLabel.BackgroundTransparency = 1
	nameLabel.Font = Enum.Font.GothamBold
	nameLabel.TextSize = 10
	nameLabel.TextStrokeTransparency = 0.5
	nameLabel.Parent = billboard

	if enemy.isHunter then
		nameLabel.Text = "⚔ HUNTER"
		nameLabel.TextColor3 = Color3.fromRGB(200, 100, 255)
	else
		nameLabel.Text = enemy.typeData.name or "Enemy"
		nameLabel.TextColor3 = Color3.fromRGB(255, 150, 150)
	end

	enemy.hpBillboard = billboard
end

function EnemyManager.updateHpBar(enemy)
	if not enemy.hpBillboard then return end

	local bgBar = enemy.hpBillboard:FindFirstChild("Background")
	if not bgBar then return end

	local hpBar = bgBar:FindFirstChild("HpBar")
	if not hpBar then return end

	local ratio = math.max(0, enemy.hp / enemy.maxHp)
	hpBar.Size = UDim2.new(ratio, 0, 1, 0)

	if ratio > 0.5 then
		hpBar.BackgroundColor3 = Color3.fromRGB(255, 80, 80)
	elseif ratio > 0.25 then
		hpBar.BackgroundColor3 = Color3.fromRGB(255, 150, 50)
	else
		hpBar.BackgroundColor3 = Color3.fromRGB(255, 50, 50)
	end
end

function EnemyManager.damage(enemyId, amount, sourceGundamId)
	local enemy = enemies[enemyId]
	if not enemy then return false end

	enemy.hp = enemy.hp - amount

	if deps.EntityRegistry then
		local entity = deps.EntityRegistry.get(enemyId)
		if entity then
			entity.hp = enemy.hp
		end
	end

	EnemyManager.updateHpBar(enemy)

	if enemy.character then
		local hrp = enemy.character:FindFirstChild("HumanoidRootPart")
		if hrp and deps.attackHitEvent then
			for _, player in ipairs(game:GetService("Players"):GetPlayers()) do
				deps.attackHitEvent:FireClient(player, {
					targetPos = hrp.Position,
					damage = amount,
					hitCount = 1,
				})
			end
		end
	end

	if enemy.hp <= 0 then
		EnemyManager.kill(enemyId, sourceGundamId)
		return true
	end

	return false
end

function EnemyManager.applySlow(enemyId, slowAmount, duration)
	local enemy = enemies[enemyId]
	if not enemy then return end

	enemy.slowAmount = slowAmount
	enemy.slowExpires = tick() + duration

	if enemy.character then
		for _, part in ipairs(enemy.character:GetDescendants()) do
			if part:IsA("BasePart") and not part:GetAttribute("OriginalColor") then
				part:SetAttribute("OriginalColor", part.Color:ToHex())
			end
			if part:IsA("BasePart") then
				local origHex = part:GetAttribute("OriginalColor")
				if origHex then
					local orig = Color3.fromHex(origHex)
					part.Color = orig:Lerp(Color3.fromRGB(100, 200, 255), 0.5)
				end
			end
		end
	end
end

function EnemyManager.clearSlow(enemy)
	enemy.slowAmount = nil
	enemy.slowExpires = nil

	if enemy.character then
		for _, part in ipairs(enemy.character:GetDescendants()) do
			if part:IsA("BasePart") then
				local origHex = part:GetAttribute("OriginalColor")
				if origHex then
					part.Color = Color3.fromHex(origHex)
				end
			end
		end
	end
end

function EnemyManager.applyOiled(enemyId, duration)
	local enemy = enemies[enemyId]
	if not enemy then return end

	enemy.oiled = true
	enemy.oiledExpires = tick() + (duration or 5)

	if enemy.character then
		for _, part in ipairs(enemy.character:GetDescendants()) do
			if part:IsA("BasePart") and not part:GetAttribute("OriginalColor") then
				part:SetAttribute("OriginalColor", part.Color:ToHex())
			end
			if part:IsA("BasePart") then
				local origHex = part:GetAttribute("OriginalColor")
				if origHex then
					local orig = Color3.fromHex(origHex)
					part.Color = orig:Lerp(Color3.fromRGB(255, 140, 0), 0.6)
				end
			end
		end
	end
end

function EnemyManager.applyBurning(enemyId, duration, damagePerTick)
	local enemy = enemies[enemyId]
	if not enemy then return end

	enemy.burning = true
	enemy.burningExpires = tick() + (duration or 3)
	enemy.burningDamage = damagePerTick or 5
	enemy.burningLastTick = tick()

	if enemy.character then
		for _, part in ipairs(enemy.character:GetDescendants()) do
			if part:IsA("BasePart") and not part:GetAttribute("OriginalColor") then
				part:SetAttribute("OriginalColor", part.Color:ToHex())
			end
			if part:IsA("BasePart") then
				local origHex = part:GetAttribute("OriginalColor")
				if origHex then
					local orig = Color3.fromHex(origHex)
					part.Color = orig:Lerp(Color3.fromRGB(255, 80, 20), 0.5)
				end
			end
		end

		local hrp = enemy.character:FindFirstChild("HumanoidRootPart")
		if hrp and not hrp:FindFirstChild("FireEffect") then
			local fire = Instance.new("ParticleEmitter")
			fire.Name = "FireEffect"
			fire.Color = ColorSequence.new(Color3.fromRGB(255, 150, 0), Color3.fromRGB(255, 50, 0))
			fire.Size = NumberSequence.new(0.5, 0)
			fire.Lifetime = NumberRange.new(0.3, 0.6)
			fire.Rate = 30
			fire.Speed = NumberRange.new(2, 4)
			fire.SpreadAngle = Vector2.new(30, 30)
			fire.Parent = hrp
		end
	end
end

function EnemyManager.shock(enemyId, baseDamage, sourceX, sourceZ, botScrap, globalPower)
	local enemy = enemies[enemyId]
	if not enemy then return 0 end

	baseDamage = baseDamage or 30
	botScrap = botScrap or 0
	globalPower = globalPower or 1

	local totalDamage = baseDamage * globalPower

	if botScrap > 0 then
		totalDamage = totalDamage * (1.5 ^ botScrap)
	end

	if enemy.oiled then
		totalDamage = totalDamage * 2
		enemy.oiled = nil
		enemy.oiledExpires = nil
		EnemyManager.createShockExplosion(enemy)
	end

	if enemy.burning then
		totalDamage = totalDamage * 1.5
		enemy.burning = nil
		enemy.burningExpires = nil
		if enemy.character then
			local hrp = enemy.character:FindFirstChild("HumanoidRootPart")
			if hrp then
				local fire = hrp:FindFirstChild("FireEffect")
				if fire then fire:Destroy() end
			end
		end
		EnemyManager.chainLightning(enemyId, totalDamage * 0.3, sourceX, sourceZ)
	end

	if enemy.slowAmount and enemy.slowAmount > 0 then
		totalDamage = totalDamage * (1 + enemy.slowAmount)
	end

	EnemyManager.damage(enemyId, math.floor(totalDamage))
	EnemyManager.createShockSparks(enemy)

	return math.floor(totalDamage)
end

function EnemyManager.checkShatterCombo(enemyId, rocketDamage)
	local enemy = enemies[enemyId]
	if not enemy then return rocketDamage end

	if enemy.slowAmount and enemy.slowAmount >= 0.5 then
		EnemyManager.clearSlow(enemy)
		EnemyManager.createShatterEffect(enemy)
		return rocketDamage * 1.5
	end

	return rocketDamage
end

function EnemyManager.createShockExplosion(enemy)
	if not enemy.character then return end
	local hrp = enemy.character:FindFirstChild("HumanoidRootPart")
	if not hrp then return end

	local explosion = Instance.new("Part")
	explosion.Shape = Enum.PartType.Ball
	explosion.Size = Vector3.new(1, 1, 1)
	explosion.Position = hrp.Position
	explosion.Anchored = true
	explosion.CanCollide = false
	explosion.Material = Enum.Material.Neon
	explosion.Color = Color3.fromRGB(255, 200, 50)
	explosion.Transparency = 0.3
	explosion.Parent = workspace

	task.spawn(function()
		for i = 1, 15 do
			explosion.Size = Vector3.new(i * 1.5, i * 1.5, i * 1.5)
			explosion.Transparency = 0.3 + (i / 15) * 0.7
			task.wait(0.02)
		end
		explosion:Destroy()
	end)
end

function EnemyManager.createShockSparks(enemy)
	if not enemy.character then return end
	local hrp = enemy.character:FindFirstChild("HumanoidRootPart")
	if not hrp then return end

	local sparks = Instance.new("ParticleEmitter")
	sparks.Color = ColorSequence.new(Color3.fromRGB(100, 200, 255), Color3.fromRGB(255, 255, 100))
	sparks.Size = NumberSequence.new(0.3, 0)
	sparks.Lifetime = NumberRange.new(0.1, 0.3)
	sparks.Rate = 100
	sparks.Speed = NumberRange.new(5, 15)
	sparks.SpreadAngle = Vector2.new(180, 180)
	sparks.Parent = hrp

	task.delay(0.2, function()
		sparks.Enabled = false
		task.delay(0.3, function() sparks:Destroy() end)
	end)
end

function EnemyManager.createShatterEffect(enemy)
	if not enemy.character then return end
	local hrp = enemy.character:FindFirstChild("HumanoidRootPart")
	if not hrp then return end

	for i = 1, 8 do
		local shard = Instance.new("Part")
		shard.Size = Vector3.new(0.3, 0.6, 0.2)
		shard.Position = hrp.Position
		shard.Anchored = false
		shard.CanCollide = false
		shard.Material = Enum.Material.Ice
		shard.Color = Color3.fromRGB(150, 220, 255)
		shard.Transparency = 0.3
		shard.Parent = workspace

		local angle = (i / 8) * math.pi * 2
		local vel = Instance.new("BodyVelocity")
		vel.Velocity = Vector3.new(math.cos(angle) * 20, 10, math.sin(angle) * 20)
		vel.MaxForce = Vector3.new(10000, 10000, 10000)
		vel.Parent = shard

		task.delay(0.5, function()
			shard:Destroy()
		end)
	end
end

function EnemyManager.chainLightning(sourceEnemyId, chainDamage, sourceX, sourceZ)
	local sourceEnemy = enemies[sourceEnemyId]
	if not sourceEnemy or not sourceEnemy.character then return end

	local sourceHrp = sourceEnemy.character:FindFirstChild("HumanoidRootPart")
	if not sourceHrp then return end

	local nearbyEnemies = EnemyManager.findInRange(sourceHrp.Position.X, sourceHrp.Position.Z, 15)
	local chainCount = 0

	for _, nearbyEnemy in ipairs(nearbyEnemies) do
		if nearbyEnemy.id ~= sourceEnemyId and chainCount < 3 then
			EnemyManager.createLightningBolt(sourceHrp.Position, nearbyEnemy.character)
			EnemyManager.damage(nearbyEnemy.id, chainDamage)
			EnemyManager.createShockSparks(nearbyEnemy)
			chainCount = chainCount + 1
		end
	end
end

function EnemyManager.createLightningBolt(startPos, targetChar)
	if not targetChar then return end
	local targetHrp = targetChar:FindFirstChild("HumanoidRootPart")
	if not targetHrp then return end

	local endPos = targetHrp.Position

	local beam = Instance.new("Part")
	beam.Anchored = true
	beam.CanCollide = false
	beam.Material = Enum.Material.Neon
	beam.Color = Color3.fromRGB(100, 200, 255)

	local distance = (endPos - startPos).Magnitude
	beam.Size = Vector3.new(0.2, 0.2, distance)
	beam.CFrame = CFrame.lookAt(startPos, endPos) * CFrame.new(0, 0, -distance / 2)
	beam.Parent = workspace

	task.delay(0.15, function()
		beam:Destroy()
	end)
end

function EnemyManager.updateStatusEffects(enemy)
	local now = tick()

	if enemy.oiledExpires and now > enemy.oiledExpires then
		enemy.oiled = nil
		enemy.oiledExpires = nil
	end

	if enemy.burning then
		if enemy.burningExpires and now > enemy.burningExpires then
			enemy.burning = nil
			enemy.burningExpires = nil
			enemy.burningDamage = nil
			if enemy.character then
				local hrp = enemy.character:FindFirstChild("HumanoidRootPart")
				if hrp then
					local fire = hrp:FindFirstChild("FireEffect")
					if fire then fire:Destroy() end
				end
			end
		elseif enemy.burningLastTick and now - enemy.burningLastTick >= 0.5 then
			enemy.burningLastTick = now
			EnemyManager.damage(enemy.id, enemy.burningDamage or 5)
		end
	end
end

function EnemyManager.kill(enemyId, killerGundamId)
	local enemy = enemies[enemyId]
	if not enemy then return end

	local deathPosition = nil
	local scrapAmount = enemy.scrap or 10

	if enemy.character then
		local hrp = enemy.character:FindFirstChild("HumanoidRootPart")
		if hrp then
			deathPosition = hrp.Position

			task.spawn(function()
				for i = 1, 10 do
					if enemy.character and enemy.character.Parent then
						local scale = 1 - (i / 10)
						enemy.character:ScaleTo(math.max(0.1, scale))
					end
					task.wait(0.03)
				end
				if enemy.character then
					enemy.character:Destroy()
				end
			end)
		end
	end

	if deps.ScrapManager and deathPosition then
		deps.ScrapManager.spawn(deathPosition, scrapAmount)
	end

	if deps.EntityRegistry then
		deps.EntityRegistry.unregister(enemyId)
	end

	if WaveManager then
		local killerOwnerId = nil
		if killerGundamId and deps.Interpreters then
			local data = deps.Interpreters.get(killerGundamId)
			if data then
				killerOwnerId = data.ownerId
			end
		end
		WaveManager.onEnemyKilled(killerOwnerId)
	end

	removeEnemyFromGrid(enemy)
	enemies[enemyId] = nil
end

local function getEnemiesNearPoint(x, z, range)
	local cellsToCheck = math.ceil(range / GRID_CELL_SIZE)
	local gx = math.floor(x / GRID_CELL_SIZE)
	local gz = math.floor(z / GRID_CELL_SIZE)

	local results = {}

	for i = -cellsToCheck, cellsToCheck do
		for j = -cellsToCheck, cellsToCheck do
			local key = (gx + i) .. "_" .. (gz + j)
			local cell = enemyGrid[key]
			if cell then
				for _, enemy in ipairs(cell) do
					table.insert(results, enemy)
				end
			end
		end
	end

	return results
end

function EnemyManager.update(dt)
	if not WaveManager then return end

	local corePos = WaveManager.getCorePosition()
	if not corePos then return end

	local toRemove = {}
	local partList = {}
	local cframeList = {}

	local CORE_REACH_DIST_SQ = 4 * 4

	for id, enemy in pairs(enemies) do
		local character = enemy.character
		local hrp = character and character:FindFirstChild("HumanoidRootPart")

		if not hrp then
			table.insert(toRemove, id)
			continue
		end

		if enemy.hp <= 0 then
			continue
		end

		local myX, myZ = hrp.Position.X, hrp.Position.Z

		local coreDx = corePos.x - myX
		local coreDz = corePos.z - myZ
		local coreDistSq = coreDx * coreDx + coreDz * coreDz

		if coreDistSq < CORE_REACH_DIST_SQ then
			WaveManager.damageCore(enemy.damage)
			WaveManager.onEnemyReachedCore()
			removeEnemyFromGrid(enemy)
			if character then character:Destroy() end
			if deps.EntityRegistry then
				deps.EntityRegistry.unregister(id)
			end
			table.insert(toRemove, id)
			continue
		end

		if enemy.slowExpires and tick() > enemy.slowExpires then
			EnemyManager.clearSlow(enemy)
		end

		EnemyManager.updateStatusEffects(enemy)

		local effectiveSpeed = enemy.speed
		if enemy.slowAmount then
			effectiveSpeed = enemy.speed * (1 - enemy.slowAmount)
		end

		if not enemy.targetCenter then
			enemy.targetCenter = PathMap.getBestNextCenter(myX, myZ)
		end

		local target = enemy.targetCenter
		if not target then
			target = corePos
		end

		local dx = target.x - myX
		local dz = target.z - myZ
		local distToTarget = math.sqrt(dx * dx + dz * dz)

		if distToTarget < 2 then
			enemy.targetCenter = PathMap.getBestNextCenter(myX, myZ)
			target = enemy.targetCenter or corePos
			dx = target.x - myX
			dz = target.z - myZ
			distToTarget = math.sqrt(dx * dx + dz * dz)
		end

		local dirX, dirZ = 0, 0
		if distToTarget > 0.1 then
			dirX = dx / distToTarget
			dirZ = dz / distToTarget
		end

		if dirX ~= 0 or dirZ ~= 0 then
			local targetVelX = dirX * effectiveSpeed
			local targetVelZ = dirZ * effectiveSpeed

			enemy.velocityX = enemy.velocityX + (targetVelX - enemy.velocityX) * 0.15
			enemy.velocityZ = enemy.velocityZ + (targetVelZ - enemy.velocityZ) * 0.15

			local newX = myX + enemy.velocityX * dt
			local newZ = myZ + enemy.velocityZ * dt

			updateEnemyGridPosition(enemy, newX, newZ)

			enemy.time = enemy.time + dt
			local bobAmount = 0.2
			local bobSpeed = enemy.speed * 2
			local bob = math.sin(enemy.time * bobSpeed) * bobAmount
			local newY = enemy.baseY + bob

			local facingAngle = math.atan2(enemy.velocityX, enemy.velocityZ) + math.pi

			local newCF = CFrame.new(newX, newY, newZ) * CFrame.Angles(0, facingAngle, 0)
			table.insert(partList, hrp)
			table.insert(cframeList, newCF)
		end
	end

	if #partList > 0 then
		workspace:BulkMoveTo(partList, cframeList, Enum.BulkMoveMode.FireCFrameChanged)
	end

	for _, id in ipairs(toRemove) do
		enemies[id] = nil
	end
end

function EnemyManager.get(id)
	return enemies[id]
end

function EnemyManager.getAll()
	return enemies
end

function EnemyManager.count()
	local n = 0
	for _ in pairs(enemies) do n = n + 1 end
	return n
end

function EnemyManager.getMinimapData()
	local data = {}

	for id, enemy in pairs(enemies) do
		if enemy.hp > 0 then
			local character = enemy.character
			local hrp = character and character:FindFirstChild("HumanoidRootPart")
			if hrp then
				local dist = PathMap.getDistance(hrp.Position.X, hrp.Position.Z)
				local maxDist = 200
				local progress = 1 - math.min(1, dist / maxDist)

				table.insert(data, {
					id = id,
					typeName = enemy.typeName,
					pathProgress = progress,
				})
			end
		end
	end

	return data
end

function EnemyManager.getPathLength()
	return 200
end

function EnemyManager.findNearest(x, z, maxRange)
	local effectiveRange = math.min(maxRange or MAX_SEARCH_RANGE, MAX_SEARCH_RANGE)
	local nearestDistSq = effectiveRange * effectiveRange

	local candidates = getEnemiesNearPoint(x, z, effectiveRange)
	local nearest = nil

	for _, enemy in ipairs(candidates) do
		if enemy.hp > 0 and enemy.character then
			local hrp = enemy.character:FindFirstChild("HumanoidRootPart")
			if hrp then
				local dx = hrp.Position.X - x
				local dz = hrp.Position.Z - z
				local distSq = dx * dx + dz * dz
				if distSq < nearestDistSq then
					nearestDistSq = distSq
					nearest = enemy
				end
			end
		end
	end

	return nearest, nearest and math.sqrt(nearestDistSq) or (maxRange or math.huge)
end

function EnemyManager.findWeakest(x, z, maxRange)
	local effectiveRange = math.min(maxRange or MAX_SEARCH_RANGE, MAX_SEARCH_RANGE)
	local effectiveRangeSq = effectiveRange * effectiveRange

	local candidates = getEnemiesNearPoint(x, z, effectiveRange)
	local weakest = nil
	local lowestHp = math.huge

	for _, enemy in ipairs(candidates) do
		if enemy.hp > 0 and enemy.character then
			local hrp = enemy.character:FindFirstChild("HumanoidRootPart")
			if hrp then
				local dx = hrp.Position.X - x
				local dz = hrp.Position.Z - z
				local distSq = dx * dx + dz * dz
				if distSq <= effectiveRangeSq and enemy.hp < lowestHp then
					lowestHp = enemy.hp
					weakest = enemy
				end
			end
		end
	end

	return weakest
end

function EnemyManager.findInRange(x, z, range)
	local inRange = {}
	local candidates = getEnemiesNearPoint(x, z, range)
	local rangeSq = range * range

	for _, enemy in ipairs(candidates) do
		if enemy.hp > 0 and enemy.character then
			local hrp = enemy.character:FindFirstChild("HumanoidRootPart")
			if hrp then
				local dx = hrp.Position.X - x
				local dz = hrp.Position.Z - z
				local distSq = dx * dx + dz * dz
				if distSq <= rangeSq then
					table.insert(inRange, enemy)
				end
			end
		end
	end

	return inRange
end

function EnemyManager.clear()
	for id, enemy in pairs(enemies) do
		if enemy.character then
			enemy.character:Destroy()
		end
		if deps and deps.EntityRegistry then
			deps.EntityRegistry.unregister(id)
		end
	end
	enemies = {}
	table.clear(enemyGrid)
end

function EnemyManager.startUpdateLoop()
	RunService.Heartbeat:Connect(function(dt)
		EnemyManager.update(dt)
	end)
end

return EnemyManager
