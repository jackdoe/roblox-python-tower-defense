-- EntityRegistry.luau
-- Manages all game entities (players and monsters)

local EntityRegistry = {}

-- Active entities
local entities = {}

function EntityRegistry.register(entity)
	if entity and entity.id then
		entities[entity.id] = entity
	end
end

function EntityRegistry.unregister(id)
	entities[id] = nil
end

function EntityRegistry.get(id)
	return entities[id]
end

function EntityRegistry.getAll()
	return entities
end

function EntityRegistry.getPosition(entity)
	if entity.character and entity.character:FindFirstChild("HumanoidRootPart") then
		local pos = entity.character.HumanoidRootPart.Position
		return pos.X, pos.Z
	end
	-- Return nil to indicate missing position
	return nil, nil
end

function EntityRegistry.getDistance(x1, y1, x2, y2)
	return math.sqrt((x2 - x1)^2 + (y2 - y1)^2)
end

function EntityRegistry.findNearest(fromX, fromY, excludeId, filterFn)
	local nearest = nil
	local nearestDist = math.huge
	for id, entity in pairs(entities) do
		if id ~= excludeId and (not filterFn or filterFn(entity)) then
			local ex, ey = EntityRegistry.getPosition(entity)
			local dist = EntityRegistry.getDistance(fromX, fromY, ex, ey)
			if dist < nearestDist then
				nearestDist = dist
				nearest = entity
			end
		end
	end
	return nearest, nearestDist
end

return EntityRegistry
