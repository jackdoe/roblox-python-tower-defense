local TweenService = game:GetService("TweenService")
local ProjectileEffects = require(script.Parent.ProjectileEffects)

local PlayerCombat = {}

local EnemyManager = nil
local WaveManager = nil

local AmmoStats = {
	[1] = {
		damage = 15,
		fireRate = 0.3,
		scrapCost = 2,
		color = Color3.fromRGB(255, 255, 150),
		name = "Bullet",
	},
	[2] = {
		damage = 40,
		fireRate = 1.0,
		scrapCost = 8,
		splashRadius = 8,
		color = Color3.fromRGB(255, 100, 50),
		name = "Rocket",
	},
	[3] = {
		damage = 25,
		fireRate = 0.5,
		scrapCost = 4,
		color = Color3.fromRGB(255, 50, 50),
		name = "Laser",
	},
	[4] = {
		damage = 10,
		fireRate = 0.4,
		scrapCost = 4,
		slowAmount = 0.6,
		slowDuration = 3,
		color = Color3.fromRGB(100, 200, 255),
		name = "Ice",
	},
	[5] = {
		damage = 60,
		fireRate = 1.5,
		scrapCost = 10,
		splashRadius = 12,
		isGrenade = true,
		color = Color3.fromRGB(100, 255, 100),
		name = "Grenade",
	},
}

function PlayerCombat.init(deps)
	EnemyManager = deps.EnemyManager
	WaveManager = deps.WaveManager
end

function PlayerCombat.getScrapCost(ammoType)
	local stats = AmmoStats[ammoType] or AmmoStats[1]
	return stats.scrapCost or 2
end

function PlayerCombat.fire(interp, enemy, ammoType)
	if not interp or not enemy then return false end

	local character = interp.character
	if not character then return false end

	local hrp = character:FindFirstChild("HumanoidRootPart")
	if not hrp then return false end

	local enemyChar = enemy.character
	local enemyHrp = enemyChar and enemyChar:FindFirstChild("HumanoidRootPart")
	if not enemyHrp then return false end

	ammoType = ammoType or 1
	local stats = AmmoStats[ammoType] or AmmoStats[1]

	local cpuHz = interp.cpuHz or 1
	local adjustedFireRate = stats.fireRate / cpuHz

	local scrapCost = stats.scrapCost or 2
	if WaveManager then
		local playerId = interp.playerId or 0
		local currentScrap = WaveManager.getScrap(playerId)
		if currentScrap < scrapCost then
			return false
		end
		WaveManager.removeScrap(playerId, scrapCost)
	end

	-- Check distance (max range 50)
	local dist = (enemyHrp.Position - hrp.Position).Magnitude
	if dist > 50 then return false end

	-- Deal damage (apply power multiplier from interpreter)
	local power = interp.power or 1
	local damage = stats.damage * power

	if stats.splashRadius and stats.splashRadius > 0 then
		local allEnemies = EnemyManager.getAll and EnemyManager.getAll() or {}
		for _, e in pairs(allEnemies) do
			if e.hp > 0 and e.character then
				local eHrp = e.character:FindFirstChild("HumanoidRootPart")
				if eHrp then
					local eDist = (eHrp.Position - enemyHrp.Position).Magnitude
					if eDist <= stats.splashRadius then
						local falloff = 1 - (eDist / stats.splashRadius) * 0.5
						local dmg = math.floor(damage * falloff)
						if ammoType == 2 and EnemyManager.checkShatterCombo then
							dmg = EnemyManager.checkShatterCombo(e.id, dmg)
						end
						EnemyManager.damage(e.id, dmg)
						if ammoType == 2 and EnemyManager.applyOiled then
							EnemyManager.applyOiled(e.id, 5)
						end
					end
				end
			end
		end
	else
		-- Single target
		EnemyManager.damage(enemy.id, damage)
	end

	-- Apply slow for ice/freeze
	if stats.slowAmount and stats.slowDuration then
		EnemyManager.applySlow(enemy.id, stats.slowAmount, stats.slowDuration)
	end

	-- Apply burning for laser
	if ammoType == 3 and EnemyManager.applyBurning then
		EnemyManager.applyBurning(enemy.id, 3, 5)
	end

	ProjectileEffects.shot(hrp.Position, enemyHrp.Position, stats)

	local vm = interp.runtime and interp.runtime.vm
	if vm and vm.block then
		vm:block()
		task.delay(adjustedFireRate, function()
			if vm and vm.unblock then vm:unblock() end
		end)
	end

	return true
end

return PlayerCombat
