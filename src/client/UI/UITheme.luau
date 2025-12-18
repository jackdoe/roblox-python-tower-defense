local UITheme = {}

UITheme.FONT = Enum.Font.Code

UITheme.COLORS = {
	bg = Color3.fromRGB(12, 16, 22),
	panel = Color3.fromRGB(20, 25, 35),
	accent = Color3.fromRGB(0, 255, 200),
	danger = Color3.fromRGB(255, 60, 80),
	success = Color3.fromRGB(60, 255, 120),
	warning = Color3.fromRGB(255, 200, 50),
	text = Color3.fromRGB(240, 245, 255),
	subtext = Color3.fromRGB(120, 130, 150),
	glass = Color3.fromRGB(255, 255, 255),
	disabledBg = Color3.fromRGB(15, 15, 20),
	errorDot = Color3.fromRGB(255, 80, 80),
	execDot = Color3.fromRGB(255, 255, 100),
}

UITheme.THEMES = {
	player = {
		frameBg = Color3.fromRGB(30, 30, 40),
		headerBg = Color3.fromRGB(40, 40, 55),
		codeBg = Color3.fromRGB(25, 25, 35),
		accent = Color3.fromRGB(100, 180, 100),
		varName = Color3.fromRGB(156, 220, 254),
		varValue = Color3.fromRGB(206, 145, 120),
	},
	gundam = {
		frameBg = Color3.fromRGB(35, 35, 40),
		headerBg = Color3.fromRGB(50, 50, 55),
		codeBg = Color3.fromRGB(30, 30, 35),
		accent = Color3.fromRGB(180, 180, 200),
		varName = Color3.fromRGB(180, 180, 220),
		varValue = Color3.fromRGB(150, 150, 180),
	},
	bot = {
		frameBg = Color3.fromRGB(40, 30, 20),
		headerBg = Color3.fromRGB(55, 40, 25),
		codeBg = Color3.fromRGB(35, 25, 15),
		accent = Color3.fromRGB(255, 160, 80),
		varName = Color3.fromRGB(255, 180, 100),
		varValue = Color3.fromRGB(255, 200, 150),
	},
}

UITheme.AMMO_COLORS = {
	passive = Color3.fromRGB(120, 120, 140),
	bullet = Color3.fromRGB(255, 240, 120),
	rocket = Color3.fromRGB(255, 120, 60),
	laser = Color3.fromRGB(255, 80, 100),
	grenade = Color3.fromRGB(120, 255, 140),
}

UITheme.ENEMY_ICONS = {
	Zombie = "●",
	Runner = "◆",
	Tank = "■",
	Boss = "★",
}

UITheme.ENEMY_COLORS = {
	Zombie = Color3.fromRGB(100, 200, 120),
	Runner = Color3.fromRGB(255, 180, 80),
	Tank = Color3.fromRGB(140, 160, 220),
	Boss = Color3.fromRGB(255, 60, 100),
}

UITheme.ENEMY_SIZES = {
	Zombie = 10,
	Runner = 12,
	Tank = 18,
	Boss = 22,
}

UITheme.BOT_COLORS = {
	Color3.fromRGB(255, 100, 100),
	Color3.fromRGB(100, 180, 255),
	Color3.fromRGB(100, 255, 150),
	Color3.fromRGB(255, 200, 100),
}

UITheme.OP_COLORS = {
	LOAD_CONST = "#569CD6",
	LOAD_VAR = "#569CD6",
	STORE_VAR = "#569CD6",
	LOAD_ATTR = "#569CD6",
	STORE_ATTR = "#569CD6",
	POP = "#808080",
	DUP = "#808080",
	BINARY_ADD = "#4EC9B0",
	BINARY_SUB = "#4EC9B0",
	BINARY_MUL = "#4EC9B0",
	BINARY_DIV = "#4EC9B0",
	BINARY_MOD = "#4EC9B0",
	BINARY_POW = "#4EC9B0",
	BINARY_FLOOR_DIV = "#4EC9B0",
	COMPARE_EQ = "#DCDCAA",
	COMPARE_NE = "#DCDCAA",
	COMPARE_LT = "#DCDCAA",
	COMPARE_GT = "#DCDCAA",
	COMPARE_LE = "#DCDCAA",
	COMPARE_GE = "#DCDCAA",
	BINARY_AND = "#C586C0",
	BINARY_OR = "#C586C0",
	UNARY_NOT = "#C586C0",
	UNARY_NEG = "#C586C0",
	JUMP = "#CE9178",
	JUMP_IF_FALSE = "#CE9178",
	JUMP_IF_TRUE = "#CE9178",
	POP_JUMP_IF_FALSE = "#CE9178",
	POP_JUMP_IF_TRUE = "#CE9178",
	CALL = "#4FC1FF",
	RETURN = "#4FC1FF",
	MAKE_FUNCTION = "#4FC1FF",
	BUILD_LIST = "#9CDCFE",
	GET_INDEX = "#9CDCFE",
	SET_INDEX = "#9CDCFE",
	UNPACK_SEQUENCE = "#9CDCFE",
	GET_ITER = "#F38BA8",
	FOR_ITER = "#F38BA8",
	YIELD = "#F44747",
	HALT = "#F44747",
}

function UITheme.formatValue(value, maxLen, depth)
	maxLen = maxLen or 30
	depth = depth or 0
	local str

	if value == nil then
		str = "None"
	elseif type(value) == "boolean" then
		str = value and "True" or "False"
	elseif type(value) == "string" then
		str = '"' .. value .. '"'
	elseif type(value) == "table" then
		if value.__type then
			if value.__type == "Enemy" and value.hp then
				str = string.format("Enemy(%s, hp=%d)", value.type or "?", value.hp)
			elseif value.__type == "Scrap" and value.x then
				str = string.format("Scrap(%d, %d)", math.floor(value.x), math.floor(value.z))
			elseif value.__type == "Core" then
				str = "Core"
			else
				str = string.format("@%s", value.__type)
			end
		else
			local isArray = true
			local arrayLen = 0
			for k, _ in pairs(value) do
				if type(k) == "number" and k == math.floor(k) and k > 0 then
					arrayLen = math.max(arrayLen, k)
				else
					isArray = false
					break
				end
			end
			if isArray then
				for i = 1, arrayLen do
					if value[i] == nil then
						isArray = false
						break
					end
				end
			end

			if isArray then
				local items = {}
				local count = 0
				for i, v in ipairs(value) do
					count = count + 1
					if count > 5 then
						table.insert(items, "...")
						break
					end
					if type(v) == "table" and depth < 2 then
						table.insert(items, UITheme.formatValue(v, 20, depth + 1))
					else
						table.insert(items, UITheme.formatValue(v, 10, depth + 1))
					end
				end
				str = "[" .. table.concat(items, ", ") .. "]"
			elseif value.id and value.type and value.hp then
				str = string.format("%s(hp=%d)", value.type or "Enemy", value.hp or 0)
			elseif value.id and value.x and value.z then
				str = string.format("Scrap@(%d,%d)", math.floor(value.x or 0), math.floor(value.z or 0))
			elseif value.id then
				str = string.format("{id=%s}", tostring(value.id):sub(1, 8))
			else
				local items = {}
				local count = 0
				for k, v in pairs(value) do
					count = count + 1
					if count > 3 then
						table.insert(items, "...")
						break
					end
					local keyStr = tostring(k)
					local valStr = UITheme.formatValue(v, 8, depth + 1)
					table.insert(items, keyStr .. ":" .. valStr)
				end
				str = "{" .. table.concat(items, ", ") .. "}"
			end
		end
	else
		str = tostring(value)
	end

	if #str > maxLen then
		str = str:sub(1, maxLen - 3) .. "..."
	end

	return str
end

function UITheme.formatStackValue(v)
	if v == nil then
		return "None"
	elseif type(v) == "boolean" then
		return v and "True" or "False"
	elseif type(v) == "table" then
		if v._isFunction then
			return "fn"
		elseif v.items then
			return "iter"
		elseif v.__type then
			return "@" .. v.__type
		else
			local count = 0
			for _ in pairs(v) do count = count + 1 end
			return "[" .. count .. "]"
		end
	elseif type(v) == "string" then
		if #v > 8 then
			return '"' .. v:sub(1, 6) .. '.."'
		end
		return '"' .. v .. '"'
	else
		return tostring(v)
	end
end

function UITheme.formatArg(arg)
	if arg == nil then
		return ""
	elseif type(arg) == "table" then
		if arg.type then
			if arg.value == nil then
				return "None"
			elseif type(arg.value) == "string" then
				local str = arg.value
				if #str > 12 then
					str = str:sub(1, 10) .. ".."
				end
				return '"' .. str .. '"'
			elseif type(arg.value) == "boolean" then
				return arg.value and "True" or "False"
			else
				return tostring(arg.value)
			end
		elseif arg.name then
			return "fn:" .. arg.name
		else
			return "{...}"
		end
	elseif type(arg) == "string" then
		return arg
	else
		return tostring(arg)
	end
end

return UITheme
