-- SoundConfig.luau
-- Sound asset IDs for the game
-- Upload your own sounds to Roblox and paste the IDs here
-- Note: If a sound fails to load (deleted/403), it will be skipped silently

local SoundConfig = {
	-- Default monster sounds (used when monster type doesn't have specific sound)
	MonsterDefaults = {
		Footstep = "rbxassetid://111025514582061",
		FootstepVolume = 0.6,

		Attack = "rbxassetid://9119560180",
		AttackVolume = 1,

		Eat = "rbxassetid://9114074529",
		EatVolume = 0.8,

		Death = "rbxassetid://9119560180",
		DeathVolume = 0.5,

		Growl = "rbxassetid://9113989909",
		GrowlVolume = 0.3,
	},

	-- Per-monster-type sounds (override defaults)
	-- Current TD enemy types: Zombie, Runner, Tank, Boss
	Monsters = {},

	-- Player sounds
	Player = {
		AttackMiss = "rbxassetid://104290383774293",
		AttackMissVolume = 0.3,

		AttackHit = "rbxassetid://4678745096",
		AttackHitVolume = 0.4,

		Hurt = "rbxassetid://109413417701675",
		HurtVolume = 0.5,

		Death = "rbxassetid://9119560180",
		DeathVolume = 0.5,
	},

	-- Ambient music (plays randomly, one after another)
	Ambient = {
		Tracks = {
			"rbxassetid://83859749685965",
			"rbxassetid://79809885826228",
			"rbxassetid://80693216662917",
		},
		Volume = 0.3,
	},

	-- Random periodic sounds (tension/atmosphere)
	Periodic = {
		MinInterval = 100,
		MaxInterval = 300,
		Volume = 0.8,
		Sounds = {
		},
	},
}

-- Get monster sound (checks type-specific first, then falls back to defaults)
function SoundConfig.getMonsterSound(typeName, soundName)
	local typeConfig = SoundConfig.Monsters[typeName]

	-- Check type-specific first
	if typeConfig and typeConfig[soundName] then
		return typeConfig[soundName], typeConfig[soundName .. "Volume"] or 0.5
	end

	-- Fall back to defaults
	local defaults = SoundConfig.MonsterDefaults
	if defaults[soundName] then
		return defaults[soundName], defaults[soundName .. "Volume"] or 0.5
	end

	return nil, 0.5
end

-- Safe sound player utility
-- Returns a function that plays sounds defensively (won't crash if sound is deleted)
function SoundConfig.playSound(soundId, volume, parent)
	if not soundId or soundId == "" then return nil end

	local sound = Instance.new("Sound")
	sound.SoundId = soundId
	sound.Volume = volume or 0.5
	sound.Parent = parent or workspace

	-- Clean up when done (or if it fails)
	sound.Ended:Once(function()
		sound:Destroy()
	end)

	-- Play in protected call - won't error if sound fails to load
	local success = pcall(function()
		sound:Play()
	end)

	if not success then
		sound:Destroy()
		return nil
	end

	return sound
end

-- Play a sound at a specific 3D position with strict distance falloff
-- Uses Attachments instead of Parts for better performance (no physics overhead)
function SoundConfig.playSpatialSound(soundId, position, volume)
	if not soundId or soundId == "" then return nil end
	if not position then return nil end

	local Debris = game:GetService("Debris")

	-- Use Attachment on Terrain for 3D audio (much lighter than creating Parts)
	local attachment = Instance.new("Attachment")
	attachment.WorldPosition = position
	attachment.Name = "AudioSource"
	attachment.Parent = workspace.Terrain

	local sound = Instance.new("Sound")
	sound.SoundId = soundId
	sound.Volume = volume or 0.5

	-- SPATIAL SETTINGS (The Magic Fix for audio overload)
	sound.RollOffMode = Enum.RollOffMode.LinearSquare -- Fades out naturally
	sound.RollOffMinDistance = 10 -- Full volume within 10 studs
	sound.RollOffMaxDistance = 80 -- Completely silent after 80 studs

	sound.Parent = attachment

	sound.Ended:Connect(function()
		attachment:Destroy()
	end)

	-- Play in protected call
	local success = pcall(function()
		sound:Play()
	end)

	if not success then
		attachment:Destroy()
		return nil
	end

	-- Safety cleanup in case sound bugs out
	Debris:AddItem(attachment, 5)

	return sound
end

return SoundConfig
