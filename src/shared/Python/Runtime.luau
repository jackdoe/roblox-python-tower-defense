-- Runtime.luau
-- Python runtime for Roblox using bytecode compilation + VM execution
-- Wraps Compiler and VM modules for the game infrastructure

local Compiler = require(script.Parent.Compiler)
local VM = require(script.Parent.VM)

local Runtime = {}
Runtime.__index = Runtime

-- Create a new runtime instance
function Runtime.new()
	local self = setmetatable({}, Runtime)

	self.source = ""
	self.compiled = nil  -- Compiled bytecode
	self.vm = VM.new()   -- Virtual machine instance
	self.running = false
	self.paused = false
	self.error = nil
	self.output = {}

	self.env = {}

	-- For API compatibility with old Runtime
	self.globals = {}
	self.globalNames = {}

	return self
end

-- Set game environment functions
function Runtime:setEnvironment(env)
	self.env = env or {}
	self.vm:setEnvironment(self.env)
end

function Runtime:compile(source, maxBytecode, selfType, envTypes)
	self.source = source
	self.error = nil
	self.output = {}
	self.globals = {}
	self.globalNames = {}

	local result = Compiler.compile(source, maxBytecode, selfType, envTypes)

	if result.error then
		self.error = result.error
		return false, self.error.message
	end

	self.compiled = result
	self.instructionCount = result.instructionCount
	return true
end

-- Start execution
function Runtime:start()
	if not self.compiled then
		return false, "No compiled code"
	end

	-- Reset VM state
	self.vm = VM.new()
	self.vm:setEnvironment(self.env)

	-- Load bytecode into VM
	local success = self.vm:load(self.compiled)
	if not success then
		self.error = self.vm.error or { message = "Failed to load bytecode", line = nil }
		return false, self.error.message
	end

	self.running = true
	self.paused = false
	self.error = nil

	return true
end

-- Step execution (call each frame)
function Runtime:step()
	if not self.running or self.paused then
		return false
	end

	-- Run VM for some steps
	local stillRunning = self.vm:run(50)

	-- Sync state from VM
	local vmState = self.vm:getState()

	-- Update running status
	self.running = vmState.running and not vmState.halted

	-- Check for errors
	if vmState.error then
		self.error = vmState.error
		self.running = false
		return false
	end

	-- Sync output
	self.output = vmState.output

	-- Sync globals for UI display
	self.globals = vmState.vars
	for name in pairs(vmState.vars) do
		self.globalNames[name] = true
	end

	return self.running
end

-- Stop execution
function Runtime:stop()
	self.running = false
	self.paused = false
	self.vm:stop()
end

-- Pause execution
function Runtime:pause()
	self.paused = true
	self.vm:pause()
end

-- Resume execution
function Runtime:resume()
	self.paused = false
	self.vm:resume()
end

-- Step one instruction (for debugger)
function Runtime:stepOnce()
	if not self.running and not self.vm.running then
		return false
	end

	local stillRunning = self.vm:stepOnce()

	-- Sync state from VM
	local vmState = self.vm:getState()

	if vmState.error then
		self.error = vmState.error
		self.running = false
		return false
	end

	self.output = vmState.output
	self.globals = vmState.vars
	for name in pairs(vmState.vars) do
		self.globalNames[name] = true
	end
	self.running = vmState.running and not vmState.halted

	return stillRunning
end

-- Get current state
function Runtime:getState()
	local vmState = self.vm:getState()

	-- Build globals including nil values
	local allGlobals = {}
	for name in pairs(self.globalNames) do
		allGlobals[name] = self.globals[name]
	end
	for name, value in pairs(self.globals) do
		if type(value) ~= "table" or not value._isFunction then
			allGlobals[name] = value
		end
	end

	return {
		running = self.running,
		paused = self.paused,
		error = self.error,
		output = self.output,
		source = self.source,
		globals = allGlobals,
		globalNames = self.globalNames,

		-- VM state: ip + bytecode. Client derives currentLine from bytecode[ip].line
		vm = {
			ip = vmState.ip,
			stack = vmState.stack,
			halted = vmState.halted,
		},
		bytecode = self.compiled and self.compiled.code or {},
	}
end

-- Get bytecode for display
function Runtime:getBytecode()
	if not self.compiled then
		return {}
	end
	return self.compiled.code
end

-- Get formatted bytecode string
function Runtime:formatBytecode()
	return Compiler.formatBytecode(self.compiled)
end

-- Get VM stack for display
function Runtime:getStack()
	return self.vm:formatStack()
end

-- Get instruction pointer
function Runtime:getIP()
	return self.vm.ip
end

-- Clear output
function Runtime:clearOutput()
	self.output = {}
	self.vm.output = {}
end

return Runtime
