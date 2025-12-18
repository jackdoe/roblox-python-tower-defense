-- Effects.luau
-- Visual effects for combat, loot, etc.

local TweenService = game:GetService("TweenService")
local Debris = game:GetService("Debris")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local SoundConfig = require(ReplicatedStorage:WaitForChild("PythonTD"):WaitForChild("SoundConfig"))
local UITheme = require(script.Parent.UI.UITheme)

local Effects = {}

--============================================================================
-- PART CACHE (Object Pooling to reduce GC)
-- Instead of creating/destroying parts, we recycle them
--============================================================================

local partCache = {}
local MAX_CACHE_SIZE = 200  -- Don't cache more than this

local function getPooledPart()
	if #partCache > 0 then
		local part = table.remove(partCache)
		part.Transparency = 0
		part.Parent = workspace
		return part
	else
		local p = Instance.new("Part")
		p.Anchored = true
		p.CanCollide = false
		return p
	end
end

local function recyclePart(part, delayTime)
	task.delay(delayTime, function()
		if part and part.Parent then
			part.Transparency = 1
			part.CFrame = CFrame.new(0, -1000, 0)  -- Move far away
			part.Parent = nil  -- Remove from workspace

			-- Only cache if we haven't exceeded max
			if #partCache < MAX_CACHE_SIZE then
				table.insert(partCache, part)
			else
				part:Destroy()  -- Actually destroy if cache is full
			end
		end
	end)
end

-- Play a player sound using SoundConfig (2D, for UI sounds)
local function playPlayerSound(soundName)
	local config = SoundConfig.Player
	if config and config[soundName] then
		SoundConfig.playSound(config[soundName], config[soundName .. "Volume"] or 0.5, workspace)
	end
end

-- Play a player sound at a specific 3D position (spatial, for combat)
local function playPlayerSoundAt(soundName, position)
	local config = SoundConfig.Player
	if config and config[soundName] and position then
		SoundConfig.playSpatialSound(config[soundName], position, config[soundName .. "Volume"] or 0.5)
	end
end

-- Attack hit effect (AOE circle swing) - subtle version
function Effects.attackHit(data)
	if not data.targetPos then return end

	-- Play attack sound at the target position (spatial 3D sound)
	-- This uses distance falloff so sounds fade when far away
	local hitCount = data.hitCount or 0
	if hitCount > 0 then
		playPlayerSoundAt("AttackHit", data.targetPos)
	else
		playPlayerSoundAt("AttackMiss", data.targetPos)
	end

	-- Blood splatter when hitting (using object pool to reduce GC)
	if hitCount > 0 and data.targetPos then
		local bloodColors = {
			Color3.fromRGB(139, 0, 0),    -- Dark red
			Color3.fromRGB(180, 20, 20),  -- Medium red
			Color3.fromRGB(100, 0, 0),    -- Very dark red
		}

		-- Big blood spray particles (20-30 particles) - splatter outward
		local particleCount = 20 + math.random(10)
		for i = 1, particleCount do
			local blood = getPooledPart()
			blood.Name = "Blood"
			-- Varied sizes for more organic look
			local size = math.random() * 0.3 + 0.15
			blood.Size = Vector3.new(size, size, size)
			blood.Shape = Enum.PartType.Ball
			blood.CFrame = CFrame.new(data.targetPos + Vector3.new(
				(math.random() - 0.5) * 0.5,
				1.2 + (math.random() - 0.5) * 0.3,
				(math.random() - 0.5) * 0.5
			))
			blood.Material = Enum.Material.SmoothPlastic
			blood.Color = bloodColors[math.random(#bloodColors)]
			blood.Transparency = 0

			-- Splatter outward and slightly down - more horizontal spread
			local angle = math.random() * math.pi * 2
			local upward = math.random() * 0.8 - 0.4  -- Mostly flat, slight up/down
			local spread = math.random() * 4 + 2  -- More horizontal spread
			local targetPos = data.targetPos + Vector3.new(
				math.cos(angle) * spread,
				upward,
				math.sin(angle) * spread
			)

			-- Varied timing for organic feel
			local duration = 0.25 + math.random() * 0.15
			local bloodTween = TweenService:Create(blood, TweenInfo.new(duration, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
				CFrame = CFrame.new(targetPos),
				Size = Vector3.new(0.08, 0.08, 0.08),
				Transparency = 1
			})
			bloodTween:Play()
			recyclePart(blood, duration + 0.1)
		end

		-- Blood splat on ground (keep using Debris for long-lived parts)
		local splat = Instance.new("Part")
		splat.Name = "BloodSplat"
		splat.Size = Vector3.new(2 + math.random() * 2, 0.05, 2 + math.random() * 2)
		splat.CFrame = CFrame.new(data.targetPos.X, 0.03, data.targetPos.Z) * CFrame.Angles(0, math.random() * math.pi * 2, 0)
		splat.Anchored = true
		splat.CanCollide = false
		splat.Material = Enum.Material.SmoothPlastic
		splat.Color = Color3.fromRGB(100, 0, 0)
		splat.Transparency = 0.3
		splat.Parent = workspace

		-- Fade out the splat over time
		local splatTween = TweenService:Create(splat, TweenInfo.new(3, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {
			Transparency = 1,
			Size = Vector3.new(splat.Size.X * 1.2, 0.05, splat.Size.Z * 1.2)
		})
		task.delay(2, function()
			splatTween:Play()
		end)
		Debris:AddItem(splat, 5)

		-- Extra burst of tiny droplets - fast outward spray (using pool)
		for i = 1, 15 do
			local droplet = getPooledPart()
			droplet.Name = "BloodDroplet"
			droplet.Size = Vector3.new(0.12, 0.12, 0.12)
			droplet.Shape = Enum.PartType.Ball
			droplet.CFrame = CFrame.new(data.targetPos + Vector3.new(0, 1.2, 0))
			droplet.Material = Enum.Material.Neon
			droplet.Color = Color3.fromRGB(200, 30, 30)
			droplet.Transparency = 0

			-- Fast outward spray with slight arc
			local angle = math.random() * math.pi * 2
			local spread = math.random() * 5 + 3  -- Far horizontal spread
			local landPos = data.targetPos + Vector3.new(
				math.cos(angle) * spread,
				0.05,
				math.sin(angle) * spread
			)

			-- Single outward arc motion
			local duration = 0.2 + math.random() * 0.15
			local dropTween = TweenService:Create(droplet, TweenInfo.new(duration, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
				CFrame = CFrame.new(landPos),
				Size = Vector3.new(0.05, 0.05, 0.05),
				Transparency = 1
			})
			dropTween:Play()
			recyclePart(droplet, duration + 0.1)
		end
	end

	-- Floating damage number
	if hitCount > 0 then
		local damage = data.damage or 0
		local anchor = Instance.new("Part")
		anchor.Size = Vector3.new(0.1, 0.1, 0.1)
		-- Random horizontal offset so numbers don't stack
		local offsetX = (math.random() - 0.5) * 1.5
		local offsetZ = (math.random() - 0.5) * 1.5
		anchor.CFrame = CFrame.new(data.targetPos + Vector3.new(offsetX, 2.5, offsetZ))
		anchor.Anchored = true
		anchor.CanCollide = false
		anchor.Transparency = 1
		anchor.Parent = workspace

		local billboard = Instance.new("BillboardGui")
		billboard.Size = UDim2.new(0, 80, 0, 40)
		billboard.StudsOffset = Vector3.new(0, 0, 0)
		billboard.Adornee = anchor
		billboard.AlwaysOnTop = true  -- Always visible
		billboard.Parent = anchor

		-- Color based on damage type or amount
		local textColor = Color3.fromRGB(255, 255, 100)  -- Default yellow
		local textSize = 18

		if data.isKill then
			textColor = Color3.fromRGB(255, 80, 80)  -- Red for kills
			textSize = 24
		elseif data.isCrit or damage >= 50 then
			textColor = Color3.fromRGB(255, 150, 50)  -- Orange for big hits
			textSize = 22
		elseif data.damageType == "ice" or data.damageType == "freeze" then
			textColor = Color3.fromRGB(100, 200, 255)  -- Cyan for ice
		elseif data.damageType == "laser" then
			textColor = Color3.fromRGB(255, 100, 100)  -- Red for laser
		elseif data.damageType == "rocket" or data.damageType == "grenade" then
			textColor = Color3.fromRGB(255, 150, 50)  -- Orange for explosives
		end

		local hitLabel = Instance.new("TextLabel")
		hitLabel.Size = UDim2.new(1, 0, 1, 0)
		hitLabel.BackgroundTransparency = 1
		hitLabel.Text = tostring(damage)
		hitLabel.TextColor3 = textColor
		hitLabel.TextStrokeTransparency = 0
		hitLabel.TextStrokeColor3 = Color3.new(0, 0, 0)
		hitLabel.Font = UITheme.FONT
		hitLabel.TextSize = textSize
		hitLabel.TextScaled = false
		hitLabel.Parent = billboard

		-- Pop-up and float animation
		task.spawn(function()
			-- Initial pop (scale up quickly)
			local startSize = textSize
			hitLabel.TextSize = startSize * 0.5
			for i = 1, 4 do
				hitLabel.TextSize = startSize * (0.5 + i * 0.15)
				task.wait(0.02)
			end
			hitLabel.TextSize = startSize

			-- Float up and fade
			for j = 1, 20 do
				anchor.CFrame = anchor.CFrame + Vector3.new(0, 0.06, 0)
				hitLabel.TextTransparency = j / 20
				hitLabel.TextStrokeTransparency = j / 20
				task.wait(0.025)
			end
			anchor:Destroy()
		end)
	end

	-- Kill effect (using pool)
	if data.isKill then
		-- Burst particles
		for i = 1, 8 do
			local particle = getPooledPart()
			particle.Size = Vector3.new(0.3, 0.3, 0.3)
			particle.Shape = Enum.PartType.Ball
			particle.CFrame = CFrame.new(data.targetPos)
			particle.Material = Enum.Material.Neon
			particle.Color = Color3.fromRGB(255, 100, 100)
			particle.Transparency = 0

			local angle = (i / 8) * math.pi * 2
			local targetPos = data.targetPos + Vector3.new(math.cos(angle) * 3, 1, math.sin(angle) * 3)

			local particleTween = TweenService:Create(particle, TweenInfo.new(0.4, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
				CFrame = CFrame.new(targetPos),
				Transparency = 1,
				Size = Vector3.new(0.1, 0.1, 0.1)
			})
			particleTween:Play()

			recyclePart(particle, 0.5)
		end
	end
end

--============================================================================
-- UPGRADE EFFECTS
--============================================================================

function Effects.gundamUpgrade(position, tier, color)
	if not position then return end

	tier = tier or 2
	-- Industrial color scheme based on tier
	if not color then
		if tier >= 3 then
			color = Color3.fromRGB(255, 220, 50)   -- Hazard Yellow for Dreadnought
		else
			color = Color3.fromRGB(255, 150, 0)    -- Industrial Orange for Arachnid
		end
	end

	-- 1. MASSIVE Energy Pillar (Sci-Fi Beam shooting to sky)
	task.spawn(function()
		local pillar = getPooledPart()
		pillar.Name = "UpgradePillar"
		pillar.Shape = Enum.PartType.Cylinder
		pillar.Size = Vector3.new(1, 80, 80)  -- Start huge
		pillar.CFrame = CFrame.new(position) * CFrame.Angles(0, 0, math.rad(90))
		pillar.Material = Enum.Material.Neon
		pillar.Color = color
		pillar.Transparency = 0.2

		-- Quick flash then shrink width rapidly (beam going to sky effect)
		local tween = TweenService:Create(pillar, TweenInfo.new(0.6, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
			Size = Vector3.new(100, 0.1, 0.1),  -- Very tall, very thin
			Transparency = 1
		})
		tween:Play()
		recyclePart(pillar, 0.7)
	end)

	-- 2. Rising Scanner Rings (3 rings that rise and shrink)
	task.spawn(function()
		for i = 1, 3 do
			local ring = getPooledPart()
			ring.Shape = Enum.PartType.Cylinder
			ring.Size = Vector3.new(0.3, 14, 14)
			ring.CFrame = CFrame.new(position - Vector3.new(0, 4, 0)) * CFrame.Angles(0, 0, math.rad(90))
			ring.Material = Enum.Material.Neon
			ring.Color = color
			ring.Transparency = 0

			local tween = TweenService:Create(ring, TweenInfo.new(1.0, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
				CFrame = CFrame.new(position + Vector3.new(0, 18, 0)) * CFrame.Angles(0, 0, math.rad(90)),
				Size = Vector3.new(0.2, 0.5, 0.5),  -- Shrink as it rises
				Transparency = 1
			})
			tween:Play()
			recyclePart(ring, 1.1)
			task.wait(0.12)
		end
	end)

	-- 3. Sparkle particles rising upward (more dramatic)
	task.spawn(function()
		local particleCount = 20 + tier * 8  -- More particles for higher tiers
		for i = 1, particleCount do
			task.delay(i * 0.015, function()
				local spark = getPooledPart()
				spark.Name = "UpgradeSpark"
				spark.Shape = Enum.PartType.Ball
				spark.Size = Vector3.new(0.5, 0.5, 0.5)
				spark.Material = Enum.Material.Neon
				spark.Color = color
				spark.Transparency = 0

				-- Random starting position around the gundam
				local angle = math.random() * math.pi * 2
				local radius = math.random() * 3
				local startPos = position + Vector3.new(
					math.cos(angle) * radius,
					math.random() * 2 - 1,
					math.sin(angle) * radius
				)
				spark.CFrame = CFrame.new(startPos)

				-- Rise upward with spiral
				local endPos = startPos + Vector3.new(
					math.cos(angle + math.pi * 2) * 1,
					10 + math.random() * 6,
					math.sin(angle + math.pi * 2) * 1
				)

				local sparkTween = TweenService:Create(spark, TweenInfo.new(0.5 + math.random() * 0.4, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
					CFrame = CFrame.new(endPos),
					Size = Vector3.new(0.05, 0.05, 0.05),
					Transparency = 1
				})
				sparkTween:Play()
				recyclePart(spark, 1)
			end)
		end
	end)

	-- 4. Ground shockwave (expanding circle)
	task.spawn(function()
		local wave = getPooledPart()
		wave.Shape = Enum.PartType.Ball
		wave.Size = Vector3.new(2, 2, 2)
		wave.CFrame = CFrame.new(position)
		wave.Material = Enum.Material.Neon
		wave.Color = color
		wave.Transparency = 0.4

		local size = tier >= 3 and 35 or 25
		local waveTween = TweenService:Create(wave, TweenInfo.new(0.5, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
			Size = Vector3.new(size, size, size),
			Transparency = 1
		})
		waveTween:Play()
		recyclePart(wave, 0.6)
	end)

	-- 5. Extra shockwave ring for tier 3
	if tier >= 3 then
		task.spawn(function()
			task.wait(0.15)
			local wave2 = getPooledPart()
			wave2.Shape = Enum.PartType.Cylinder
			wave2.Size = Vector3.new(0.2, 5, 5)
			wave2.CFrame = CFrame.new(position.X, position.Y + 0.5, position.Z) * CFrame.Angles(0, 0, math.rad(90))
			wave2.Material = Enum.Material.Neon
			wave2.Color = color
			wave2.Transparency = 0.3

			local wave2Tween = TweenService:Create(wave2, TweenInfo.new(0.7, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
				Size = Vector3.new(0.05, 45, 45),
				Transparency = 1
			})
			wave2Tween:Play()
			recyclePart(wave2, 0.8)
		end)
	end

	-- 6. Floating tier text (pop in and float up)
	task.spawn(function()
		local anchor = Instance.new("Part")
		anchor.Size = Vector3.new(0.1, 0.1, 0.1)
		anchor.CFrame = CFrame.new(position + Vector3.new(0, 5, 0))
		anchor.Anchored = true
		anchor.CanCollide = false
		anchor.Transparency = 1
		anchor.Parent = workspace

		local billboard = Instance.new("BillboardGui")
		billboard.Size = UDim2.new(0, 200, 0, 60)
		billboard.AlwaysOnTop = true
		billboard.Parent = anchor

		local tierNames = {"", "ARACHNID", "DREADNOUGHT"}
		local text = Instance.new("TextLabel")
		text.Size = UDim2.new(1, 0, 1, 0)
		text.BackgroundTransparency = 1
		text.Text = tierNames[tier] or ("TIER " .. tier)
		text.TextColor3 = color
		text.TextStrokeTransparency = 0
		text.TextStrokeColor3 = Color3.new(0, 0, 0)
		text.Font = UITheme.FONT
		text.TextSize = 0  -- Start at 0 for pop effect
		text.TextScaled = false
		text.Parent = billboard

		-- Pop in effect
		local popTween = TweenService:Create(text, TweenInfo.new(0.25, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
			TextSize = 32
		})
		popTween:Play()

		-- Float up
		local floatTween = TweenService:Create(anchor, TweenInfo.new(1.5, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
			CFrame = anchor.CFrame + Vector3.new(0, 10, 0)
		})
		floatTween:Play()

		-- Fade out after a delay
		task.delay(0.8, function()
			local fadeTween = TweenService:Create(text, TweenInfo.new(0.5), {
				TextTransparency = 1,
				TextStrokeTransparency = 1
			})
			fadeTween:Play()
		end)

		Debris:AddItem(anchor, 2)
	end)
end

--============================================================================
-- SCRAP DEPOSIT EFFECT
--============================================================================

function Effects.scrapDeposit(fromPos, toPos, amount)
	if not fromPos or not toPos then return end
	amount = math.min(amount or 1, 10)

	local scrapColor = Color3.fromRGB(255, 200, 50)

	for i = 1, amount do
		task.delay((i - 1) * 0.05, function()
			local particle = getPooledPart()
			particle.Name = "ScrapParticle"
			particle.Shape = Enum.PartType.Ball
			particle.Size = Vector3.new(0.8, 0.8, 0.8)
			particle.Material = Enum.Material.Neon
			particle.Color = scrapColor
			particle.Transparency = 0

			local offset = Vector3.new(
				(math.random() - 0.5) * 2,
				math.random() * 1,
				(math.random() - 0.5) * 2
			)
			particle.CFrame = CFrame.new(fromPos + offset)

			local arcHeight = (fromPos - toPos).Magnitude * 0.3
			local midPoint = (fromPos + toPos) / 2 + Vector3.new(0, arcHeight, 0)

			task.spawn(function()
				local duration = 0.4
				local steps = 20
				for j = 1, steps do
					local t = j / steps
					local t1 = 1 - t
					local pos = t1 * t1 * fromPos + 2 * t1 * t * midPoint + t * t * toPos
					particle.CFrame = CFrame.new(pos)
					particle.Size = Vector3.new(0.8 - t * 0.5, 0.8 - t * 0.5, 0.8 - t * 0.5)
					particle.Transparency = t * 0.5
					task.wait(duration / steps)
				end
			end)

			recyclePart(particle, 0.5)
		end)
	end

	task.delay(amount * 0.05 + 0.3, function()
		local flash = getPooledPart()
		flash.Shape = Enum.PartType.Ball
		flash.Size = Vector3.new(1, 1, 1)
		flash.CFrame = CFrame.new(toPos)
		flash.Material = Enum.Material.Neon
		flash.Color = scrapColor
		flash.Transparency = 0.3

		local flashTween = TweenService:Create(flash, TweenInfo.new(0.3, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
			Size = Vector3.new(4, 4, 4),
			Transparency = 1
		})
		flashTween:Play()
		recyclePart(flash, 0.4)
	end)
end

return Effects
