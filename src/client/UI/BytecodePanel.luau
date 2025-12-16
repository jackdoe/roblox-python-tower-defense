local DragModule = require(script.Parent.DragModule)
local UITheme = require(script.Parent.UITheme)

local BytecodePanel = {}
local THEMES = UITheme.THEMES
local COLORS = UITheme.COLORS
local OP_COLORS = UITheme.OP_COLORS
local formatArg = UITheme.formatArg
local formatStackValue = UITheme.formatStackValue

function BytecodePanel.create(parent)
	local panel = {}
	local currentTheme = "player"
	local cachedBytecode = {}

	local frame = Instance.new("Frame")
	frame.Name = "BytecodePanel"
	frame.Size = UDim2.new(0, 280, 0, 250)
	frame.AnchorPoint = Vector2.new(0, 1)
	frame.Position = UDim2.new(1, -640, 1, -10)
	frame.BackgroundColor3 = THEMES.player.frameBg
	frame.BorderSizePixel = 0
	frame.ClipsDescendants = true
	frame.Parent = parent

	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 8)
	corner.Parent = frame

	local header = Instance.new("Frame")
	header.Name = "Header"
	header.Size = UDim2.new(1, 0, 0, 28)
	header.BackgroundColor3 = THEMES.player.headerBg
	header.BorderSizePixel = 0
	header.Parent = frame

	local headerCorner = Instance.new("UICorner")
	headerCorner.CornerRadius = UDim.new(0, 8)
	headerCorner.Parent = header

	DragModule.makeDraggable(frame, header)

	local title = Instance.new("TextLabel")
	title.Size = UDim2.new(0.6, 0, 1, 0)
	title.Position = UDim2.new(0, 10, 0, 0)
	title.BackgroundTransparency = 1
	title.Text = "BYTECODE"
	title.TextColor3 = COLORS.text
	title.TextXAlignment = Enum.TextXAlignment.Left
	title.Font = Enum.Font.Code
	title.TextSize = 12
	title.Parent = header

	local copyBtn = Instance.new("TextButton")
	copyBtn.Name = "CopyBtn"
	copyBtn.Size = UDim2.new(0, 45, 0, 18)
	copyBtn.Position = UDim2.new(1, -125, 0, 5)
	copyBtn.BackgroundColor3 = COLORS.panel
	copyBtn.Text = "COPY"
	copyBtn.TextColor3 = COLORS.text
	copyBtn.Font = Enum.Font.Code
	copyBtn.TextSize = 10
	copyBtn.Parent = header

	local copyBtnCorner = Instance.new("UICorner")
	copyBtnCorner.CornerRadius = UDim.new(0, 4)
	copyBtnCorner.Parent = copyBtn

	local ipLabel = Instance.new("TextLabel")
	ipLabel.Name = "IP"
	ipLabel.Size = UDim2.new(0, 70, 1, 0)
	ipLabel.Position = UDim2.new(1, -75, 0, 0)
	ipLabel.BackgroundTransparency = 1
	ipLabel.Text = "IP: 0"
	ipLabel.TextColor3 = COLORS.accent
	ipLabel.TextXAlignment = Enum.TextXAlignment.Right
	ipLabel.Font = Enum.Font.Code
	ipLabel.TextSize = 12
	ipLabel.Parent = header

	-- Store bytecode text for copying
	local currentBytecodeText = ""

	-- ===== BYTECODE SECTION =====
	-- Layout constants
	local BC_HEADER_Y = 34
	local BC_SCROLL_Y = BC_HEADER_Y + 18  -- 52
	local LINE_HEIGHT = 12  -- Actual text line height
	local MIN_BC_HEIGHT = 60
	local MAX_BC_HEIGHT = 350
	local STACK_GAP = 6
	local STACK_HEADER_HEIGHT = 16
	local STACK_FRAME_HEIGHT = 70
	local BOTTOM_PADDING = 8

	local bcHeader = Instance.new("TextLabel")
	bcHeader.Size = UDim2.new(1, -20, 0, 16)
	bcHeader.Position = UDim2.new(0, 10, 0, BC_HEADER_Y)
	bcHeader.BackgroundTransparency = 1
	bcHeader.Text = "INSTRUCTIONS"
	bcHeader.TextColor3 = COLORS.subtext
	bcHeader.TextXAlignment = Enum.TextXAlignment.Left
	bcHeader.Font = Enum.Font.Code
	bcHeader.TextSize = 10
	bcHeader.Parent = frame

	local bcScroll = Instance.new("ScrollingFrame")
	bcScroll.Name = "BytecodeScroll"
	bcScroll.Size = UDim2.new(1, -20, 0, MIN_BC_HEIGHT)
	bcScroll.Position = UDim2.new(0, 10, 0, BC_SCROLL_Y)
	bcScroll.BackgroundColor3 = THEMES.player.codeBg
	bcScroll.BorderSizePixel = 0
	bcScroll.ScrollBarThickness = 4
	bcScroll.ScrollBarImageColor3 = COLORS.subtext
	bcScroll.CanvasSize = UDim2.new(0, 0, 0, 0)
	bcScroll.Parent = frame

	local bcCorner = Instance.new("UICorner")
	bcCorner.CornerRadius = UDim.new(0, 6)
	bcCorner.Parent = bcScroll

	local bcLabel = Instance.new("TextLabel")
	bcLabel.Name = "Bytecode"
	bcLabel.Size = UDim2.new(1, -8, 0, 0)
	bcLabel.Position = UDim2.new(0, 4, 0, 4)
	bcLabel.BackgroundTransparency = 1
	bcLabel.Text = ""
	bcLabel.RichText = true
	bcLabel.TextColor3 = COLORS.text
	bcLabel.TextXAlignment = Enum.TextXAlignment.Left
	bcLabel.TextYAlignment = Enum.TextYAlignment.Top
	bcLabel.Font = Enum.Font.Code
	bcLabel.TextSize = 11
	bcLabel.TextWrapped = false
	bcLabel.AutomaticSize = Enum.AutomaticSize.Y
	bcLabel.Parent = bcScroll

	-- ===== STACK SECTION =====
	-- Position will be updated dynamically based on bytecode height

	local stackHeader = Instance.new("TextLabel")
	stackHeader.Size = UDim2.new(1, -20, 0, STACK_HEADER_HEIGHT)
	stackHeader.Position = UDim2.new(0, 10, 0, 0)
	stackHeader.BackgroundTransparency = 1
	stackHeader.Text = "STACK"
	stackHeader.TextColor3 = COLORS.subtext
	stackHeader.TextXAlignment = Enum.TextXAlignment.Left
	stackHeader.Font = Enum.Font.Code
	stackHeader.TextSize = 10
	stackHeader.Parent = frame

	local stackFrame = Instance.new("Frame")
	stackFrame.Name = "StackFrame"
	stackFrame.Size = UDim2.new(1, -20, 0, STACK_FRAME_HEIGHT)
	stackFrame.Position = UDim2.new(0, 10, 0, 0)
	stackFrame.BackgroundColor3 = THEMES.player.codeBg
	stackFrame.BorderSizePixel = 0
	stackFrame.ClipsDescendants = true
	stackFrame.Parent = frame

	local stackCorner = Instance.new("UICorner")
	stackCorner.CornerRadius = UDim.new(0, 6)
	stackCorner.Parent = stackFrame

	local stackLabel = Instance.new("TextLabel")
	stackLabel.Name = "Stack"
	stackLabel.Size = UDim2.new(1, -8, 1, -8)
	stackLabel.Position = UDim2.new(0, 4, 0, 4)
	stackLabel.BackgroundTransparency = 1
	stackLabel.Text = "(empty)"
	stackLabel.RichText = true
	stackLabel.TextColor3 = COLORS.subtext
	stackLabel.TextXAlignment = Enum.TextXAlignment.Left
	stackLabel.TextYAlignment = Enum.TextYAlignment.Top
	stackLabel.Font = Enum.Font.Code
	stackLabel.TextSize = 11
	stackLabel.TextWrapped = true
	stackLabel.Parent = stackFrame

	panel.frame = frame

	function panel:setTheme(themeName)
		currentTheme = themeName or "player"
		local theme = THEMES[currentTheme] or THEMES.player
		frame.BackgroundColor3 = theme.frameBg
		header.BackgroundColor3 = theme.headerBg
		bcScroll.BackgroundColor3 = theme.codeBg
		stackFrame.BackgroundColor3 = theme.codeBg
	end

	-- Store current IP for copy button
	local currentIP = 0

	-- Copy button handler
	copyBtn.MouseButton1Click:Connect(function()
		if currentBytecodeText ~= "" then
			-- Use setclipboard if available (Roblox Studio)
			if setclipboard then
				setclipboard("IP: " .. currentIP .. "\n" .. currentBytecodeText)
				copyBtn.Text = "DONE!"
				copyBtn.BackgroundColor3 = COLORS.success
			else
				-- Fallback: print to output
				print("=== BYTECODE (IP: " .. currentIP .. ") ===")
				print(currentBytecodeText)
				print("================")
				copyBtn.Text = "LOG"
				copyBtn.BackgroundColor3 = COLORS.warning
			end
			task.delay(1, function()
				copyBtn.Text = "COPY"
				copyBtn.BackgroundColor3 = COLORS.panel
			end)
		end
	end)

	function panel:update(state)
		if state.bytecode then
			cachedBytecode = state.bytecode
		end
		local bytecode = cachedBytecode
		local vm = state.vm or {}
		local ip = vm.ip or (state.currentLine and 0) or 0
		local stack = vm.stack or {}

		-- Store IP for copy button
		currentIP = ip

		-- Update IP display
		ipLabel.Text = "IP: " .. ip

		-- Build bytecode display
		if #bytecode > 0 then
			local lines = {}
			local plainLines = {}  -- For copy
			for i, instr in ipairs(bytecode) do
				local addr = string.format("%3d", i)
				local op = instr.op or "?"
				local arg = formatArg(instr.arg)
				local srcLine = instr.line or 0

				-- Plain text for copying
				local plainLine = addr .. " " .. op
				if arg ~= "" then
					plainLine = plainLine .. " " .. arg
				end
				if srcLine > 0 then
					plainLine = plainLine .. " L" .. srcLine
				end
				table.insert(plainLines, plainLine)

				-- Get opcode color
				local opColor = OP_COLORS[op] or "#D4D4D4"

				-- Format the line (rich text)
				-- Current instruction: cyan line number, same layout (no arrow to avoid text jumping)
				local line
				if i == ip then
					line = '<font color="#00FFFF"><b>' .. addr .. '</b></font> <font color="' .. opColor .. '"><b>' .. op .. '</b></font>'
					if arg ~= "" then
						line = line .. ' <font color="#FFFFFF"><b>' .. arg .. '</b></font>'
					end
				else
					line = '<font color="#505060">' .. addr .. '</font> <font color="' .. opColor .. '">' .. op .. '</font>'
					if arg ~= "" then
						line = line .. ' <font color="#9CDCFE">' .. arg .. '</font>'
					end
				end

				-- Add source line reference (dim)
				if srcLine > 0 then
					line = line .. ' <font color="#404040">L' .. srcLine .. '</font>'
				end

				table.insert(lines, line)
			end

			bcLabel.Text = table.concat(lines, "\n")
			currentBytecodeText = table.concat(plainLines, "\n")

			-- Auto-resize to fit bytecode (no scrolling needed for most programs)
			local contentHeight = #bytecode * LINE_HEIGHT + 8
			local bcHeight = math.max(MIN_BC_HEIGHT, math.min(contentHeight, MAX_BC_HEIGHT))

			-- Update bytecode area size
			bcScroll.Size = UDim2.new(1, -20, 0, bcHeight)
			bcScroll.CanvasSize = UDim2.new(0, 0, 0, contentHeight)

			-- Reposition stack section below bytecode
			local stackY = BC_SCROLL_Y + bcHeight + STACK_GAP
			stackHeader.Position = UDim2.new(0, 10, 0, stackY)
			stackFrame.Position = UDim2.new(0, 10, 0, stackY + STACK_HEADER_HEIGHT + 2)

			-- Resize frame to fit everything
			local totalHeight = stackY + STACK_HEADER_HEIGHT + 2 + STACK_FRAME_HEIGHT + BOTTOM_PADDING
			frame.Size = UDim2.new(0, 280, 0, totalHeight)
		else
			bcLabel.Text = '<font color="#606080">No bytecode loaded</font>'
			bcScroll.Size = UDim2.new(1, -20, 0, MIN_BC_HEIGHT)
			bcScroll.CanvasSize = UDim2.new(0, 0, 0, 0)

			-- Reset to minimum layout
			local stackY = BC_SCROLL_Y + MIN_BC_HEIGHT + STACK_GAP
			stackHeader.Position = UDim2.new(0, 10, 0, stackY)
			stackFrame.Position = UDim2.new(0, 10, 0, stackY + STACK_HEADER_HEIGHT + 2)
			local totalHeight = stackY + STACK_HEADER_HEIGHT + 2 + STACK_FRAME_HEIGHT + BOTTOM_PADDING
			frame.Size = UDim2.new(0, 280, 0, totalHeight)
		end

		-- Build stack display
		if #stack > 0 then
			local stackParts = {}

			-- Show stack from bottom to top (reversed)
			for i = #stack, 1, -1 do
				local val = formatStackValue(stack[i])
				local marker = ""
				if i == #stack then
					marker = '<font color="#00FFFF"> &lt;- TOP</font>'
				end
				table.insert(stackParts, '<font color="#B5CEA8">[' .. (i-1) .. ']</font> ' .. val .. marker)
			end

			stackLabel.Text = table.concat(stackParts, "\n")
		else
			stackLabel.Text = '<font color="#606080">(empty)</font>'
		end
	end

	function panel:setVisible(visible)
		frame.Visible = visible
	end

	function panel:clearCache()
		cachedBytecode = {}
	end

	return panel
end

return BytecodePanel
