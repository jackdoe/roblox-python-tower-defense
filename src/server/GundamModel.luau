local GundamStats = require(script.Parent.GundamStats)
local ProjectileEffects = require(script.Parent.ProjectileEffects)

local GundamModel = {}

local GROUND_Y = GundamStats.GROUND_Y

function GundamModel.create(x, z, ownerColor)
	local model = Instance.new("Model")
	model.Name = "Gundam"

	local function weldTo(part0, part1)
		local w = Instance.new("WeldConstraint")
		w.Part0 = part0
		w.Part1 = part1
		w.Parent = part0
	end

	local armorColor = Color3.fromRGB(200, 200, 210)
	local darkColor = Color3.fromRGB(50, 50, 55)
	local accentColor = ownerColor or Color3.fromRGB(0, 255, 255)

	local root = Instance.new("Part")
	root.Name = "HumanoidRootPart"
	root.Size = Vector3.new(4, 4, 4)
	root.Position = Vector3.new(x, GROUND_Y + 2, z)
	root.Transparency = 1
	root.Anchored = true
	root.CanCollide = false
	root.Parent = model
	model.PrimaryPart = root

	local basePillar = Instance.new("Part")
	basePillar.Name = "BasePillar"
	basePillar.Shape = Enum.PartType.Cylinder
	basePillar.Size = Vector3.new(3, 3.5, 3.5)
	basePillar.Position = Vector3.new(x, GROUND_Y + 1.5, z)
	basePillar.Orientation = Vector3.new(0, 0, 90)
	basePillar.Material = Enum.Material.Metal
	basePillar.Color = darkColor
	basePillar.Anchored = true
	basePillar.Parent = model

	for i = 0, 5 do
		local angle = math.rad(i * 60)
		local radius = 2.2

		local wedge = Instance.new("WedgePart")
		wedge.Name = "ArmorSkirt"
		wedge.Size = Vector3.new(2, 2.5, 2)
		wedge.Material = Enum.Material.Metal
		wedge.Color = armorColor
		wedge.Anchored = true
		wedge.CanCollide = true

		local offset = Vector3.new(math.sin(angle) * radius, GROUND_Y + 1.25, math.cos(angle) * radius)
		local pos = Vector3.new(x, 0, z) + offset

		wedge.CFrame = CFrame.lookAt(pos, Vector3.new(x, GROUND_Y, z))
		wedge.Parent = model

		local vent = Instance.new("Part")
		vent.Size = Vector3.new(0.5, 1.5, 0.2)
		vent.Color = accentColor
		vent.Material = Enum.Material.Neon
		vent.Anchored = true
		vent.CFrame = wedge.CFrame * CFrame.new(1.1, -0.5, 0.5)
		vent.Parent = model
	end

	local head = Instance.new("Part")
	head.Name = "Head"
	head.Size = Vector3.new(2.5, 2.5, 3)
	head.Position = Vector3.new(x, GROUND_Y + 3.5, z)
	head.Anchored = true
	head.CanCollide = false
	head.Material = Enum.Material.Metal
	head.Color = armorColor
	head.Parent = model

	local hatch = Instance.new("Part")
	hatch.Size = Vector3.new(1.5, 0.2, 1.5)
	hatch.Color = darkColor
	hatch.CFrame = head.CFrame * CFrame.new(0, 1.3, 0)
	hatch.Anchored = false
	hatch.CanCollide = false
	hatch.Parent = model
	weldTo(head, hatch)

	for _, side in ipairs({ -1, 1 }) do
		local ear = Instance.new("Part")
		ear.Shape = Enum.PartType.Cylinder
		ear.Size = Vector3.new(1, 2.5, 2.5)
		ear.Color = armorColor
		ear.Material = Enum.Material.Metal
		ear.Anchored = false
		ear.CanCollide = false
		ear.CFrame = head.CFrame * CFrame.new(side * 1.5, 0, 0) * CFrame.Angles(0, 0, math.rad(90))
		ear.Parent = model
		weldTo(head, ear)

		local earCap = Instance.new("Part")
		earCap.Shape = Enum.PartType.Cylinder
		earCap.Size = Vector3.new(1.1, 1.5, 1.5)
		earCap.Color = darkColor
		earCap.Material = Enum.Material.Metal
		earCap.Anchored = false
		earCap.CanCollide = false
		earCap.CFrame = head.CFrame * CFrame.new(side * 1.5, 0, 0) * CFrame.Angles(0, 0, math.rad(90))
		earCap.Parent = model
		weldTo(head, earCap)
	end

	local mantlet = Instance.new("Part")
	mantlet.Size = Vector3.new(1.2, 1.2, 1.5)
	mantlet.Color = darkColor
	mantlet.Material = Enum.Material.DiamondPlate
	mantlet.Anchored = false
	mantlet.CanCollide = false
	mantlet.CFrame = head.CFrame * CFrame.new(0, 0, -2)
	mantlet.Parent = model
	weldTo(head, mantlet)

	local barrel = Instance.new("Part")
	barrel.Name = "Barrel"
	barrel.Shape = Enum.PartType.Cylinder
	barrel.Size = Vector3.new(3, 0.8, 0.8)
	barrel.Color = armorColor
	barrel.Material = Enum.Material.Metal
	barrel.Anchored = false
	barrel.CanCollide = false
	barrel.CFrame = mantlet.CFrame * CFrame.new(0, 0, -2) * CFrame.Angles(0, math.rad(90), 0)
	barrel.Parent = model
	weldTo(head, barrel)

	local tip = Instance.new("Part")
	tip.Name = "Tip"
	tip.Shape = Enum.PartType.Cylinder
	tip.Size = Vector3.new(1, 1.2, 1.2)
	tip.Color = darkColor
	tip.Material = Enum.Material.Metal
	tip.Anchored = false
	tip.CanCollide = false
	tip.CFrame = barrel.CFrame * CFrame.new(2, 0, 0)
	tip.Parent = model
	weldTo(head, tip)

	local hole = Instance.new("Part")
	hole.Shape = Enum.PartType.Cylinder
	hole.Size = Vector3.new(0.1, 0.6, 0.6)
	hole.Color = Color3.new(0, 0, 0)
	hole.Anchored = false
	hole.CanCollide = false
	hole.CFrame = tip.CFrame * CFrame.new(0.5, 0, 0)
	hole.Parent = model
	weldTo(head, hole)

	model.Parent = workspace
	model:SetAttribute("OwnerColorR", accentColor.R)
	model:SetAttribute("OwnerColorG", accentColor.G)
	model:SetAttribute("OwnerColorB", accentColor.B)

	return model
end

local UPGRADE_COLORS = {
	Color3.fromRGB(200, 200, 210),
	Color3.fromRGB(180, 140, 100),
	Color3.fromRGB(120, 180, 120),
	Color3.fromRGB(100, 140, 200),
	Color3.fromRGB(180, 100, 180),
	Color3.fromRGB(255, 180, 80),
	Color3.fromRGB(255, 215, 0),
}

local ACCENT_COLORS = {
	Color3.fromRGB(0, 255, 255),
	Color3.fromRGB(255, 150, 0),
	Color3.fromRGB(0, 255, 100),
	Color3.fromRGB(100, 150, 255),
	Color3.fromRGB(255, 100, 255),
	Color3.fromRGB(255, 200, 50),
	Color3.fromRGB(255, 255, 100),
}

function GundamModel.applyColorUpgrade(gundam, maxBytecode)
	local character = gundam.character
	if not character then return end

	local upgradeLevel = math.floor((maxBytecode - 32) / 32) + 1
	local colorIndex = math.min(upgradeLevel, #UPGRADE_COLORS)
	local baseColor = UPGRADE_COLORS[colorIndex]
	local ownerR = character:GetAttribute("OwnerColorR")
	local ownerG = character:GetAttribute("OwnerColorG")
	local ownerB = character:GetAttribute("OwnerColorB")
	local accentColor = ownerR and Color3.new(ownerR, ownerG, ownerB) or ACCENT_COLORS[colorIndex]

	for _, part in ipairs(character:GetDescendants()) do
		if part:IsA("BasePart") and part.Name ~= "HumanoidRootPart" then
			if part.Color.R > 0.3 or part.Name == "Head" or part.Name:find("Armor") or part.Name == "Barrel" then
				part.Color = baseColor
			end
			if part.Material == Enum.Material.Neon then
				part.Color = accentColor
			end
		end
	end
end

function GundamModel.applyVisualUpgrade(gundam, cpuHz)
	local character = gundam.character
	if not character then return end

	local upgradeLevel = math.floor((cpuHz - 1) / 2 + 0.5) + 1
	local colorIndex = math.min(upgradeLevel, #UPGRADE_COLORS)
	local baseColor = UPGRADE_COLORS[colorIndex]
	local ownerR = character:GetAttribute("OwnerColorR")
	local ownerG = character:GetAttribute("OwnerColorG")
	local ownerB = character:GetAttribute("OwnerColorB")
	local accentColor = ownerR and Color3.new(ownerR, ownerG, ownerB) or ACCENT_COLORS[colorIndex]

	local head = character:FindFirstChild("Head")
	local hrp = character:FindFirstChild("HumanoidRootPart") or character.PrimaryPart
	if not head or not hrp then return end

	for _, child in ipairs(character:GetChildren()) do
		if child:GetAttribute("UpgradePart") then
			child:Destroy()
		end
	end

	for _, part in ipairs(character:GetDescendants()) do
		if part:IsA("BasePart") and part.Name ~= "HumanoidRootPart" and not part:GetAttribute("UpgradePart") then
			if part.Color.R > 0.3 or part.Name == "Head" or part.Name:find("Armor") or part.Name == "Barrel" then
				part.Color = baseColor
			end
			if part.Material == Enum.Material.Neon then
				part.Color = accentColor
			end
		end
	end

	local function weldToHead(part)
		part:SetAttribute("UpgradePart", true)
		part.Anchored = false
		part.CanCollide = false
		local weld = Instance.new("WeldConstraint")
		weld.Part0 = head
		weld.Part1 = part
		weld.Parent = part
	end

	if upgradeLevel >= 2 then
		local leftCannon = Instance.new("Part")
		leftCannon.Name = "LeftAutocannon"
		leftCannon.Shape = Enum.PartType.Cylinder
		leftCannon.Size = Vector3.new(4, 0.6, 0.6)
		leftCannon.Material = Enum.Material.Metal
		leftCannon.Color = Color3.fromRGB(50, 50, 55)
		leftCannon.CFrame = head.CFrame * CFrame.new(-0.6, 0.2, -3.5) * CFrame.Angles(0, math.rad(90), 0)
		leftCannon.Parent = character
		weldToHead(leftCannon)

		local rightCannon = Instance.new("Part")
		rightCannon.Name = "RightAutocannon"
		rightCannon.Shape = Enum.PartType.Cylinder
		rightCannon.Size = Vector3.new(4, 0.6, 0.6)
		rightCannon.Material = Enum.Material.Metal
		rightCannon.Color = Color3.fromRGB(50, 50, 55)
		rightCannon.CFrame = head.CFrame * CFrame.new(0.6, 0.2, -3.5) * CFrame.Angles(0, math.rad(90), 0)
		rightCannon.Parent = character
		weldToHead(rightCannon)

		for _, xOff in ipairs({-0.6, 0.6}) do
			local muzzle = Instance.new("Part")
			muzzle.Name = "AutocannonMuzzle"
			muzzle.Shape = Enum.PartType.Cylinder
			muzzle.Size = Vector3.new(0.3, 0.8, 0.8)
			muzzle.Material = Enum.Material.Neon
			muzzle.Color = accentColor
			muzzle.CFrame = head.CFrame * CFrame.new(xOff, 0.2, -5.7) * CFrame.Angles(0, math.rad(90), 0)
			muzzle.Parent = character
			weldToHead(muzzle)
		end

		local legAngles = {
			{x = -1.3, z = 1.0, rot = math.rad(135)},
			{x = 1.3, z = 1.0, rot = math.rad(-135)},
			{x = -1.5, z = -0.5, rot = math.rad(45)},
			{x = 1.5, z = -0.5, rot = math.rad(-45)},
		}

		for i, legData in ipairs(legAngles) do
			local hip = Instance.new("Part")
			hip.Name = "SpiderHip_" .. i
			hip.Shape = Enum.PartType.Ball
			hip.Size = Vector3.new(0.5, 0.5, 0.5)
			hip.Material = Enum.Material.Metal
			hip.Color = Color3.fromRGB(40, 40, 45)
			hip.CFrame = head.CFrame * CFrame.new(legData.x, -0.3, legData.z)
			hip.Parent = character
			weldToHead(hip)

			local upperLeg = Instance.new("Part")
			upperLeg.Name = "SpiderUpperLeg_" .. i
			upperLeg.Size = Vector3.new(0.3, 2.0, 0.3)
			upperLeg.Material = Enum.Material.DiamondPlate
			upperLeg.Color = baseColor
			local legCFrame = hip.CFrame * CFrame.Angles(0, legData.rot, math.rad(30)) * CFrame.new(0, -1, 0)
			upperLeg.CFrame = legCFrame
			upperLeg.Parent = character
			weldToHead(upperLeg)

			local knee = Instance.new("Part")
			knee.Name = "SpiderKnee_" .. i
			knee.Shape = Enum.PartType.Ball
			knee.Size = Vector3.new(0.4, 0.4, 0.4)
			knee.Material = Enum.Material.Neon
			knee.Color = accentColor
			knee.CFrame = legCFrame * CFrame.new(0, -1.1, 0)
			knee.Parent = character
			weldToHead(knee)

			local lowerLeg = Instance.new("Part")
			lowerLeg.Name = "SpiderLowerLeg_" .. i
			lowerLeg.Size = Vector3.new(0.25, 2.5, 0.25)
			lowerLeg.Material = Enum.Material.Metal
			lowerLeg.Color = Color3.fromRGB(60, 60, 65)
			local lowerCFrame = knee.CFrame * CFrame.Angles(math.rad(45), 0, 0) * CFrame.new(0, -1.25, 0)
			lowerLeg.CFrame = lowerCFrame
			lowerLeg.Parent = character
			weldToHead(lowerLeg)

			local foot = Instance.new("Part")
			foot.Name = "SpiderFoot_" .. i
			foot.Size = Vector3.new(0.15, 0.4, 0.15)
			foot.Material = Enum.Material.Metal
			foot.Color = Color3.fromRGB(30, 30, 35)
			foot.CFrame = lowerCFrame * CFrame.new(0, -1.4, 0)
			foot.Parent = character
			weldToHead(foot)
		end

		local stripe = Instance.new("Part")
		stripe.Name = "CautionStripe"
		stripe.Size = Vector3.new(2.6, 0.15, 0.15)
		stripe.Material = Enum.Material.Neon
		stripe.Color = accentColor
		stripe.CFrame = head.CFrame * CFrame.new(0, 1.3, 0)
		stripe.Parent = character
		weldToHead(stripe)
	end

	if upgradeLevel >= 3 then
		local gatlingBase = Instance.new("Part")
		gatlingBase.Name = "GatlingHousing"
		gatlingBase.Shape = Enum.PartType.Cylinder
		gatlingBase.Size = Vector3.new(2.5, 1.8, 1.8)
		gatlingBase.Material = Enum.Material.DiamondPlate
		gatlingBase.Color = Color3.fromRGB(50, 55, 45)
		gatlingBase.CFrame = head.CFrame * CFrame.new(0, 0.1, -2.5) * CFrame.Angles(0, math.rad(90), 0)
		gatlingBase.Parent = character
		weldToHead(gatlingBase)

		local barrelOffsets = {
			{y = 0.5, x = 0},
			{y = -0.25, x = -0.4},
			{y = -0.25, x = 0.4},
		}

		for i, offset in ipairs(barrelOffsets) do
			local gBarrel = Instance.new("Part")
			gBarrel.Name = "GatlingBarrel_" .. i
			gBarrel.Shape = Enum.PartType.Cylinder
			gBarrel.Size = Vector3.new(5, 0.5, 0.5)
			gBarrel.Material = Enum.Material.Metal
			gBarrel.Color = Color3.fromRGB(40, 42, 38)
			gBarrel.CFrame = head.CFrame * CFrame.new(offset.x, offset.y, -5) * CFrame.Angles(0, math.rad(90), 0)
			gBarrel.Parent = character
			weldToHead(gBarrel)

			local muzzleRing = Instance.new("Part")
			muzzleRing.Name = "GatlingMuzzle_" .. i
			muzzleRing.Shape = Enum.PartType.Cylinder
			muzzleRing.Size = Vector3.new(0.2, 0.7, 0.7)
			muzzleRing.Material = Enum.Material.Neon
			muzzleRing.Color = accentColor
			muzzleRing.CFrame = head.CFrame * CFrame.new(offset.x, offset.y, -7.6) * CFrame.Angles(0, math.rad(90), 0)
			muzzleRing.Parent = character
			weldToHead(muzzleRing)
		end

		for _, side in ipairs({-1, 1}) do
			local tankArmor = Instance.new("WedgePart")
			tankArmor.Name = "TankArmor_" .. side
			tankArmor.Size = Vector3.new(1.2, 2.5, 3.5)
			tankArmor.Material = Enum.Material.DiamondPlate
			tankArmor.Color = baseColor
			tankArmor.CFrame = head.CFrame * CFrame.new(side * 2.2, 0.2, 0) * CFrame.Angles(0, side * math.rad(90), 0)
			tankArmor.Parent = character
			weldToHead(tankArmor)

			local hazardStripe = Instance.new("Part")
			hazardStripe.Name = "HazardStripe_" .. side
			hazardStripe.Size = Vector3.new(0.1, 0.4, 3.2)
			hazardStripe.Material = Enum.Material.Neon
			hazardStripe.Color = accentColor
			hazardStripe.CFrame = head.CFrame * CFrame.new(side * 2.85, 0.8, 0)
			hazardStripe.Parent = character
			weldToHead(hazardStripe)
		end

		local radarBox = Instance.new("Part")
		radarBox.Name = "RadarBox"
		radarBox.Size = Vector3.new(1.5, 0.8, 1.2)
		radarBox.Material = Enum.Material.Metal
		radarBox.Color = Color3.fromRGB(45, 50, 40)
		radarBox.CFrame = head.CFrame * CFrame.new(0, 1.8, 0.5)
		radarBox.Parent = character
		weldToHead(radarBox)

		local smallDish = Instance.new("Part")
		smallDish.Name = "RadarDish"
		smallDish.Shape = Enum.PartType.Cylinder
		smallDish.Size = Vector3.new(0.1, 1.0, 1.0)
		smallDish.Material = Enum.Material.Neon
		smallDish.Color = accentColor
		smallDish.CFrame = radarBox.CFrame * CFrame.new(0, 0.5, 0) * CFrame.Angles(0, 0, math.rad(90))
		smallDish.Parent = character
		weldToHead(smallDish)

		for _, zOff in ipairs({-0.8, 0.8}) do
			local vent = Instance.new("Part")
			vent.Name = "ExhaustVent"
			vent.Size = Vector3.new(0.6, 0.3, 0.6)
			vent.Material = Enum.Material.DiamondPlate
			vent.Color = Color3.fromRGB(30, 30, 35)
			vent.CFrame = head.CFrame * CFrame.new(0, 1.4, zOff + 1.2)
			vent.Parent = character
			weldToHead(vent)
		end

		local beacon = Instance.new("Part")
		beacon.Name = "WarningBeacon"
		beacon.Shape = Enum.PartType.Cylinder
		beacon.Size = Vector3.new(0.4, 0.5, 0.5)
		beacon.Material = Enum.Material.Neon
		beacon.Color = accentColor
		beacon.Transparency = 0.2
		beacon.CFrame = radarBox.CFrame * CFrame.new(0.6, 0.5, 0) * CFrame.Angles(0, 0, math.rad(90))
		beacon.Parent = character
		weldToHead(beacon)
	end
end

function GundamModel.createBillboard(gundam)
	local character = gundam.character
	local hrp = character:FindFirstChild("HumanoidRootPart") or character.PrimaryPart
	if not hrp then return end

	local ownerColor = Color3.fromRGB(
		(character:GetAttribute("OwnerColorR") or 0) * 255,
		(character:GetAttribute("OwnerColorG") or 1) * 255,
		(character:GetAttribute("OwnerColorB") or 1) * 255
	)

	local billboard = Instance.new("BillboardGui")
	billboard.Name = "GundamBillboard"
	billboard.Size = UDim2.new(0, 120, 0, 60)
	billboard.StudsOffset = Vector3.new(0, 5, 0)
	billboard.AlwaysOnTop = true
	billboard.Parent = hrp

	local bg = Instance.new("Frame")
	bg.Name = "Background"
	bg.Size = UDim2.new(1, 0, 1, 0)
	bg.BackgroundColor3 = Color3.fromRGB(20, 20, 30)
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
	idLabel.Text = gundam.name or "G_?.py"
	idLabel.TextColor3 = ownerColor
	idLabel.Font = Enum.Font.GothamBold
	idLabel.TextSize = 12
	idLabel.TextXAlignment = Enum.TextXAlignment.Left
	idLabel.Parent = bg

	local statusLabel = Instance.new("TextLabel")
	statusLabel.Name = "StatusLabel"
	statusLabel.Size = UDim2.new(0.6, 0, 0.3, 0)
	statusLabel.Position = UDim2.new(0.35, 0, 0.05, 0)
	statusLabel.BackgroundTransparency = 1
	statusLabel.Text = "IDLE"
	statusLabel.TextColor3 = Color3.fromRGB(150, 150, 150)
	statusLabel.Font = Enum.Font.Code
	statusLabel.TextSize = 10
	statusLabel.TextXAlignment = Enum.TextXAlignment.Right
	statusLabel.Parent = bg

	local powerBg = Instance.new("Frame")
	powerBg.Name = "PowerBarBg"
	powerBg.Size = UDim2.new(0.9, 0, 0.15, 0)
	powerBg.Position = UDim2.new(0.05, 0, 0.4, 0)
	powerBg.BackgroundColor3 = Color3.fromRGB(40, 40, 40)
	powerBg.BorderSizePixel = 0
	powerBg.Parent = bg

	local powerBar = Instance.new("Frame")
	powerBar.Name = "PowerBar"
	powerBar.Size = UDim2.new(1, 0, 1, 0)
	powerBar.BackgroundColor3 = Color3.fromRGB(255, 150, 50)
	powerBar.BorderSizePixel = 0
	powerBar.Parent = powerBg

	local ammoBg = Instance.new("Frame")
	ammoBg.Name = "AmmoBarBg"
	ammoBg.Size = UDim2.new(0.9, 0, 0.15, 0)
	ammoBg.Position = UDim2.new(0.05, 0, 0.6, 0)
	ammoBg.BackgroundColor3 = Color3.fromRGB(40, 40, 40)
	ammoBg.BorderSizePixel = 0
	ammoBg.Parent = bg

	local ammoBar = Instance.new("Frame")
	ammoBar.Name = "AmmoBar"
	ammoBar.Size = UDim2.new(1, 0, 1, 0)
	ammoBar.BackgroundColor3 = Color3.fromRGB(100, 150, 255)
	ammoBar.BorderSizePixel = 0
	ammoBar.Parent = ammoBg

	local powerLabel = Instance.new("TextLabel")
	powerLabel.Name = "PowerLabel"
	powerLabel.Size = UDim2.new(1, 0, 0.2, 0)
	powerLabel.Position = UDim2.new(0, 0, 0.78, 0)
	powerLabel.BackgroundTransparency = 1
	powerLabel.Text = "1.0x @ 40"
	powerLabel.TextColor3 = Color3.fromRGB(180, 180, 180)
	powerLabel.Font = Enum.Font.Code
	powerLabel.TextSize = 9
	powerLabel.Parent = bg

	gundam.billboard = billboard
end

function GundamModel.updateBillboard(gundam)
	local billboard = gundam.billboard
	if not billboard then return end

	local interp = gundam.interpreter
	local bg = billboard:FindFirstChild("Background")
	if not bg then return end

	local cpuHz = interp and interp.cpuHz or 1
	local upgradeLevel = math.floor((cpuHz - 1) / 2 + 0.5) + 1

	local idLabel = bg:FindFirstChild("IdLabel")
	if idLabel then
		idLabel.Text = gundam.name or "G_?.py"
		if upgradeLevel >= 3 then
			idLabel.TextColor3 = Color3.fromRGB(255, 150, 220)
		elseif upgradeLevel >= 2 then
			idLabel.TextColor3 = Color3.fromRGB(100, 200, 255)
		else
			idLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
		end
	end

	local statusLabel = bg:FindFirstChild("StatusLabel")
	if statusLabel then
		local errorMsg = type(interp.error) == "table" and interp.error.message or interp.error
		if errorMsg and errorMsg ~= "" then
			statusLabel.Text = "ERR: " .. tostring(errorMsg):sub(1, 25)
			statusLabel.TextColor3 = Color3.fromRGB(255, 100, 100)
		elseif interp.status == "RUNNING" then
			statusLabel.Text = "RUNNING"
			statusLabel.TextColor3 = Color3.fromRGB(100, 255, 100)
		elseif interp.ammo <= 0 then
			statusLabel.Text = "EMPTY"
			statusLabel.TextColor3 = Color3.fromRGB(255, 100, 100)
		elseif interp.target then
			statusLabel.Text = "FIRING"
			statusLabel.TextColor3 = Color3.fromRGB(255, 200, 100)
		else
			statusLabel.Text = "IDLE"
			statusLabel.TextColor3 = Color3.fromRGB(150, 150, 150)
		end
	end

	local powerBarBg = bg:FindFirstChild("PowerBarBg")
	if powerBarBg then
		local powerBar = powerBarBg:FindFirstChild("PowerBar")
		if powerBar then
			local currentRange = interp.dynamicRange or 40
			local powerMultiplier = 40 / currentRange
			local barRatio = math.clamp((60 - currentRange) / 50, 0, 1)
			powerBar.Size = UDim2.new(barRatio, 0, 1, 0)

			if powerMultiplier >= 2 then
				powerBar.BackgroundColor3 = Color3.fromRGB(255, 100, 100)
			elseif powerMultiplier >= 1 then
				powerBar.BackgroundColor3 = Color3.fromRGB(255, 200, 100)
			else
				powerBar.BackgroundColor3 = Color3.fromRGB(100, 200, 255)
			end
		end
	end

	local ammoBarBg = bg:FindFirstChild("AmmoBarBg")
	if ammoBarBg then
		local ammoBar = ammoBarBg:FindFirstChild("AmmoBar")
		if ammoBar then
			local ratio = interp.ammo / interp.maxAmmo
			ammoBar.Size = UDim2.new(ratio, 0, 1, 0)
			if ratio > 0.3 then
				ammoBar.BackgroundColor3 = Color3.fromRGB(100, 150, 255)
			else
				ammoBar.BackgroundColor3 = Color3.fromRGB(255, 100, 100)
			end
		end
	end

	local powerLabel = bg:FindFirstChild("PowerLabel")
	if powerLabel then
		local currentRange = interp.dynamicRange or 40
		local powerMultiplier = 40 / currentRange
		powerLabel.Text = string.format("%.1fx @ %d", powerMultiplier, currentRange)
	end
end

function GundamModel.applyPowerScale(gundam, power)
	local character = gundam.character
	if not character then return end

	local scale = 1 + (power - 1) * 0.1
	character:ScaleTo(scale)
end

function GundamModel.createMuzzleFlash(gundam, targetPos, ammoStats)
	local character = gundam.character
	local barrel = character:FindFirstChild("Barrel")
	local tip = character:FindFirstChild("Tip")
	local origin = tip and tip.Position or (barrel and barrel.Position) or character.PrimaryPart.Position

	ProjectileEffects.shot(origin, targetPos, ammoStats or {})
end

return GundamModel
