local Players = game:GetService("Players")
local PhysicsService = game:GetService("PhysicsService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local PythonTD = ReplicatedStorage:WaitForChild("PythonTD")
local Config = require(PythonTD.Config)
local EntityRegistry = require(PythonTD.Modules.EntityRegistry)

local RemoteEvents = require(script.Parent.RemoteEvents)

local PlayerManager = {}

PhysicsService:RegisterCollisionGroup("Players")
PhysicsService:CollisionGroupSetCollidable("Players", "Players", false)

local playerPids = {}
local nextPlayerId = 1
local rateLimits = {}

local deps = nil
local arenaMap = nil
local unitSpawning = nil
local Interpreters = nil

function PlayerManager.init(dependencies, map, spawning, interpretersModule)
	deps = dependencies
	arenaMap = map
	unitSpawning = spawning
	Interpreters = interpretersModule
end

function PlayerManager.get(userId)
	local pid = playerPids[userId]
	if not pid then return nil end
	local data = Interpreters.get(pid)
	return data and data.interpreter
end

function PlayerManager.getPid(userId)
	return playerPids[userId]
end

function PlayerManager.getAll()
	local result = {}
	for userId, pid in pairs(playerPids) do
		local data = Interpreters.get(pid)
		if data then
			result[userId] = data.interpreter
		end
	end
	return result
end

function PlayerManager.checkRateLimit(player, action, cooldown)
	local key = player.UserId .. "_" .. action
	local now = tick()
	if rateLimits[key] and now - rateLimits[key] < cooldown then
		return false
	end
	rateLimits[key] = now
	return true
end

local function setPlayerCollisionGroup(character)
	for _, part in pairs(character:GetDescendants()) do
		if part:IsA("BasePart") then
			part.CollisionGroup = "Players"
		end
	end
	character.DescendantAdded:Connect(function(part)
		if part:IsA("BasePart") then
			part.CollisionGroup = "Players"
		end
	end)
end

local function onCharacterAdded(player, playerId, character)
	setPlayerCollisionGroup(character)

	local oldPid = playerPids[player.UserId]
	if oldPid then
		Interpreters.destroy(oldPid)
	end

	local pid = Interpreters.createPlayer(player.UserId, character, playerId)
	local data = Interpreters.get(pid)
	local interp = data.interpreter

	interp.playerName = player.Name
	interp.ammoInventory = Config.STARTING_AMMO or 100
	interp.scrapInventory = 0
	interp.maxCapacity = Config.PLAYER_CAPACITY or 5

	playerPids[player.UserId] = pid

	task.defer(function()
		local spawnPos = arenaMap.playerSpawn
		if spawnPos and character and character.Parent then
			local hrp = character:FindFirstChild("HumanoidRootPart")
			if hrp then
				local angle = spawnPos.facingAngle or 0
				hrp.CFrame = CFrame.new(spawnPos.x, Config.PLATFORM_Y + 3, spawnPos.z) * CFrame.Angles(0, math.rad(angle), 0)
			end
		end
	end)

	Interpreters.sendFullSync(player)
end

function PlayerManager.onPlayerAdded(player)
	local playerId = nextPlayerId
	nextPlayerId = nextPlayerId + 1

	player.CharacterAdded:Connect(function(character)
		onCharacterAdded(player, playerId, character)
	end)

	if player.Character then
		onCharacterAdded(player, playerId, player.Character)
	end

	if unitSpawning then
		local waveState = deps.WaveManager.getState()
		local currentWave = waveState.waveNumber or 0
		if currentWave >= 1 then
			unitSpawning.spawnForPlayer(player, currentWave)
		end
	end
end

function PlayerManager.onPlayerRemoving(player)
	local userId = player.UserId

	local pid = playerPids[userId]
	if pid then
		Interpreters.destroy(pid)
		playerPids[userId] = nil
	end

	Interpreters.clearPlayerCache(userId)

	if unitSpawning then
		unitSpawning.removePlayerUnits(userId)
	end
end

function PlayerManager.updateScrap(interp, player, ScrapManager, WaveManager)
	if not player.Character then return end

	local hrp = player.Character:FindFirstChild("HumanoidRootPart")
	if not hrp then return end

	local px, pz = hrp.Position.X, hrp.Position.Z

	local capacity = Config.PLAYER_CAPACITY or 5
	if (interp.scrapInventory or 0) < capacity then
		local scrap = ScrapManager.findNearest(px, pz, Config.PICKUP_RANGE or 5)
		if scrap and scrap.id and ScrapManager.collect(scrap.id) then
			interp.scrapInventory = (interp.scrapInventory or 0) + 1
		end
	end

	local coreX, coreZ = arenaMap.core.x, arenaMap.core.z
	local distToCore = math.sqrt((px - coreX)^2 + (pz - coreZ)^2)
	if distToCore <= 10 and (interp.scrapInventory or 0) > 0 then
		local pieceValue = Config.SCRAP_PIECE_VALUE or 10
		local amount = interp.scrapInventory
		WaveManager.addScrap(player.UserId, amount * pieceValue)
		interp.scrapInventory = 0
		RemoteEvents.depositEffect:FireAllClients(
			Vector3.new(px, Config.PLATFORM_Y + 2, pz),
			Vector3.new(coreX, Config.PLATFORM_Y + 3, coreZ),
			amount
		)
	end
end

function PlayerManager.buildGameState(userId, interp)
	local state = {}

	local allPlayers = {}
	for _, entity in pairs(EntityRegistry.getAll()) do
		if entity.isPlayer and entity.playerId then
			table.insert(allPlayers, {
				id = entity.playerId,
				name = entity.playerName or "Player",
				isMe = (entity.id == interp.id),
			})
		end
	end
	table.sort(allPlayers, function(a, b) return (a.id or 0) < (b.id or 0) end)
	state.allPlayers = allPlayers
	state.myPlayerId = interp.playerId

	state.scrap = deps.WaveManager.getScrap(userId)
	state.ammoInventory = interp.ammoInventory
	state.scrapInventory = interp.scrapInventory or 0
	state.maxCapacity = interp.maxCapacity or 50

	local waveState = deps.WaveManager.getState()
	state.waveNumber = waveState.waveNumber
	state.phase = waveState.phase
	state.coreHp = waveState.coreHp
	state.coreMaxHp = waveState.coreMaxHp
	state.restartTimeRemaining = waveState.restartTimeRemaining
	state.enemiesRemaining = waveState.enemiesRemaining
	state.enemiesTotal = waveState.enemiesTotal

	state.enemyMinimap = deps.EnemyManager.getMinimapData()
	state.pathLength = deps.EnemyManager.getPathLength()

	return state
end

return PlayerManager
