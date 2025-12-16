local TweenService = game:GetService("TweenService")

local ProjectileEffects = {}

function ProjectileEffects.flash(position, color, startSize, endSize, duration)
	startSize = startSize or 1
	endSize = endSize or 3
	duration = duration or 0.1
	color = color or Color3.fromRGB(255, 255, 200)

	task.spawn(function()
		local flash = Instance.new("Part")
		flash.Shape = Enum.PartType.Ball
		flash.Size = Vector3.new(startSize, startSize, startSize)
		flash.Position = position
		flash.Anchored = true
		flash.CanCollide = false
		flash.Material = Enum.Material.Neon
		flash.Color = color
		flash.Transparency = 0.2
		flash.Parent = workspace

		local tween = TweenService:Create(flash, TweenInfo.new(duration), {
			Size = Vector3.new(endSize, endSize, endSize),
			Transparency = 1
		})
		tween:Play()
		tween.Completed:Wait()
		flash:Destroy()
	end)
end

function ProjectileEffects.beam(origin, targetPos, color, thickness, duration)
	thickness = thickness or 0.2
	duration = duration or 0.15
	color = color or Color3.fromRGB(255, 255, 200)

	local dist = (targetPos - origin).Magnitude

	local beam = Instance.new("Part")
	beam.Name = "Beam"
	beam.Anchored = true
	beam.CanCollide = false
	beam.Material = Enum.Material.Neon
	beam.Color = color
	beam.Size = Vector3.new(thickness, thickness, dist)
	beam.CFrame = CFrame.lookAt(origin, targetPos) * CFrame.new(0, 0, -dist / 2)
	beam.Parent = workspace

	local tween = TweenService:Create(beam, TweenInfo.new(duration), {
		Transparency = 1,
		Size = Vector3.new(0, 0, dist)
	})
	tween:Play()

	task.delay(duration, function()
		beam:Destroy()
	end)

	return beam
end

function ProjectileEffects.explosion(position, color, startSize, endSize, duration)
	startSize = startSize or 2
	endSize = endSize or 12
	duration = duration or 0.15
	color = color or Color3.fromRGB(255, 100, 50)

	task.spawn(function()
		local explosion = Instance.new("Part")
		explosion.Name = "Explosion"
		explosion.Shape = Enum.PartType.Ball
		explosion.Size = Vector3.new(startSize, startSize, startSize)
		explosion.Position = position
		explosion.Anchored = true
		explosion.CanCollide = false
		explosion.Material = Enum.Material.Neon
		explosion.Color = color
		explosion.Parent = workspace

		local tween = TweenService:Create(explosion, TweenInfo.new(duration), {
			Size = Vector3.new(endSize, endSize, endSize),
			Transparency = 1
		})
		tween:Play()
		tween.Completed:Wait()
		explosion:Destroy()
	end)
end

function ProjectileEffects.explosionWithRing(position, color, radius, duration)
	radius = radius or 12
	duration = duration or 0.3
	color = color or Color3.fromRGB(255, 200, 50)

	task.spawn(function()
		local explosion = Instance.new("Part")
		explosion.Shape = Enum.PartType.Ball
		explosion.Size = Vector3.new(2, 2, 2)
		explosion.Position = position
		explosion.Anchored = true
		explosion.CanCollide = false
		explosion.Material = Enum.Material.Neon
		explosion.Color = color
		explosion.Transparency = 0
		explosion.Parent = workspace

		local ring = Instance.new("Part")
		ring.Name = "ExplosionRing"
		ring.Size = Vector3.new(2, 0.3, 2)
		ring.Position = position
		ring.Anchored = true
		ring.CanCollide = false
		ring.Material = Enum.Material.Neon
		ring.Color = Color3.fromRGB(255, 150, 50)
		ring.Transparency = 0.3
		ring.Parent = workspace

		local explosionTween = TweenService:Create(explosion, TweenInfo.new(duration, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
			Size = Vector3.new(radius, radius, radius),
			Transparency = 1,
			Color = Color3.fromRGB(255, 100, 50)
		})

		local ringTween = TweenService:Create(ring, TweenInfo.new(duration + 0.1, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
			Size = Vector3.new(radius * 2, 0.1, radius * 2),
			Transparency = 1
		})

		explosionTween:Play()
		ringTween:Play()

		task.wait(duration + 0.2)
		explosion:Destroy()
		ring:Destroy()
	end)
end

function ProjectileEffects.debris(position, count, color, spread, duration)
	count = count or 12
	spread = spread or 10
	duration = duration or 0.4
	color = color or Color3.fromRGB(255, 150, 50)

	for i = 1, count do
		local debris = Instance.new("Part")
		debris.Size = Vector3.new(0.3, 0.3, 0.3)
		debris.Position = position
		debris.Anchored = true
		debris.CanCollide = false
		debris.Material = Enum.Material.Neon
		debris.Color = Color3.fromRGB(color.R * 255, (color.G * 255) + math.random(50), color.B * 255)
		debris.Transparency = 0
		debris.Parent = workspace

		local angle = (i / count) * math.pi * 2
		local debrisTarget = position + Vector3.new(
			math.cos(angle) * spread,
			math.random() * 4,
			math.sin(angle) * spread
		)

		local tween = TweenService:Create(debris, TweenInfo.new(duration, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
			Position = debrisTarget,
			Size = Vector3.new(0.1, 0.1, 0.1),
			Transparency = 1
		})
		tween:Play()

		task.delay(duration + 0.1, function()
			debris:Destroy()
		end)
	end
end

function ProjectileEffects.grenade(origin, targetPos, color, splashRadius, onImpact)
	color = color or Color3.fromRGB(100, 255, 100)
	splashRadius = splashRadius or 12

	local dist = (targetPos - origin).Magnitude
	local flightTime = math.min(0.6, dist / 50)
	local arcHeight = math.min(dist * 0.3, 10)

	task.spawn(function()
		local grenade = Instance.new("Part")
		grenade.Name = "Grenade"
		grenade.Shape = Enum.PartType.Ball
		grenade.Size = Vector3.new(0.8, 0.8, 0.8)
		grenade.Position = origin + Vector3.new(0, 1, 0)
		grenade.Anchored = true
		grenade.CanCollide = false
		grenade.Material = Enum.Material.Metal
		grenade.Color = Color3.fromRGB(60, 80, 60)
		grenade.Parent = workspace

		local glow = Instance.new("PointLight")
		glow.Color = color
		glow.Brightness = 2
		glow.Range = 4
		glow.Parent = grenade

		local startPos = origin + Vector3.new(0, 1, 0)
		local endPos = targetPos
		local steps = math.floor(flightTime / 0.02)

		for i = 1, steps do
			local t = i / steps
			local currentPos = startPos:Lerp(endPos, t)
			local heightOffset = math.sin(t * math.pi) * arcHeight
			grenade.Position = currentPos + Vector3.new(0, heightOffset, 0)
			grenade.CFrame = grenade.CFrame * CFrame.Angles(0.3, 0.2, 0.1)
			task.wait(0.02)
		end

		grenade:Destroy()

		if onImpact then
			onImpact()
		end

		ProjectileEffects.explosionWithRing(endPos, Color3.fromRGB(255, 200, 50), splashRadius)
		ProjectileEffects.debris(endPos, 12, Color3.fromRGB(255, 150, 50), splashRadius * 0.8)
	end)
end

function ProjectileEffects.shot(origin, targetPos, stats)
	local color = stats.color or Color3.fromRGB(255, 255, 200)

	if stats.isGrenade then
		ProjectileEffects.grenade(origin, targetPos, color, stats.splashRadius)
		return
	end

	ProjectileEffects.flash(origin, color, 0.5, 2, 0.1)

	if stats.splashRadius and stats.splashRadius > 0 then
		local beam = Instance.new("Part")
		beam.Name = "Beam"
		beam.Anchored = true
		beam.CanCollide = false
		beam.Material = Enum.Material.Neon
		beam.Color = color
		local dist = (targetPos - origin).Magnitude
		beam.Size = Vector3.new(0.4, 0.4, dist)
		beam.CFrame = CFrame.lookAt(origin, targetPos) * CFrame.new(0, 0, -dist / 2)
		beam.Parent = workspace

		task.delay(0.05, function()
			beam:Destroy()
			ProjectileEffects.explosion(targetPos, color, 2, stats.splashRadius)
		end)
	else
		ProjectileEffects.beam(origin, targetPos, color, 0.3, 0.15)
		ProjectileEffects.flash(targetPos, color, 1, 3, 0.2)
	end
end

return ProjectileEffects
