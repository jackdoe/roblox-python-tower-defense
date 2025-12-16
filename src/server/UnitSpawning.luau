local Players = game:GetService("Players")

local UnitSpawning = {}

local spawnedUnits = {}

local Interpreters = nil
local arenaMap = nil

function UnitSpawning.init(map, interpretersModule)
	arenaMap = map
	Interpreters = interpretersModule
end

function UnitSpawning.spawnForPlayer(player, waveNumber)
	local userId = player.UserId

	if arenaMap.initialGundams then
		for i, pos in ipairs(arenaMap.initialGundams) do
			local unlockWave = pos.unlockWave or 1
			local key = userId .. "_gundam_" .. i
			if unlockWave <= waveNumber and not spawnedUnits[key] then
				local playerIndex = 0
				for idx, p in ipairs(Players:GetPlayers()) do
					if p.UserId == userId then
						playerIndex = idx - 1
						break
					end
				end
				local offsetX = (playerIndex % 3) * 12 - 12
				local offsetZ = math.floor(playerIndex / 3) * 12

				local pid = Interpreters.create("gundam", userId, pos.x + offsetX, pos.z + offsetZ)
				if pid then
					spawnedUnits[key] = pid
				end
			end
		end
	end

	if arenaMap.initialBots then
		for i, pos in ipairs(arenaMap.initialBots) do
			local unlockWave = pos.unlockWave or 1
			local key = userId .. "_bot_" .. i
			if unlockWave <= waveNumber and not spawnedUnits[key] then
				local playerIndex = 0
				for idx, p in ipairs(Players:GetPlayers()) do
					if p.UserId == userId then
						playerIndex = idx - 1
						break
					end
				end
				local offsetX = (playerIndex % 3) * 10 - 10
				local offsetZ = math.floor(playerIndex / 3) * 10

				local pid = Interpreters.create("bot", userId, pos.x + offsetX, pos.z + offsetZ)
				if pid then
					spawnedUnits[key] = pid
				end
			end
		end
	end
end

function UnitSpawning.spawnForWave(waveNumber)
	for _, player in ipairs(Players:GetPlayers()) do
		UnitSpawning.spawnForPlayer(player, waveNumber)
	end
end

function UnitSpawning.removePlayerUnits(userId)
	for key, pid in pairs(spawnedUnits) do
		if string.match(key, "^" .. userId .. "_") then
			Interpreters.destroy(pid)
			spawnedUnits[key] = nil
		end
	end
end

function UnitSpawning.reset()
	spawnedUnits = {}
	UnitSpawning.spawnForWave(1)
end

return UnitSpawning
