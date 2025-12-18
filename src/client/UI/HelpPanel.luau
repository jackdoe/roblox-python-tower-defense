local UITheme = require(script.Parent.UITheme)

local HelpPanel = {}

local AMBER = Color3.fromRGB(255, 191, 0)
local AMBER_DIM = Color3.fromRGB(180, 140, 40)
local BG_COLOR = Color3.fromRGB(12, 12, 8)

local HELP_TEXT = [[
PYTHONTD(1)                      GAME MANUAL                      PYTHONTD(1)

NAME
       PythonTD - tower defense with programmable units

SYNOPSIS
       while True:
           enemies = self.scan()
           if len(enemies) > 0:
               self.set_target(nearest(enemies))
               self.fire(BULLET)

-------------------------------------------------------------------------------
                                 AMMO TYPES
-------------------------------------------------------------------------------
       Gundams use ammo (reload costs 2S per ammo). Player weapons cost scrap.

       GUNDAM WEAPONS                        PLAYER WEAPONS
       Name      Dmg  Ammo  Rate  Notes       Name      Dmg  Cost  Rate
       --------- ---  ----  ----  ------      --------- ---  ----  ----
       BULLET     15    1   0.2s  Fast        BULLET      7   1S   0.3s
       ROCKET     80    4   1.0s  Splash      ROCKET     40   2S   1.0s
       LASER      40    2   0.1s  Burns       LASER      20   1S   0.5s
       ICE        20    2   0.4s  60% slow    ICE        10   1S   0.4s
       GRENADE    60    5   1.5s  Splash      GRENADE    30   2S   1.5s

       Player ROCKET applies OILED. Both ICE weapons freeze (60% slow).

-------------------------------------------------------------------------------
                                  DEBUFFS
-------------------------------------------------------------------------------
       SLOW      Enemy moves at reduced speed. New slow replaces old.
       OILED     Coated in oil for 5 seconds. Amplifies SHOCK damage 2x.
       BURNING   Takes 5 damage every 0.5s for 3s (30 total). From LASER.
       FROZEN    Slowed by 50% or more. ROCKET shatters for 1.5x damage.

-------------------------------------------------------------------------------
                                   COMBOS
-------------------------------------------------------------------------------
       Bots can SHOCK enemies to trigger powerful combos:

       SHOCK + OILED     = 2x damage, explosion visual, clears oil
       SHOCK + BURNING   = 1.5x damage, chains lightning to 3 nearby (30% dmg)
       SHOCK + SLOW      = (1 + slowAmount)x damage (60% slow = 1.6x)
       ROCKET + FROZEN   = SHATTER: 1.5x damage, clears ice (needs 50%+ slow)

       Combos stack MULTIPLICATIVELY! Order: cargo -> oiled -> burning -> slow
       Example: 5 cargo + oiled + burning + 60% slow on 30 base shock:
         30 × 7.6 (cargo) × 2 (oil) × 1.5 (burn) × 1.6 (slow) = 1094 damage!

       Chain lightning range: 15 units from target
       Bot stuns for 2s after shocking (vulnerable!)

-------------------------------------------------------------------------------
                                   TYPES
-------------------------------------------------------------------------------
       Understanding what your functions return and accept:

       Enemy     A single enemy. Has hp, pos, is_boss, etc.
       [Enemy]   A list of enemies. Use len() to count, [0] to get first.
       [x, z]    A position. Two numbers: x (left/right), z (forward/back).
       AmmoType  One of: BULLET, ROCKET, LASER, ICE, GRENADE
       number    A whole or decimal number like 10, 3.5, -20
       bool      True or False

-------------------------------------------------------------------------------
                          OBJECTS: SELF AND OTHERS
-------------------------------------------------------------------------------
       Each unit (Gundam, Bot, Player) is an OBJECT with data and actions.

       SELF - YOUR UNIT
       "self" refers to the unit running the code. Use it to control yourself:

           self.pos                 # read your position
           self.carrying            # read how much scrap you have
           self.scan()              # perform a scan action
           self.fire(BULLET)        # perform a fire action

       OTHER UNITS - G1, G2, B1, B2, etc.
       You can read data from other units on your team:

           B1.pos                   # where is Bot 1?
           B1.carrying              # how much scrap does Bot 1 have?
           G3.ammo                  # how much ammo does Gundam 3 have?

       PROPERTIES vs METHODS
       Properties are data you READ. No parentheses:

           self.pos                 # [x, z] position
           self.carrying            # number of scrap
           self.ammo                # current ammo (Gundam)
           self.max_ammo            # max ammo capacity (Gundam)
           self.max_capacity        # max scrap capacity (Bot/Player)
           enemy.hp                 # enemy health
           enemy.is_boss            # True/False

       Methods are actions you DO. Use parentheses:

           self.scan()              # returns list of enemies
           self.fire(BULLET)        # shoots, returns True/False
           self.collect()           # picks up scrap
           self.teleport([0, 0])    # moves to position
           self.set_target(enemy)   # aims at enemy

       EXAMPLE - Coordinated Attack
           # Bot checks if Gundam needs help
           if G1.ammo < 50 and self.carrying > 0:
               self.say("G1 low on ammo!")
               self.teleport([0, 0])
               self.deposit()

-------------------------------------------------------------------------------
                               BOT ABILITIES
-------------------------------------------------------------------------------
       self.collect()               [Enemy] or nothing
           Finds nearest scrap cluster and moves to collect it.

       self.deposit()               True/False
           Deposits carried scrap at core. Must be within 15 units.

       self.shock(enemy)            True/False
           Teleports to enemy and zaps for 30 base damage. Triggers combos!
           Damage scales with cargo: 30 × 1.5^cargo (exponential!)
           Consumes HALF your cargo (rounded up).
           5 cargo = 228 dmg, 10 cargo = 1732 dmg!

       self.teleport([x, z])        True/False
           Instantly moves to position. [0,0] is the core.

       self.explode()               True/False
           Sacrifices 10+ cargo for massive AOE. Bot is destroyed.

       self.forward(n)              True/False
           Walks forward n units in facing direction.

       self.backward(n)             True/False
           Walks backward n units.

       self.left(degrees)           True/False
           Rotates left. Default 90 degrees.

       self.right(degrees)          True/False
           Rotates right. Default 90 degrees.

       self.carrying                number
           How much scrap bot is carrying.

       self.max_capacity            number
           Maximum scrap bot can carry (10).

       self.scan()                  [Enemy]
           Returns list of enemies within range 50.

       self.say("message")          nothing
           Shows a speech bubble above bot for 3 seconds.

       self.pos                     [x, z]
           Current position relative to core.

       self.hacker                  Player
           Access your owner's player. Use self.hacker.target() etc.

-------------------------------------------------------------------------------
                              GUNDAM ABILITIES
-------------------------------------------------------------------------------
       self.fire(AMMO)              True/False  [BLOCKING]
           Fires at current target. Waits for cooldown (scales with CPU).

       self.scan()                  [Enemy]
           Returns list of enemies within range.

       self.set_target(enemy)       nothing
           Locks aim onto an enemy. Required before fire().

       self.target()                Enemy or None
           Returns currently targeted enemy, or None.

       self.set_range(n)            nothing
           Sets base range (10-60). Less range = more damage (40/range).
           Power upgrades extend effective range (+20% per power level).

       self.ammo                    number
           Current ammo in magazine.

       self.max_ammo                number
           Maximum ammo capacity (300).

       self.hacker                  Player
           Access your owner's player. Use self.hacker.target() etc.

       self.reload()                number
           Reloads ammo from scrap (2S per ammo). Returns amount reloaded.

       self.pos                     [x, z]
           Current position relative to core.

-------------------------------------------------------------------------------
                              PLAYER ABILITIES
-------------------------------------------------------------------------------
       self.fire(AMMO)              True/False  [BLOCKING]
           Fire at target. Costs scrap (1-2S). Waits for cooldown.

       self.scan()                  [Enemy]
           Returns enemies within range 50.

       self.set_target(enemy)       nothing
           Lock aim onto an enemy.

       self.carrying                number
           How much scrap player is carrying.

       self.max_capacity            number
           Maximum scrap player can carry (10).

       self.hacker                  Player
           Returns yourself. Try self.hacker.hacker.hacker.target()!

       self.collect()               True/False
           Picks up scrap within range 8.

       self.teleport([x, z])        True/False
           Instantly moves to position.

       self.deposit()               True/False
           Deposits scrap at core. Must be within 15 units.

       self.drop(n)                 True/False
           Drops n scrap pieces (costs n×10 from wallet). Share with team!

       self.explode()               True/False
           AOE attack that consumes carried scrap.

       self.pos                     [x, z]
           Current position relative to core.

-------------------------------------------------------------------------------
                                 SELECTORS
-------------------------------------------------------------------------------
       These pick ONE enemy from a list:

       nearest([Enemy])             Enemy
           Returns enemy closest to you.

       furthest([Enemy])            Enemy
           Returns enemy farthest from you.

       weakest([Enemy])             Enemy
           Returns enemy with lowest HP.

       strongest([Enemy])           Enemy
           Returns enemy with highest HP.

       Example:
           enemies = self.scan()          # get list of enemies
           target = nearest(enemies)      # pick the closest one
           self.set_target(target)        # aim at it

-------------------------------------------------------------------------------
                                  ENEMY
-------------------------------------------------------------------------------
       When you scan, you get Enemy objects. Here's what they have:

       enemy.hp                     number - Current health
       enemy.max_hp                 number - Maximum health
       enemy.pos                    [x, z] - Position
       enemy.is_boss                True/False - Is it a boss?
       enemy.burning                True/False - Is it on fire?
       enemy.frozen                 True/False - Is it frozen (50%+ slow)?
       enemy.slowed                 True/False - Is it slowed at all?
       enemy.oiled                  True/False - Is it oiled?

-------------------------------------------------------------------------------
                             GLOBAL VARIABLES
-------------------------------------------------------------------------------
       CORE.hp                      Current core health
       CORE.pos                     Core position [0, 0]
       G1, G2, ... G10              Access other gundams by ID
       B1, B2, B3, ...              Access bots by ID

-------------------------------------------------------------------------------
                            HOW PYTHON WORKS
-------------------------------------------------------------------------------
       Your code goes through 3 stages before running:

       1. LEXER
          Reads your text and breaks it into tokens.
          "if x > 5:" becomes: [IF] [x] [>] [5] [:]
          Tracks indentation for Python blocks.

       2. COMPILER
          Converts tokens into bytecode instructions.
          "x = 5" becomes: LOAD_CONST 5, STORE_VAR x
          Checks for errors like undefined variables.

       3. VIRTUAL MACHINE (VM)
          Executes bytecode one instruction at a time.
          Uses a stack to compute values.
          Each CPU tick runs multiple instructions.

-------------------------------------------------------------------------------
                              CPU AND RAM
-------------------------------------------------------------------------------
       Each unit has CPU speed (Hz) and RAM (bytes).

       CPU (SPEED)
       Base: 1 Hz       Each upgrade: +2 Hz
       Cost: 100 scrap, then x1.5 per upgrade

       Example costs:
         1 Hz -> 3 Hz    100 scrap
         3 Hz -> 5 Hz    150 scrap
         5 Hz -> 7 Hz    225 scrap
         ...and so on

       Higher Hz = your program runs faster AND you fire faster!
       Fire rate scales with CPU: actualRate = baseRate / cpuHz
       At 5 Hz with BULLET (0.2s): fires every 0.04s instead of 0.2s!
       Bot movement speed also scales: baseSpeed + (cpuHz - 1) × 4

       fire() is BLOCKING - your program waits for the cooldown.

       RAM (PROGRAM SIZE)
       Base: 32 bytes   Each upgrade: +32 bytes
       Cost: 75 scrap, then x1.5 per upgrade

       Example costs:
         32B -> 64B      75 scrap
         64B -> 96B     112 scrap
         96B -> 128B    168 scrap
         ...and so on

       RAM limits your program size (bytecode instructions).
       More RAM = longer, more complex programs.
       Simple loop = ~15 bytes. Full AI = ~60+ bytes.

-------------------------------------------------------------------------------
                                 ECONOMY
-------------------------------------------------------------------------------
       Starting scrap: 1000
       Each player has their own scrap balance (not shared!)
       Scrap drops from killed enemies.
       Your bots deposit scrap to YOUR balance.
       Use self.drop(n) to share scrap with teammates.
       Each scrap piece = 10 scrap currency.
       Damage scoreboard (top-right) shows who's contributing!

       COSTS
       Gundam: 100 scrap base (x1.5 per gundam)
       Bot: 75 scrap base (x1.3 per bot, unlimited)
       Player weapons: 1-2S per shot
       CPU/RAM upgrades: see tables above

-------------------------------------------------------------------------------
                              FIRST CHALLENGE
-------------------------------------------------------------------------------
       The default gundam program fires but NEVER RELOADS!

           while True:
               enemies = self.scan()
               if len(enemies) > 0:
                   self.set_target(nearest(enemies))
                   self.fire(BULLET)

       Your first task: add reload logic. But there's a catch...
       Base RAM (32 bytes) is NOT enough for a full reload program!

       You must choose wisely:
         - Write minimal code that fits in 32 bytes
         - Or upgrade RAM first (costs scrap)
         - Or accept running dry and reloading manually

       This is the machinist's dilemma: code efficiency vs upgrades.

-------------------------------------------------------------------------------
                                  TIPS
-------------------------------------------------------------------------------
       - ICE enemies before ROCKET for shatter bonus (freezes at 50%+ slow)
       - SHOCK oiled enemies for 2x damage + explosion
       - SHOCK burning enemies for 1.5x + chain lightning
       - Stack debuffs before SHOCK for multiplicative damage!
       - SHOCK teleports bot to target, then consumes all cargo
       - Bots can teleport([0,0]) to instantly return to core
       - Lower range = more damage (40/range). Power extends reach, not damage.
       - Check enemy.is_boss to prioritize threats
       - Use B1.carrying to coordinate between units

                                                              PYTHONTD(1)
]]

function HelpPanel.create(parent, onClose)
    local panel = {}

    local overlay = Instance.new("Frame")
    overlay.Name = "HelpOverlay"
    overlay.Size = UDim2.new(1, 0, 1, 0)
    overlay.BackgroundColor3 = Color3.new(0, 0, 0)
    overlay.BackgroundTransparency = 0.4
    overlay.BorderSizePixel = 0
    overlay.ZIndex = 100
    overlay.Visible = false
    overlay.Parent = parent

    local frame = Instance.new("Frame")
    frame.Name = "HelpPanel"
    frame.Size = UDim2.new(0, 620, 0.85, 0)
    frame.Position = UDim2.new(0.5, 0, 0.5, 0)
    frame.AnchorPoint = Vector2.new(0.5, 0.5)
    frame.BackgroundColor3 = BG_COLOR
    frame.BorderSizePixel = 0
    frame.ZIndex = 101
    frame.Parent = overlay

    local border = Instance.new("UIStroke")
    border.Color = AMBER_DIM
    border.Thickness = 2
    border.Parent = frame

    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(0, 4)
    corner.Parent = frame

    local scroll = Instance.new("ScrollingFrame")
    scroll.Name = "Scroll"
    scroll.Size = UDim2.new(1, -24, 1, -50)
    scroll.Position = UDim2.new(0, 12, 0, 10)
    scroll.BackgroundTransparency = 1
    scroll.BorderSizePixel = 0
    scroll.ScrollBarThickness = 6
    scroll.ScrollBarImageColor3 = AMBER_DIM
    scroll.CanvasSize = UDim2.new(0, 0, 0, 0)
    scroll.AutomaticCanvasSize = Enum.AutomaticSize.Y
    scroll.ZIndex = 102
    scroll.Parent = frame

    local content = Instance.new("TextLabel")
    content.Name = "Content"
    content.Size = UDim2.new(1, 0, 0, 0)
    content.BackgroundTransparency = 1
    content.Text = HELP_TEXT
    content.TextColor3 = AMBER
    content.Font = UITheme.FONT
    content.TextSize = 14
    content.TextXAlignment = Enum.TextXAlignment.Left
    content.TextYAlignment = Enum.TextYAlignment.Top
    content.AutomaticSize = Enum.AutomaticSize.Y
    content.TextWrapped = false
    content.ZIndex = 103
    content.Parent = scroll

    local closeBtn = Instance.new("TextButton")
    closeBtn.Name = "CloseBtn"
    closeBtn.Size = UDim2.new(0, 100, 0, 30)
    closeBtn.Position = UDim2.new(0.5, -50, 1, -40)
    closeBtn.BackgroundColor3 = AMBER_DIM
    closeBtn.Text = "CLOSE"
    closeBtn.TextColor3 = BG_COLOR
    closeBtn.Font = UITheme.FONT
    closeBtn.TextSize = 14
    closeBtn.ZIndex = 102
    closeBtn.Parent = frame

    local closeCorner = Instance.new("UICorner")
    closeCorner.CornerRadius = UDim.new(0, 4)
    closeCorner.Parent = closeBtn

    closeBtn.MouseButton1Click:Connect(function()
        panel.hide()
        if onClose then onClose() end
    end)

    overlay.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 then
            local pos = input.Position
            local framePos = frame.AbsolutePosition
            local frameSize = frame.AbsoluteSize
            if pos.X < framePos.X or pos.X > framePos.X + frameSize.X or
                pos.Y < framePos.Y or pos.Y > framePos.Y + frameSize.Y then
                panel.hide()
                if onClose then onClose() end
            end
        end
    end)

    function panel.show()
        overlay.Visible = true
    end

    function panel.hide()
        overlay.Visible = false
    end

    function panel.toggle()
        overlay.Visible = not overlay.Visible
    end

    function panel.isVisible()
        return overlay.Visible
    end

    function panel.getFrame()
        return overlay
    end

    return panel
end

return HelpPanel
