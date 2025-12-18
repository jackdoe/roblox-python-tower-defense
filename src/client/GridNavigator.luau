-- GridNavigator.luau (client)
-- Tuned visuals: Fading ghost lines, weaker path lines, correct angle arcs.

local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local UITheme = require(script.Parent.UI.UITheme)

local GridNavigator = {}

-- // CONFIGURATION //
local SETTINGS = {
    -- Dimensions
    PathThickness = 0.15,
    GhostThickness = 0.1,
    GhostLength = 6,
    ArcRadius = 3,
    ArcTickSize = Vector3.new(0.1, 0.01, 0.2), -- Width, Height, Length
    YOffset = 0,
    SnapToGrid = false,                        -- Set true to snap clicks to integer positions

    -- Colors
    Colors = {
        Path = Color3.fromRGB(0, 255, 255),
        Ghost = Color3.fromRGB(200, 200, 200),
        Arc = Color3.fromRGB(78, 154, 6), -- Dimmer orange
    }
}

-- State
local enabled = false
local waypoints = {}
local pathHistory = {}

-- // UTILITIES //

local function roundPos(x, z)
    if SETTINGS.SnapToGrid then
        return math.floor(x + 0.5), math.floor(z + 0.5)
    end
    return x, z
end

local function getPlayerState()
    local player = Players.LocalPlayer
    local char = player and player.Character
    local hrp = char and char:FindFirstChild("HumanoidRootPart")
    if not hrp then return nil end

    local look = hrp.CFrame.LookVector
    local flatLook = Vector3.new(look.X, 0, look.Z).Unit

    return {
        pos = hrp.Position + Vector3.new(0, SETTINGS.YOffset, 0),
        look = flatLook,
        yLevel = hrp.Position.Y + SETTINGS.YOffset
    }
end

-- // VISUAL GENERATORS //

local function createNode(pos, color)
    local part = Instance.new("Part")
    part.Name = "NavNode"
    part.Size = Vector3.new(0.35, 0.35, 0.35)
    part.Shape = Enum.PartType.Ball
    part.Position = pos
    part.Anchored = true
    part.CanCollide = false
    part.Material = Enum.Material.Neon
    part.Color = color
    part.CastShadow = false
    part.Parent = workspace
    table.insert(waypoints, part)
    return part
end

local function createLine(p1, p2, color, isGhost)
    local dist = (p1 - p2).Magnitude
    if dist < 0.1 then return end

    local part = Instance.new("Part")
    part.Name = isGhost and "GhostContainer" or "PathContainer"
    part.Transparency = 1
    part.Anchored = true
    part.CanCollide = false
    part.Position = (p1 + p2) / 2
    part.Parent = workspace

    local att0 = Instance.new("Attachment", part)
    local att1 = Instance.new("Attachment", part)
    att0.WorldPosition = p1
    att1.WorldPosition = p2

    local beam = Instance.new("Beam")
    beam.Attachment0 = att0
    beam.Attachment1 = att1
    beam.Color = ColorSequence.new(color)
    beam.FaceCamera = true
    beam.Segments = 1
    beam.LightEmission = 1
    beam.LightInfluence = 0

    if isGhost then
        beam.Width0 = SETTINGS.GhostThickness
        beam.Width1 = SETTINGS.GhostThickness
        beam.Transparency = NumberSequence.new({
            NumberSequenceKeypoint.new(0, 0.6),
            NumberSequenceKeypoint.new(1, 1.0)
        })
        beam.Texture = "rbxassetid://6070747046"
        beam.TextureMode = Enum.TextureMode.Wrap
        beam.TextureLength = 4
    else
        beam.Width0 = SETTINGS.PathThickness
        beam.Width1 = SETTINGS.PathThickness
        beam.Transparency = NumberSequence.new(0.4)
    end

    beam.Parent = part
    table.insert(waypoints, part)
    return beam
end

local function createLabel(pos, text, color, isAngle)
    local part = Instance.new("Part")
    part.Transparency = 1
    part.Anchored = true
    part.CanCollide = false
    part.Position = pos
    part.Parent = workspace

    local bb = Instance.new("BillboardGui")
    bb.Size = UDim2.new(0, 100, 0, 40)
    bb.StudsOffset = isAngle and Vector3.new(0, 0.5, 0) or Vector3.new(0, 1.25, 0)
    bb.AlwaysOnTop = true
    bb.Parent = part

    local label = Instance.new("TextLabel")
    label.Size = UDim2.new(1, 0, 1, 0)
    label.BackgroundTransparency = 1
    label.Text = text
    label.TextColor3 = color
    label.TextSize = 16
    label.Font = UITheme.FONT
    label.TextStrokeTransparency = 0
    label.TextStrokeColor3 = Color3.new(0, 0, 0)
    label.Parent = bb

    table.insert(waypoints, part)
end

local function createArc(center, dirFrom, dirTo)
    local det = dirFrom.X * dirTo.Z - dirFrom.Z * dirTo.X
    local dot = dirFrom.X * dirTo.X + dirFrom.Z * dirTo.Z
    local angleRad = math.atan2(det, dot)
    local deg = math.abs(math.deg(angleRad))

    if deg < 5 then return end

    local steps = math.floor(deg / 6)
    if steps < 2 then steps = 2 end

    local baseCF = CFrame.lookAt(center, center + dirFrom)

    for i = 1, steps do
        local alpha = i / steps
        local currentRad = angleRad * alpha
        local rotation = CFrame.Angles(0, -currentRad, 0)
        local tickCF = baseCF * rotation
        local tickPos = center + (tickCF.LookVector * SETTINGS.ArcRadius)

        local tick = Instance.new("Part")
        tick.Size = SETTINGS.ArcTickSize
        tick.Anchored = true
        tick.CanCollide = false
        tick.Material = Enum.Material.SmoothPlastic -- Softer material
        tick.Color = SETTINGS.Colors.Arc
        tick.Transparency = 0.1                     -- Slightly transparent
        tick.CFrame = CFrame.lookAt(tickPos, center)
        tick.Parent = workspace
        table.insert(waypoints, tick)
    end

    local midRad = angleRad * 0.5
    local midRotation = CFrame.Angles(0, -midRad, 0)
    local midCF = baseCF * midRotation
    local labelPos = center + (midCF.LookVector * (SETTINGS.ArcRadius + 1))

    createLabel(labelPos, math.floor(deg) .. "°", SETTINGS.Colors.Arc, true)
end

-- // LOGIC //

function GridNavigator.clear()
    for _, v in ipairs(waypoints) do
        v:Destroy()
    end
    waypoints = {}
    pathHistory = {}
end

function GridNavigator.addWaypoint(worldX, worldZ)
    local playerState = getPlayerState()
    if not playerState then return end

    local yLevel = playerState.yLevel
    local tx, tz = roundPos(worldX, worldZ)
    local targetPos = Vector3.new(tx, yLevel, tz)

    local originPos
    local refHeading

    if #pathHistory == 0 then
        originPos = playerState.pos
        refHeading = playerState.look
        createNode(originPos, SETTINGS.Colors.Path)
    else
        local last = pathHistory[#pathHistory]
        originPos = last.pos
        refHeading = last.heading
    end

    local vecToTarget = (targetPos - originPos)
    local dist = vecToTarget.Magnitude

    if dist < 1 then return end

    local newHeading = vecToTarget.Unit

    createLine(originPos, targetPos, SETTINGS.Colors.Path, false)
    createNode(targetPos, SETTINGS.Colors.Path)
    createLine(originPos, originPos + (refHeading * SETTINGS.GhostLength), SETTINGS.Colors.Ghost, true)
    createArc(originPos, refHeading, newHeading)
    createLabel(targetPos, math.floor(dist) .. "", SETTINGS.Colors.Path, false)

    table.insert(pathHistory, {
        pos = targetPos,
        heading = newHeading
    })
end

local function intersectHorizontalPlane(rayOrigin, rayDir, planeY)
    if math.abs(rayDir.Y) < 0.0001 then return nil end
    local t = (planeY - rayOrigin.Y) / rayDir.Y
    if t < 0 then return nil end
    return rayOrigin + rayDir * t
end

function GridNavigator.onInput(input, processed)
    if processed or not enabled then return end

    if input.UserInputType == Enum.UserInputType.MouseButton2 then
        local modifierHeld = UserInputService:IsKeyDown(Enum.KeyCode.LeftControl)
            or UserInputService:IsKeyDown(Enum.KeyCode.RightControl)
            or UserInputService:IsKeyDown(Enum.KeyCode.LeftMeta)
            or UserInputService:IsKeyDown(Enum.KeyCode.RightMeta)

        if modifierHeld then
            GridNavigator.clear()
        end
    elseif input.UserInputType == Enum.UserInputType.MouseButton1 then
        local ctrl = UserInputService:IsKeyDown(Enum.KeyCode.LeftControl)
            or UserInputService:IsKeyDown(Enum.KeyCode.RightControl)
            or UserInputService:IsKeyDown(Enum.KeyCode.LeftMeta)

        if ctrl then
            local playerState = getPlayerState()
            if not playerState then return end

            local mouse = Players.LocalPlayer:GetMouse()
            local cam = workspace.CurrentCamera
            local ray = cam:ScreenPointToRay(mouse.X, mouse.Y)

            -- Intersect with horizontal plane at player's Y level
            local hitPos = intersectHorizontalPlane(ray.Origin, ray.Direction, playerState.yLevel)

            if hitPos then
                GridNavigator.addWaypoint(hitPos.X, hitPos.Z)
            end
        end
    end
end

function GridNavigator.enable()
    enabled = true
    UserInputService.InputBegan:Connect(GridNavigator.onInput)
end

function GridNavigator.disable()
    enabled = false
    GridNavigator.clear()
end

return GridNavigator
