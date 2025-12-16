local ReplicatedStorage = game:GetService("ReplicatedStorage")
local PythonTD = ReplicatedStorage:WaitForChild("PythonTD")
local Config = require(PythonTD.Config)

local PathMap = {}

local CELL_SIZE = 15
local INF = 1e9

local grid = {}
local distance = {}
local width = 0
local height = 0
local coreGx, coreGz = 0, 0
local spawnGates = {}

local function idx(gx, gz)
	return gx + (gz - 1) * width
end

function PathMap.init(layout, cellSize)
	CELL_SIZE = cellSize or 15
	height = #layout
	width = #layout[1]

	grid = {}
	distance = {}
	spawnGates = {}

	local totalCells = width * height
	for i = 1, totalCells do
		grid[i] = false
		distance[i] = INF
	end

	for gz = 1, height do
		local row = layout[gz]
		for gx = 1, width do
			local char = row:sub(gx, gx)
			local i = idx(gx, gz)

			if char == "1" or char == "G" or char == "C" then
				grid[i] = true
			end

			if char == "G" then
				table.insert(spawnGates, {gx = gx, gz = gz})
			elseif char == "C" then
				coreGx, coreGz = gx, gz
			end
		end
	end

	PathMap.computeDistances()
	PathMap.createVisuals()
end

function PathMap.computeDistances()
	for i = 1, width * height do
		distance[i] = INF
	end

	local queue = {}
	local head = 1

	if coreGx == 0 or coreGz == 0 then
		return
	end

	local coreIdx = idx(coreGx, coreGz)
	distance[coreIdx] = 0
	table.insert(queue, {gx = coreGx, gz = coreGz})

	local dirs = {{1, 0}, {-1, 0}, {0, 1}, {0, -1}}

	while head <= #queue do
		local current = queue[head]
		head = head + 1

		local gx, gz = current.gx, current.gz
		local currentDist = distance[idx(gx, gz)]

		for _, dir in ipairs(dirs) do
			local nx = gx + dir[1]
			local nz = gz + dir[2]

			if nx >= 1 and nx <= width and nz >= 1 and nz <= height then
				local ni = idx(nx, nz)
				if grid[ni] and distance[ni] == INF then
					distance[ni] = currentDist + 1
					table.insert(queue, {gx = nx, gz = nz})
				end
			end
		end
	end
end

function PathMap.worldToGrid(x, z)
	return math.floor(x / CELL_SIZE) + 1, math.floor(z / CELL_SIZE) + 1
end

function PathMap.gridToWorld(gx, gz)
	return (gx - 0.5) * CELL_SIZE, (gz - 0.5) * CELL_SIZE
end

function PathMap.isWalkable(x, z)
	local gx, gz = PathMap.worldToGrid(x, z)
	if gx < 1 or gx > width or gz < 1 or gz > height then
		return false
	end
	return grid[idx(gx, gz)]
end

function PathMap.getDistance(x, z)
	local gx, gz = PathMap.worldToGrid(x, z)
	if gx < 1 or gx > width or gz < 1 or gz > height then
		return INF
	end
	return distance[idx(gx, gz)]
end

function PathMap.getDistanceGrid(gx, gz)
	if gx < 1 or gx > width or gz < 1 or gz > height then
		return INF
	end
	return distance[idx(gx, gz)]
end

function PathMap.getBestNextCenter(x, z)
	local gx, gz = PathMap.worldToGrid(x, z)
	local currentDist = PathMap.getDistanceGrid(gx, gz)

	if currentDist == 0 then
		return nil
	end

	local candidates = {}
	local bestDist = currentDist

	local dirs = {{1, 0}, {-1, 0}, {0, 1}, {0, -1}}
	for _, dir in ipairs(dirs) do
		local ngx, ngz = gx + dir[1], gz + dir[2]
		local d = PathMap.getDistanceGrid(ngx, ngz)
		if d < bestDist then
			bestDist = d
			candidates = {{gx = ngx, gz = ngz}}
		elseif d == bestDist and d < currentDist then
			table.insert(candidates, {gx = ngx, gz = ngz})
		end
	end

	if #candidates == 0 then
		return nil
	end

	local chosen = candidates[math.random(#candidates)]
	local wx, wz = PathMap.gridToWorld(chosen.gx, chosen.gz)
	return {x = wx, z = wz}
end

function PathMap.getCoreWorldPos()
	local x, z = PathMap.gridToWorld(coreGx, coreGz)
	return {x = x, z = z}
end

function PathMap.getPlayerSpawn()
	local x, z = PathMap.gridToWorld(coreGx, coreGz)
	return {x = x, z = z + CELL_SIZE}
end

function PathMap.getSpawnGates()
	local gates = {}
	for i, g in ipairs(spawnGates) do
		local x, z = PathMap.gridToWorld(g.gx, g.gz)
		table.insert(gates, {x = x, z = z, index = i})
	end
	return gates
end

function PathMap.getSize()
	return width, height
end

function PathMap.getCellSize()
	return CELL_SIZE
end

function PathMap.getWorldSize()
	return width * CELL_SIZE, height * CELL_SIZE
end

function PathMap.isRestrictedForGundam(x, z, margin)
	margin = margin or 8
	local worldW, worldH = PathMap.getWorldSize()

	if x < margin or x > worldW - margin or z < margin or z > worldH - margin then
		return true, "boundary"
	end

	if PathMap.isWalkable(x, z) then
		return true, "path"
	end

	local core = PathMap.getCoreWorldPos()
	local dx = x - core.x
	local dz = z - core.z
	if dx * dx + dz * dz < 20 * 20 then
		return true, "core"
	end

	for _, gate in ipairs(PathMap.getSpawnGates()) do
		local gx = x - gate.x
		local gz = z - gate.z
		if gx * gx + gz * gz < 15 * 15 then
			return true, "gate"
		end
	end

	return false
end

function PathMap.createVisuals()
	local folder = workspace:FindFirstChild("PathVisuals")
	if folder then folder:Destroy() end

	folder = Instance.new("Folder")
	folder.Name = "PathVisuals"
	folder.Parent = workspace

	for gz = 1, height do
		for gx = 1, width do
			if grid[idx(gx, gz)] then
				local wx, wz = PathMap.gridToWorld(gx, gz)
				local part = Instance.new("Part")
				part.Size = Vector3.new(CELL_SIZE - 0.1, 0.3, CELL_SIZE - 0.1)
				part.Position = Vector3.new(wx, Config.PLATFORM_Y + 0.15, wz)
				part.Anchored = true
				part.CanCollide = false
				part.Material = Enum.Material.SmoothPlastic
				part.Color = Color3.fromRGB(30, 30, 35)
				part.Parent = folder
			end
		end
	end
end

return PathMap
