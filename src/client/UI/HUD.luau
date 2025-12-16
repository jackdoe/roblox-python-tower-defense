local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")
local UITheme = require(script.Parent.UITheme)

local HUD = {}
local COLORS = UITheme.COLORS
local TOP_INSET = 48

function HUD.create(parent, callbacks)
	local hud = {
		callbacks = callbacks or {},
		selection = nil,
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
	coreLabel.Font = Enum.Font.GothamBold
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
	coreHP.Font = Enum.Font.GothamBlack
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
	scrapText.Font = Enum.Font.GothamBold
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
	waveTitle.Font = Enum.Font.GothamBold
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
	enemyCount.Font = Enum.Font.Gotham
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
	waveActionBtn.Font = Enum.Font.GothamBold
	waveActionBtn.TextSize = 14
	waveActionBtn.AutoButtonColor = true
	waveActionBtn.Parent = parent

	local waveActionCorner = Instance.new("UICorner")
	waveActionCorner.CornerRadius = UDim.new(0, 8)
	waveActionCorner.Parent = waveActionBtn

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

	return hud
end

return HUD
