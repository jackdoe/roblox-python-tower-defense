local Classes = {}

local T = {
	ANY = "any",
	NIL = "nil",
	BOOL = "bool",
	NUMBER = "number",
	STRING = "string",
	LIST = "List",
	ENEMY = "Enemy",
	GUNDAM = "Gundam",
	BOT = "Bot",
	PLAYER = "Player",
	AMMO_TYPE = "AmmoType",
	VECTOR = "Vector",
	FUNCTION = "Function",
}

Classes.T = T

local function method(args, returns, impl)
	return { kind = "method", args = args, returns = returns, impl = impl }
end

local function prop(typ, getter)
	return { kind = "prop", type = typ, get = getter }
end

local function queueTask(entity, taskType, args, blocking)
	if not entity.taskQueue then
		entity.taskQueue = {}
	end
	table.insert(entity.taskQueue, {
		type = taskType,
		args = args or {},
		startTime = tick(),
	})
	if blocking then
		entity.waitingForTask = true
		local vm = entity.interpreter and entity.interpreter.runtime and entity.interpreter.runtime.vm
		if vm and vm.block then vm:block() end
	end
	return true
end

Classes.Enemy = {
	name = "Enemy",
	members = {
		id = prop(T.STRING, function(deps, e) return e.id end),
		is_boss = prop(T.BOOL, function(deps, e) return e.typeName == "Boss" end),
		hp = prop(T.NUMBER, function(deps, e) return e.hp or 0 end),
		max_hp = prop(T.NUMBER, function(deps, e) return e.maxHp or 1 end),
		burning = prop(T.BOOL, function(deps, e) return e.burning or false end),
		frozen = prop(T.BOOL, function(deps, e) return (e.slowAmount and e.slowAmount >= 0.5) or false end),
		slowed = prop(T.BOOL, function(deps, e) return (e.slowAmount and e.slowAmount > 0) or false end),
		oiled = prop(T.BOOL, function(deps, e) return e.oiled or false end),

		pos = prop(T.VECTOR, function(deps, enemy)
			local EnemyManager = deps.EnemyManager
			local e = EnemyManager and EnemyManager.get and EnemyManager.get(enemy.id)
			if e and e.character then
				local hrp = e.character:FindFirstChild("HumanoidRootPart") or e.character.PrimaryPart
				if hrp then
					local coreX, coreZ = deps.getCoreOffset()
					return { math.floor(hrp.Position.X - coreX), math.floor(hrp.Position.Z - coreZ) }
				end
			end
			return { 0, 0 }
		end),
	},
}

Classes.Gundam = {
	name = "Gundam",
	members = {
		pos = prop(T.VECTOR, function(deps, gundam)
			if gundam.character then
				local x, z = deps.getCharacterPos(gundam.character)
				local coreX, coreZ = deps.getCoreOffset()
				return { math.floor(x - coreX), math.floor(z - coreZ) }
			end
			return { 0, 0 }
		end),

		ammo = prop(T.NUMBER, function(deps, gundam)
			return gundam.interpreter and gundam.interpreter.ammo or 0
		end),

		max_ammo = prop(T.NUMBER, function(deps, gundam)
			return gundam.interpreter and gundam.interpreter.maxAmmo or 300
		end),

		hacker = prop(T.PLAYER, function(deps, gundam)
			local Interpreters = deps.Interpreters
			if not Interpreters or not gundam.ownerId then return nil end
			for _, data in pairs(Interpreters.getByType("player")) do
				if data.ownerId == gundam.ownerId then
					return Classes.buildProxy("Player", {
						id = "player",
						playerId = data.ownerId,
						character = data.interpreter.character,
						interpreter = data.interpreter,
					}, deps)
				end
			end
			return nil
		end),

		reload = method({ T.NUMBER }, T.NUMBER, function(deps, gundam, amount)
			local interp = gundam.interpreter
			if not interp then return 0 end

			local needed = (interp.maxAmmo or 300) - (interp.ammo or 0)
			if needed <= 0 then return 0 end

			amount = amount or needed
			local toReload = math.min(amount, needed)

			interp.reloadPending = {
				amount = toReload,
				startTime = tick(),
				duration = 1 + (toReload / 50),
				collected = 0,
			}

			local vm = interp.runtime and interp.runtime.vm
			if vm and vm.block then vm:block() end

			return toReload
		end),

		set_range = method({ T.NUMBER }, T.NIL, function(deps, gundam, range)
			if gundam.interpreter then
				gundam.interpreter.dynamicRange = math.clamp(range or 40, 10, 60)
			end
		end),

		set_target = method({ T.ENEMY }, T.NIL, function(deps, gundam, enemy)
			if gundam.interpreter and enemy and enemy.id then
				gundam.interpreter.target = enemy.id
			end
		end),

		target = method({}, { "optional", T.ENEMY }, function(deps, gundam)
			if not gundam.interpreter then return nil end
			local targetId = gundam.interpreter.target
			if not targetId then return nil end

			local EnemyManager = deps.EnemyManager
			if EnemyManager and EnemyManager.get then
				local enemy = EnemyManager.get(targetId)
				if enemy and enemy.hp and enemy.hp > 0 then
					return deps.createEnemyProxy(enemy)
				end
			end
			return nil
		end),

		fire = method({ T.AMMO_TYPE }, T.BOOL, function(deps, gundam, ammoType)
			ammoType = ammoType or 1
			local interp = gundam.interpreter
			if not interp then return false end

			local GundamStats = deps.GundamStats
			local GundamModel = deps.GundamModel
			if not GundamStats or not GundamModel then return false end

			local AmmoStats = GundamStats.AmmoStats
			local ammoStats = AmmoStats[ammoType] or AmmoStats[1]

			if interp.ammo < ammoStats.ammoCost then return false end

			local cpuHz = interp.cpuHz or 1
			local adjustedFireRate = ammoStats.fireRate / cpuHz

			if not interp.target then return false end

			local EnemyManager = deps.EnemyManager
			if not EnemyManager then return false end

			local enemy = EnemyManager.get(interp.target)
			if not enemy or enemy.hp <= 0 then
				interp.target = nil
				return false
			end

			local character = gundam.character
			local myHrp = character and (character:FindFirstChild("HumanoidRootPart") or character.PrimaryPart)
			local enemyHrp = enemy.character and enemy.character:FindFirstChild("HumanoidRootPart")
			if not myHrp or not enemyHrp then return false end

			local dist = (enemyHrp.Position - myHrp.Position).Magnitude
			local currentRange = interp.dynamicRange or 40
			if dist > currentRange then
				interp.target = nil
				return false
			end

			interp.ammo = interp.ammo - ammoStats.ammoCost

			local baseRange = 40
			local damageMult = baseRange / currentRange
			local tierDamageMult = interp.tierDamageMultiplier or 1
			local unitPower = interp.power or 1
			local finalDamage = math.floor(ammoStats.damage * damageMult * tierDamageMult * unitPower)

			if ammoStats.splashRadius and ammoStats.splashRadius > 0 then
				local enemies = EnemyManager.getAll and EnemyManager.getAll() or {}
				for _, e in pairs(enemies) do
					if e.hp > 0 and e.character then
						local eHrp = e.character:FindFirstChild("HumanoidRootPart")
						if eHrp then
							local eDist = (eHrp.Position - enemyHrp.Position).Magnitude
							if eDist <= ammoStats.splashRadius then
								local falloff = 1 - (eDist / ammoStats.splashRadius) * 0.5
								local dmg = math.floor(finalDamage * falloff)
								if ammoType == 2 and EnemyManager.checkShatterCombo then
									dmg = EnemyManager.checkShatterCombo(e.id, dmg)
								end
								EnemyManager.damage(e.id, dmg, gundam.id)
							end
						end
					end
				end
			else
				if finalDamage > 0 then
					EnemyManager.damage(interp.target, finalDamage, gundam.id)
				end
			end

			if ammoStats.slowAmount and ammoStats.slowDuration then
				EnemyManager.applySlow(interp.target, ammoStats.slowAmount, ammoStats.slowDuration)
			end

			if ammoType == 3 and EnemyManager.applyBurning then
				EnemyManager.applyBurning(interp.target, 3, 5)
			end

			GundamModel.createMuzzleFlash(gundam, enemyHrp.Position, ammoStats)

			local vm = interp.runtime and interp.runtime.vm
			if vm and vm.block then
				vm:block()
				task.delay(adjustedFireRate, function()
					if vm and vm.unblock then vm:unblock() end
				end)
			end

			return true
		end),

		scan = method({}, { T.LIST, T.ENEMY }, function(deps, gundam)
			if not gundam.character then return {} end
			local x, z = deps.getCharacterPos(gundam.character)
			local range = gundam.interpreter and gundam.interpreter.dynamicRange or 40

			local EnemyManager = deps.EnemyManager
			if EnemyManager and EnemyManager.findInRange then
				local enemies = EnemyManager.findInRange(x, z, range)
				local results = {}
				for _, e in ipairs(enemies) do
					table.insert(results, deps.createEnemyProxy(e))
				end
				return results
			end
			return {}
		end),
	},
}

Classes.Bot = {
	name = "Bot",
	members = {
		pos = prop(T.VECTOR, function(deps, bot)
			if bot.character then
				local x, z = deps.getCharacterPos(bot.character)
				local coreX, coreZ = deps.getCoreOffset()
				return { math.floor(x - coreX), math.floor(z - coreZ) }
			end
			return { 0, 0 }
		end),

		hacker = prop(T.PLAYER, function(deps, bot)
			local Interpreters = deps.Interpreters
			if not Interpreters or not bot.ownerId then return nil end
			for _, data in pairs(Interpreters.getByType("player")) do
				if data.ownerId == bot.ownerId then
					return Classes.buildProxy("Player", {
						id = "player",
						playerId = data.ownerId,
						character = data.interpreter.character,
						interpreter = data.interpreter,
					}, deps)
				end
			end
			return nil
		end),

		carrying = prop(T.NUMBER, function(deps, bot)
			return bot.scrapInventory or 0
		end),

		max_capacity = prop(T.NUMBER, function(deps, bot)
			return bot.maxCapacity or 10
		end),

		forward = method({ T.NUMBER }, T.BOOL, function(deps, bot, steps)
			steps = steps or 10
			if not bot.character then return false end
			local hrp = bot.character:FindFirstChild("HumanoidRootPart")
			if not hrp then return false end

			local facingAngle = bot.facingAngle or 0
			local dirX = -math.sin(facingAngle)
			local dirZ = -math.cos(facingAngle)
			local targetX = hrp.Position.X + dirX * steps
			local targetZ = hrp.Position.Z + dirZ * steps
			local coreX, coreZ = deps.getCoreOffset()

			return Classes.Bot.members.teleport.impl(deps, bot, { targetX - coreX, targetZ - coreZ })
		end),

		backward = method({ T.NUMBER }, T.BOOL, function(deps, bot, steps)
			return Classes.Bot.members.forward.impl(deps, bot, -(steps or 10))
		end),

		left = method({ T.NUMBER }, T.BOOL, function(deps, bot, angle)
			angle = angle or 90
			bot.facingAngle = (bot.facingAngle or 0) + math.rad(angle)
			return true
		end),

		right = method({ T.NUMBER }, T.BOOL, function(deps, bot, angle)
			return Classes.Bot.members.left.impl(deps, bot, -(angle or 90))
		end),

		teleport = method({ T.VECTOR }, T.BOOL, function(deps, bot, pos)
			if type(pos) ~= "table" or #pos ~= 2 then return false end
			local coreX, coreZ = deps.getCoreOffset()
			return queueTask(bot, "TELEPORT", { x = pos[1] + coreX, z = pos[2] + coreZ }, true)
		end),

		shock = method({ T.ENEMY }, T.BOOL, function(deps, bot, target)
			local enemyId = type(target) == "table" and target.id or target
			if not enemyId then return false end
			return queueTask(bot, "SHOCK", { enemyId = enemyId }, true)
		end),

		scan = method({}, { T.LIST, T.ENEMY }, function(deps, bot)
			if not bot.character then return {} end
			local x, z = deps.getCharacterPos(bot.character)

			local EnemyManager = deps.EnemyManager
			if EnemyManager and EnemyManager.findInRange then
				local enemies = EnemyManager.findInRange(x, z, 50)
				local results = {}
				for _, e in ipairs(enemies) do
					table.insert(results, deps.createEnemyProxy(e))
				end
				return results
			end
			return {}
		end),

		collect = method({}, T.BOOL, function(deps, bot)
			local capacity = bot.maxCapacity or 10
			if (bot.scrapInventory or 0) >= capacity then return true end

			local ScrapManager = deps.ScrapManager
			if not ScrapManager then return false end

			local hrp = bot.character and bot.character:FindFirstChild("HumanoidRootPart")
			if not hrp then return false end

			local x, z, count = ScrapManager.findBestCluster(hrp.Position.X, hrp.Position.Z, 200, 20)
			if not x or count == 0 then return false end

			return queueTask(bot, "COLLECT", {}, true)
		end),

		explode = method({}, T.BOOL, function(deps, bot)
			local cargo = bot.scrapInventory or 0
			if cargo < 10 then
				error("explode() requires at least 10 scrap (carrying " .. cargo .. ")")
			end
			return queueTask(bot, "EXPLODE", {}, true)
		end),

		say = method({ T.STRING }, T.NIL, function(deps, bot, message)
			local character = bot.character
			if not character then return end

			local head = character:FindFirstChild("Head") or character.PrimaryPart
			if not head then return end

			local bb = head:FindFirstChild("BotChat")
			if not bb then
				bb = Instance.new("BillboardGui")
				bb.Name = "BotChat"
				bb.Size = UDim2.new(0, 150, 0, 50)
				bb.StudsOffset = Vector3.new(0, 4, 0)
				bb.AlwaysOnTop = true
				bb.Parent = head

				local txt = Instance.new("TextLabel")
				txt.Name = "ChatText"
				txt.Size = UDim2.new(1, 0, 1, 0)
				txt.BackgroundTransparency = 1
				txt.TextColor3 = Color3.new(1, 1, 1)
				txt.TextStrokeTransparency = 0
				txt.TextStrokeColor3 = Color3.new(0, 0, 0)
				txt.Font = Enum.Font.Cartoon
				txt.TextSize = 18
				txt.TextScaled = false
				txt.Parent = bb
			end

			local txt = bb:FindFirstChild("ChatText")
			if txt then
				txt.Text = tostring(message)
				task.delay(3, function()
					if txt and txt.Parent and txt.Text == tostring(message) then
						txt.Text = ""
					end
				end)
			end
		end),

		deposit = method({}, T.BOOL, function(deps, bot)
			if (bot.scrapInventory or 0) <= 0 then return false end
			if not bot.character then return false end
			if not bot.ownerId then return false end

			local hrp = bot.character:FindFirstChild("HumanoidRootPart")
			if not hrp then return false end

			local coreX, coreZ = deps.getCoreOffset()
			local dist = math.sqrt((hrp.Position.X - coreX)^2 + (hrp.Position.Z - coreZ)^2)
			if dist > 15 then return false end

			local WaveManager = deps.WaveManager
			if not WaveManager then return false end

			local ReplicatedStorage = game:GetService("ReplicatedStorage")
			local PythonTD = ReplicatedStorage:WaitForChild("PythonTD")
			local Config = require(PythonTD.Config)
			local pieceValue = Config.SCRAP_PIECE_VALUE or 10
			local amount = bot.scrapInventory

			WaveManager.addScrap(bot.ownerId, amount * pieceValue)
			bot.scrapInventory = 0

			local depositEvent = PythonTD:FindFirstChild("DepositEffect")
			if depositEvent then
				depositEvent:FireAllClients(
					hrp.Position,
					Vector3.new(coreX, Config.PLATFORM_Y + 3, coreZ),
					amount
				)
			end
			return true
		end),
	},
}

Classes.Player = {
	name = "Player",
	members = {
		pos = prop(T.VECTOR, function(deps, player)
			if player.character then
				local x, z = deps.getCharacterPos(player.character)
				local coreX, coreZ = deps.getCoreOffset()
				return { math.floor(x - coreX), math.floor(z - coreZ) }
			end
			return { 0, 0 }
		end),

		carrying = prop(T.NUMBER, function(deps, player)
			return player.interpreter and player.interpreter.scrapInventory or 0
		end),

		max_capacity = prop(T.NUMBER, function(deps, player)
			return player.interpreter and player.interpreter.maxCapacity or 10
		end),

		hacker = prop(T.PLAYER, function(deps, player)
			return Classes.buildProxy("Player", player, deps)
		end),

		forward = method({ T.NUMBER }, T.BOOL, function(deps, player, steps)
			steps = steps or 10
			if not player.character then return false end
			local hrp = player.character:FindFirstChild("HumanoidRootPart")
			if not hrp then return false end

			local lookVector = hrp.CFrame.LookVector
			local targetPos = hrp.Position + lookVector * steps
			local coreX, coreZ = deps.getCoreOffset()
			return Classes.Player.members.teleport.impl(deps, player, { targetPos.X - coreX, targetPos.Z - coreZ })
		end),

		backward = method({ T.NUMBER }, T.BOOL, function(deps, player, steps)
			return Classes.Player.members.forward.impl(deps, player, -(steps or 10))
		end),

		left = method({ T.NUMBER }, T.BOOL, function(deps, player, angle)
			return true
		end),

		right = method({ T.NUMBER }, T.BOOL, function(deps, player, angle)
			return true
		end),

		teleport = method({ T.VECTOR }, T.BOOL, function(deps, player, pos)
			if type(pos) ~= "table" or #pos ~= 2 then return false end
			if not player.character then return false end
			local hrp = player.character:FindFirstChild("HumanoidRootPart")
			if not hrp then return false end

			local coreX, coreZ = deps.getCoreOffset()
			local Config = require(game:GetService("ReplicatedStorage"):WaitForChild("PythonTD").Config)
			hrp.CFrame = CFrame.new(pos[1] + coreX, Config.PLATFORM_Y + 3, pos[2] + coreZ)
			return true
		end),

		scan = method({}, { T.LIST, T.ENEMY }, function(deps, player)
			if not player.character then return {} end
			local x, z = deps.getCharacterPos(player.character)

			local EnemyManager = deps.EnemyManager
			if EnemyManager and EnemyManager.findInRange then
				local enemies = EnemyManager.findInRange(x, z, 50)
				local results = {}
				for _, e in ipairs(enemies) do
					table.insert(results, deps.createEnemyProxy(e))
				end
				return results
			end
			return {}
		end),

		say = method({ T.STRING }, T.NIL, function(deps, player, message)
		end),

		deposit = method({}, T.BOOL, function(deps, player)
			local interp = player.interpreter
			if not interp then return false end
			if (interp.scrapInventory or 0) <= 0 then return false end
			if not player.character then return false end

			local hrp = player.character:FindFirstChild("HumanoidRootPart")
			if not hrp then return false end

			local coreX, coreZ = deps.getCoreOffset()
			local dist = math.sqrt((hrp.Position.X - coreX)^2 + (hrp.Position.Z - coreZ)^2)
			if dist > 15 then return false end

			local WaveManager = deps.WaveManager
			if not WaveManager then return false end

			local ReplicatedStorage = game:GetService("ReplicatedStorage")
			local PythonTD = ReplicatedStorage:WaitForChild("PythonTD")
			local Config = require(PythonTD.Config)
			local pieceValue = Config.SCRAP_PIECE_VALUE or 10
			local amount = interp.scrapInventory

			local playerId = interp.playerId or 0
			WaveManager.addScrap(playerId, amount * pieceValue)
			interp.scrapInventory = 0

			local depositEvent = PythonTD:FindFirstChild("DepositEffect")
			if depositEvent then
				depositEvent:FireAllClients(
					hrp.Position,
					Vector3.new(coreX, Config.PLATFORM_Y + 3, coreZ),
					amount
				)
			end
			return true
		end),

		collect = method({}, T.BOOL, function(deps, player)
			if not player.character then return false end
			local hrp = player.character:FindFirstChild("HumanoidRootPart")
			if not hrp then return false end

			local interp = player.interpreter
			if not interp then return false end

			local capacity = interp.maxCapacity or 10
			if (interp.scrapInventory or 0) >= capacity then return true end

			local ScrapManager = deps.ScrapManager
			if not ScrapManager then return false end

			local pickupRange = 8
			local collected = 0

			while (interp.scrapInventory or 0) < capacity do
				local nearest = ScrapManager.findNearest(hrp.Position.X, hrp.Position.Z, pickupRange)
				if not nearest then break end
				if ScrapManager.collect(nearest.id) then
					interp.scrapInventory = (interp.scrapInventory or 0) + 1
					collected = collected + 1
				else
					break
				end
			end

			return collected > 0
		end),

		explode = method({}, T.BOOL, function(deps, player)
			if not player.character then return false end
			local PlayerCombat = deps.PlayerCombat
			if PlayerCombat and PlayerCombat.explode then
				return PlayerCombat.explode(player.playerId)
			end
			return false
		end),

		fire = method({ T.AMMO_TYPE }, T.BOOL, function(deps, player, ammoType)
			local PlayerCombat = deps.PlayerCombat
			if not PlayerCombat or not PlayerCombat.fire then return false end
			if not player.interpreter then return false end

			local targetId = player.interpreter.target
			if not targetId then return false end

			local EnemyManager = deps.EnemyManager
			local enemy = EnemyManager and EnemyManager.get and EnemyManager.get(targetId)
			if not enemy then return false end

			return PlayerCombat.fire(player.interpreter, enemy, ammoType or 1)
		end),

		set_target = method({ T.ENEMY }, T.NIL, function(deps, player, enemy)
			if player.interpreter and enemy and enemy.id then
				player.interpreter.target = enemy.id
			end
		end),

		target = method({}, { "optional", T.ENEMY }, function(deps, player)
			if not player.interpreter then return nil end
			local targetId = player.interpreter.target
			if not targetId then return nil end
			local EnemyManager = deps.EnemyManager
			if EnemyManager and EnemyManager.get then
				local enemy = EnemyManager.get(targetId)
				if enemy and enemy.hp and enemy.hp > 0 then
					return deps.createEnemyProxy(enemy)
				end
			end
			return nil
		end),

		drop = method({ T.NUMBER }, T.BOOL, function(deps, player, pieces)
			pieces = math.floor(pieces or 1)
			if pieces < 1 then return false end

			local interp = player.interpreter
			if not interp then return false end

			local hrp = player.character and player.character:FindFirstChild("HumanoidRootPart")
			if not hrp then return false end

			local ScrapManager = deps.ScrapManager
			local WaveManager = deps.WaveManager
			if not ScrapManager or not WaveManager then return false end

			local ReplicatedStorage = game:GetService("ReplicatedStorage")
			local PythonTD = ReplicatedStorage:WaitForChild("PythonTD")
			local Config = require(PythonTD.Config)
			local pieceValue = Config.SCRAP_PIECE_VALUE or 10

			local playerId = interp.playerId or 0
			local cost = pieces * pieceValue
			local currentScrap = WaveManager.getScrap(playerId)
			if currentScrap < cost then return false end

			WaveManager.removeScrap(playerId, cost)
			ScrapManager.spawn(hrp.Position, pieces)
			return true
		end),
	},
}

Classes.Builtins = {
	["True"] = T.BOOL,
	["False"] = T.BOOL,
	["None"] = T.NIL,

	["print"] = { type = "Function", args = { T.ANY }, returns = T.NIL },
	["len"] = { type = "Function", args = { T.LIST }, returns = T.NUMBER },
	["range"] = { type = "Function", args = { T.NUMBER }, returns = { T.LIST, T.NUMBER } },
	["abs"] = { type = "Function", args = { T.NUMBER }, returns = T.NUMBER },
	["min"] = { type = "Function", args = { T.NUMBER, T.NUMBER }, returns = T.NUMBER },
	["max"] = { type = "Function", args = { T.NUMBER, T.NUMBER }, returns = T.NUMBER },

	["nearest"] = { type = "Function", args = { { T.LIST, T.ENEMY } }, returns = T.ENEMY },
	["furthest"] = { type = "Function", args = { { T.LIST, T.ENEMY } }, returns = T.ENEMY },
	["strongest"] = { type = "Function", args = { { T.LIST, T.ENEMY } }, returns = T.ENEMY },
	["weakest"] = { type = "Function", args = { { T.LIST, T.ENEMY } }, returns = T.ENEMY },

	["BULLET"] = T.AMMO_TYPE,
	["ROCKET"] = T.AMMO_TYPE,
	["LASER"] = T.AMMO_TYPE,
	["ICE"] = T.AMMO_TYPE,
	["GRENADE"] = T.AMMO_TYPE,

	["CORE"] = T.ANY,
}

Classes.EnvPatterns = {
	["^G%d+$"] = "Gundam",
	["^B%d+$"] = "Bot",
}

function Classes.getMethodInfo(className, methodName)
	local classDef = Classes[className]
	if not classDef or not classDef.members then return nil end
	local member = classDef.members[methodName]
	if member and member.kind == "method" then return member end
	return nil
end

function Classes.getPropertyType(className, propName)
	local classDef = Classes[className]
	if not classDef or not classDef.members then return nil end
	local member = classDef.members[propName]
	if member and member.kind == "prop" then return member.type end
	return nil
end

function Classes.getAllMembers(className)
	local classDef = Classes[className]
	if not classDef or not classDef.members then return {} end

	local members = {}
	for name, member in pairs(classDef.members) do
		if member.kind == "method" then
			table.insert(members, { name = name, kind = "method", info = member })
		else
			table.insert(members, { name = name, kind = "property", type = member.type })
		end
	end
	return members
end

function Classes.getBuiltinType(name)
	if Classes.Builtins[name] then
		return Classes.Builtins[name]
	end
	for pattern, className in pairs(Classes.EnvPatterns) do
		if name:match(pattern) then
			return className
		end
	end
	return nil
end

function Classes.buildProxy(className, instance, deps)
	local classDef = Classes[className]
	if not classDef or not classDef.members then return {} end

	local data = { __type = className }

	for memberName, member in pairs(classDef.members) do
		if member.kind == "method" then
			data[memberName] = function(...)
				return member.impl(deps, instance, ...)
			end
		end
	end

	return setmetatable(data, {
		__index = function(_, key)
			local member = classDef.members[key]
			if member and member.kind == "prop" then
				return member.get(deps, instance)
			end
			return nil
		end
	})
end

return Classes
