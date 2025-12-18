local TweenService = game:GetService("TweenService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UITheme = require(script.Parent.UITheme)
local EditorPanel = require(script.Parent.EditorPanel)

local PythonTD = ReplicatedStorage:WaitForChild("PythonTD")
local Python = require(PythonTD.Python)
local Config = require(PythonTD.Config)

local MainIDE = {}
local COLORS = UITheme.COLORS
local formatValue = UITheme.formatValue

local OP_COLORS = {
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

local BYTECODE_WIDTH = 240
local STACK_WIDTH = 80
local VARS_WIDTH = 160
local OUTPUT_WIDTH = 160
local IDE_HEIGHT_SCALE = 0.36
local HEADER_HEIGHT = 28
local TOOLBAR_HEIGHT = 24
local ERROR_HEIGHT = 36
local BASE_TEXT_SIZE = 14

function MainIDE.create(parent, callbacks)
	callbacks = callbacks or {}
	local interpreters = {}
	local currentTabId = nil
	local tabs = {}

	local container = Instance.new("Frame")
	container.Name = "IDE_Main"
	container.Size = UDim2.new(1, 0, IDE_HEIGHT_SCALE, 0)
	container.Position = UDim2.new(0, 0, 1 - IDE_HEIGHT_SCALE, 0)
	container.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
	container.BorderSizePixel = 0
	container.ClipsDescendants = false
	container.Parent = parent

	local topBar = Instance.new("Frame")
	topBar.Size = UDim2.new(1, 0, 0, 28)
	topBar.Position = UDim2.new(0, 0, 0, -28)
	topBar.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
	topBar.BackgroundTransparency = 0
	topBar.BorderSizePixel = 0
	topBar.Parent = container
	Instance.new("UICorner", topBar).CornerRadius = UDim.new(0, 6)

	local topBarLayout = Instance.new("UIListLayout")
	topBarLayout.FillDirection = Enum.FillDirection.Horizontal
	topBarLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center
	topBarLayout.VerticalAlignment = Enum.VerticalAlignment.Center
	topBarLayout.Padding = UDim.new(0, 8)
	topBarLayout.Parent = topBar

	local botBuildBtn = Instance.new("TextButton")
	botBuildBtn.Name = "BotBuildBtn"
	botBuildBtn.Size = UDim2.new(0, 0, 0, 20)
	botBuildBtn.AutomaticSize = Enum.AutomaticSize.X
	botBuildBtn.BackgroundColor3 = Color3.fromHex("#333333")
	botBuildBtn.Text = "+ROBOT (B): 75S"
	botBuildBtn.TextColor3 = Color3.fromRGB(215, 135, 70)
	botBuildBtn.Font = Enum.Font.RobotoMono
	botBuildBtn.TextSize = BASE_TEXT_SIZE
	botBuildBtn.Parent = topBar
	Instance.new("UICorner", botBuildBtn).CornerRadius = UDim.new(0, 4)
	local botBtnPad = Instance.new("UIPadding")
	botBtnPad.PaddingLeft = UDim.new(0, 8)
	botBtnPad.PaddingRight = UDim.new(0, 8)
	botBtnPad.Parent = botBuildBtn

	local gundamBuildBtn = Instance.new("TextButton")
	gundamBuildBtn.Name = "GundamBuildBtn"
	gundamBuildBtn.Size = UDim2.new(0, 0, 0, 20)
	gundamBuildBtn.AutomaticSize = Enum.AutomaticSize.X
	gundamBuildBtn.BackgroundColor3 = Color3.fromHex("#333333")
	gundamBuildBtn.Text = "+GUNDAM (G): 100S"
	gundamBuildBtn.TextColor3 = Color3.fromRGB(0, 255, 255)
	gundamBuildBtn.Font = Enum.Font.RobotoMono
	gundamBuildBtn.TextSize = BASE_TEXT_SIZE
	gundamBuildBtn.Parent = topBar
	Instance.new("UICorner", gundamBuildBtn).CornerRadius = UDim.new(0, 4)
	local gundamBtnPad = Instance.new("UIPadding")
	gundamBtnPad.PaddingLeft = UDim.new(0, 8)
	gundamBtnPad.PaddingRight = UDim.new(0, 8)
	gundamBtnPad.Parent = gundamBuildBtn

	local helpBtn = Instance.new("TextButton")
	helpBtn.Name = "HelpBtn"
	helpBtn.Size = UDim2.new(0, 0, 0, 20)
	helpBtn.AutomaticSize = Enum.AutomaticSize.X
	helpBtn.BackgroundColor3 = Color3.fromRGB(255, 191, 0)
	helpBtn.Text = "HELP"
	helpBtn.TextColor3 = Color3.fromRGB(12, 12, 8)
	helpBtn.Font = Enum.Font.RobotoMono
	helpBtn.TextSize = BASE_TEXT_SIZE
	helpBtn.Parent = topBar
	Instance.new("UICorner", helpBtn).CornerRadius = UDim.new(0, 4)
	local helpBtnPad = Instance.new("UIPadding")
	helpBtnPad.PaddingLeft = UDim.new(0, 8)
	helpBtnPad.PaddingRight = UDim.new(0, 8)
	helpBtnPad.Parent = helpBtn

	local hideBtn = Instance.new("TextButton")
	hideBtn.Name = "HideBtn"
	hideBtn.Size = UDim2.new(0, 0, 0, 20)
	hideBtn.AutomaticSize = Enum.AutomaticSize.X
	hideBtn.BackgroundColor3 = Color3.fromHex("#333333")
	hideBtn.Text = "HIDE"
	hideBtn.TextColor3 = COLORS.subtext
	hideBtn.Font = Enum.Font.RobotoMono
	hideBtn.TextSize = BASE_TEXT_SIZE
	hideBtn.Parent = topBar
	Instance.new("UICorner", hideBtn).CornerRadius = UDim.new(0, 4)
	local hideBtnPad = Instance.new("UIPadding")
	hideBtnPad.PaddingLeft = UDim.new(0, 8)
	hideBtnPad.PaddingRight = UDim.new(0, 8)
	hideBtnPad.Parent = hideBtn

	local fontScale = 1.2
	local BASE_FONT_SIZES = {}
	local textElements = {}
	local editorRef = nil

	local function registerText(element, baseSize)
		table.insert(textElements, element)
		BASE_FONT_SIZES[element] = baseSize or element.TextSize
	end

	local function applyFontScale()
		for _, el in ipairs(textElements) do
			local base = BASE_FONT_SIZES[el] or 10
			el.TextSize = math.floor(base * fontScale)
		end
		if editorRef and editorRef.setFontScale then
			editorRef:setFontScale(fontScale)
		end
		for pid, tab in pairs(tabs) do
			if tab.button then
				local name = tab.button.Text:gsub("^ ", "")
				local isPlayer = interpreters[pid] and interpreters[pid].type == "player"
				local textWidth = #name * 7 + 20
				if not isPlayer then textWidth = textWidth + 16 end
				tab.button.Size = UDim2.new(0, textWidth * fontScale, 1, 0)
				local close = tab.button:FindFirstChild("CloseBtn")
				if close then
					close.Size = UDim2.new(0, 16 * fontScale, 0, 16 * fontScale)
				end
			end
		end
		if topBarButtons then
			for _, btn in ipairs(topBarButtons) do
				btn.Size = UDim2.new(0, 0, 0, math.floor(BASE_TOPBAR_HEIGHT * fontScale))
			end
		end
		if callbacks.onFontScaleChanged then
			callbacks.onFontScaleChanged(fontScale)
		end
	end

	local function scaledSize(baseSize)
		return math.floor(baseSize * fontScale)
	end

	local fontDownBtn = Instance.new("TextButton")
	fontDownBtn.Name = "FontDownBtn"
	fontDownBtn.Size = UDim2.new(0, 0, 0, 20)
	fontDownBtn.AutomaticSize = Enum.AutomaticSize.X
	fontDownBtn.BackgroundColor3 = Color3.fromHex("#333333")
	fontDownBtn.Text = "A-"
	fontDownBtn.TextColor3 = COLORS.text
	fontDownBtn.Font = Enum.Font.RobotoMono
	fontDownBtn.TextSize = BASE_TEXT_SIZE
	fontDownBtn.Parent = topBar
	Instance.new("UICorner", fontDownBtn).CornerRadius = UDim.new(0, 4)
	local fontDownPad = Instance.new("UIPadding")
	fontDownPad.PaddingLeft = UDim.new(0, 6)
	fontDownPad.PaddingRight = UDim.new(0, 6)
	fontDownPad.Parent = fontDownBtn

	local fontUpBtn = Instance.new("TextButton")
	fontUpBtn.Name = "FontUpBtn"
	fontUpBtn.Size = UDim2.new(0, 0, 0, 20)
	fontUpBtn.AutomaticSize = Enum.AutomaticSize.X
	fontUpBtn.BackgroundColor3 = Color3.fromHex("#333333")
	fontUpBtn.Text = "A+"
	fontUpBtn.TextColor3 = COLORS.text
	fontUpBtn.Font = Enum.Font.RobotoMono
	fontUpBtn.TextSize = BASE_TEXT_SIZE
	fontUpBtn.Parent = topBar
	Instance.new("UICorner", fontUpBtn).CornerRadius = UDim.new(0, 4)
	local fontUpPad = Instance.new("UIPadding")
	fontUpPad.PaddingLeft = UDim.new(0, 6)
	fontUpPad.PaddingRight = UDim.new(0, 6)
	fontUpPad.Parent = fontUpBtn

	local topBarButtons = { botBuildBtn, gundamBuildBtn, helpBtn, hideBtn, fontDownBtn, fontUpBtn }
	local BASE_TOPBAR_HEIGHT = 20

	fontDownBtn.MouseButton1Click:Connect(function()
		fontScale = math.max(0.6, fontScale - 0.1)
		applyFontScale()
	end)

	fontUpBtn.MouseButton1Click:Connect(function()
		fontScale = math.min(2.0, fontScale + 0.1)
		applyFontScale()
	end)

	local headerBar = Instance.new("Frame")
	headerBar.Name = "HeaderBar"
	headerBar.Size = UDim2.new(1, 0, 0, HEADER_HEIGHT)
	headerBar.Position = UDim2.new(0, 0, 0, 0)
	headerBar.BackgroundColor3 = Color3.fromRGB(20, 20, 20)
	headerBar.BorderSizePixel = 0
	headerBar.Parent = container

	local tabsScroll = Instance.new("ScrollingFrame")
	tabsScroll.Size = UDim2.new(1, 0, 1, 0)
	tabsScroll.BackgroundTransparency = 1
	tabsScroll.BorderSizePixel = 0
	tabsScroll.ScrollBarThickness = 0
	tabsScroll.CanvasSize = UDim2.new(0, 0, 0, 0)
	tabsScroll.AutomaticCanvasSize = Enum.AutomaticSize.X
	tabsScroll.ScrollingDirection = Enum.ScrollingDirection.X
	tabsScroll.ClipsDescendants = false
	tabsScroll.Parent = headerBar

	local tabsLayout = Instance.new("UIListLayout")
	tabsLayout.FillDirection = Enum.FillDirection.Horizontal
	tabsLayout.SortOrder = Enum.SortOrder.LayoutOrder
	tabsLayout.Parent = tabsScroll

	local contentArea = Instance.new("Frame")
	contentArea.Name = "ContentArea"
	contentArea.Size = UDim2.new(1, 0, 1, -HEADER_HEIGHT)
	contentArea.Position = UDim2.new(0, 0, 0, HEADER_HEIGHT)
	contentArea.BackgroundTransparency = 1
	contentArea.Parent = container

	local colBytecode = Instance.new("Frame")
	colBytecode.Name = "Col_Bytecode"
	colBytecode.Size = UDim2.new(0, BYTECODE_WIDTH, 1, 0)
	colBytecode.Position = UDim2.new(0, 0, 0, 0)
	colBytecode.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
	colBytecode.BorderSizePixel = 0
	colBytecode.Parent = contentArea

	local bcHeader = Instance.new("Frame")
	bcHeader.Size = UDim2.new(1, 0, 0, 28)
	bcHeader.BackgroundTransparency = 1
	bcHeader.Parent = colBytecode

	local computerLabel = Instance.new("TextLabel")
	computerLabel.Size = UDim2.new(1, -4, 0, 12)
	computerLabel.Position = UDim2.new(0, 2, 0, 1)
	computerLabel.BackgroundTransparency = 1
	computerLabel.Text = "[BYTECODE]"
	computerLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
	computerLabel.Font = Enum.Font.RobotoMono
	computerLabel.TextSize = BASE_TEXT_SIZE
	computerLabel.TextXAlignment = Enum.TextXAlignment.Left
	computerLabel.Parent = bcHeader

	local statsLabel = Instance.new("TextLabel")
	statsLabel.Name = "StatsLabel"
	statsLabel.Size = UDim2.new(1, -4, 0, 12)
	statsLabel.Position = UDim2.new(0, 2, 0, 14)
	statsLabel.BackgroundTransparency = 1
	statsLabel.RichText = true
	statsLabel.Text = '<font color="#4EC9B0">CPU:1hz</font> <font color="#DCDCAA">RAM:0/32</font>'
	statsLabel.Font = Enum.Font.RobotoMono
	statsLabel.TextSize = BASE_TEXT_SIZE
	statsLabel.TextXAlignment = Enum.TextXAlignment.Left
	statsLabel.Parent = bcHeader

	local bcList = Instance.new("ScrollingFrame")
	bcList.Size = UDim2.new(1, 0, 1, -28)
	bcList.Position = UDim2.new(0, 0, 0, 28)
	bcList.BackgroundTransparency = 1
	bcList.BorderSizePixel = 0
	bcList.CanvasSize = UDim2.new(0, 0, 0, 0)
	bcList.AutomaticCanvasSize = Enum.AutomaticSize.Y
	bcList.ScrollBarThickness = 2
	bcList.Parent = colBytecode

	local bcLayout = Instance.new("UIListLayout")
	bcLayout.Parent = bcList

	local colStack = Instance.new("Frame")
	colStack.Name = "Col_Stack"
	colStack.Size = UDim2.new(0, STACK_WIDTH, 1, 0)
	colStack.Position = UDim2.new(0, BYTECODE_WIDTH + 2, 0, 0)
	colStack.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
	colStack.BorderSizePixel = 0
	colStack.Parent = contentArea

	local stackHeader = Instance.new("TextLabel")
	stackHeader.Size = UDim2.new(1, -4, 0, 16)
	stackHeader.Position = UDim2.new(0, 2, 0, 0)
	stackHeader.BackgroundTransparency = 1
	stackHeader.Text = "[STACK]"
	stackHeader.TextColor3 = Color3.fromRGB(255, 255, 255)
	stackHeader.Font = Enum.Font.RobotoMono
	stackHeader.TextSize = BASE_TEXT_SIZE
	stackHeader.TextXAlignment = Enum.TextXAlignment.Left
	stackHeader.Parent = colStack

	local stackList = Instance.new("ScrollingFrame")
	stackList.Size = UDim2.new(1, 0, 1, -16)
	stackList.Position = UDim2.new(0, 0, 0, 16)
	stackList.BackgroundTransparency = 1
	stackList.BorderSizePixel = 0
	stackList.CanvasSize = UDim2.new(0, 0, 0, 0)
	stackList.AutomaticCanvasSize = Enum.AutomaticSize.Y
	stackList.ScrollBarThickness = 2
	stackList.Parent = colStack

	local stackLayout = Instance.new("UIListLayout")
	stackLayout.Parent = stackList

	local colOutput = Instance.new("Frame")
	colOutput.Name = "Col_Output"
	colOutput.Size = UDim2.new(0, OUTPUT_WIDTH, 1, 0)
	colOutput.AnchorPoint = Vector2.new(1, 0)
	colOutput.Position = UDim2.new(1, 0, 0, 0)
	colOutput.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
	colOutput.BorderSizePixel = 0
	colOutput.Parent = contentArea

	local outHeader = Instance.new("TextLabel")
	outHeader.Size = UDim2.new(1, -4, 0, 16)
	outHeader.Position = UDim2.new(0, 2, 0, 0)
	outHeader.BackgroundTransparency = 1
	outHeader.Text = "[OUTPUT]"
	outHeader.TextColor3 = Color3.fromRGB(255, 255, 255)
	outHeader.Font = Enum.Font.RobotoMono
	outHeader.TextSize = BASE_TEXT_SIZE
	outHeader.TextXAlignment = Enum.TextXAlignment.Left
	outHeader.Parent = colOutput

	local outList = Instance.new("ScrollingFrame")
	outList.Size = UDim2.new(1, 0, 1, -16)
	outList.Position = UDim2.new(0, 0, 0, 16)
	outList.BackgroundTransparency = 1
	outList.BorderSizePixel = 0
	outList.CanvasSize = UDim2.new(0, 0, 0, 0)
	outList.AutomaticCanvasSize = Enum.AutomaticSize.Y
	outList.ScrollBarThickness = 2
	outList.Parent = colOutput

	local outLayout = Instance.new("UIListLayout")
	outLayout.Parent = outList

	local colVars = Instance.new("Frame")
	colVars.Name = "Col_Vars"
	colVars.Size = UDim2.new(0, VARS_WIDTH, 1, 0)
	colVars.AnchorPoint = Vector2.new(1, 0)
	colVars.Position = UDim2.new(1, -OUTPUT_WIDTH - 2, 0, 0)
	colVars.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
	colVars.BorderSizePixel = 0
	colVars.Parent = contentArea

	local varHeader = Instance.new("TextLabel")
	varHeader.Size = UDim2.new(1, -4, 0, 16)
	varHeader.Position = UDim2.new(0, 2, 0, 0)
	varHeader.BackgroundTransparency = 1
	varHeader.Text = "[VARIABLES]"
	varHeader.TextColor3 = Color3.fromRGB(255, 255, 255)
	varHeader.Font = Enum.Font.RobotoMono
	varHeader.TextSize = BASE_TEXT_SIZE
	varHeader.TextXAlignment = Enum.TextXAlignment.Left
	varHeader.Parent = colVars

	local varList = Instance.new("ScrollingFrame")
	varList.Size = UDim2.new(1, 0, 1, -16)
	varList.Position = UDim2.new(0, 0, 0, 16)
	varList.BackgroundTransparency = 1
	varList.BorderSizePixel = 0
	varList.CanvasSize = UDim2.new(0, 0, 0, 0)
	varList.AutomaticCanvasSize = Enum.AutomaticSize.Y
	varList.ScrollBarThickness = 2
	varList.Parent = colVars

	local varLayout = Instance.new("UIListLayout")
	varLayout.Padding = UDim.new(0, 1)
	varLayout.Parent = varList

	local colEditor = Instance.new("Frame")
	colEditor.Name = "Col_Editor"
	colEditor.Size = UDim2.new(1, -(BYTECODE_WIDTH + STACK_WIDTH + VARS_WIDTH + OUTPUT_WIDTH + 8), 1, 0)
	colEditor.Position = UDim2.new(0, BYTECODE_WIDTH + STACK_WIDTH + 4, 0, 0)
	colEditor.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
	colEditor.BorderSizePixel = 0
	colEditor.Parent = contentArea

	local toolbar = Instance.new("Frame")
	toolbar.Name = "Toolbar"
	toolbar.Size = UDim2.new(1, 0, 0, TOOLBAR_HEIGHT)
	toolbar.Position = UDim2.new(0, 0, 0, 0)
	toolbar.BackgroundColor3 = Color3.fromRGB(20, 20, 20)
	toolbar.BorderSizePixel = 0
	toolbar.Parent = colEditor

	local leftBtns = Instance.new("Frame")
	leftBtns.Name = "LeftButtons"
	leftBtns.Size = UDim2.new(0, 0, 0, 18)
	leftBtns.AutomaticSize = Enum.AutomaticSize.X
	leftBtns.Position = UDim2.new(0, 4, 0.5, 0)
	leftBtns.AnchorPoint = Vector2.new(0, 0.5)
	leftBtns.BackgroundTransparency = 1
	leftBtns.Parent = toolbar

	local leftLayout = Instance.new("UIListLayout")
	leftLayout.FillDirection = Enum.FillDirection.Horizontal
	leftLayout.VerticalAlignment = Enum.VerticalAlignment.Center
	leftLayout.SortOrder = Enum.SortOrder.LayoutOrder
	leftLayout.Padding = UDim.new(0, 6)
	leftLayout.Parent = leftBtns

	local runBtn = Instance.new("TextButton")
	runBtn.Name = "RunBtn"
	runBtn.Size = UDim2.new(0, 0, 0, 18)
	runBtn.AutomaticSize = Enum.AutomaticSize.X
	runBtn.BackgroundColor3 = COLORS.success
	runBtn.Text = "./script.py ^1"
	runBtn.TextColor3 = COLORS.bg
	runBtn.Font = Enum.Font.RobotoMono
	runBtn.TextSize = BASE_TEXT_SIZE
	runBtn.LayoutOrder = 1
	runBtn.Parent = leftBtns
	Instance.new("UICorner", runBtn).CornerRadius = UDim.new(0, 4)
	local runBtnPad = Instance.new("UIPadding")
	runBtnPad.PaddingLeft = UDim.new(0, 6)
	runBtnPad.PaddingRight = UDim.new(0, 6)
	runBtnPad.Parent = runBtn

	local gdbBtn = Instance.new("TextButton")
	gdbBtn.Name = "GdbBtn"
	gdbBtn.Size = UDim2.new(0, 0, 0, 18)
	gdbBtn.AutomaticSize = Enum.AutomaticSize.X
	gdbBtn.BackgroundColor3 = COLORS.warning
	gdbBtn.Text = "GDB"
	gdbBtn.TextColor3 = COLORS.bg
	gdbBtn.Font = Enum.Font.RobotoMono
	gdbBtn.TextSize = BASE_TEXT_SIZE
	gdbBtn.LayoutOrder = 2
	gdbBtn.Parent = leftBtns
	Instance.new("UICorner", gdbBtn).CornerRadius = UDim.new(0, 4)
	local gdbBtnPad = Instance.new("UIPadding")
	gdbBtnPad.PaddingLeft = UDim.new(0, 6)
	gdbBtnPad.PaddingRight = UDim.new(0, 6)
	gdbBtnPad.Parent = gdbBtn

	local dbgBtn = Instance.new("TextButton")
	dbgBtn.Name = "DbgBtn"
	dbgBtn.Size = UDim2.new(0, 40, 0, 18)
	dbgBtn.BackgroundColor3 = COLORS.danger
	dbgBtn.Text = "DBG"
	dbgBtn.TextColor3 = COLORS.text
	dbgBtn.Font = Enum.Font.RobotoMono
	dbgBtn.TextSize = BASE_TEXT_SIZE
	dbgBtn.Visible = false
	dbgBtn.LayoutOrder = 3
	dbgBtn.Parent = leftBtns
	Instance.new("UICorner", dbgBtn).CornerRadius = UDim.new(0, 4)

	local defaultBtn = Instance.new("TextButton")
	defaultBtn.Name = "DefaultBtn"
	defaultBtn.Size = UDim2.new(0, 0, 0, 18)
	defaultBtn.AutomaticSize = Enum.AutomaticSize.X
	defaultBtn.BackgroundColor3 = Color3.fromHex("#333333")
	defaultBtn.Text = "DEFAULT"
	defaultBtn.TextColor3 = Color3.fromRGB(150, 150, 200)
	defaultBtn.Font = Enum.Font.RobotoMono
	defaultBtn.TextSize = BASE_TEXT_SIZE
	defaultBtn.LayoutOrder = 4
	defaultBtn.Parent = leftBtns
	Instance.new("UICorner", defaultBtn).CornerRadius = UDim.new(0, 4)
	local defaultBtnPad = Instance.new("UIPadding")
	defaultBtnPad.PaddingLeft = UDim.new(0, 6)
	defaultBtnPad.PaddingRight = UDim.new(0, 6)
	defaultBtnPad.Parent = defaultBtn

	local rightBtns = Instance.new("Frame")
	rightBtns.Name = "RightButtons"
	rightBtns.Size = UDim2.new(0, 0, 0, 18)
	rightBtns.AutomaticSize = Enum.AutomaticSize.X
	rightBtns.Position = UDim2.new(1, -4, 0.5, 0)
	rightBtns.AnchorPoint = Vector2.new(1, 0.5)
	rightBtns.BackgroundTransparency = 1
	rightBtns.Parent = toolbar

	local rightLayout = Instance.new("UIListLayout")
	rightLayout.FillDirection = Enum.FillDirection.Horizontal
	rightLayout.VerticalAlignment = Enum.VerticalAlignment.Center
	rightLayout.SortOrder = Enum.SortOrder.LayoutOrder
	rightLayout.Padding = UDim.new(0, 6)
	rightLayout.Parent = rightBtns

	local powerBtn = Instance.new("TextButton")
	powerBtn.Name = "PowerBtn"
	powerBtn.Size = UDim2.new(0, 0, 0, 18)
	powerBtn.AutomaticSize = Enum.AutomaticSize.X
	powerBtn.BackgroundColor3 = Color3.fromHex("#333333")
	powerBtn.Text = "+PWR x2:100S"
	powerBtn.TextColor3 = Color3.fromRGB(255, 100, 100)
	powerBtn.Font = Enum.Font.RobotoMono
	powerBtn.TextSize = BASE_TEXT_SIZE
	powerBtn.LayoutOrder = 1
	powerBtn.Parent = rightBtns
	Instance.new("UICorner", powerBtn).CornerRadius = UDim.new(0, 4)
	local pwrBtnPad = Instance.new("UIPadding")
	pwrBtnPad.PaddingLeft = UDim.new(0, 6)
	pwrBtnPad.PaddingRight = UDim.new(0, 6)
	pwrBtnPad.Parent = powerBtn

	local buyCpuBtn = Instance.new("TextButton")
	buyCpuBtn.Name = "BuyCpuBtn"
	buyCpuBtn.Size = UDim2.new(0, 0, 0, 18)
	buyCpuBtn.AutomaticSize = Enum.AutomaticSize.X
	buyCpuBtn.BackgroundColor3 = Color3.fromHex("#333333")
	buyCpuBtn.Text = "+CPU:100S"
	buyCpuBtn.TextColor3 = COLORS.success
	buyCpuBtn.Font = Enum.Font.RobotoMono
	buyCpuBtn.TextSize = BASE_TEXT_SIZE
	buyCpuBtn.Visible = false
	buyCpuBtn.LayoutOrder = 2
	buyCpuBtn.Parent = rightBtns
	Instance.new("UICorner", buyCpuBtn).CornerRadius = UDim.new(0, 4)
	local cpuBtnPad = Instance.new("UIPadding")
	cpuBtnPad.PaddingLeft = UDim.new(0, 6)
	cpuBtnPad.PaddingRight = UDim.new(0, 6)
	cpuBtnPad.Parent = buyCpuBtn

	local buyRamBtn = Instance.new("TextButton")
	buyRamBtn.Name = "BuyRamBtn"
	buyRamBtn.Size = UDim2.new(0, 0, 0, 18)
	buyRamBtn.AutomaticSize = Enum.AutomaticSize.X
	buyRamBtn.BackgroundColor3 = Color3.fromHex("#333333")
	buyRamBtn.Text = "+RAM:75S"
	buyRamBtn.TextColor3 = COLORS.warning
	buyRamBtn.Font = Enum.Font.RobotoMono
	buyRamBtn.TextSize = BASE_TEXT_SIZE
	buyRamBtn.Visible = false
	buyRamBtn.LayoutOrder = 3
	buyRamBtn.Parent = rightBtns
	Instance.new("UICorner", buyRamBtn).CornerRadius = UDim.new(0, 4)
	local ramBtnPad = Instance.new("UIPadding")
	ramBtnPad.PaddingLeft = UDim.new(0, 6)
	ramBtnPad.PaddingRight = UDim.new(0, 6)
	ramBtnPad.Parent = buyRamBtn

	local editorArea = Instance.new("Frame")
	editorArea.Size = UDim2.new(1, 0, 1, -(TOOLBAR_HEIGHT + ERROR_HEIGHT))
	editorArea.Position = UDim2.new(0, 0, 0, TOOLBAR_HEIGHT)
	editorArea.BackgroundTransparency = 1
	editorArea.Parent = colEditor

	local editor = EditorPanel.create(editorArea)
	editorRef = editor
	local editorTextBox = editor:getTextBox()
	local isProcessingSync = false

	local errorBar = Instance.new("Frame")
	errorBar.Name = "ErrorBar"
	errorBar.Size = UDim2.new(1, 0, 0, ERROR_HEIGHT)
	errorBar.Position = UDim2.new(0, 0, 1, -ERROR_HEIGHT)
	errorBar.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
	errorBar.BorderSizePixel = 0
	errorBar.Parent = colEditor

	local stdErrLabel = Instance.new("TextLabel")
	stdErrLabel.Size = UDim2.new(1, -10, 1, -4)
	stdErrLabel.Position = UDim2.new(0, 5, 0, 2)
	stdErrLabel.BackgroundTransparency = 1
	stdErrLabel.Text = ""
	stdErrLabel.TextColor3 = COLORS.danger
	stdErrLabel.TextXAlignment = Enum.TextXAlignment.Left
	stdErrLabel.TextYAlignment = Enum.TextYAlignment.Top
	stdErrLabel.Font = Enum.Font.RobotoMono
	stdErrLabel.TextSize = BASE_TEXT_SIZE
	stdErrLabel.TextWrapped = true
	stdErrLabel.Parent = errorBar

	local function getAvailableNames()
		local names = {}
		for pid, data in pairs(interpreters) do
			if data.name and data.type then
				local varName = data.name:gsub("%.py$", "")
				if data.type == "gundam" then
					names[varName] = "Gundam"
				elseif data.type == "bot" then
					names[varName] = "Bot"
				elseif data.type == "player" then
					names[varName] = "Player"
				end
			end
		end
		return names
	end

	local function tryCompile(source, maxBytecode, selfType)
		local availableNames = getAvailableNames()
		local success, result = pcall(function()
			return Python.compile(source, maxBytecode or 9999, selfType or "Entity", availableNames)
		end)
		if not success then
			return false, { message = tostring(result), line = nil }
		end
		if result.error then
			return false, result.error
		end
		return true, nil
	end

	local function isEditing(data)
		return data and data.localSource and data.originalSource and data.localSource ~= data.originalSource
	end

	local function onTextChanged()
		if isProcessingSync then return end
		if not currentTabId then return end

		local data = interpreters[currentTabId]
		if not data then return end

		local newSource = editorTextBox.Text
		local wasEditing = isEditing(data)
		data.localSource = newSource

		if not wasEditing and isEditing(data) then
			if callbacks.onPause then
				callbacks.onPause(currentTabId)
			end
		end

		if isEditing(data) then
			local maxBytecode = data.maxBytecode or 128
			local compileOk, compileError = tryCompile(newSource, maxBytecode, data.selfType)
			data.compileOk = compileOk
			data.compileError = compileError

			if compileOk then
				stdErrLabel.Text = ""
				editor:setErrorLine(-1)
				runBtn.BackgroundColor3 = COLORS.success
			else
				stdErrLabel.Text = compileError.message or ""
				editor:setErrorLine(compileError.line)
				runBtn.BackgroundColor3 = Color3.fromHex("#555555")
			end

			runBtn.Text = "./" .. (data.name or "script.py") .. " ^1"
			gdbBtn.Text = "REVERT"
			gdbBtn.BackgroundColor3 = COLORS.danger
		end
	end

	editorTextBox:GetPropertyChangedSignal("Text"):Connect(onTextChanged)

	local ide = {}

	local function clearList(frame)
		for _, c in ipairs(frame:GetChildren()) do
			if c:IsA("GuiObject") then c:Destroy() end
		end
	end

	local function updateStats(data)
		local cpu = data.cpuHz or 1
		local ram = data.bytecode and #data.bytecode or 0
		local maxRam = data.maxBytecode or 32
		local pwr = data.power or 1
		local ramColor = ram > maxRam and "#F44747" or "#DCDCAA"
		statsLabel.Text = string.format(
			'<font color="#4EC9B0">CPU:%dhz</font> <font color="%s">RAM:%d/%d</font> <font color="#FF6464">PWR:x%d</font>',
			cpu, ramColor, ram, maxRam, pwr)
	end

	local function updateState(pid)
		if pid ~= currentTabId then return end
		local data = interpreters[pid]
		if not data then return end

		local status = data.status
		local isPaused = data.paused
		local editing = isEditing(data)

		local scriptName = "./" .. (data.name or "script.py") .. " ^1"
		runBtn.Text = scriptName

		if editing then
			runBtn.BackgroundColor3 = data.compileOk and COLORS.success or Color3.fromHex("#555555")
			gdbBtn.Text = "REVERT"
			gdbBtn.BackgroundColor3 = COLORS.danger
			editor:setReadOnly(false)
		elseif isPaused then
			runBtn.BackgroundColor3 = COLORS.success
			gdbBtn.Text = "STEP"
			gdbBtn.BackgroundColor3 = COLORS.warning
			editor:setReadOnly(true)
			stdErrLabel.TextColor3 = COLORS.warning
			stdErrLabel.Text = "paused - click STEP or " .. scriptName .. " to continue"
		elseif status == "RUNNING" then
			runBtn.BackgroundColor3 = Color3.fromHex("#2d5a2d")
			gdbBtn.Text = "PAUSE"
			gdbBtn.BackgroundColor3 = COLORS.warning
			editor:setReadOnly(false)
		else
			runBtn.BackgroundColor3 = COLORS.success
			gdbBtn.Text = "GDB"
			gdbBtn.BackgroundColor3 = COLORS.warning
			editor:setReadOnly(false)
		end

		buyCpuBtn.Visible = true
		buyRamBtn.Visible = true

		local currentCpuHz = data.cpuHz or Config.BASE_CPU_HZ
		local cpuUpgradeCount = math.floor((currentCpuHz - Config.BASE_CPU_HZ) / Config.CPU_HZ_INCREMENT + 0.5)
		local cpuCost = math.floor(Config.CPU_BASE_COST * (Config.CPU_COST_MULTIPLIER ^ cpuUpgradeCount))
		buyCpuBtn.Text = string.format("+CPU:%dS", cpuCost)

		local currentRam = data.maxBytecode or Config.BASE_RAM
		local ramUpgradeCount = math.floor((currentRam - Config.BASE_RAM) / Config.RAM_INCREMENT)
		local ramCost = math.floor(Config.RAM_BASE_COST * (Config.RAM_COST_MULTIPLIER ^ ramUpgradeCount))
		buyRamBtn.Text = string.format("+RAM:%dS", ramCost)

		local unitPower = data.power or 1
		local powerCost = math.floor(100 * (2 ^ (unitPower - 1)))
		powerBtn.Text = string.format("+PWR x%d:%dS", unitPower + 1, powerCost)

		clearList(varList)
		local varNames = {}
		for k in pairs(data.variables or {}) do table.insert(varNames, k) end
		table.sort(varNames)

		for _, k in ipairs(varNames) do
			local v = data.variables[k]
			if v ~= "__NIL__" then
				local l = Instance.new("TextLabel")
				l.Size = UDim2.new(1, -4, 0, 14)
				l.Position = UDim2.new(0, 2, 0, 0)
				l.BackgroundTransparency = 1
				l.RichText = true
				l.Text = string.format('<font color="#9CDCFE">%s</font>=<font color="#CE9178">%s</font>', k,
					formatValue(v, 12))
				l.Font = Enum.Font.RobotoMono
				l.TextSize = scaledSize(BASE_TEXT_SIZE)
				l.TextXAlignment = Enum.TextXAlignment.Left
				l.Parent = varList
			end
		end

		clearList(stackList)
		local stack = data.stack or {}
		if #stack > 0 then
			for i = #stack, 1, -1 do
				local l = Instance.new("TextLabel")
				l.Size = UDim2.new(1, -4, 0, 14)
				l.Position = UDim2.new(0, 2, 0, 0)
				l.BackgroundTransparency = 1
				l.RichText = true
				l.Text = string.format('<font color="#606080">[%d]</font> <font color="#B5CEA8">%s</font>', i - 1,
					formatValue(stack[i], 8))
				l.Font = Enum.Font.RobotoMono
				l.TextSize = scaledSize(BASE_TEXT_SIZE)
				l.TextXAlignment = Enum.TextXAlignment.Left
				l.Parent = stackList
			end
		else
			local l = Instance.new("TextLabel")
			l.Size = UDim2.new(1, -4, 0, 14)
			l.Position = UDim2.new(0, 2, 0, 0)
			l.BackgroundTransparency = 1
			l.Text = "(empty)"
			l.TextColor3 = Color3.fromRGB(96, 96, 128)
			l.Font = Enum.Font.RobotoMono
			l.TextSize = scaledSize(BASE_TEXT_SIZE)
			l.TextXAlignment = Enum.TextXAlignment.Left
			l.Parent = stackList
		end

		clearList(bcList)
		local execLine = nil
		if data.bytecode then
			for i, instr in ipairs(data.bytecode) do
				local l = Instance.new("TextLabel")
				l.Size = UDim2.new(1, -2, 0, 14)
				l.Position = UDim2.new(0, 1, 0, 0)
				l.RichText = true
				local opColor = OP_COLORS[instr.op] or "#cccccc"
				local prefix = (data.ip == i) and ">" or " "
				local argStr = ""
				if instr.arg ~= nil then
					if type(instr.arg) == "table" then
						if instr.arg.type then
							if instr.arg.value == nil then
								argStr = "None"
							elseif type(instr.arg.value) == "boolean" then
								argStr = instr.arg.value and "True" or "False"
							elseif type(instr.arg.value) == "string" then
								argStr = '"' .. tostring(instr.arg.value) .. '"'
							else
								argStr = tostring(instr.arg.value)
							end
						elseif instr.arg.name then
							argStr = "fn:" .. instr.arg.name
						else
							argStr = tostring(instr.arg)
						end
					else
						argStr = tostring(instr.arg)
					end
				end
				if #argStr > 14 then argStr = argStr:sub(1, 12) .. ".." end
				l.Text = string.format('%s<font color="#888">%02d</font> <font color="%s">%-12s</font> %s',
					prefix, i, opColor, instr.op or "?", argStr)
				l.TextColor3 = Color3.fromRGB(200, 200, 200)
				l.Font = Enum.Font.RobotoMono
				l.TextSize = scaledSize(BASE_TEXT_SIZE)
				l.TextXAlignment = Enum.TextXAlignment.Left
				if data.ip == i then
					l.BackgroundColor3 = Color3.fromRGB(60, 60, 40)
					l.BackgroundTransparency = 0
				else
					l.BackgroundTransparency = 1
				end
				l.Parent = bcList

				if data.ip == i and (status == "RUNNING" or isPaused) and instr.line then
					execLine = instr.line
				end
			end
			updateStats(data)
		end

		editor:setExecLine(execLine)

		clearList(outList)
		if data.output and data.output ~= "" then
			for line in string.gmatch(data.output .. "\n", "([^\n]*)\n") do
				if line ~= "" then
					local l = Instance.new("TextLabel")
					l.Size = UDim2.new(1, -4, 0, 12)
					l.Position = UDim2.new(0, 2, 0, 0)
					l.BackgroundTransparency = 1
					l.Text = line
					l.TextColor3 = COLORS.success
					l.Font = Enum.Font.RobotoMono
					l.TextSize = scaledSize(BASE_TEXT_SIZE)
					l.TextXAlignment = Enum.TextXAlignment.Left
					l.TextTruncate = Enum.TextTruncate.AtEnd
					l.Parent = outList
				end
			end
		end

		if editing then
			if data.compileError then
				stdErrLabel.TextColor3 = COLORS.danger
				stdErrLabel.Text = data.compileError.message or ""
				editor:setErrorLine(data.compileError.line)
			else
				stdErrLabel.Text = ""
				editor:setErrorLine(-1)
			end
		elseif data.error and data.error.message and data.error.message ~= "" then
			stdErrLabel.TextColor3 = COLORS.danger
			stdErrLabel.Text = data.error.message
			editor:setErrorLine(data.error.line)
		elseif not isPaused then
			stdErrLabel.Text = ""
			editor:setErrorLine(-1)
		end
	end

	local function ensureTab(pid)
		if tabs[pid] then return end

		local data = interpreters[pid]
		local name = data and (data.name or data.type) or "script.py"
		local isPlayer = data and data.type == "player"

		local textWidth = #name * 7 + 20
		if not isPlayer then textWidth = textWidth + 16 end

		local btn = Instance.new("TextButton")
		btn.Name = tostring(pid)
		btn.Size = UDim2.new(0, textWidth * fontScale, 1, 0)
		btn.BackgroundColor3 = Color3.fromHex("#2d2d2d")
		btn.BorderSizePixel = 0
		btn.Text = " " .. name
		btn.TextColor3 = COLORS.subtext
		btn.Font = Enum.Font.RobotoMono
		btn.TextSize = math.floor(BASE_TEXT_SIZE * fontScale)
		btn.TextXAlignment = Enum.TextXAlignment.Left
		btn.ClipsDescendants = true
		btn.Parent = tabsScroll
		registerText(btn, BASE_TEXT_SIZE)

		local indicator = Instance.new("Frame")
		indicator.Name = "SelectIndicator"
		indicator.Size = UDim2.new(1, 0, 0, 2)
		indicator.Position = UDim2.new(0, 0, 1, -2)
		indicator.BackgroundColor3 = Color3.fromRGB(0, 200, 255)
		indicator.BorderSizePixel = 0
		indicator.Visible = false
		indicator.Parent = btn

		if not isPlayer then
			local close = Instance.new("TextButton")
			close.Name = "CloseBtn"
			close.Size = UDim2.new(0, 16 * fontScale, 0, 16 * fontScale)
			close.AnchorPoint = Vector2.new(1, 0.5)
			close.Position = UDim2.new(1, -2, 0.5, 0)
			close.BackgroundTransparency = 1
			close.Text = "×"
			close.TextColor3 = COLORS.subtext
			close.Font = Enum.Font.RobotoMono
			close.TextSize = math.floor(BASE_TEXT_SIZE * fontScale)
			close.Parent = btn
			close.MouseButton1Click:Connect(function() ide:closeTab(pid) end)
			registerText(close, BASE_TEXT_SIZE)
		end

		btn.MouseButton1Click:Connect(function() ide:openTab(pid) end)

		tabs[pid] = { button = btn, indicator = indicator }
	end

	function ide:openTab(pid)
		ensureTab(pid)

		for id, tab in pairs(tabs) do
			if id == pid then
				tab.button.BackgroundColor3 = Color3.fromHex("#1a1a1a")
				tab.button.TextColor3 = Color3.fromRGB(0, 220, 255)
				if tab.indicator then tab.indicator.Visible = true end
			else
				tab.button.BackgroundColor3 = Color3.fromHex("#2d2d2d")
				tab.button.TextColor3 = COLORS.subtext
				if tab.indicator then tab.indicator.Visible = false end
			end
		end

		currentTabId = pid
		local data = interpreters[pid]
		if data then
			local selfTypeMap = { player = "Player", gundam = "Gundam", bot = "Bot" }
			editor:setSelfType(selfTypeMap[data.type] or "Player")

			local source = data.localSource or data.source or ""
			isProcessingSync = true
			editor:setText(source)
			isProcessingSync = false

			if not data.originalSource then
				data.originalSource = data.source or ""
			end
			if not data.localSource then
				data.localSource = source
			end

			updateState(pid)
			if callbacks.onTabOpen then
				callbacks.onTabOpen(pid)
			end
		end
	end

	function ide:closeTab(pid)
		local tab = tabs[pid]
		if not tab then return end

		local data = interpreters[pid]
		if data and data.type == "player" then return end

		tab.button:Destroy()
		tabs[pid] = nil
		if currentTabId == pid then
			currentTabId = nil
			for nextPid in pairs(tabs) do
				ide:openTab(nextPid)
				break
			end
		end
		if callbacks.onTabClose then callbacks.onTabClose(pid) end
	end

	function ide:closeTabSilent(pid)
		if tabs[pid] then
			tabs[pid].button:Destroy()
			tabs[pid] = nil
			if currentTabId == pid then
				currentTabId = nil
				for nextPid in pairs(tabs) do
					ide:openTab(nextPid)
					break
				end
			end
		end
	end

	function ide:sync(payload)
		local payloadPids = {}
		for pid in pairs(payload) do
			payloadPids[tostring(pid)] = true
		end

		local toRemove = {}
		for pid in pairs(interpreters) do
			if not payloadPids[tostring(pid)] then
				table.insert(toRemove, pid)
			end
		end
		for _, pid in ipairs(toRemove) do
			interpreters[pid] = nil
			if tabs[pid] then
				ide:closeTabSilent(pid)
			end
		end

		local playerPid = nil
		for pid, data in pairs(payload) do
			local isNew = not interpreters[pid]
			if isNew then
				interpreters[pid] = { pid = pid }
			end
			local localData = interpreters[pid]

			local hadLocalSource = localData.localSource
			for k, v in pairs(data) do localData[k] = v end

			if data.type == "player" then
				playerPid = pid
			end

			if not localData.originalSource and data.source then
				localData.originalSource = data.source
			end
			if not hadLocalSource and data.source then
				localData.localSource = data.source
			end

			ensureTab(pid)

			if pid == currentTabId then
				if not isEditing(localData) then
					isProcessingSync = true
					editor:setText(localData.localSource or localData.source or "")
					isProcessingSync = false
				end
				updateState(pid)
			end
		end

		if not currentTabId and playerPid then
			ide:openTab(playerPid)
		end
	end

	function ide:getInterpreterType(pid)
		return interpreters[pid] and interpreters[pid].type
	end

	function ide:getRange(pid)
		local data = interpreters[pid]
		return data and data.dynamicRange or 40
	end

	function ide:recheckCompile(pid)
		pid = pid or currentTabId
		if not pid then return end
		local data = interpreters[pid]
		if not data then return end

		local source = data.localSource or data.source or ""
		local maxBytecode = data.maxBytecode or 128
		local compileOk, compileError = tryCompile(source, maxBytecode, data.selfType)
		data.compileOk = compileOk
		data.compileError = compileError
		data.error = nil

		if pid == currentTabId then
			if compileOk then
				stdErrLabel.Text = ""
				editor:setErrorLine(-1)
			else
				stdErrLabel.TextColor3 = COLORS.danger
				stdErrLabel.Text = compileError and compileError.message or ""
				editor:setErrorLine(compileError and compileError.line or -1)
			end
			updateState(pid)
		end
	end

	function ide:getCounts()
		local g, b = 0, 0
		for _, d in pairs(interpreters) do
			if d.type == "gundam" then g = g + 1 elseif d.type == "bot" then b = b + 1 end
		end
		return g, b
	end

	function ide:getCurrentTabId() return currentTabId end

	function ide:getText() return editor:getText() end

	function ide:triggerRun()
		if not currentTabId then return false end
		local data = interpreters[currentTabId]
		if not data then return false end

		if isEditing(data) and not data.compileOk then return false end

		data.originalSource = data.localSource
		data.compileOk = true
		data.compileError = nil
		data.paused = false
		stdErrLabel.Text = ""
		editor:setErrorLine(-1)

		if callbacks.onRun then callbacks.onRun(currentTabId) end
		return true
	end

	runBtn.MouseButton1Click:Connect(function()
		ide:triggerRun()
	end)

	gdbBtn.MouseButton1Click:Connect(function()
		if not currentTabId then return end
		local data = interpreters[currentTabId]
		if not data then return end

		if isEditing(data) then
			data.localSource = data.originalSource
			data.compileOk = true
			data.compileError = nil
			data.paused = false
			isProcessingSync = true
			editor:setText(data.originalSource or "")
			isProcessingSync = false
			stdErrLabel.Text = ""
			editor:setErrorLine(-1)
			if callbacks.onRun then callbacks.onRun(currentTabId) end
		else
			if data.status == "RUNNING" and not data.paused then
				if callbacks.onPause then callbacks.onPause(currentTabId) end
			else
				if callbacks.onStep then callbacks.onStep(currentTabId) end
			end
		end
	end)

	buyCpuBtn.MouseButton1Click:Connect(function()
		if callbacks.onBuyCpu and currentTabId then callbacks.onBuyCpu(currentTabId) end
	end)

	buyRamBtn.MouseButton1Click:Connect(function()
		if callbacks.onBuyRam and currentTabId then callbacks.onBuyRam(currentTabId) end
	end)

	defaultBtn.MouseButton1Click:Connect(function()
		if not currentTabId then return end
		local data = interpreters[currentTabId]
		if data then
			data.localSource = nil
			data.originalSource = nil
			data.compileOk = true
			data.compileError = nil
		end
		if callbacks.onReset then callbacks.onReset(currentTabId) end
	end)

	dbgBtn.MouseButton1Click:Connect(function()
		if not currentTabId then return end
		local data = interpreters[currentTabId]
		if not data then return end
		print("========== DEBUG: BYTECODE ==========")
		print("PID:", currentTabId, "Type:", data.type or "?", "Name:", data.name or "?")
		print("Source:")
		print(data.localSource or data.source or "(no source)")
		print("")
		local bc = data.bytecode or {}
		print("Bytecode (" .. #bc .. " instructions):")
		for i, instr in ipairs(bc) do
			local argStr = ""
			if instr.arg ~= nil then
				if type(instr.arg) == "table" then
					if instr.arg.type then
						if instr.arg.value == nil then
							argStr = "None"
						elseif type(instr.arg.value) == "string" then
							argStr = '"' .. tostring(instr.arg.value) .. '"'
						else
							argStr = tostring(instr.arg.value)
						end
					elseif instr.arg.name then
						argStr = "<func " .. instr.arg.name .. ">"
					else
						argStr = tostring(instr.arg)
					end
				else
					argStr = tostring(instr.arg)
				end
			end
			print(string.format("%3d [L%d] %-20s %s", i, instr.line or 0, instr.op or "?", argStr))
		end
		print("========== END BYTECODE ==========")
	end)

	local hidden = false
	hideBtn.MouseButton1Click:Connect(function()
		hidden = not hidden
		if hidden then
			hideBtn.Text = "SHOW"
			TweenService:Create(container, TweenInfo.new(0.2, Enum.EasingStyle.Quad), {
				Position = UDim2.new(0, 0, 1, 0)
			}):Play()
		else
			hideBtn.Text = "HIDE"
			TweenService:Create(container, TweenInfo.new(0.2, Enum.EasingStyle.Quad), {
				Position = UDim2.new(0, 0, 1 - IDE_HEIGHT_SCALE, 0)
			}):Play()
		end
	end)

	botBuildBtn.MouseButton1Click:Connect(function()
		if callbacks.onBuildBot then callbacks.onBuildBot() end
	end)

	gundamBuildBtn.MouseButton1Click:Connect(function()
		if callbacks.onBuildGundam then callbacks.onBuildGundam() end
	end)

	helpBtn.MouseButton1Click:Connect(function()
		if callbacks.onHelp then callbacks.onHelp() end
	end)

	powerBtn.MouseButton1Click:Connect(function()
		if callbacks.onBuyPower and currentTabId then callbacks.onBuyPower(currentTabId) end
	end)

	function ide:updateEconomy(botCost, gundamCost)
		botBuildBtn.Text = string.format("+ROBOT (B): %dS", botCost or 75)
		gundamBuildBtn.Text = string.format("+GUNDAM (G): %dS", gundamCost or 100)
	end

	ide.frame = container
	ide.container = container

	local function scanForText(parent)
		for _, child in ipairs(parent:GetChildren()) do
			if child:IsA("TextLabel") or child:IsA("TextButton") or child:IsA("TextBox") then
				if child.TextSize > 0 and child ~= fontDownBtn and child ~= fontUpBtn then
					registerText(child, child.TextSize)
				end
			end
			scanForText(child)
		end
	end
	scanForText(container)
	scanForText(topBar)
	applyFontScale()

	return ide
end

return MainIDE
