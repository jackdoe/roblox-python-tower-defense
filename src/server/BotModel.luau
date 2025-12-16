local ReplicatedStorage = game:GetService("ReplicatedStorage")
local PythonTD = ReplicatedStorage:WaitForChild("PythonTD")
local BotStats = require(script.Parent.BotStats)

local BotModel = {}

local GROUND_Y = BotStats.GROUND_Y
local COLORS = BotStats.COLORS

function BotModel.create(x, z, ownerColor)
	local model = Instance.new("Model")
	model.Name = "ScrappyBot"

	local accentColor = ownerColor or COLORS.NEON_CYAN

	local function makePart(name, size, color, mat, parent, posOffset)
		local p = Instance.new("Part")
		p.Name = name
		p.Size = size
		p.Color = color
		p.Material = mat or Enum.Material.Plastic
		p.Anchored = false
		p.CanCollide = false
		p.BottomSurface = Enum.SurfaceType.Smooth
		p.TopSurface = Enum.SurfaceType.Smooth
		p.Parent = model

		if parent then
			p.CFrame = parent.CFrame * posOffset
			local w = Instance.new("WeldConstraint")
			w.Part0 = parent
			w.Part1 = p
			w.Parent = parent
		end
		return p
	end

	local hrp = Instance.new("Part")
	hrp.Name = "HumanoidRootPart"
	hrp.Size = Vector3.new(2, 2, 2)
	hrp.Position = Vector3.new(x, GROUND_Y + 2.5, z)
	hrp.Transparency = 1
	hrp.Anchored = true
	hrp.CanCollide = false
	hrp.Parent = model
	model.PrimaryPart = hrp

	local torso = makePart("Torso", Vector3.new(2.2, 1.8, 1.5), COLORS.RUST_ORANGE, Enum.Material.Metal, hrp, CFrame.new(0, 0, 0))

	makePart("Vent", Vector3.new(1.4, 0.8, 0.1), COLORS.DARK_METAL, Enum.Material.DiamondPlate, torso, CFrame.new(0, -0.2, -0.76))

	local head = makePart("Head", Vector3.new(2.4, 1.6, 1.6), COLORS.RUST_ORANGE, Enum.Material.Metal, torso, CFrame.new(0, 1.7, 0))

	makePart("Faceplate", Vector3.new(2.0, 1.2, 0.1), COLORS.DARK_METAL, Enum.Material.Plastic, head, CFrame.new(0, 0, -0.8))

	makePart("LeftEye", Vector3.new(0.5, 0.6, 0.1), accentColor, Enum.Material.Neon, head, CFrame.new(-0.5, 0.1, -0.86))
	makePart("RightEye", Vector3.new(0.5, 0.6, 0.1), accentColor, Enum.Material.Neon, head, CFrame.new(0.5, 0.1, -0.86))

	makePart("AntennaStem", Vector3.new(0.1, 0.8, 0.1), COLORS.DARK_METAL, Enum.Material.Plastic, head, CFrame.new(0.5, 1.0, 0))
	makePart("AntennaBulb", Vector3.new(0.3, 0.3, 0.3), accentColor, Enum.Material.Neon, head, CFrame.new(0.5, 1.5, 0))

	local leftShoulder = makePart("LeftShoulder", Vector3.new(0.5, 0.5, 0.5), COLORS.JOINT_GREY, Enum.Material.Plastic, torso, CFrame.new(-1.35, 0.5, 0))
	local rightShoulder = makePart("RightShoulder", Vector3.new(0.5, 0.5, 0.5), COLORS.JOINT_GREY, Enum.Material.Plastic, torso, CFrame.new(1.35, 0.5, 0))

	makePart("LeftArm", Vector3.new(0.4, 1.2, 0.8), COLORS.RUST_ORANGE, Enum.Material.Metal, leftShoulder, CFrame.new(-0.1, -0.8, 0))
	makePart("RightArm", Vector3.new(0.4, 1.2, 0.8), COLORS.RUST_ORANGE, Enum.Material.Metal, rightShoulder, CFrame.new(0.1, -0.8, 0))

	makePart("LeftFoot", Vector3.new(0.8, 0.6, 1.2), COLORS.DARK_METAL, Enum.Material.DiamondPlate, torso, CFrame.new(-0.6, -1.5, 0))
	makePart("RightFoot", Vector3.new(0.8, 0.6, 1.2), COLORS.DARK_METAL, Enum.Material.DiamondPlate, torso, CFrame.new(0.6, -1.5, 0))

	local backpack = makePart("Backpack", Vector3.new(1.8, 1.2, 0.8), COLORS.DARK_METAL, Enum.Material.Plastic, torso, CFrame.new(0, 0.2, 0.9))

	local scrapPile = makePart("ScrapPile", Vector3.new(1.6, 0.1, 0.6), COLORS.GOLD_SCRAP, Enum.Material.Foil, backpack, CFrame.new(0, 0.65, 0))
	scrapPile.Transparency = 1

	local chatPart = Instance.new("Part")
	chatPart.Name = "ChatHead"
	chatPart.Transparency = 1
	chatPart.Size = Vector3.new(0.1, 0.1, 0.1)
	chatPart.Anchored = false
	chatPart.CanCollide = false
	chatPart.CFrame = head.CFrame * CFrame.new(0, 1.5, 0)
	chatPart.Parent = model

	local chatWeld = Instance.new("WeldConstraint")
	chatWeld.Part0 = head
	chatWeld.Part1 = chatPart
	chatWeld.Parent = head

	local bg = Instance.new("BillboardGui")
	bg.Name = "ChatBubble"
	bg.Size = UDim2.new(0, 120, 0, 40)
	bg.StudsOffset = Vector3.new(0, 0.5, 0)
	bg.AlwaysOnTop = true
	bg.Parent = chatPart

	local bubble = Instance.new("Frame")
	bubble.Name = "Bubble"
	bubble.Size = UDim2.new(1, 0, 1, 0)
	bubble.BackgroundColor3 = Color3.new(1, 1, 1)
	bubble.BackgroundTransparency = 1
	bubble.Parent = bg

	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0.3, 0)
	corner.Parent = bubble

	local chatText = Instance.new("TextLabel")
	chatText.Name = "Text"
	chatText.Size = UDim2.new(1, -10, 1, -6)
	chatText.Position = UDim2.new(0, 5, 0, 3)
	chatText.BackgroundTransparency = 1
	chatText.Text = ""
	chatText.TextColor3 = Color3.new(0.2, 0.2, 0.2)
	chatText.TextScaled = true
	chatText.Font = Enum.Font.GothamBold
	chatText.TextTransparency = 1
	chatText.Parent = bubble

	model.Parent = workspace

	model:SetAttribute("WalkCycle", 0)
	model:SetAttribute("AnimSpeed", 0)
	model:SetAttribute("BaseY", GROUND_Y + 2.5)
	model:SetAttribute("FacingAngle", 0)
	model:SetAttribute("ChatExpiry", 0)
	model:SetAttribute("OwnerColorR", accentColor.R)
	model:SetAttribute("OwnerColorG", accentColor.G)
	model:SetAttribute("OwnerColorB", accentColor.B)

	return model
end

function BotModel.applyPowerScale(bot, power)
	local character = bot.character
	if not character then return end

	local scale = 1 + (power - 1) * 0.1
	local baseScale = character:GetAttribute("BaseScale") or 1
	if not character:GetAttribute("BaseScale") then
		character:SetAttribute("BaseScale", 1)
	end

	character:ScaleTo(scale)
end

function BotModel.createBillboard(bot)
	local character = bot.character
	local hrp = character:FindFirstChild("HumanoidRootPart") or character.PrimaryPart
	if not hrp then return end

	local ownerColor = Color3.fromRGB(
		(character:GetAttribute("OwnerColorR") or 0) * 255,
		(character:GetAttribute("OwnerColorG") or 1) * 255,
		(character:GetAttribute("OwnerColorB") or 1) * 255
	)

	local billboard = Instance.new("BillboardGui")
	billboard.Name = "BotBillboard"
	billboard.Size = UDim2.new(0, 80, 0, 40)
	billboard.StudsOffset = Vector3.new(0, 3, 0)
	billboard.AlwaysOnTop = true
	billboard.Parent = hrp

	local bg = Instance.new("Frame")
	bg.Size = UDim2.new(1, 0, 1, 0)
	bg.BackgroundColor3 = Color3.fromRGB(20, 30, 40)
	bg.BackgroundTransparency = 0.3
	bg.BorderSizePixel = 0
	bg.Parent = billboard

	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 6)
	corner.Parent = bg

	local border = Instance.new("UIStroke")
	border.Color = ownerColor
	border.Thickness = 2
	border.Parent = bg

	local idLabel = Instance.new("TextLabel")
	idLabel.Name = "IdLabel"
	idLabel.Size = UDim2.new(0.5, 0, 0.5, 0)
	idLabel.Position = UDim2.new(0, 4, 0, 2)
	idLabel.BackgroundTransparency = 1
	idLabel.Text = bot.name or "B_?.py"
	idLabel.TextColor3 = ownerColor
	idLabel.Font = Enum.Font.GothamBold
	idLabel.TextSize = 11
	idLabel.TextXAlignment = Enum.TextXAlignment.Left
	idLabel.Parent = bg

	local cargoLabel = Instance.new("TextLabel")
	cargoLabel.Name = "CargoLabel"
	cargoLabel.Size = UDim2.new(0.6, 0, 0.5, 0)
	cargoLabel.Position = UDim2.new(0.4, 0, 0, 2)
	cargoLabel.BackgroundTransparency = 1
	cargoLabel.Text = "0/50"
	cargoLabel.TextColor3 = Color3.fromRGB(255, 200, 100)
	cargoLabel.Font = Enum.Font.Code
	cargoLabel.TextSize = 12
	cargoLabel.TextXAlignment = Enum.TextXAlignment.Right
	cargoLabel.Parent = bg

	local cargoBarBg = Instance.new("Frame")
	cargoBarBg.Name = "CargoBarBg"
	cargoBarBg.Size = UDim2.new(0.9, 0, 0.2, 0)
	cargoBarBg.Position = UDim2.new(0.05, 0, 0.55, 0)
	cargoBarBg.BackgroundColor3 = Color3.fromRGB(40, 40, 40)
	cargoBarBg.BorderSizePixel = 0
	cargoBarBg.Parent = bg

	local cargoBar = Instance.new("Frame")
	cargoBar.Name = "CargoBar"
	cargoBar.Size = UDim2.new(0, 0, 1, 0)
	cargoBar.BackgroundColor3 = Color3.fromRGB(255, 200, 100)
	cargoBar.BorderSizePixel = 0
	cargoBar.Parent = cargoBarBg

	local statusLabel = Instance.new("TextLabel")
	statusLabel.Name = "StatusLabel"
	statusLabel.Size = UDim2.new(1, 0, 0.25, 0)
	statusLabel.Position = UDim2.new(0, 0, 0.75, 0)
	statusLabel.BackgroundTransparency = 1
	statusLabel.Text = "IDLE"
	statusLabel.TextColor3 = Color3.fromRGB(150, 150, 150)
	statusLabel.Font = Enum.Font.Code
	statusLabel.TextSize = 9
	statusLabel.Parent = bg

	bot.billboard = billboard
end

function BotModel.updateBillboard(bot)
	local billboard = bot.billboard
	if not billboard then return end

	local bg = billboard:FindFirstChild("Frame") or billboard:FindFirstChildOfClass("Frame")
	if not bg then return end

	local idLabel = bg:FindFirstChild("IdLabel")
	if idLabel then
		idLabel.Text = bot.name or "B_?.py"
	end

	local cargoLabel = bg:FindFirstChild("CargoLabel")
	if cargoLabel then
		cargoLabel.Text = (bot.scrapInventory or 0) .. "/" .. (bot.maxCapacity or 50)
	end

	local cargoBarBg = bg:FindFirstChild("CargoBarBg")
	if cargoBarBg then
		local cargoBar = cargoBarBg:FindFirstChild("CargoBar")
		if cargoBar then
			local ratio = (bot.scrapInventory or 0) / (bot.maxCapacity or 50)
			cargoBar.Size = UDim2.new(ratio, 0, 1, 0)
		end
	end

	local statusLabel = bg:FindFirstChild("StatusLabel")
	if statusLabel then
		local status = bot.status or "IDLE"
		if bot.isMoving then
			statusLabel.Text = "MOVING"
			statusLabel.TextColor3 = Color3.fromRGB(100, 255, 100)
		elseif (bot.scrapInventory or 0) >= (bot.maxCapacity or 50) then
			statusLabel.Text = "FULL"
			statusLabel.TextColor3 = Color3.fromRGB(255, 200, 100)
		elseif status == "COLLECTING" then
			statusLabel.Text = "COLLECT"
			statusLabel.TextColor3 = Color3.fromRGB(100, 200, 255)
		elseif status == "DELIVERING" then
			statusLabel.Text = "DELIVER"
			statusLabel.TextColor3 = Color3.fromRGB(100, 255, 200)
		elseif status == "SHOCKING" then
			statusLabel.Text = "ZAP!"
			statusLabel.TextColor3 = Color3.fromRGB(255, 255, 100)
		elseif status == "TELEPORTING" then
			statusLabel.Text = "WARP"
			statusLabel.TextColor3 = Color3.fromRGB(0, 255, 255)
		elseif status == "STUNNED" then
			statusLabel.Text = "STUNNED"
			statusLabel.TextColor3 = Color3.fromRGB(255, 100, 100)
		elseif status == "WAITING" then
			statusLabel.Text = "WAIT"
			statusLabel.TextColor3 = Color3.fromRGB(200, 200, 100)
		else
			statusLabel.Text = "IDLE"
			statusLabel.TextColor3 = Color3.fromRGB(150, 150, 150)
		end
	end
end

function BotModel.createShockEffect(bot)
	if not bot.character then return end
	local hrp = bot.character:FindFirstChild("HumanoidRootPart")
	if not hrp then return end

	local sparks = Instance.new("ParticleEmitter")
	sparks.Name = "ShockSparks"
	sparks.Color = ColorSequence.new(Color3.fromRGB(100, 200, 255), Color3.fromRGB(255, 255, 100))
	sparks.Size = NumberSequence.new(0.2, 0)
	sparks.Lifetime = NumberRange.new(0.1, 0.2)
	sparks.Rate = 80
	sparks.Speed = NumberRange.new(3, 8)
	sparks.SpreadAngle = Vector2.new(180, 180)
	sparks.Parent = hrp

	for _, part in pairs(bot.character:GetDescendants()) do
		if part:IsA("BasePart") and part.Name ~= "HumanoidRootPart" then
			local oldColor = part.Color
			part.Color = Color3.fromRGB(100, 200, 255)
			task.delay(0.15, function()
				if part and part.Parent then
					part.Color = Color3.fromRGB(255, 255, 100)
				end
			end)
			task.delay(0.3, function()
				if part and part.Parent then
					part.Color = oldColor
				end
			end)
		end
	end

	task.delay(BotStats.SHOCK_STUN_TIME, function()
		if sparks and sparks.Parent then
			sparks.Enabled = false
			task.delay(0.3, function()
				if sparks then sparks:Destroy() end
			end)
		end
		if bot then bot.status = "IDLE" end
	end)
end

function BotModel.createExplosionEffect(bot, scrapAmount)
	if not bot.character then return end
	local hrp = bot.character:FindFirstChild("HumanoidRootPart")
	if not hrp then return end

	local scale = math.min(scrapAmount / 50, 2)

	local explosion = Instance.new("ParticleEmitter")
	explosion.Name = "ScrapExplosion"
	explosion.Color = ColorSequence.new({
		ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 200, 50)),
		ColorSequenceKeypoint.new(0.5, Color3.fromRGB(255, 100, 50)),
		ColorSequenceKeypoint.new(1, Color3.fromRGB(100, 50, 50)),
	})
	explosion.Size = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.5 * scale),
		NumberSequenceKeypoint.new(0.3, 2 * scale),
		NumberSequenceKeypoint.new(1, 0),
	})
	explosion.Lifetime = NumberRange.new(0.3, 0.6)
	explosion.Rate = 200
	explosion.Speed = NumberRange.new(10 * scale, 25 * scale)
	explosion.SpreadAngle = Vector2.new(180, 180)
	explosion.Parent = hrp

	local ring = Instance.new("Part")
	ring.Shape = Enum.PartType.Cylinder
	ring.Size = Vector3.new(0.5, 2, 2)
	ring.CFrame = hrp.CFrame * CFrame.Angles(0, 0, math.rad(90))
	ring.Anchored = true
	ring.CanCollide = false
	ring.Material = Enum.Material.Neon
	ring.Color = Color3.fromRGB(255, 150, 50)
	ring.Transparency = 0.3
	ring.Parent = workspace

	task.spawn(function()
		for i = 1, 15 do
			local size = 2 + i * 2 * scale
			ring.Size = Vector3.new(0.5, size, size)
			ring.Transparency = 0.3 + (i / 15) * 0.7
			task.wait(0.02)
		end
		ring:Destroy()
	end)

	for _, part in pairs(bot.character:GetDescendants()) do
		if part:IsA("BasePart") and part.Name ~= "HumanoidRootPart" then
			local oldColor = part.Color
			part.Color = Color3.fromRGB(255, 150, 50)
			task.delay(0.3, function()
				if part and part.Parent then
					part.Color = oldColor
				end
			end)
		end
	end

	task.delay(0.3, function()
		if explosion and explosion.Parent then
			explosion.Enabled = false
			task.delay(0.5, function()
				if explosion then explosion:Destroy() end
			end)
		end
	end)
end

function BotModel.createTeleportEffect(bot, startPos, endPos)
	if not bot.character then return end
	local hrp = bot.character:FindFirstChild("HumanoidRootPart")
	if not hrp then return end

	local function createZapRing(pos, expanding)
		local ring = Instance.new("Part")
		ring.Shape = Enum.PartType.Cylinder
		ring.Size = expanding and Vector3.new(0.3, 1, 1) or Vector3.new(0.3, 8, 8)
		ring.CFrame = CFrame.new(pos) * CFrame.Angles(0, 0, math.rad(90))
		ring.Anchored = true
		ring.CanCollide = false
		ring.Material = Enum.Material.Neon
		ring.Color = Color3.fromRGB(0, 255, 255)
		ring.Transparency = 0.2
		ring.Parent = workspace

		task.spawn(function()
			for i = 1, 10 do
				local size = expanding and (1 + i * 0.8) or (8 - i * 0.7)
				ring.Size = Vector3.new(0.3, size, size)
				ring.Transparency = 0.2 + (i / 10) * 0.8
				task.wait(0.02)
			end
			ring:Destroy()
		end)
	end

	local function createSparks(pos)
		local sparkPart = Instance.new("Part")
		sparkPart.Size = Vector3.new(0.1, 0.1, 0.1)
		sparkPart.Position = pos
		sparkPart.Transparency = 1
		sparkPart.Anchored = true
		sparkPart.CanCollide = false
		sparkPart.Parent = workspace

		local sparks = Instance.new("ParticleEmitter")
		sparks.Color = ColorSequence.new(Color3.fromRGB(0, 255, 255), Color3.fromRGB(255, 255, 255))
		sparks.Size = NumberSequence.new(0.3, 0)
		sparks.Lifetime = NumberRange.new(0.15, 0.3)
		sparks.Rate = 0
		sparks.Speed = NumberRange.new(5, 15)
		sparks.SpreadAngle = Vector2.new(180, 180)
		sparks.Parent = sparkPart

		sparks:Emit(30)
		game.Debris:AddItem(sparkPart, 0.5)
	end

	createZapRing(startPos, true)
	createSparks(startPos)

	for _, part in pairs(bot.character:GetDescendants()) do
		if part:IsA("BasePart") and part.Name ~= "HumanoidRootPart" then
			local oldColor = part.Color
			local oldTransparency = part.Transparency
			part.Color = Color3.fromRGB(0, 255, 255)
			part.Transparency = 0.5
			task.delay(0.15, function()
				if part and part.Parent then
					part.Color = oldColor
					part.Transparency = oldTransparency
				end
			end)
		end
	end

	task.delay(0.1, function()
		createZapRing(endPos, false)
		createSparks(endPos)
	end)
end

return BotModel
