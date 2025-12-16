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
		btn.BackgroundColor3 = COLORS.bg
		btn.BackgroundTransparency = 0.5
		btn.Text = ""
		btn.TextColor3 = COLORS.accent
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
		btnPadding.PaddingLeft = UDim.new(0, 4)
		btnPadding.PaddingRight = UDim.new(0, 4)
		btnPadding.Parent = btn

		helpButtons[i] = btn
		helpConns[i] = nil
	end

	local function getContext(text)
		local obj, attr = text:match("([%w_]+)%.([%w_]*)$")
		if obj then
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

	return panel
end

return EditorPanel
