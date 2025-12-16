local TweenService = game:GetService("TweenService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local PythonTD = ReplicatedStorage:WaitForChild("PythonTD")
local Config = require(PythonTD.Config)

local ScrapManager = {}

local GROUND_Y = Config.PLATFORM_Y
local GRID_CELL_SIZE = 20
local SCRAP_LIFETIME = 60
local PIECE_VALUE = Config.SCRAP_PIECE_VALUE

local scrapPiles = {}
local scrapGrid = {}
local deps = nil

function ScrapManager.init(dependencies)
	deps = dependencies
end

local function getGridKey(x, z)
	local gx = math.floor(x / GRID_CELL_SIZE)
	local gz = math.floor(z / GRID_CELL_SIZE)
	return gx .. "_" .. gz
end

local function addToGrid(scrap)
	if not scrap.part or not scrap.part.Parent then return end
	local pos = scrap.part.Position
	local key = getGridKey(pos.X, pos.Z)
	scrap.gridKey = key
	if not scrapGrid[key] then
		scrapGrid[key] = {}
	end
	table.insert(scrapGrid[key], scrap)
end

local function removeFromGrid(scrap)
	if not scrap.gridKey then return end
	local cell = scrapGrid[scrap.gridKey]
	if cell then
		for i, s in ipairs(cell) do
			if s.id == scrap.id then
				table.remove(cell, i)
				if #cell == 0 then
					scrapGrid[scrap.gridKey] = nil
				end
				break
			end
		end
	end
	scrap.gridKey = nil
end

local function spawnSinglePiece(position, offset)
	local id = game:GetService("HttpService"):GenerateGUID()

	local part = Instance.new("Part")
	part.Name = "Scrap_" .. id
	part.Size = Vector3.new(1.5, 1.5, 1.5)
	part.Position = position + Vector3.new(offset.x, 2, offset.z)
	part.Color = Color3.fromRGB(255, 200, 50)
	part.Material = Enum.Material.Metal
	part.Anchored = false
	part.CanCollide = true
	part.Shape = Enum.PartType.Block

	local light = Instance.new("PointLight")
	light.Color = Color3.fromRGB(255, 200, 50)
	light.Brightness = 0.5
	light.Range = 6
	light.Parent = part

	part.Velocity = Vector3.new(
		offset.x * 10 + (math.random() - 0.5) * 10,
		15 + math.random() * 10,
		offset.z * 10 + (math.random() - 0.5) * 10
	)
	part.RotVelocity = Vector3.new(
		math.random() * 5,
		math.random() * 5,
		math.random() * 5
	)

	part.Parent = workspace

	local scrapData = {
		id = id,
		part = part,
		created = tick(),
		gridKey = nil,
		settled = false,
	}

	scrapPiles[id] = scrapData

	task.delay(2, function()
		if part and part.Parent then
			part.Anchored = true
			part.CanCollide = false
			scrapData.settled = true
			addToGrid(scrapData)
		end
	end)

	task.delay(SCRAP_LIFETIME, function()
		if scrapPiles[id] then
			ScrapManager.remove(id)
		end
	end)

	return id
end

function ScrapManager.spawn(position, totalValue)
	local pieceCount = math.max(1, math.floor(totalValue / PIECE_VALUE))
	local ids = {}

	for i = 1, pieceCount do
		local angle = (i / pieceCount) * math.pi * 2
		local radius = math.min(pieceCount * 0.5, 3)
		local offset = {
			x = math.cos(angle) * radius,
			z = math.sin(angle) * radius,
		}
		local id = spawnSinglePiece(position, offset)
		table.insert(ids, id)
	end

	return ids
end

function ScrapManager.remove(id)
	local scrap = scrapPiles[id]
	if not scrap then return end

	removeFromGrid(scrap)

	if scrap.part then
		task.spawn(function()
			local part = scrap.part
			if part and part.Parent then
				local tween = TweenService:Create(part, TweenInfo.new(0.3), {
					Transparency = 1,
					Size = Vector3.new(0.1, 0.1, 0.1),
				})
				tween:Play()
				tween.Completed:Wait()
				part:Destroy()
			end
		end)
	end

	scrapPiles[id] = nil
end

function ScrapManager.collect(id)
	local scrap = scrapPiles[id]
	if not scrap then return false end

	ScrapManager.remove(id)
	return true
end

function ScrapManager.get(id)
	return scrapPiles[id]
end

function ScrapManager.getAll()
	return scrapPiles
end

function ScrapManager.count()
	local n = 0
	for _ in pairs(scrapPiles) do n = n + 1 end
	return n
end

function ScrapManager.getPieceValue()
	return PIECE_VALUE
end

local function getScrapNearPoint(x, z, range)
	local cellsToCheck = math.ceil(range / GRID_CELL_SIZE)
	local gx = math.floor(x / GRID_CELL_SIZE)
	local gz = math.floor(z / GRID_CELL_SIZE)

	local results = {}

	for i = -cellsToCheck, cellsToCheck do
		for j = -cellsToCheck, cellsToCheck do
			local key = (gx + i) .. "_" .. (gz + j)
			local cell = scrapGrid[key]
			if cell then
				for _, scrap in ipairs(cell) do
					if scrap.settled then
						table.insert(results, scrap)
					end
				end
			end
		end
	end

	return results
end

function ScrapManager.findNearest(x, z, maxRange)
	maxRange = maxRange or 100
	local nearest = nil
	local nearestDistSq = maxRange * maxRange

	local candidates = getScrapNearPoint(x, z, maxRange)

	for _, scrap in ipairs(candidates) do
		if scrap.part and scrap.part.Parent then
			local pos = scrap.part.Position
			local dx = pos.X - x
			local dz = pos.Z - z
			local distSq = dx * dx + dz * dz
			if distSq < nearestDistSq then
				nearestDistSq = distSq
				nearest = scrap
			end
		end
	end

	return nearest, nearest and math.sqrt(nearestDistSq) or maxRange
end

function ScrapManager.findInRange(x, z, range)
	local results = {}
	local rangeSq = range * range

	local candidates = getScrapNearPoint(x, z, range)

	for _, scrap in ipairs(candidates) do
		if scrap.part and scrap.part.Parent then
			local pos = scrap.part.Position
			local dx = pos.X - x
			local dz = pos.Z - z
			local distSq = dx * dx + dz * dz
			if distSq <= rangeSq then
				table.insert(results, scrap)
			end
		end
	end

	return results
end

function ScrapManager.findBestCluster(x, z, searchRange, pickupRange)
	searchRange = searchRange or 200
	pickupRange = pickupRange or 20

	local candidates = getScrapNearPoint(x, z, searchRange)
	if #candidates == 0 then return nil, 0, 0 end

	local bestX, bestZ = 0, 0
	local bestCount = 0

	for _, scrap in ipairs(candidates) do
		if scrap.part and scrap.part.Parent then
			local cx = scrap.part.Position.X
			local cz = scrap.part.Position.Z

			local count = 0
			local sumX, sumZ = 0, 0

			for _, other in ipairs(candidates) do
				if other.part and other.part.Parent then
					local ox = other.part.Position.X
					local oz = other.part.Position.Z
					local dx = ox - cx
					local dz = oz - cz
					local distSq = dx * dx + dz * dz
					if distSq <= pickupRange * pickupRange then
						count = count + 1
						sumX = sumX + ox
						sumZ = sumZ + oz
					end
				end
			end

			if count > bestCount then
				bestCount = count
				bestX = sumX / count
				bestZ = sumZ / count
			end
		end
	end

	if bestCount == 0 then return nil, 0, 0 end
	return bestX, bestZ, bestCount
end

function ScrapManager.clear()
	for id, scrap in pairs(scrapPiles) do
		if scrap.part then
			scrap.part:Destroy()
		end
	end
	scrapPiles = {}
	table.clear(scrapGrid)
end

return ScrapManager
