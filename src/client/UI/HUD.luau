local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")
local UITheme = require(script.Parent.UITheme)

local HUD = {}
local COLORS = UITheme.COLORS
local TOP_INSET = 48

local SCOREBOARD_TITLE_SIZE = 14
local SCOREBOARD_ROW_SIZE = 12

function HUD.create(parent, callbacks)
	local hud = {
		callbacks = callbacks or {},
		selection = nil,
		fontScale = 1.0,
	}

	local coreDisplay = Instance.new("Frame")
	coreDisplay.Name = "CoreDisplay"
	coreDisplay.Size = UDim2.new(0, 160, 0, 50)
	coreDisplay.Position = UDim2.new(0, 15, 0, TOP_INSET + 10)
	coreDisplay.BackgroundColor3 = COLORS.panel
	coreDisplay.Parent = parent

	local coreCorner = Instance.new("UICorner")
	coreCorner.CornerRadius = UDim.new(0, 8)
	coreCorner.Parent = coreDisplay

	local coreLabel = Instance.new("TextLabel")
	coreLabel.Name = "Label"
	coreLabel.Size = UDim2.new(1, -10, 0, 20)
	coreLabel.Position = UDim2.new(0, 5, 0, 5)
	coreLabel.BackgroundTransparency = 1
	coreLabel.Text = "CORE HP"
	coreLabel.TextColor3 = COLORS.subtext
	coreLabel.Font = UITheme.FONT
	coreLabel.TextSize = 10
	coreLabel.TextXAlignment = Enum.TextXAlignment.Left
	coreLabel.Parent = coreDisplay

	local coreHP = Instance.new("TextLabel")
	coreHP.Name = "HP"
	coreHP.Size = UDim2.new(1, -10, 0, 25)
	coreHP.Position = UDim2.new(0, 5, 0, 22)
	coreHP.BackgroundTransparency = 1
	coreHP.Text = "1000 / 1000"
	coreHP.TextColor3 = COLORS.success
	coreHP.Font = UITheme.FONT
	coreHP.TextSize = 16
	coreHP.TextXAlignment = Enum.TextXAlignment.Left
	coreHP.Parent = coreDisplay

	local scrapDisplay = Instance.new("Frame")
	scrapDisplay.Name = "ScrapDisplay"
	scrapDisplay.Size = UDim2.new(0, 160, 0, 28)
	scrapDisplay.Position = UDim2.new(0, 15, 0, TOP_INSET + 65)
	scrapDisplay.BackgroundColor3 = COLORS.panel
	scrapDisplay.Parent = parent

	local scrapCorner = Instance.new("UICorner")
	scrapCorner.CornerRadius = UDim.new(0, 8)
	scrapCorner.Parent = scrapDisplay

	local scrapText = Instance.new("TextLabel")
	scrapText.Name = "ScrapText"
	scrapText.Size = UDim2.new(1, -10, 1, 0)
	scrapText.Position = UDim2.new(0, 5, 0, 0)
	scrapText.BackgroundTransparency = 1
	scrapText.Text = "SCRAP: 0"
	scrapText.TextColor3 = COLORS.warning
	scrapText.Font = UITheme.FONT
	scrapText.TextSize = 14
	scrapText.TextXAlignment = Enum.TextXAlignment.Left
	scrapText.Parent = scrapDisplay

	local waveDisplay = Instance.new("Frame")
	waveDisplay.Name = "WaveDisplay"
	waveDisplay.Size = UDim2.new(0, 160, 0, 40)
	waveDisplay.Position = UDim2.new(0, 15, 0, TOP_INSET + 98)
	waveDisplay.BackgroundColor3 = COLORS.panel
	waveDisplay.Parent = parent

	local waveCorner = Instance.new("UICorner")
	waveCorner.CornerRadius = UDim.new(0, 8)
	waveCorner.Parent = waveDisplay

	local waveTitle = Instance.new("TextLabel")
	waveTitle.Name = "Title"
	waveTitle.Size = UDim2.new(1, -10, 0, 18)
	waveTitle.Position = UDim2.new(0, 5, 0, 4)
	waveTitle.BackgroundTransparency = 1
	waveTitle.Text = "WAVE 1"
	waveTitle.TextColor3 = COLORS.accent
	waveTitle.Font = UITheme.FONT
	waveTitle.TextSize = 14
	waveTitle.TextXAlignment = Enum.TextXAlignment.Left
	waveTitle.Parent = waveDisplay

	local enemyCount = Instance.new("TextLabel")
	enemyCount.Name = "EnemyCount"
	enemyCount.Size = UDim2.new(1, -10, 0, 14)
	enemyCount.Position = UDim2.new(0, 5, 0, 22)
	enemyCount.BackgroundTransparency = 1
	enemyCount.Text = "0 / 0"
	enemyCount.TextColor3 = COLORS.danger
	enemyCount.Font = UITheme.FONT
	enemyCount.TextSize = 12
	enemyCount.TextXAlignment = Enum.TextXAlignment.Left
	enemyCount.Parent = waveDisplay

	local waveActionBtn = Instance.new("TextButton")
	waveActionBtn.Name = "WaveActionBtn"
	waveActionBtn.Size = UDim2.new(0, 160, 0, 35)
	waveActionBtn.Position = UDim2.new(0, 15, 0, TOP_INSET + 143)
	waveActionBtn.BackgroundColor3 = COLORS.accent
	waveActionBtn.Text = "START"
	waveActionBtn.TextColor3 = COLORS.bg
	waveActionBtn.Font = UITheme.FONT
	waveActionBtn.TextSize = 14
	waveActionBtn.AutoButtonColor = true
	waveActionBtn.Parent = parent

	local waveActionCorner = Instance.new("UICorner")
	waveActionCorner.CornerRadius = UDim.new(0, 8)
	waveActionCorner.Parent = waveActionBtn

	local scoreboardFrame = Instance.new("Frame")
	scoreboardFrame.Name = "Scoreboard"
	scoreboardFrame.Size = UDim2.new(0, 160, 0, 120)
	scoreboardFrame.Position = UDim2.new(1, -175, 0, TOP_INSET + 10)
	scoreboardFrame.BackgroundColor3 = COLORS.panel
	scoreboardFrame.Parent = parent

	local scoreboardCorner = Instance.new("UICorner")
	scoreboardCorner.CornerRadius = UDim.new(0, 8)
	scoreboardCorner.Parent = scoreboardFrame

	local scoreboardTitle = Instance.new("TextLabel")
	scoreboardTitle.Name = "Title"
	scoreboardTitle.Size = UDim2.new(1, -10, 0, 20)
	scoreboardTitle.Position = UDim2.new(0, 5, 0, 4)
	scoreboardTitle.BackgroundTransparency = 1
	scoreboardTitle.Text = "// DMG_LOG"
	scoreboardTitle.TextColor3 = Color3.fromRGB(255, 176, 0)
	scoreboardTitle.Font = UITheme.FONT
	scoreboardTitle.TextSize = SCOREBOARD_TITLE_SIZE
	scoreboardTitle.TextXAlignment = Enum.TextXAlignment.Left
	scoreboardTitle.Parent = scoreboardFrame

	local scoreboardList = Instance.new("Frame")
	scoreboardList.Name = "List"
	scoreboardList.Size = UDim2.new(1, -10, 1, -26)
	scoreboardList.Position = UDim2.new(0, 5, 0, 22)
	scoreboardList.BackgroundTransparency = 1
	scoreboardList.Parent = scoreboardFrame

	local scoreboardLayout = Instance.new("UIListLayout")
	scoreboardLayout.SortOrder = Enum.SortOrder.LayoutOrder
	scoreboardLayout.Padding = UDim.new(0, 2)
	scoreboardLayout.Parent = scoreboardList

	local currentPhase = "LOBBY"

	waveActionBtn.MouseButton1Click:Connect(function()
		if currentPhase == "LOBBY" then
			if callbacks.onReady then callbacks.onReady() end
		end
	end)

	function hud.updateWave(waveNum, remaining, total)
		waveTitle.Text = "WAVE " .. (waveNum or 0)
		if total and total > 0 then
			enemyCount.Text = (remaining or 0) .. " / " .. total .. " remaining"
		else
			enemyCount.Text = ""
		end
	end

	function hud.updateEconomy(scrap, gundamCost, botCost)
		scrapText.Text = "SCRAP: " .. (scrap or 0)
	end

	function hud.updateCore(hp, maxHp)
		coreHP.Text = (hp or 0) .. " / " .. (maxHp or 1000)

		local ratio = (hp or 0) / (maxHp or 1000)
		if ratio > 0.6 then
			coreHP.TextColor3 = COLORS.success
		elseif ratio > 0.3 then
			coreHP.TextColor3 = COLORS.warning
		else
			coreHP.TextColor3 = COLORS.danger
		end
	end

	function hud.updatePhase(phaseName)
		currentPhase = phaseName or "LOBBY"

		if phaseName == "COMBAT" then
			waveActionBtn.Visible = false
		elseif phaseName == "LOBBY" then
			waveActionBtn.Visible = true
		else
			waveActionBtn.Visible = false
		end
	end

	function hud.select(objData)
		hud.selection = objData
	end

	function hud.deselect()
		hud.selection = nil
	end

	function hud.updateBotSlot(slotNum, botData)
	end

	function hud.updateBotParty(botStates)
	end

	function hud.triggerGlobalCooldown(duration)
	end

	function hud.triggerReloadCooldown(duration, weaponIndex)
	end

	function hud.highlightWeapon(weaponIndex)
	end

	function hud.isReloading()
		return false
	end

	function hud.getCurrentWeapon()
		return 1
	end

	function hud.setCurrentWeapon(w)
	end

	function hud.updateScoreboard(damageBoard)
		for _, child in ipairs(scoreboardList:GetChildren()) do
			if child:IsA("TextLabel") then
				child:Destroy()
			end
		end

		if not damageBoard then return end

		local localUserId = Players.LocalPlayer and Players.LocalPlayer.UserId
		local amber = Color3.fromRGB(255, 176, 0)
		local amberDim = Color3.fromRGB(180, 120, 0)
		local rowSize = math.floor(SCOREBOARD_ROW_SIZE * hud.fontScale)

		for i, entry in ipairs(damageBoard) do
			if i > 5 then break end

			local row = Instance.new("TextLabel")
			row.Name = "Row" .. i
			row.Size = UDim2.new(1, 0, 0, rowSize + 4)
			row.BackgroundTransparency = 1
			row.Font = UITheme.FONT
			row.TextSize = rowSize
			row.TextXAlignment = Enum.TextXAlignment.Left
			row.LayoutOrder = i

			local name = entry.name or "???"
			if #name > 8 then name = name:sub(1, 6) .. ".." end
			local dmg = entry.damage or 0
			local hexDmg = string.format("0x%X", dmg)

			row.Text = string.format("0x%02X %s: %s", i - 1, name, hexDmg)

			if entry.userId == localUserId then
				row.TextColor3 = amber
			else
				row.TextColor3 = amberDim
			end

			row.Parent = scoreboardList
		end
	end

	function hud.setFontScale(scale)
		hud.fontScale = scale
		scoreboardTitle.TextSize = math.floor(SCOREBOARD_TITLE_SIZE * scale)
	end

	return hud
end

return HUD
