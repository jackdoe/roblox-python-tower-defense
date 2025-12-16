local ProgramLibrary = {}

ProgramLibrary.categories = {
	"Gundam",
	"Bot",
	"Player",
}

ProgramLibrary.programs = {
	{
		name = "Basic Gundam",
		targetType = "gundam",
		category = "Gundam",
		code = [[
while True:
    enemies = self.scan()
    if len(enemies) > 0:
        self.set_target(nearest(enemies))
        self.fire(BULLET)
]],
	},
	{
		name = "Focus Weak",
		targetType = "gundam",
		category = "Gundam",
		code = [[
while True:
    enemies = self.scan()
    if len(enemies) > 0:
        self.set_target(weakest(enemies))
        self.fire(BULLET)
]],
	},
	{
		name = "Ice Support",
		targetType = "gundam",
		category = "Gundam",
		code = [[
while True:
    enemies = self.scan()
    if len(enemies) > 0:
        self.set_target(nearest(enemies))
        self.fire(ICE)
]],
	},
	{
		name = "Rocket Barrage",
		targetType = "gundam",
		category = "Gundam",
		code = [[
while True:
    enemies = self.scan()
    if len(enemies) >= 3:
        self.set_target(nearest(enemies))
        self.fire(ROCKET)
]],
	},
	{
		name = "Sniper",
		targetType = "gundam",
		category = "Gundam",
		code = [[
while True:
    self.set_range(60)
    enemies = self.scan()
    if len(enemies) > 0:
        self.set_target(strongest(enemies))
        self.fire(LASER)
]],
	},
	{
		name = "Collector",
		targetType = "bot",
		category = "Bot",
		code = [[
while True:
    self.collect()
]],
	},
	{
		name = "Scout",
		targetType = "bot",
		category = "Bot",
		code = [[
while True:
    self.forward(20)
    self.left(90)
]],
	},
	{
		name = "Shock Trooper",
		targetType = "bot",
		category = "Bot",
		code = [[
while True:
    enemies = self.scan()
    if len(enemies) > 0:
        self.shock(nearest(enemies))
    else:
        self.collect()
]],
	},
	{
		name = "Kamikaze",
		targetType = "bot",
		category = "Bot",
		code = [[
while True:
    self.collect()
    if self.cargo > 50:
        enemies = self.scan()
        if len(enemies) > 0:
            self.teleport(nearest(enemies).pos)
            self.explode()
]],
	},
	{
		name = "Run & Gun",
		targetType = "player",
		category = "Player",
		code = [[
while True:
    enemies = self.scan()
    if len(enemies) > 0:
        self.set_target(nearest(enemies))
        self.fire(BULLET)
    self.forward(5)
]],
	},
	{
		name = "Collector",
		targetType = "player",
		category = "Player",
		code = [[
while True:
    self.collect()
]],
	},
	{
		name = "Bomber",
		targetType = "player",
		category = "Player",
		code = [[
while True:
    self.collect()
    if self.cargo > 30:
        enemies = self.scan()
        if len(enemies) > 0:
            self.teleport(nearest(enemies).pos)
            self.explode()
]],
	},
}

function ProgramLibrary.getByCategory(category)
	local result = {}
	for _, prog in ipairs(ProgramLibrary.programs) do
		if prog.category == category then
			table.insert(result, prog)
		end
	end
	return result
end

function ProgramLibrary.getByTarget(targetType)
	local result = {}
	for _, prog in ipairs(ProgramLibrary.programs) do
		if prog.targetType == targetType then
			table.insert(result, prog)
		end
	end
	return result
end

function ProgramLibrary.getAll()
	return ProgramLibrary.programs
end

function ProgramLibrary.find(name)
	for _, prog in ipairs(ProgramLibrary.programs) do
		if prog.name == name then
			return prog
		end
	end
	return nil
end

return ProgramLibrary
