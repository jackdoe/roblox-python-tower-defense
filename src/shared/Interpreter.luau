local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Python = require(script.Parent.Python)

local Interpreter = {}
Interpreter.__index = Interpreter

function Interpreter.new(player, isMonster, deps)
	local self = setmetatable({}, Interpreter)

	self.id = game:GetService("HttpService"):GenerateGUID()
	self.isPlayer = not isMonster
	self.isMonster = isMonster or false
	self.player = not isMonster and player or nil
	self.character = nil

	self.runtime = Python.createRuntime()
	self.source = ""
	self.lastProgram = ""

	self.status = "IDLE"
	self.error = nil
	self.output = {}
	self.nextPrintId = 1
	self.paused = false
	self.blocked = false

	self.cpuHz = 1
	self.maxBytecode = 32
	self.selfType = nil
	self.tickAccumulator = 0

	self.gameEnv = {}
	self.deps = deps

	self.ammo = 0
	self.maxAmmo = 0
	self.range = 40
	self.dynamicRange = 40
	self.target = nil
	self.lastFireTime = 0

	return self
end

function Interpreter:setGameEnvironment(env)
	self.gameEnv = env
	self.runtime:setEnvironment(env)
end

function Interpreter:load(source)
	self.source = source
	self.lastProgram = source
	self.error = nil
	self.output = {}
	self.tickAccumulator = 1

	local success = self.runtime:compile(source, self.maxBytecode, self.selfType)

	if not success then
		self.error = self.runtime.error
		self.status = "ERROR"
		return false
	end

	self.runtime:setEnvironment(self.gameEnv)

	local startSuccess = self.runtime:start()
	if not startSuccess then
		self.error = self.runtime.error or { message = "Failed to start", line = nil }
		self.status = "ERROR"
		return false
	end

	self.status = "READY"
	self.paused = false
	return true
end

function Interpreter:step()
	if self.status == "ERROR" or self.status == "DONE" then
		return false, 0
	end

	if self.paused or self.blocked then
		return true, 1
	end

	local running = self.runtime:step()

	local state = self.runtime:getState()
	if state.error then
		self.error = state.error
		self.status = "ERROR"
		return false, 0
	end

	if running then
		self.status = "RUNNING"
		return true, 1
	else
		self.status = "DONE"
		return false, 0
	end
end

function Interpreter:run(maxTicks, maxFreeSteps)
	maxTicks = maxTicks or 1

	local ticksConsumed = 0

	for _ = 1, maxTicks do
		local continue, tickCost = self:step()
		if not continue then break end
		ticksConsumed = ticksConsumed + tickCost
	end

	return self.status
end

function Interpreter:update(dt)
	if self.status == "ERROR" or self.status == "DONE" then
		return self.status
	end

	if self.paused or self.blocked then
		return self.status
	end

	self.tickAccumulator = self.tickAccumulator + dt * self.cpuHz
	local ticksToRun = math.floor(self.tickAccumulator)
	self.tickAccumulator = self.tickAccumulator - ticksToRun

	if ticksToRun > 0 then
		self:run(ticksToRun)
	end

	return self.status
end

function Interpreter:stepOnce()
	if self.status == "ERROR" or self.status == "DONE" then
		return false
	end

	local running = false
	if self.runtime then
		running = self.runtime:stepOnce()
	end

	if self.runtime then
		local state = self.runtime:getState()
		if state.error then
			self.error = state.error
			self.status = "ERROR"
			return false
		end
	end

	if running then
		self.status = "RUNNING"
		return true
	else
		self.status = "DONE"
		return false
	end
end

function Interpreter:reset()
	self.runtime:stop()
	self.status = "READY"
	self.error = nil
	self.output = {}
	self.paused = false
	self.tickAccumulator = 0

	if self.lastProgram and #self.lastProgram > 0 then
		self:load(self.lastProgram)
	end
end

function Interpreter:getCurrentTokenIndex()
	if self.runtime then
		local state = self.runtime:getState()
		local bytecode = state.bytecode or {}
		local ip = state.vm and state.vm.ip or 1
		return bytecode[ip] and bytecode[ip].line or 0
	end
	return 0
end

function Interpreter:getState()
	local state = self:getDynamicState()
	local static = self:getStaticState()

	for k, v in pairs(static) do
		state[k] = v
	end

	return state
end

local MAX_OUTPUT_LINES = 20
local MAX_LINE_LENGTH = 60

function Interpreter:getDynamicState()
	local lines = {}
	local startIdx = math.max(1, #self.output - MAX_OUTPUT_LINES + 1)
	for i = startIdx, #self.output do
		local entry = self.output[i]
		local msg = entry.message or ""
		if #msg > MAX_LINE_LENGTH then
			msg = msg:sub(1, MAX_LINE_LENGTH - 3) .. "..."
		end
		lines[#lines + 1] = string.format("0x%03x: %s", entry.id or 0, msg)
	end
	local output = table.concat(lines, "\n")

	local NIL_MARKER = "__NIL__"
	local variables = {}
	if self.runtime then
		if self.runtime.globalNames then
			for name in pairs(self.runtime.globalNames) do
				local value = self.runtime.globals[name]
				if value == nil then
					variables[name] = NIL_MARKER
				elseif type(value) ~= "table" or not value._isFunction then
					variables[name] = value
				end
			end
		end
		if self.runtime.globals then
			for name, value in pairs(self.runtime.globals) do
				if variables[name] == nil then
					if type(value) ~= "table" or not value._isFunction then
						variables[name] = value
					end
				end
			end
		end
	end

	local vmState = nil
	local currentLine = 0
	if self.runtime then
		local runtimeState = self.runtime:getState()
		vmState = runtimeState.vm
		local bytecode = runtimeState.bytecode or {}
		local ip = vmState and vmState.ip or 1
		currentLine = bytecode[ip] and bytecode[ip].line or 0
	end

	return {
		vm = vmState,
		currentLine = currentLine,
		status = self.status,
		error = self.error,
		output = output,
		paused = self.paused,
		ammo = self.ammo,
		maxAmmo = self.maxAmmo,
		dynamicRange = self.dynamicRange,
		variables = variables,
		cpuHz = self.cpuHz,
		maxBytecode = self.maxBytecode,
	}
end

function Interpreter:getStaticState()
	local bytecode = {}
	if self.runtime then
		local runtimeState = self.runtime:getState()
		bytecode = runtimeState.bytecode or {}
	end

	return {
		source = self.source,
		bytecode = bytecode,
		language = "Python",
	}
end

return Interpreter
