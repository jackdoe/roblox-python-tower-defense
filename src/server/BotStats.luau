local ReplicatedStorage = game:GetService("ReplicatedStorage")
local PythonTD = ReplicatedStorage:WaitForChild("PythonTD")
local Config = require(PythonTD.Config)

local BotStats = {}

BotStats.GROUND_Y = Config.PLATFORM_Y

BotStats.DEFAULT_PROGRAM = [[
while True:
    if self.collect():
        if self.carrying >= 3:
            self.teleport([0, 0])
            self.deposit()
]]

BotStats.BASE = {
	name = "SupplyBot",
	speed = 28,
	maxCapacity = 10,
	pickupRange = 5,
	transferRange = 8,
	cost = 75,
}

BotStats.BOT_BASE_COST = 75
BotStats.BOT_COST_MULTIPLIER = 1.3

BotStats.BOT_RADIUS = 2
BotStats.GUNDAM_RADIUS = 3

BotStats.SHOCK_RANGE = 10
BotStats.SHOCK_DAMAGE = 30
BotStats.SHOCK_STUN_TIME = 2

BotStats.MAX_BOTS_PER_PLAYER = 4
BotStats.RESPAWN_TIME = 30
BotStats.SHIELD_COOLDOWN = 60

BotStats.COLORS = {
	RUST_ORANGE = Color3.fromRGB(215, 135, 70),
	DARK_METAL  = Color3.fromRGB(45, 50, 55),
	JOINT_GREY  = Color3.fromRGB(80, 85, 90),
	NEON_CYAN   = Color3.fromRGB(0, 255, 255),
	GOLD_SCRAP  = Color3.fromRGB(255, 215, 0),
}

BotStats.COLOR_MAP = {
	red = Color3.fromRGB(255, 80, 80),
	blue = Color3.fromRGB(80, 150, 255),
	green = Color3.fromRGB(80, 255, 80),
	yellow = Color3.fromRGB(255, 255, 80),
	cyan = Color3.fromRGB(80, 255, 255),
	purple = Color3.fromRGB(180, 80, 255),
	pink = Color3.fromRGB(255, 150, 200),
	orange = Color3.fromRGB(255, 180, 80),
	white = Color3.fromRGB(240, 240, 240),
	black = Color3.fromRGB(50, 50, 50),
}

return BotStats
