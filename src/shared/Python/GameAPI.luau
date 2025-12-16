local Classes = require(script.Parent.Classes)

local GameAPI = {}

local function pyToString(value, depth)
	depth = depth or 0
	if depth > 3 then return "..." end
	if value == nil then return "None"
	elseif type(value) == "boolean" then return value and "True" or "False"
	elseif type(value) == "string" then return '"' .. value .. '"'
	elseif type(value) == "number" then return tostring(value)
	elseif type(value) == "function" then return "<function>"
	elseif type(value) == "table" then
		if value._isFunction then return "<function>" end
		if value.__type then
			if value.__type == "Enemy" and value.hp then
				return string.format("Enemy(%s, hp=%d)", value.type or "?", value.hp)
			elseif value.__type == "Scrap" and value.x then
				return string.format("Scrap(%d, %d)", math.floor(value.x), math.floor(value.z))
			elseif value.__type == "Core" then
				return "Core"
			else
				return string.format("@%s", value.__type)
			end
		end
		local isArray, maxIdx = true, 0
		for k in pairs(value) do
			if type(k) ~= "number" or k < 1 then isArray = false; break end
			maxIdx = math.max(maxIdx, k)
		end
		if isArray and maxIdx > 0 then
			local parts = {}
			for i = 1, math.min(maxIdx, 10) do table.insert(parts, pyToString(value[i], depth + 1)) end
			if maxIdx > 10 then table.insert(parts, "...") end
			return "[" .. table.concat(parts, ", ") .. "]"
		end
		return "{...}"
	end
	return tostring(value)
end

local function makeDeps(registries)
	local deps = {
		EnemyManager = registries.EnemyManager,
		ScrapManager = registries.ScrapManager,
		WaveManager = registries.WaveManager,
		PlayerCombat = registries.PlayerCombat,
		GundamStats = registries.GundamStats,
		GundamModel = registries.GundamModel,
	}

	function deps.getCoreOffset()
		local wm = deps.WaveManager
		if wm and wm.getCorePosition then
			local pos = wm.getCorePosition()
			if pos then return pos.x or 150, pos.z or 150 end
		end
		return 150, 150
	end

	function deps.getCharacterPos(character)
		local hrp = character and character:FindFirstChild("HumanoidRootPart")
		if hrp then return hrp.Position.X, hrp.Position.Z end
		return 0, 0
	end

	function deps.createEnemyProxy(enemy)
		return enemy and Classes.buildProxy("Enemy", enemy, deps)
	end

	return deps
end

local function addUtilities(env, interp)
	env.print = function(...)
		if not interp.output then interp.output = {} end
		local parts = {}
		for _, v in ipairs({...}) do parts[#parts + 1] = pyToString(v) end
		local id = interp.nextPrintId or 1
		interp.nextPrintId = id + 1
		interp.output[#interp.output + 1] = { id = id, message = table.concat(parts, " ") }
		while #interp.output > 50 do table.remove(interp.output, 1) end
	end
	env.len = function(t) return type(t) == "table" and #t or 0 end
	env.range = function(a, b, c)
		local s, e, st = 0, a, 1
		if b then s, e = a, b end
		if c then st = c end
		local result = {}
		for i = s, e - 1, st do result[#result + 1] = i end
		return result
	end
	env.abs, env.min, env.max = math.abs, math.min, math.max
	env.int = function(x) return math.floor(tonumber(x) or 0) end
	env.str = tostring
	env.True, env.False = true, false
	env.BULLET, env.ROCKET, env.LASER, env.ICE, env.GRENADE = 1, 2, 3, 4, 5
end

local function addEnemySelectors(env, getPos, deps)
	local function enemyPos(enemy)
		if not (deps.EnemyManager and enemy and enemy.id) then return nil, nil end
		local e = deps.EnemyManager.get(enemy.id)
		if not (e and e.character) then return nil, nil end
		local hrp = e.character:FindFirstChild("HumanoidRootPart")
		return hrp and hrp.Position.X, hrp and hrp.Position.Z
	end

	local function selectBy(list, scanFn, compareFn)
		list = list or scanFn()
		if #list == 0 then return nil end
		local best, bestVal = nil, nil
		local refX, refZ = getPos()
		for _, e in ipairs(list) do
			local ex, ez = enemyPos(e)
			local val = ex and compareFn(e, ex, ez, refX, refZ)
			if val and (not bestVal or val < bestVal) then
				best, bestVal = e, val
			end
		end
		return best
	end

	env.nearest = function(list, scanFn)
		return selectBy(list, scanFn or env.self.scan, function(_, ex, ez, rx, rz)
			return (ex - rx)^2 + (ez - rz)^2
		end)
	end

	env.furthest = function(list, scanFn)
		return selectBy(list, scanFn or env.self.scan, function(_, ex, ez, rx, rz)
			return -((ex - rx)^2 + (ez - rz)^2)
		end)
	end

	env.weakest = function(list, scanFn)
		return selectBy(list, scanFn or env.self.scan, function(e) return e.hp end)
	end

	env.strongest = function(list, scanFn)
		return selectBy(list, scanFn or env.self.scan, function(e) return -e.hp end)
	end
end

local function addCore(env, deps)
	env.CORE = setmetatable({}, {
		__index = function(_, key)
			if key == "pos" then return {0, 0} end
			if key == "hp" then
				local wm = deps.WaveManager
				return wm and wm.getCoreHealth and wm.getCoreHealth() or 100
			end
		end
	})
end

local function createEnv(className, instance, registries, getPosOverride)
	local deps = makeDeps(registries)
	local env = {}

	env.self = Classes.buildProxy(className, instance, deps)

	local getPos = getPosOverride or function()
		return deps.getCharacterPos(instance.character)
	end

	addEnemySelectors(env, getPos, deps)
	addUtilities(env, instance.interpreter or {})
	addCore(env, deps)

	local Interpreters = registries.Interpreters
	if Interpreters then
		setmetatable(env, {
			__index = function(_, key)
				if type(key) ~= "string" then return nil end
				local gPid = key:match("^G(%d+)$")
				local bPid = key:match("^B(%d+)$")
				local pid = gPid or bPid
				if pid then
					local data = Interpreters.get(pid)
					if data and data.entity then
						if gPid and data.type == "gundam" then
							return Classes.buildProxy("Gundam", data.entity, deps)
						elseif bPid and data.type == "bot" then
							return Classes.buildProxy("Bot", data.entity, deps)
						end
					end
				end
				return nil
			end
		})
	end

	return env
end

function GameAPI.createGundamEnvironment(gundam, registries)
	local deps = makeDeps(registries)
	return createEnv("Gundam", gundam, registries, function()
		return deps.getCharacterPos(gundam.character)
	end)
end

function GameAPI.createBotEnvironment(bot, registries)
	return createEnv("Bot", bot, registries)
end

function GameAPI.createPlayerEnvironment(player, interp, registries)
	return createEnv("Player", {
		id = "player",
		playerId = player.UserId,
		character = interp.character,
		interpreter = interp,
	}, registries)
end

GameAPI.pyToString = pyToString

return GameAPI
