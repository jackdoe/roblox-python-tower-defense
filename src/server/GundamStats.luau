local ReplicatedStorage = game:GetService("ReplicatedStorage")
local PythonTD = ReplicatedStorage:WaitForChild("PythonTD")
local Config = require(PythonTD.Config)

local GundamStats = {}

GundamStats.GROUND_Y = Config.PLATFORM_Y

GundamStats.BASE = {
	name = "Gundam",
	modelName = "Gundam",
	maxAmmo = 300,
	range = 40,
	cost = 100,
}

GundamStats.GUNDAM_BASE_COST = 100
GundamStats.GUNDAM_COST_MULTIPLIER = 1.5

GundamStats.AmmoStats = {
	[1] = {
		name = "BULLET",
		damage = 15,
		ammoCost = 1,
		fireRate = 0.2,
		color = Color3.fromRGB(255, 255, 200),
	},
	[2] = {
		name = "ROCKET",
		damage = 80,
		ammoCost = 4,
		fireRate = 1.0,
		splashRadius = 12,
		color = Color3.fromRGB(255, 100, 50),
	},
	[3] = {
		name = "LASER",
		damage = 40,
		ammoCost = 2,
		fireRate = 0.1,
		color = Color3.fromRGB(255, 50, 50),
	},
	[4] = {
		name = "ICE",
		damage = 20,
		ammoCost = 2,
		fireRate = 0.4,
		slowAmount = 0.6,
		slowDuration = 4.0,
		color = Color3.fromRGB(100, 200, 255),
	},
	[5] = {
		name = "GRENADE",
		damage = 60,
		ammoCost = 5,
		fireRate = 1.5,
		splashRadius = 12,
		color = Color3.fromRGB(100, 255, 100),
	},
}

GundamStats.AMMO_NAMES = {
	[1] = "BULLET",
	[2] = "ROCKET",
	[3] = "LASER",
	[4] = "ICE",
	[5] = "GRENADE",
}

GundamStats.DEFAULT_PROGRAM = [[
while True:
    enemies = self.scan()
    if len(enemies) > 0:
        self.set_target(nearest(enemies))
        self.fire(BULLET)
]]

GundamStats.MAX_GUNDAMS = 10

return GundamStats
