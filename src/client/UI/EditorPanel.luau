local UserInputService = game:GetService("UserInputService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local PythonTD = ReplicatedStorage:WaitForChild("PythonTD")
local Classes = require(PythonTD.Python.Classes)
local UITheme = require(script.Parent.UITheme)

local EditorPanel = {}
local COLORS = UITheme.COLORS

local function formatType(t)
	if type(t) == "table" then
		if t[1] == "optional" then
			return formatType(t[2]) .. "?"
		elseif t[1] == "List" or t[1] == Classes.T.LIST then
			return "List[" .. formatType(t[2]) .. "]"
		else
			return table.concat(t, ", ")
		end
	end
	return tostring(t)
end

local function formatArgs(args)
	if not args or #args == 0 then return "()" end
	local parts = {}
	for i, arg in ipairs(args) do
		table.insert(parts, formatType(arg))
	end
	return "(" .. table.concat(parts, ", ") .. ")"
end

local function buildHelpData()
	local help = {
		keywords = {
			{word = "while", sig = "while condition:", desc = "loop"},
			{word = "if", sig = "if condition:", desc = "conditional"},
			{word = "elif", sig = "elif condition:", desc = "else if"},
			{word = "else", sig = "else:", desc = "fallback"},
			{word = "for", sig = "for x in list:", desc = "iterate"},
			{word = "def", sig = "def name():", desc = "function"},
			{word = "return", sig = "return value", desc = "exit function"},
			{word = "break", sig = "break", desc = "exit loop"},
			{word = "continue", sig = "continue", desc = "next iteration"},
			{word = "and", sig = "a and b", desc = "logical and"},
			{word = "or", sig = "a or b", desc = "logical or"},
			{word = "not", sig = "not x", desc = "logical not"},
			{word = "in", sig = "x in list", desc = "membership"},
			{word = "True", sig = "True", desc = "boolean true"},
			{word = "False", sig = "False", desc = "boolean false"},
			{word = "None", sig = "None", desc = "null value"},
		},
		builtins = {},
		methods = {
			Bot = {},
			Gundam = {},
			Player = {},
			Enemy = {},
		},
	}

	for name, info in pairs(Classes.Builtins) do
		if type(info) == "table" and info.type == "Function" then
			table.insert(help.builtins, {
				word = name,
				sig = name .. formatArgs(info.args) .. " -> " .. formatType(info.returns),
				desc = name,
			})
		elseif type(info) == "string" and info ~= "Function" then
			table.insert(help.builtins, {
				word = name,
				sig = name .. ": " .. info,
				desc = "constant",
			})
		end
	end

	for className, classDef in pairs({Bot = Classes.Bot, Gundam = Classes.Gundam, Player = Classes.Player, Enemy = Classes.Enemy}) do
		if classDef and classDef.members then
			for memberName, member in pairs(classDef.members) do
				if member.kind == "method" then
					table.insert(help.methods[className], {
						word = memberName,
						sig = memberName .. formatArgs(member.args) .. " -> " .. formatType(member.returns),
						desc = "method",
					})
				elseif member.kind == "prop" then
					table.insert(help.methods[className], {
						word = memberName,
						sig = memberName .. ": " .. formatType(member.type),
						desc = "property",
					})
				end
			end
			table.sort(help.methods[className], function(a, b) return a.word < b.word end)
		end
	end

	table.sort(help.builtins, function(a, b) return a.word < b.word end)
	return help
end

local HELP_DATA = buildHelpData()

function EditorPanel.create(parent, selfType)
	local panel = {}
	local isReadOnly = false
	local currentErrorLine = -1
	local currentExecLine = -1

	local frame = Instance.new("Frame")
	frame.Name = "EditorFrame"
	frame.Size = UDim2.new(1, 0, 1, 0)
	frame.BackgroundTransparency = 1
	frame.Parent = parent

	local HELP_BAR_HEIGHT = 20

	local lineScroll = Instance.new("ScrollingFrame")
	lineScroll.Name = "LineScroll"
	lineScroll.Size = UDim2.new(0, 40, 1, -HELP_BAR_HEIGHT)
	lineScroll.BackgroundTransparency = 1
	lineScroll.BorderSizePixel = 0
	lineScroll.ScrollBarThickness = 0
	lineScroll.ScrollingEnabled = false
	lineScroll.Parent = frame

	local lineNumbers = Instance.new("TextLabel")
	lineNumbers.Name = "LineNumbers"
	lineNumbers.Size = UDim2.new(1, -4, 0, 0)
	lineNumbers.BackgroundTransparency = 1
	lineNumbers.Text = "1"
	lineNumbers.TextColor3 = COLORS.subtext
	lineNumbers.TextXAlignment = Enum.TextXAlignment.Right
	lineNumbers.TextYAlignment = Enum.TextYAlignment.Top
	lineNumbers.Font = Enum.Font.Code
	lineNumbers.TextSize = 13
	lineNumbers.RichText = true
	lineNumbers.AutomaticSize = Enum.AutomaticSize.Y
	lineNumbers.Parent = lineScroll

	local codeScroll = Instance.new("ScrollingFrame")
	codeScroll.Name = "CodeScroll"
	codeScroll.Size = UDim2.new(1, -45, 1, -HELP_BAR_HEIGHT)
	codeScroll.Position = UDim2.new(0, 45, 0, 0)
	codeScroll.BackgroundTransparency = 1
	codeScroll.BorderSizePixel = 0
	codeScroll.ScrollBarThickness = 6
	codeScroll.ScrollBarImageColor3 = COLORS.subtext
	codeScroll.CanvasSize = UDim2.new(0, 0, 0, 0)
	codeScroll.Parent = frame

	local textBox = Instance.new("TextBox")
	textBox.Name = "CodeInput"
	textBox.Size = UDim2.new(1, -10, 1, 0)
	textBox.BackgroundTransparency = 1
	textBox.Text = ""
	textBox.PlaceholderText = ""
	textBox.TextColor3 = COLORS.text
	textBox.TextXAlignment = Enum.TextXAlignment.Left
	textBox.TextYAlignment = Enum.TextYAlignment.Top
	textBox.Font = Enum.Font.Code
	textBox.TextSize = 13
	textBox.MultiLine = true
	textBox.ClearTextOnFocus = false
	textBox.TextWrapped = false
	textBox.Parent = codeScroll

	local helpBar = Instance.new("ScrollingFrame")
	helpBar.Name = "HelpBar"
	helpBar.Size = UDim2.new(1, 0, 0, HELP_BAR_HEIGHT)
	helpBar.Position = UDim2.new(0, 0, 1, -HELP_BAR_HEIGHT)
	helpBar.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
	helpBar.BackgroundTransparency = 0
	helpBar.BorderSizePixel = 0
	helpBar.ScrollBarThickness = 0
	helpBar.ScrollingDirection = Enum.ScrollingDirection.X
	helpBar.CanvasSize = UDim2.new(0, 0, 0, 0)
	helpBar.AutomaticCanvasSize = Enum.AutomaticSize.X
	helpBar.Parent = frame

	local helpLayout = Instance.new("UIListLayout")
	helpLayout.FillDirection = Enum.FillDirection.Horizontal
	helpLayout.Padding = UDim.new(0, 4)
	helpLayout.VerticalAlignment = Enum.VerticalAlignment.Center
	helpLayout.Parent = helpBar

	local helpPadding = Instance.new("UIPadding")
	helpPadding.PaddingLeft = UDim.new(0, 4)
	helpPadding.PaddingRight = UDim.new(0, 4)
	helpPadding.Parent = helpBar

	local MAX_HELP_ITEMS = 12
	local helpButtons = {}
	local helpConns = {}
	local currentSelfType = selfType or "Player"

	for i = 1, MAX_HELP_ITEMS do
		local btn = Instance.new("TextButton")
		btn.Name = "Help" .. i
		btn.Size = UDim2.new(0, 60, 0, 16)
		btn.BackgroundColor3 = Color3.fromRGB(0, 80, 100)
		btn.BackgroundTransparency = 0
		btn.Text = ""
		btn.TextColor3 = Color3.fromRGB(255, 255, 255)
		btn.Font = Enum.Font.Code
		btn.TextSize = 10
		btn.AutomaticSize = Enum.AutomaticSize.X
		btn.TextTruncate = Enum.TextTruncate.AtEnd
		btn.Visible = false
		btn.LayoutOrder = i
		btn.Parent = helpBar

		local btnCorner = Instance.new("UICorner")
		btnCorner.CornerRadius = UDim.new(0, 3)
		btnCorner.Parent = btn

		local btnPadding = Instance.new("UIPadding")
		btnPadding.PaddingLeft = UDim.new(0, 6)
		btnPadding.PaddingRight = UDim.new(0, 6)
		btnPadding.Parent = btn

		helpButtons[i] = btn
		helpConns[i] = nil
	end

	local function getContext(text)
		local chain = text:match("([%w_%.]+)%.([%w_]*)$")
		if chain then
			local parts = {}
			for part in chain:gmatch("[%w_]+") do
				table.insert(parts, part)
			end
			local attr = text:match("%.([%w_]*)$") or ""

			if #parts >= 2 then
				local base = parts[1]
				local prop = parts[2]
				local baseType = nil

				if base == "self" then
					baseType = currentSelfType
				elseif base:match("^B%d$") then
					baseType = "Bot"
				elseif base:match("^G%d+$") then
					baseType = "Gundam"
				end

				if baseType and prop == "hacker" then
					return "Player", attr:lower()
				end
			end

			local obj = parts[1]
			if obj == "self" then
				return "self", attr:lower()
			elseif obj:match("^B%d$") then
				return "Bot", attr:lower()
			elseif obj:match("^G%d+$") then
				return "Gundam", attr:lower()
			end
		end
		local lastWord = text:match("([%w_]+)$")
		if lastWord then
			return "global", lastWord:lower()
		end
		return nil, ""
	end

	local function filterMatches(items, prefix)
		local matches = {}
		for _, item in ipairs(items) do
			if prefix == "" or item.word:lower():sub(1, #prefix) == prefix then
				table.insert(matches, item)
				if #matches >= MAX_HELP_ITEMS then break end
			end
		end
		return matches
	end

	local function updateHelp()
		local text = textBox.Text
		local context, prefix = getContext(text)

		for i = 1, MAX_HELP_ITEMS do
			helpButtons[i].Visible = false
			if helpConns[i] then
				helpConns[i]:Disconnect()
				helpConns[i] = nil
			end
		end

		local matches = {}
		if context == "self" then
			local methods = HELP_DATA.methods[currentSelfType] or {}
			matches = filterMatches(methods, prefix)
		elseif context == "Bot" or context == "Gundam" or context == "Player" or context == "Enemy" then
			local methods = HELP_DATA.methods[context] or {}
			matches = filterMatches(methods, prefix)
		elseif context == "global" then
			for _, item in ipairs(HELP_DATA.keywords) do
				if item.word:lower():sub(1, #prefix) == prefix then
					table.insert(matches, item)
					if #matches >= MAX_HELP_ITEMS then break end
				end
			end
			if #matches < MAX_HELP_ITEMS then
				for _, item in ipairs(HELP_DATA.builtins) do
					if item.word:lower():sub(1, #prefix) == prefix then
						table.insert(matches, item)
						if #matches >= MAX_HELP_ITEMS then break end
					end
				end
			end
		end

		for i, match in ipairs(matches) do
			local btn = helpButtons[i]
			btn.Text = match.sig
			btn.Visible = true

			helpConns[i] = btn.MouseButton1Click:Connect(function()
				local currentText = textBox.Text
				local insertWord = match.word
				if context == "self" or context == "Bot" or context == "Gundam" or context == "Player" or context == "Enemy" then
					local newText = currentText:gsub("([%w_]+%.)([%w_]*)$", "%1" .. insertWord)
					textBox.Text = newText
				else
					local newText = currentText:gsub("([%w_]+)$", insertWord)
					textBox.Text = newText
				end
				textBox:CaptureFocus()
			end)
		end
	end

	textBox:GetPropertyChangedSignal("Text"):Connect(updateHelp)
	textBox.Focused:Connect(updateHelp)

	function panel:setSelfType(newType)
		currentSelfType = newType or "Player"
		updateHelp()
	end

	codeScroll:GetPropertyChangedSignal("CanvasPosition"):Connect(function()
		lineScroll.CanvasPosition = Vector2.new(0, codeScroll.CanvasPosition.Y)
	end)

	local function updateLines()
		local text = textBox.Text
		local lines = 1
		for _ in string.gmatch(text, "\n") do lines = lines + 1 end

		local numStr = ""
		for i = 1, lines do
			if i == currentErrorLine then
				numStr = numStr .. '<font color="#FF5050">● ' .. i .. '</font>\n'
			elseif i == currentExecLine then
				numStr = numStr .. '<font color="#6A9955">▶ ' .. i .. '</font>\n'
			else
				numStr = numStr .. i .. "\n"
			end
		end

		lineNumbers.Text = numStr

		local h = math.max(codeScroll.AbsoluteWindowSize.Y, lines * 13 + 50)
		codeScroll.CanvasSize = UDim2.new(0, 0, 0, h)
		lineScroll.CanvasSize = UDim2.new(0, 0, 0, h)
		textBox.Size = UDim2.new(1, -10, 0, h)
	end

	textBox:GetPropertyChangedSignal("Text"):Connect(updateLines)

	function panel:getText() return textBox.Text end
	function panel:setText(t) textBox.Text = t; updateLines() end
	function panel:getFrame() return frame end
	function panel:getTextBox() return textBox end

	function panel:setReadOnly(ro)
		isReadOnly = ro
		textBox.TextEditable = not ro
		textBox.TextColor3 = ro and COLORS.subtext or COLORS.text
	end

	function panel:setErrorLine(line)
		currentErrorLine = line or -1
		updateLines()
	end

	function panel:setExecLine(line)
		currentExecLine = line or -1
		updateLines()
	end

	local baseFontSizes = {
		[textBox] = 13,
		[lineNumbers] = 13,
	}
	for i = 1, MAX_HELP_ITEMS do
		baseFontSizes[helpButtons[i]] = 10
	end

	function panel:setFontScale(scale)
		for element, baseSize in pairs(baseFontSizes) do
			element.TextSize = math.floor(baseSize * scale)
		end
	end

	local function isWordChar(c)
		return c:match("[%w_]") ~= nil
	end

	local function findWordBoundary(text, pos, direction)
		if direction > 0 then
			while pos <= #text and not isWordChar(text:sub(pos, pos)) do
				pos = pos + 1
			end
			while pos <= #text and isWordChar(text:sub(pos, pos)) do
				pos = pos + 1
			end
		else
			pos = pos - 1
			while pos > 0 and not isWordChar(text:sub(pos, pos)) do
				pos = pos - 1
			end
			while pos > 0 and isWordChar(text:sub(pos, pos)) do
				pos = pos - 1
			end
			pos = pos + 1
		end
		return pos
	end

	local function getLineStartEnd(text, pos)
		local lineStart = 1
		for i = pos - 1, 1, -1 do
			if text:sub(i, i) == "\n" then
				lineStart = i + 1
				break
			end
		end
		local lineEnd = text:find("\n", pos) or (#text + 1)
		return lineStart, lineEnd
	end

	local function getCursorLineCol(text, pos)
		local line = 1
		local col = 1
		for i = 1, math.min(pos - 1, #text) do
			if text:sub(i, i) == "\n" then
				line = line + 1
				col = 1
			else
				col = col + 1
			end
		end
		return line, col
	end

	local function moveCursorVertical(delta)
		local text = textBox.Text
		local pos = textBox.CursorPosition
		if pos < 1 then pos = 1 end
		local line, col = getCursorLineCol(text, pos)
		local targetLine = line + delta
		if targetLine < 1 then return end

		local currentLine = 1
		local lineStart = 1
		for i = 1, #text do
			if currentLine == targetLine then
				local lineEnd = text:find("\n", i) or (#text + 1)
				local lineLen = lineEnd - lineStart
				local newCol = math.min(col, lineLen + 1)
				textBox.CursorPosition = lineStart + newCol - 1
				return
			end
			if text:sub(i, i) == "\n" then
				currentLine = currentLine + 1
				lineStart = i + 1
			end
		end

		if currentLine == targetLine then
			local lineLen = #text - lineStart + 1
			local newCol = math.min(col, lineLen + 1)
			textBox.CursorPosition = lineStart + newCol - 1
		end
	end

	UserInputService.InputBegan:Connect(function(input, gameProcessed)
		if not textBox:IsFocused() then return end
		if input.UserInputType ~= Enum.UserInputType.Keyboard then return end

		local ctrl = UserInputService:IsKeyDown(Enum.KeyCode.LeftControl) or UserInputService:IsKeyDown(Enum.KeyCode.RightControl)
		local alt = UserInputService:IsKeyDown(Enum.KeyCode.LeftAlt) or UserInputService:IsKeyDown(Enum.KeyCode.RightAlt)

		local text = textBox.Text
		local pos = textBox.CursorPosition
		if pos < 1 then pos = 1 end

		if ctrl and not alt then
			if input.KeyCode == Enum.KeyCode.G then
				textBox:ReleaseFocus()
			elseif input.KeyCode == Enum.KeyCode.E then
				local _, lineEnd = getLineStartEnd(text, pos)
				textBox.CursorPosition = lineEnd
			elseif input.KeyCode == Enum.KeyCode.F then
				if pos <= #text then
					textBox.CursorPosition = pos + 1
				end
			elseif input.KeyCode == Enum.KeyCode.B then
				if pos > 1 then
					textBox.CursorPosition = pos - 1
				end
			elseif input.KeyCode == Enum.KeyCode.P then
				moveCursorVertical(-1)
			elseif input.KeyCode == Enum.KeyCode.N then
				moveCursorVertical(1)
			elseif input.KeyCode == Enum.KeyCode.H then
				if pos > 1 and not isReadOnly then
					textBox.Text = text:sub(1, pos - 2) .. text:sub(pos)
					textBox.CursorPosition = pos - 1
				end
			elseif input.KeyCode == Enum.KeyCode.D then
				if pos <= #text and not isReadOnly then
					textBox.Text = text:sub(1, pos - 1) .. text:sub(pos + 1)
				end
			elseif input.KeyCode == Enum.KeyCode.K then
				if not isReadOnly then
					local _, lineEnd = getLineStartEnd(text, pos)
					if pos < lineEnd then
						textBox.Text = text:sub(1, pos - 1) .. text:sub(lineEnd)
					elseif pos <= #text then
						textBox.Text = text:sub(1, pos - 1) .. text:sub(pos + 1)
					end
				end
			end
		elseif alt and not ctrl then
			if input.KeyCode == Enum.KeyCode.F then
				textBox.CursorPosition = findWordBoundary(text, pos, 1)
			elseif input.KeyCode == Enum.KeyCode.B then
				textBox.CursorPosition = findWordBoundary(text, pos, -1)
			end
		end
	end)

	return panel
end

return EditorPanel
