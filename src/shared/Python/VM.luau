local Compiler = require(script.Parent.Compiler)
local Op = Compiler.Op

local VM = {}
VM.__index = VM

local function cleanError(err)
	if type(err) ~= "string" then return tostring(err) end
	return err:gsub("ReplicatedStorage%.PythonTD%.[^:]+:%d+:%s*", ""):gsub("^%s+", "")
end

-- Create a new VM instance
function VM.new()
	local self = setmetatable({}, VM)

	-- Execution state
	self.code = {}  -- Bytecode instructions
	self.ip = 1     -- Instruction pointer
	self.stack = {} -- Operand stack
	self.vars = {}  -- Global variables
	self.varNames = {} -- Track all variable names (for UI)

	-- Call stack for functions
	self.callStack = {}

	-- Status
	self.running = false
	self.paused = false
	self.halted = false
	self.error = nil
	self.output = {}

	-- Game environment (injected functions)
	self.env = {}

	-- Time-slicing
	self.tickCount = 0
	self.maxTicksPerStep = 100
	self.shouldYield = false

	-- Wait state
	self.waitUntil = 0

	-- Blocking operation state (callback-based)
	-- When true, VM is blocked waiting for external signal
	self.blocked = false

	-- Iterator state (for for loops)
	self.iterators = {}

	-- Source code (for reference)
	self.source = ""

	return self
end

-- Set game environment
function VM:setEnvironment(env)
	self.env = env or {}
end

-- Load compiled bytecode
function VM:load(compiled)
	if not compiled or not compiled.code then
		self.error = { message = "No bytecode to load", line = nil }
		return false
	end

	self.code = compiled.code
	self.source = compiled.source or ""
	self.ip = 1
	self.stack = {}
	self.vars = {}
	self.varNames = {}
	self.callStack = {}
	self.running = true
	self.paused = false
	self.halted = false
	self.error = nil
	self.output = {}
	self.iterators = {}
	self.blocked = false
	self.waitUntil = 0

	return true
end

local NIL_MARKER = { _isNil = true }

-- Push value onto stack
function VM:push(value)
	if value == nil then
		table.insert(self.stack, NIL_MARKER)
	else
		table.insert(self.stack, value)
	end
end

-- Pop value from stack
function VM:pop()
	if #self.stack == 0 then
		-- Get current instruction for context
		local instr = self.code[self.ip]
		local context = ""
		if instr then
			context = " at " .. (instr.op or "?")
			if instr.arg then
				context = context .. " " .. tostring(instr.arg)
			end
			if instr.line then
				context = context .. " (line " .. instr.line .. ")"
			end
		end
		-- Throw error so pcall catches it properly
		error("Stack underflow" .. context)
	end
	local value = table.remove(self.stack)
	-- Convert nil marker back to actual nil
	if type(value) == "table" and value._isNil then
		return nil
	end
	return value
end

-- Peek at top of stack without popping
function VM:peek()
	return self.stack[#self.stack]
end

local NOT_FOUND = {}

function VM:getVar(name)
	if #self.callStack > 0 then
		local frame = self.callStack[#self.callStack]
		if frame.localNames and frame.localNames[name] then
			return frame.locals[name]
		end
	end

	if self.varNames[name] then
		return self.vars[name]
	end

	if self.env[name] ~= nil then
		return self.env[name]
	end

	if name == "True" then return true end
	if name == "False" then return false end
	if name == "None" then return nil end

	return NOT_FOUND
end

function VM:setVar(name, value)
	if #self.callStack > 0 then
		local frame = self.callStack[#self.callStack]
		if (frame.localNames and frame.localNames[name]) or not self.varNames[name] then
			frame.locals[name] = value
			frame.localNames = frame.localNames or {}
			frame.localNames[name] = true
			return
		end
	end

	self.vars[name] = value
	self.varNames[name] = true
end

-- Execute one instruction
function VM:step()
	if not self.running or self.halted then
		return false
	end

	if self.paused then
		return true -- Still "running" but paused
	end

	-- Check wait state
	if self.waitUntil > 0 then
		if os.clock() < self.waitUntil then
			return true -- Still waiting
		end
		self.waitUntil = 0
	end

	-- Check blocked state (callback-based)
	if self.blocked then
		return true -- Waiting for unblock() call
	end

	-- Check bounds
	if self.ip < 1 or self.ip > #self.code then
		self.halted = true
		self.running = false
		return false
	end

	local instr = self.code[self.ip]
	local instrLine = instr.line or 0

	local op = instr.op
	local arg = instr.arg

	-- Execute instruction
	local success, err = pcall(function()
		self:executeInstruction(op, arg)
	end)

	if not success then
		self.error = { message = cleanError(err), line = instrLine }
		print("RUNTIME: Line " .. instrLine .. ": " .. self.error.message)
		self.running = false
		return false
	end

	-- Check for yield
	if self.shouldYield then
		self.shouldYield = false
		return true
	end

	return self.running
end

-- Execute a single instruction
function VM:executeInstruction(op, arg)
	-- Load/Store operations
	if op == Op.LOAD_CONST then
		if type(arg) == "table" and arg.type then
			self:push(arg.value)
		else
			self:push(arg)
		end
		self.ip = self.ip + 1
	elseif op == Op.LOAD_VAR then
		local value = self:getVar(arg)
		if value == NOT_FOUND then
			error("NameError: '" .. arg .. "' is not defined")
		end
		self:push(value)
		self.ip = self.ip + 1
	elseif op == Op.STORE_VAR then
		local value = self:pop()
		self:setVar(arg, value)
		self.ip = self.ip + 1
	elseif op == Op.LOAD_ATTR then
		local obj = self:pop()
		if obj == nil then
			error("AttributeError: cannot access '." .. arg .. "' on None")
		elseif type(obj) == "table" then
			self:push(obj[arg])
		else
			error("AttributeError: '" .. type(obj) .. "' has no attribute '" .. arg .. "'")
		end
		self.ip = self.ip + 1
	elseif op == Op.STORE_ATTR then
		local value = self:pop()
		local obj = self:pop()
		if type(obj) == "table" then
			obj[arg] = value
		end
		self.ip = self.ip + 1

		-- Stack operations
	elseif op == Op.POP then
		self:pop()
		self.ip = self.ip + 1
	elseif op == Op.DUP then
		local value = self:peek()
		self:push(value)
		self.ip = self.ip + 1

		-- Binary operations
	elseif op == Op.BINARY_ADD then
		local b = self:pop()
		local a = self:pop()
		if type(a) == "string" or type(b) == "string" then
			self:push(tostring(a) .. tostring(b))
		else
			self:push((a or 0) + (b or 0))
		end
		self.ip = self.ip + 1
	elseif op == Op.BINARY_SUB then
		local b = self:pop()
		local a = self:pop()
		self:push((a or 0) - (b or 0))
		self.ip = self.ip + 1
	elseif op == Op.BINARY_MUL then
		local b = self:pop()
		local a = self:pop()
		self:push((a or 0) * (b or 0))
		self.ip = self.ip + 1
	elseif op == Op.BINARY_DIV then
		local b = self:pop()
		local a = self:pop()
		self:push((a or 0) / (b or 0))
		self.ip = self.ip + 1
	elseif op == Op.BINARY_MOD then
		local b = self:pop()
		local a = self:pop()
		self:push((a or 0) % (b or 0))
		self.ip = self.ip + 1
	elseif op == Op.BINARY_POW then
		local b = self:pop()
		local a = self:pop()
		self:push((a or 0) ^ (b or 0))
		self.ip = self.ip + 1
	elseif op == Op.BINARY_FLOOR_DIV then
		local b = self:pop()
		local a = self:pop()
		self:push(math.floor((a or 0) / (b or 0)))
		self.ip = self.ip + 1

		-- Comparison
	elseif op == Op.COMPARE_EQ then
		local b = self:pop()
		local a = self:pop()
		self:push(a == b)
		self.ip = self.ip + 1
	elseif op == Op.COMPARE_NE then
		local b = self:pop()
		local a = self:pop()
		self:push(a ~= b)
		self.ip = self.ip + 1
	elseif op == Op.COMPARE_LT then
		local b = self:pop()
		local a = self:pop()
		self:push((a or 0) < (b or 0))
		self.ip = self.ip + 1
	elseif op == Op.COMPARE_GT then
		local b = self:pop()
		local a = self:pop()
		self:push((a or 0) > (b or 0))
		self.ip = self.ip + 1
	elseif op == Op.COMPARE_LE then
		local b = self:pop()
		local a = self:pop()
		self:push((a or 0) <= (b or 0))
		self.ip = self.ip + 1
	elseif op == Op.COMPARE_GE then
		local b = self:pop()
		local a = self:pop()
		self:push((a or 0) >= (b or 0))
		self.ip = self.ip + 1

		-- Logical
	elseif op == Op.BINARY_AND then
		local b = self:pop()
		local a = self:pop()
		self:push(a and b)
		self.ip = self.ip + 1
	elseif op == Op.BINARY_OR then
		local b = self:pop()
		local a = self:pop()
		self:push(a or b)
		self.ip = self.ip + 1
	elseif op == Op.UNARY_NOT then
		local a = self:pop()
		self:push(not a)
		self.ip = self.ip + 1
	elseif op == Op.UNARY_NEG then
		local a = self:pop()
		self:push(-(a or 0))
		self.ip = self.ip + 1

		-- Control flow
	elseif op == Op.JUMP then
		self.ip = arg
	elseif op == Op.JUMP_IF_FALSE then
		local cond = self:pop()
		if not cond then
			self.ip = arg
		else
			self.ip = self.ip + 1
		end
	elseif op == Op.JUMP_IF_TRUE then
		local cond = self:pop()
		if cond then
			self.ip = arg
		else
			self.ip = self.ip + 1
		end
	elseif op == Op.POP_JUMP_IF_FALSE then
		local cond = self:pop()
		if not cond then
			self.ip = arg
		else
			self.ip = self.ip + 1
		end
	elseif op == Op.POP_JUMP_IF_TRUE then
		local cond = self:pop()
		if cond then
			self.ip = arg
		else
			self.ip = self.ip + 1
		end
	elseif op == Op.CALL then
		local nargs = arg
		local args = {}

		for i = nargs, 1, -1 do
			args[i] = self:pop()
		end

		local callee = self:pop()

		if callee == nil then
			error("TypeError: cannot call None")
		end

		local success, result = pcall(function()
			return self:callFunction(callee, args)
		end)

		if not success then
			error("RuntimeError: " .. cleanError(result))
		end

		self:push(result)
		self.ip = self.ip + 1
	elseif op == Op.RETURN then
		local returnValue = self:pop()

		if #self.callStack > 0 then
			-- Return from function
			local frame = table.remove(self.callStack)
			self.ip = frame.returnAddr
			self.stack = frame.savedStack
			self:push(returnValue)
		else
			-- Return from main program
			self:push(returnValue)
			self.halted = true
			self.running = false
		end
	elseif op == Op.MAKE_FUNCTION then
		-- arg is the function object
		self:push({
			_isFunction = true,
			name = arg.name,
			params = arg.params,
			code = arg.code,
		})
		self.ip = self.ip + 1

		-- Data structures
	elseif op == Op.BUILD_LIST then
		local n = arg
		local list = {}
		for i = n, 1, -1 do
			list[i] = self:pop()
		end
		self:push(list)
		self.ip = self.ip + 1
	elseif op == Op.GET_INDEX then
		local index = self:pop()
		local obj = self:pop()

		if type(obj) == "table" then
			-- Python 0-indexed -> Lua 1-indexed
			self:push(obj[index + 1])
		elseif type(obj) == "string" then
			self:push(string.sub(obj, index + 1, index + 1))
		else
			self:push(nil)
		end
		self.ip = self.ip + 1
	elseif op == Op.SET_INDEX then
		local index = self:pop()
		local obj = self:pop()
		local value = self:pop()

		if type(obj) == "table" then
			-- Python 0-indexed -> Lua 1-indexed
			obj[index + 1] = value
		end
		self.ip = self.ip + 1
	elseif op == Op.UNPACK_SEQUENCE then
		local n = arg
		local seq = self:pop()

		if type(seq) == "table" then
			-- Push items in order (they'll be stored in reverse)
			for i = 1, n do
				self:push(seq[i])
			end
		end
		self.ip = self.ip + 1

		-- Iteration
	elseif op == Op.GET_ITER then
		local iterable = self:pop()
		local iterator = {
			items = iterable,
			index = 0,
		}
		self:push(iterator)
		self.ip = self.ip + 1
	elseif op == Op.FOR_ITER then
		local iterator = self:peek()

		if type(iterator) == "table" and iterator.items then
			iterator.index = iterator.index + 1

			if type(iterator.items) == "table" and iterator.index <= #iterator.items then
				-- Push next item
				self:push(iterator.items[iterator.index])
				self.ip = self.ip + 1
			else
				-- Exhausted, jump to end
				self.ip = arg
			end
		else
			self.ip = arg
		end

		-- Special
	elseif op == Op.NOP then
		-- No operation, just advance
		self.ip = self.ip + 1
	elseif op == Op.YIELD then
		self.shouldYield = true
		self.ip = self.ip + 1
	elseif op == Op.HALT then
		self.halted = true
		self.running = false
	else
		error("Unknown opcode: " .. tostring(op))
	end
end

function VM:callUserFunction(callee, args)
	local frame = {
		returnAddr = self.ip + 1,
		savedStack = self.stack,
		locals = {},
		localNames = {},
	}

	for i, param in ipairs(callee.params) do
		frame.locals[param] = args[i]
		frame.localNames[param] = true
	end

	table.insert(self.callStack, frame)

	-- Set up new execution context
	self.stack = {}

	local savedCode = self.code
	local savedIp = self.ip

	self.code = callee.code
	self.ip = 1

	-- Execute function until RETURN
	while self.running and not self.halted and self.ip <= #self.code do
		local instr = self.code[self.ip]
		if instr.op == Op.RETURN then
			local returnValue = self:pop()

			-- Restore state
			local returnFrame = table.remove(self.callStack)
			self.stack = returnFrame.savedStack
			self.code = savedCode
			self.ip = savedIp

			return returnValue
		end

		self:step()
	end

	-- No explicit return
	self.code = savedCode
	self.ip = savedIp
	if #self.callStack > 0 then
		local returnFrame = table.remove(self.callStack)
		self.stack = returnFrame.savedStack
	end

	return nil
end

-- Call a function (built-in or user-defined)
function VM:callFunction(callee, args)
	-- Check for callable tables
	if type(callee) == "table" then
		-- User-defined function (has _isFunction marker)
		if callee._isFunction then
			return self:callUserFunction(callee, args)
		end

		-- Callable table with __call metamethod
		local mt = getmetatable(callee)
		if mt and mt.__call then
			return mt.__call(callee, table.unpack(args))
		end
	end

	-- Native Lua function (from environment)
	if type(callee) == "function" then
		return callee(table.unpack(args))
	end

	error("Cannot call: " .. tostring(callee))
end

-- Run for multiple steps (time-sliced execution)
function VM:run(maxSteps)
	maxSteps = maxSteps or 100

	for i = 1, maxSteps do
		if not self:step() then
			return false
		end

		if self.shouldYield or self.waitUntil > 0 then
			return true
		end
	end

	return self.running
end

-- Get current state for UI
function VM:getState()
	-- Get all variables including nil values
	local allVars = {}
	for name in pairs(self.varNames) do
		allVars[name] = self.vars[name]
	end

	-- Also include non-nil values
	for name, value in pairs(self.vars) do
		if type(value) ~= "table" or not value._isFunction then
			allVars[name] = value
		end
	end

	return {
		ip = self.ip,
		stack = self.stack,
		vars = allVars,
		running = self.running,
		paused = self.paused,
		halted = self.halted,
		error = self.error,
		output = self.output,
		code = self.code,
	}
end

-- Stop execution
function VM:stop()
	self.running = false
	self.halted = true
end

-- Pause execution
function VM:pause()
	self.paused = true
end

-- Resume execution
function VM:resume()
	self.paused = false
end

-- Block execution (for async operations)
-- Game code calls this, then unblock() when done
function VM:block()
	self.blocked = true
end

function VM:unblock(result)
	self.blocked = false
	if result == nil then
		self.asyncResult = NIL_MARKER
	else
		self.asyncResult = result
	end
end

-- Step one instruction (for debugger)
function VM:stepOnce()
	if self.halted then
		return false
	end

	local wasPaused = self.paused
	self.paused = false

	self:step()

	self.paused = true
	return self.running and not self.halted
end

-- Format stack for display
function VM:formatStack()
	local parts = {}
	for i, v in ipairs(self.stack) do
		if v == nil then
			table.insert(parts, "None")
		elseif type(v) == "boolean" then
			table.insert(parts, v and "True" or "False")
		elseif type(v) == "table" then
			if v._isFunction then
				table.insert(parts, "<fn:" .. (v.name or "?") .. ">")
			elseif v.items then
				table.insert(parts, "<iter>")
			else
				table.insert(parts, "[list:" .. #v .. "]")
			end
		elseif type(v) == "string" then
			if #v > 10 then
				table.insert(parts, '"' .. v:sub(1, 10) .. '..."')
			else
				table.insert(parts, '"' .. v .. '"')
			end
		else
			table.insert(parts, tostring(v))
		end
	end
	return parts
end

return VM
