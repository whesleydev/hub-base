-- hub base | menu portavel entre jogos
-- executor: Delta, Xeno, Solara, Fluxus, Wave

local BASE = "https://raw.githubusercontent.com/whesleydev/hub-base/main"
local SCRIPT_VERSION = 1
local CONFIG_PATH = "hubbase_config.json"

local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local HttpService = game:GetService("HttpService")
local Lighting = game:GetService("Lighting")
local LocalPlayer = Players.LocalPlayer

local previous = _G.__hubBase
if previous then
    pcall(function()
        if previous.window and previous.window.Destroy then
            previous.window:Destroy()
        end
        for _, key in ipairs({"bubble", "statusGui", "espFolder", "logGui"}) do
            if previous[key] then
                previous[key]:Destroy()
            end
        end
        if previous.stopFly then
            previous.stopFly()
        end
        for _, conn in ipairs(previous.connections or {}) do
            pcall(function()
                conn:Disconnect()
            end)
        end
    end)
end

local session = {version = SCRIPT_VERSION, connections = {}}
_G.__hubBase = session

local Rayfield = loadstring(game:HttpGet("https://sirius.menu/rayfield"))()

local state = {
    speed = 16,
    jump = 50,
    flySpeed = 300,
    fly = false,
    jumpFly = true,
    maxFlyHeight = 300,
    moveMode = "rig",
    travelSpeed = 300,
    attackDelay = 0.02,
    farmRange = 1500,
    autoFarm = false,
    fastAttack = false,
    killAura = false,
    auraRange = 45,
    hitbox = false,
    hitboxSize = 16,
    autoEquip = true,
    espEnemy = false,
    espTarget = true,
    espPlayer = false,
    espName = true,
    espHealth = true,
    espDistance = true,
    espTracer = false,
    espSkeleton = false,
    espBox = false,
    espChams = false,
    espFill = false,
    espRange = 1500,
    espOnlySelected = false,
    selectedPlayer = nil,
    colorEnemy = {255, 80, 80},
    colorTarget = {255, 200, 60},
    colorPlayer = {80, 160, 255},
    colorChams = {255, 120, 200},
    verboseLogs = true,
    showLogPanel = false,
    antiAfk = true,
    waypoints = {},
}

-- ===== log =====
local LOG_PATH = "bloxfruit_log.txt"
local LOG_MAX = 500

local Log = {
    lines = {},
    entries = {},
    verbose = true,
    dirtyPanel = false,
    panelLines = {},
}

local function stamp()
    local ok, value = pcall(function()
        return os.date("%H:%M:%S")
    end)
    return ok and value or "??:??:??"
end

function Log.add(level, text)
    local line = string.format("[%s] %-5s %s", stamp(), level, tostring(text))
    Log.lines[#Log.lines + 1] = line
    if #Log.lines > LOG_MAX then
        table.remove(Log.lines, 1)
    end
    Log.entries[#Log.entries + 1] = {level = level, text = tostring(text), time = stamp()}
    if #Log.entries > LOG_MAX then
        table.remove(Log.entries, 1)
    end
    Log.dirtyPanel = true
    if state.verboseLogs then
        print(line)
    end
end

function Log.dump()
    return table.concat(Log.lines, "\n")
end

function Log.clear()
    Log.lines = {}
    Log.entries = {}
    Log.dirtyPanel = true
end

function Log.guard(name, fn)
    return function(...)
        local ok, err = pcall(fn, ...)
        if not ok then
            Log.add("ERRO", name .. ": " .. tostring(err))
        end
        return ok
    end
end

session.Log = Log


-- ===== modulos de jogo =====
-- cada modulo entrega: name, placeIds, enemies(), targets(), playerLevel()
-- enemies() -> lista de {model = Model, part = BasePart}
-- targets() -> lista de {model = Model, part = BasePart}

local Modules = {}

local function humanoidOf(model)
    return model:FindFirstChildOfClass("Humanoid")
            or model:FindFirstChild("Humanoid", true)
end

local function aliveRoot(model)
    local hum = humanoidOf(model)
    if not hum or hum.Health <= 0 then
        return nil
    end
    return model:FindFirstChild("HumanoidRootPart")
            or model:FindFirstChild("HumanoidRootPart", true)
            or model:FindFirstChildWhichIsA("BasePart")
end

local function isPlayerCharacter(model)
    return Players:GetPlayerFromCharacter(model) ~= nil
end

local descendantCache = {at = 0, list = {}}

local function descendants()
    if os.clock() - descendantCache.at < 3 then
        return descendantCache.list
    end
    descendantCache.at = os.clock()
    descendantCache.list = Workspace:GetDescendants()
    return descendantCache.list
end

Modules.generic = {
    name = "Generico",
    placeIds = {},
    enemies = function()
        local out = {}
        for _, model in ipairs(Workspace:GetChildren()) do
            if model:IsA("Model") and model ~= LocalPlayer.Character
                    and not isPlayerCharacter(model)
                    and not Players:FindFirstChild(model.Name) then
                local part = aliveRoot(model)
                if part then
                    out[#out + 1] = {model = model, part = part}
                end
            end
        end
        return out
    end,
    targets = function()
        local out = {}
        for _, object in ipairs(Workspace:GetChildren()) do
            if object:IsA("Model") and object:FindFirstChildWhichIsA("BasePart") then
                local lower = string.lower(object.Name)
                if string.find(lower, "fruit", 1, true) or string.find(lower, "chest", 1, true)
                        or string.find(lower, "drop", 1, true) then
                    out[#out + 1] = {model = object,
                                     part = object:FindFirstChildWhichIsA("BasePart")}
                end
            end
        end
        return out
    end,
    playerLevel = function()
        return 1
    end,
}

Modules.bloxfruits = {
    name = "Blox Fruits",
    placeIds = {2753915549, 4442272183, 7449423635},
    enemies = function()
        local out = {}
        local folder = Workspace:FindFirstChild("Enemies")
        if not folder then
            return Modules.generic.enemies()
        end
        for _, model in ipairs(folder:GetChildren()) do
            if model:IsA("Model") and not isPlayerCharacter(model) then
                local part = aliveRoot(model)
                if part then
                    out[#out + 1] = {model = model, part = part}
                end
            end
        end
        return out
    end,
    targets = function()
        local out = {}
        local fruitNames = {
            Rocket = true, Spin = true, Blade = true, Spring = true, Bomb = true,
            Smoke = true, Spike = true, Flame = true, Falcon = true, Ice = true,
            Sand = true, Dark = true, Diamond = true, Light = true, Rubber = true,
            Barrier = true, Ghost = true, Magma = true, Quake = true, Buddha = true,
            Love = true, Spider = true, Sound = true, Phoenix = true, Portal = true,
            Rumble = true, Paw = true, Gravity = true, Dough = true, Shadow = true,
            Venom = true, Control = true, Spirit = true, Dragon = true, Leopard = true,
        }
        for _, object in ipairs(Workspace:GetChildren()) do
            local part = object:FindFirstChild("Handle") or object:FindFirstChildWhichIsA("BasePart")
            if part and (fruitNames[object.Name]
                    or string.find(string.lower(object.Name), "chest", 1, true)) then
                out[#out + 1] = {model = object, part = part}
            end
        end
        return out
    end,
    playerLevel = function()
        local ok, value = pcall(function()
            return LocalPlayer.Data.Level.Value
        end)
        if ok and type(value) == "number" then
            return value
        end
        return 1
    end,
}

local function detectModule()
    for _, module in pairs(Modules) do
        for _, placeId in ipairs(module.placeIds or {}) do
            if placeId == game.PlaceId then
                return module
            end
        end
    end
    return Modules.generic
end

local Game = detectModule()


local function humanoid()
    local char = LocalPlayer.Character
    return char and char:FindFirstChildOfClass("Humanoid")
end

local function rootPart()
    local char = LocalPlayer.Character
    return char and char:FindFirstChild("HumanoidRootPart")
end


-- ===== alvos =====
local function collectEnemies()
    local ok, list = pcall(Game.enemies)
    return ok and list or {}
end

local function collectTargets()
    local ok, list = pcall(Game.targets)
    return ok and list or {}
end

local function playerLevel()
    local ok, value = pcall(Game.playerLevel)
    return ok and value or 1
end

-- ===== voo / deslocamento =====
local flyRig = {
    lock = 0,
    active = false,
    align = nil,
    orient = nil,
    attach = nil,
    target = nil,
    holdTimer = 0,
    pressedUntil = 0,
}

session.connections[#session.connections + 1] = UserInputService.JumpRequest:Connect(function()
    flyRig.pressedUntil = os.clock() + 0.35
end)

local function destroyRig()
    for _, key in ipairs({"align", "orient", "attach"}) do
        local object = flyRig[key]
        if object then
            pcall(function()
                object:Destroy()
            end)
            flyRig[key] = nil
        end
    end
    flyRig.active = false
    flyRig.target = nil
    local hum = humanoid()
    if hum then
        hum.WalkSpeed = state.speed
    end
end

session.stopFly = destroyRig

local function buildRig()
    local char = LocalPlayer.Character
    local root = char and char:FindFirstChild("HumanoidRootPart")
    local hum = char and char:FindFirstChildOfClass("Humanoid")
    if not root or not hum then
        return false
    end

    flyRig.attach = Instance.new("Attachment")
    flyRig.attach.Name = "hubFlyAttach"
    flyRig.attach.Parent = root

    flyRig.align = Instance.new("AlignPosition")
    flyRig.align.Name = "hubFlyAlign"
    flyRig.align.Attachment0 = flyRig.attach
    flyRig.align.Mode = Enum.PositionAlignmentMode.OneAttachment
    flyRig.align.MaxForce = 1e6
    flyRig.align.MaxVelocity = 1e4
    flyRig.align.Responsiveness = 45
    flyRig.align.Position = root.Position
    flyRig.align.Parent = root

    flyRig.orient = Instance.new("AlignOrientation")
    flyRig.orient.Attachment0 = flyRig.attach
    flyRig.orient.Mode = Enum.OrientationAlignmentMode.OneAttachment
    flyRig.orient.MaxTorque = 1e6
    flyRig.orient.Responsiveness = 45
    flyRig.orient.CFrame = CFrame.new(root.Position) * CFrame.Angles(0, math.rad(root.Orientation.Y), 0)
    flyRig.orient.Parent = root

    flyRig.target = root.Position
    flyRig.active = true
    hum.WalkSpeed = 0
    return true
end

local function updateFly(dt)
    local hum = humanoid()
    local root = rootPart()
    if not hum or not root then
        if flyRig.active then
            destroyRig()
        end
        return
    end
    if flyRig.lock > 0 then
        return
    end
    if flyRig.active and (not flyRig.align or not flyRig.align.Parent) then
        destroyRig()
    end

    local held = UserInputService:IsKeyDown(Enum.KeyCode.Space)
            or os.clock() < flyRig.pressedUntil

    if held then
        flyRig.holdTimer = math.min(flyRig.holdTimer + dt, 4)
    else
        flyRig.holdTimer = math.max(flyRig.holdTimer - dt * 3, 0)
    end

    local wantFly = state.fly or (state.jumpFly and flyRig.holdTimer > 0.45)
    if not wantFly then
        if flyRig.active then
            destroyRig()
        end
        return
    end
    if not flyRig.active and not buildRig() then
        return
    end
    if not flyRig.align or not flyRig.target then
        return
    end

    local speed = state.flySpeed
    local move = hum.MoveDirection
    local step = Vector3.new(move.X, 0, move.Z) * speed * dt
    local rise = 0
    if held and root.Position.Y < state.maxFlyHeight then
        rise = speed * 0.7 * dt
    end

    flyRig.target = flyRig.target + step + Vector3.new(0, rise, 0)
    flyRig.align.Position = flyRig.target
    if flyRig.orient then
        flyRig.orient.CFrame = CFrame.new(flyRig.target)
                * CFrame.Angles(0, math.rad(root.Orientation.Y), 0)
    end
end

local function cframeTravel(target, speed)
    if flyRig.active then
        destroyRig()
    end
    local deadline = os.clock() + 15
    while os.clock() < deadline do
        if _G.__bloxHub ~= session then
            break
        end
        local root = rootPart()
        if not root then
            break
        end
        local delta = target - root.Position
        if delta.Magnitude < 6 then
            return true
        end
        local dt = RunService.Heartbeat:Wait()
        if dt > 0.2 then
            dt = 0.2
        end
        local step = math.min(speed * dt, delta.Magnitude)
        root.CFrame = CFrame.new(root.Position + delta.Unit * step)
    end
    return false
end

local function travelTo(target, speed)
    if state.moveMode == "cframe" then
        return cframeTravel(target, speed)
    end
    local root = rootPart()
    if not root or not target then
        return false
    end

    local owned = false
    if not flyRig.active then
        if not buildRig() then
            return cframeTravel(target, speed)
        end
        owned = true
    end

    flyRig.lock = flyRig.lock + 1

    local ok, reached = pcall(function()
        flyRig.target = root.Position
        if not flyRig.align then
            return false
        end
        flyRig.align.Position = flyRig.target

        local maxSpeed = math.min(speed, 220)
        local deadline = os.clock() + 15
        local arrived = false
        local watchdog = os.clock()
        local watchPos = root.Position

        while os.clock() < deadline do
            if _G.__bloxHub ~= session then
                break
            end
            if not rootPart() or not flyRig.align or not flyRig.target then
                break
            end
            local dt = RunService.Heartbeat:Wait()
            if dt > 0.25 then
                dt = 0.25
            end
            local current = flyRig.target
            if not current then
                break
            end
            local delta = target - current
            if delta.Magnitude < 6 then
                arrived = true
                break
            end
            local flat = Vector3.new(delta.X, 0, delta.Z)
            local direction = flat.Magnitude > 0.1 and flat.Unit or Vector3.zero
            local lift = 0
            if delta.Y > 3 then
                lift = 1
            elseif delta.Y < -3 then
                lift = -1
            end
            local move = direction + Vector3.new(0, lift, 0)
            if move.Magnitude > 0.01 then
                flyRig.target = flyRig.target + move.Unit * maxSpeed * dt
            end
            flyRig.align.Position = flyRig.target

            if os.clock() - watchdog > 1.2 then
                local now = rootPart()
                if now and (now.Position - watchPos).Magnitude < 8 then
                    return "stuck"
                end
                if now then
                    watchPos = now.Position
                end
                watchdog = os.clock()
            end
        end
        return arrived
    end)

    flyRig.lock = math.max(0, flyRig.lock - 1)

    if not ok then
        Log.add("ERRO", "travelTo: " .. tostring(reached))
        if owned then
            destroyRig()
        end
        return false
    end

    if reached == "stuck" then
        if owned then
            destroyRig()
        end
        state.moveMode = "cframe"
        status("movimento: CFrame")
        return cframeTravel(target, speed)
    end

    if owned then
        destroyRig()
    end

    Log.add(reached and "ACAO" or "AVISO",
            string.format("deslocamento %s | modo %s", reached and "ok" or "incompleto", state.moveMode))
    return reached == true
end

local function touchSweep(seconds)
    if not flyRig.active or not flyRig.align then
        return
    end
    local center = flyRig.target
    local start = os.clock()
    while (os.clock() - start) < seconds and _G.__bloxHub == session do
        RunService.Heartbeat:Wait()
        local angle = (os.clock() - start) * 9
        flyRig.target = center + Vector3.new(math.cos(angle) * 8, 0, math.sin(angle) * 8)
        flyRig.align.Position = flyRig.target
    end
    flyRig.target = center
    flyRig.align.Position = center
end

-- ===== ESP =====
local espFolder = Instance.new("Folder")
espFolder.Name = "BloxEsp"
pcall(function()
    espFolder.Parent = uiRoot()
end)
session.espFolder = espFolder

local chamsFolder = Instance.new("Folder")
chamsFolder.Name = "hubChams"
pcall(function()
    chamsFolder.Parent = Workspace
end)

local espItems = {}
local tracers = {}
local chams = {}
local drawLines = {}

local function line(key, thickness)
    if not Drawing then
        return nil
    end
    local object = drawLines[key]
    if not object then
        object = Drawing.new("Line")
        object.Thickness = thickness or 1
        object.Transparency = 0.9
        object.Visible = false
        drawLines[key] = object
    end
    return object
end

local function hidePrefix(prefix)
    for key, object in pairs(drawLines) do
        if string.sub(key, 1, #prefix) == prefix then
            pcall(function()
                object.Visible = false
            end)
        end
    end
end

local SKELETON = {
    R15 = {
        {"Head", "UpperTorso"}, {"UpperTorso", "LowerTorso"},
        {"UpperTorso", "LeftUpperArm"}, {"LeftUpperArm", "LeftLowerArm"},
        {"LeftLowerArm", "LeftHand"},
        {"UpperTorso", "RightUpperArm"}, {"RightUpperArm", "RightLowerArm"},
        {"RightLowerArm", "RightHand"},
        {"LowerTorso", "LeftUpperLeg"}, {"LeftUpperLeg", "LeftLowerLeg"},
        {"LeftLowerLeg", "LeftFoot"},
        {"LowerTorso", "RightUpperLeg"}, {"RightUpperLeg", "RightLowerLeg"},
        {"RightLowerLeg", "RightFoot"},
    },
    R6 = {
        {"Head", "Torso"}, {"Torso", "Left Arm"}, {"Torso", "Right Arm"},
        {"Torso", "Left Leg"}, {"Torso", "Right Leg"},
    },
}

local function removeEsp(model)
    local item = espItems[model]
    if item then
        for _, object in pairs(item) do
            if typeof(object) == "Instance" then
                pcall(function()
                    object:Destroy()
                end)
            end
        end
        espItems[model] = nil
    end
    local tracer = tracers[model]
    if tracer then
        pcall(function()
            tracer:Remove()
        end)
        tracers[model] = nil
    end
end

local function ensureEsp(model, part, color, title)
    local item = espItems[model]
    if item and item.highlight and item.highlight.Parent then
        return item
    end

    local highlight = Instance.new("Highlight")
    highlight.FillTransparency = state.espFill and 0.6 or 1
    highlight.FillColor = color
    highlight.OutlineColor = color
    highlight.OutlineTransparency = 0.25
    highlight.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
    highlight.Adornee = model
    highlight.Parent = espFolder

    local billboard = Instance.new("BillboardGui")
    billboard.Size = UDim2.fromOffset(150, 34)
    billboard.StudsOffset = Vector3.new(0, 3.4, 0)
    billboard.AlwaysOnTop = true
    billboard.MaxDistance = state.espRange
    billboard.Adornee = part
    billboard.Parent = espFolder

    local nameLabel = Instance.new("TextLabel")
    nameLabel.Size = UDim2.new(1, 0, 0.55, 0)
    nameLabel.BackgroundTransparency = 1
    nameLabel.Font = Enum.Font.Gotham
    nameLabel.TextSize = 12
    nameLabel.TextColor3 = color
    nameLabel.TextStrokeTransparency = 0.55
    nameLabel.TextStrokeColor3 = Color3.fromRGB(0, 0, 0)
    nameLabel.Text = title
    nameLabel.Parent = billboard

    local barBack = Instance.new("Frame")
    barBack.Size = UDim2.new(0.8, 0, 0.14, 0)
    barBack.Position = UDim2.new(0.1, 0, 0.62, 0)
    barBack.BackgroundColor3 = Color3.fromRGB(20, 20, 20)
    barBack.BorderSizePixel = 0
    barBack.Parent = billboard

    local barFill = Instance.new("Frame")
    barFill.Size = UDim2.fromScale(1, 1)
    barFill.BackgroundColor3 = Color3.fromRGB(90, 220, 120)
    barFill.BorderSizePixel = 0
    barFill.Parent = barBack

    item = {highlight = highlight, billboard = billboard, label = nameLabel,
            barBack = barBack, barFill = barFill}
    espItems[model] = item

    if state.espTracer and Drawing then
        local tracer = Drawing.new("Line")
        tracer.Thickness = 1
        tracer.Color = color
        tracer.Transparency = 0.6
        tracers[model] = tracer
    end
    return item
end

local function updateSkeleton(model, key, color)
    local camera = Workspace.CurrentCamera
    if not camera then
        return
    end
    local rig = model:FindFirstChild("UpperTorso") and "R15" or "R6"
    local joints = SKELETON[rig]
    if not joints then
        return
    end
    for index, pair in ipairs(joints) do
        local a = model:FindFirstChild(pair[1], true)
        local b = model:FindFirstChild(pair[2], true)
        if a and b and a:IsA("BasePart") and b:IsA("BasePart") then
            local object = line(key .. "_sk" .. index, 1)
            if object then
                local pa, onA = camera:WorldToViewportPoint(a.Position)
                local pb, onB = camera:WorldToViewportPoint(b.Position)
                if onA and onB then
                    object.From = Vector2.new(pa.X, pa.Y)
                    object.To = Vector2.new(pb.X, pb.Y)
                    object.Color = color
                    object.Visible = true
                else
                    object.Visible = false
                end
            end
        end
    end
end

local function updateBox(model, key, color)
    local camera = Workspace.CurrentCamera
    if not camera then
        return
    end
    local ok, cf, size = pcall(function()
        local c, s = model:GetBoundingBox()
        return c, s
    end)
    if not ok or not cf then
        hidePrefix(key .. "_box")
        return
    end

    local minX, minY = math.huge, math.huge
    local maxX, maxY = -math.huge, -math.huge
    local visible = false

    for _, sx in ipairs({-0.5, 0.5}) do
        for _, sy in ipairs({-0.5, 0.5}) do
            for _, sz in ipairs({-0.5, 0.5}) do
                local world = cf * Vector3.new(size.X * sx, size.Y * sy, size.Z * sz)
                local point, onScreen = camera:WorldToViewportPoint(world)
                if onScreen then
                    visible = true
                    minX = math.min(minX, point.X)
                    minY = math.min(minY, point.Y)
                    maxX = math.max(maxX, point.X)
                    maxY = math.max(maxY, point.Y)
                end
            end
        end
    end

    if not visible then
        hidePrefix(key .. "_box")
        return
    end

    local corners = {
        {Vector2.new(minX, minY), Vector2.new(maxX, minY)},
        {Vector2.new(maxX, minY), Vector2.new(maxX, maxY)},
        {Vector2.new(maxX, maxY), Vector2.new(minX, maxY)},
        {Vector2.new(minX, maxY), Vector2.new(minX, minY)},
    }
    for index, pair in ipairs(corners) do
        local object = line(key .. "_box" .. index, 1)
        if object then
            object.From = pair[1]
            object.To = pair[2]
            object.Color = color
            object.Visible = true
        end
    end
end

local function updateChams(character, color, key)
    local root = character:FindFirstChild("HumanoidRootPart")
    if not root then
        return
    end
    local entry = chams[key]
    if not entry or not entry.model or not entry.model.Parent then
        local clone = character:Clone()
        for _, object in ipairs(clone:GetDescendants()) do
            if object:IsA("Script") or object:IsA("LocalScript") then
                object:Destroy()
            elseif object:IsA("BasePart") then
                object.Anchored = true
                object.CanCollide = false
                object.CanQuery = false
                object.CanTouch = false
                object.Transparency = 0.5
                object.Material = Enum.Material.SmoothPlastic
                object.Color = color
            elseif object:IsA("Decal") or object:IsA("Texture") then
                object.Transparency = 1
            end
        end
        clone.Name = "hubCham_" .. key
        clone.Parent = chamsFolder

        local highlight = Instance.new("Highlight")
        highlight.FillColor = color
        highlight.FillTransparency = 0.65
        highlight.OutlineColor = color
        highlight.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
        highlight.Adornee = clone
        highlight.Parent = chamsFolder

        entry = {model = clone, highlight = highlight}
        chams[key] = entry
    end

    local primary = entry.model.PrimaryPart or entry.model:FindFirstChild("HumanoidRootPart")
    if primary then
        entry.model.PrimaryPart = primary
        pcall(function()
            entry.model:PivotTo(root.CFrame)
        end)
    end
end

local function clearChams()
    for key, entry in pairs(chams) do
        pcall(function()
            if entry.model then
                entry.model:Destroy()
            end
            if entry.highlight then
                entry.highlight:Destroy()
            end
        end)
        chams[key] = nil
    end
end

local function screenPoint(part)
    local camera = Workspace.CurrentCamera
    if not camera then
        return nil
    end
    local point, onScreen = camera:WorldToViewportPoint(part.Position)
    if not onScreen then
        return nil
    end
    return Vector2.new(point.X, point.Y)
end

local function refreshEsp()
    local active = {}
    local mine = rootPart()

    local function handle(entry, color, title)
        active[entry.model] = true
        local item = ensureEsp(entry.model, entry.part, color, title)
        if not item or not item.highlight or not item.highlight.Parent then
            return
        end
        local distance = mine and (entry.part.Position - mine.Position).Magnitude or 0
        if distance > state.espRange then
            item.billboard.Enabled = false
            item.highlight.Enabled = false
            hidePrefix(tostring(entry.model))
            return
        end
        item.highlight.Enabled = true
        item.billboard.Enabled = true

        local pieces = {}
        if state.espName then
            pieces[#pieces + 1] = title
        end
        if state.espDistance then
            pieces[#pieces + 1] = string.format("[%d]", math.floor(distance))
        end
        item.label.Text = table.concat(pieces, " ")
        item.barBack.Visible = state.espHealth

        local hum = entry.model:FindFirstChildOfClass("Humanoid")
        if hum and hum.MaxHealth > 0 then
            local ratio = math.clamp(hum.Health / hum.MaxHealth, 0, 1)
            item.barFill.Size = UDim2.fromScale(ratio, 1)
            item.barFill.BackgroundColor3 = Color3.fromRGB(220 * (1 - ratio) + 90 * ratio,
                    90 + 130 * ratio, 90)
        end

        local key = tostring(entry.model)
        if state.espSkeleton then
            updateSkeleton(entry.model, key, color)
        else
            hidePrefix(key .. "_sk")
        end
        if state.espBox then
            updateBox(entry.model, key, color)
        else
            hidePrefix(key .. "_box")
        end
        if state.espHeadDot then
            local head = entry.model:FindFirstChild("Head")
            if head then
                local dot = line(key .. "_head", 3)
                local point = screenPoint(head)
                if dot then
                    if point then
                        dot.From = point
                        dot.To = point + Vector2.new(0, 1)
                        dot.Color = color
                        dot.Visible = true
                    else
                        dot.Visible = false
                    end
                end
            end
        else
            hidePrefix(key .. "_head")
        end

        local tracer = tracers[entry.model]
        if tracer then
            if state.espTracer then
                local point = screenPoint(entry.part)
                local camera = Workspace.CurrentCamera
                if point and camera then
                    tracer.From = Vector2.new(camera.ViewportSize.X / 2, camera.ViewportSize.Y)
                    tracer.To = point
                    tracer.Visible = true
                else
                    tracer.Visible = false
                end
            else
                tracer.Visible = false
            end
        end
    end

    local function rgb(t)
        return Color3.fromRGB(t[1], t[2], t[3])
    end

    if state.espTarget then
        for _, fruit in ipairs(collectTargets()) do
            handle(fruit, rgb(state.colorTarget), fruit.model.Name)
        end
    end
    if state.espEnemy then
        for _, enemy in ipairs(collectEnemies()) do
            handle(enemy, rgb(state.colorEnemy), enemy.model.Name)
        end
    end
    if state.espPlayer then
        for _, player in ipairs(Players:GetPlayers()) do
            if player ~= LocalPlayer and player.Character then
                local root = player.Character:FindFirstChild("HumanoidRootPart")
                if root and (not state.espOnlySelected or player.Name == state.selectedPlayer) then
                    handle({model = player.Character, part = root},
                            rgb(state.colorPlayer), player.Name)
                    if state.espChams then
                        updateChams(player.Character, rgb(state.colorChams), player.Name)
                    end
                end
            end
        end
    end

    for model in pairs(espItems) do
        if not active[model] or not model.Parent then
            removeEsp(model)
        end
    end
    for model in pairs(tracers) do
        if not active[model] then
            local tracer = tracers[model]
            pcall(function()
                tracer:Remove()
            end)
            tracers[model] = nil
        end
    end
    if not state.espChams then
        clearChams()
    else
        for name, entry in pairs(chams) do
            local player = Players:FindFirstChild(name)
            if not player or not player.Character or not state.espPlayer then
                pcall(function()
                    if entry.model then
                        entry.model:Destroy()
                    end
                    if entry.highlight then
                        entry.highlight:Destroy()
                    end
                end)
                chams[name] = nil
            end
        end
    end
end


-- ===== combate =====
local function currentTool()
    local char = LocalPlayer.Character
    return char and char:FindFirstChildOfClass("Tool")
end

local function equipTool()
    if not state.autoEquip then
        return
    end
    local char = LocalPlayer.Character
    local backpack = LocalPlayer:FindFirstChild("Backpack")
    if not char or not backpack or char:FindFirstChildOfClass("Tool") then
        return
    end
    local hum = char:FindFirstChildOfClass("Humanoid")
    for _, tool in ipairs(backpack:GetChildren()) do
        if tool:IsA("Tool") and hum then
            pcall(function()
                hum:EquipTool(tool)
            end)
            return
        end
    end
end

local function activateTool()
    equipTool()
    local tool = currentTool()
    if not tool then
        return false
    end
    pcall(function()
        tool:Activate()
    end)
    return true
end

local function pickTarget()
    local list = collectEnemies()
    local mine = rootPart()
    if not mine then
        return nil, math.huge
    end
    local best, bestDistance = nil, math.huge
    for _, entry in ipairs(list) do
        local distance = (entry.part.Position - mine.Position).Magnitude
        if distance < bestDistance then
            best, bestDistance = entry, distance
        end
    end
    return best, bestDistance
end

local function applyMovement()
    local hum = humanoid()
    if hum then
        hum.WalkSpeed = flyRig.active and 0 or state.speed
        hum.UseJumpPower = true
        hum.JumpPower = state.jump
    end
end

local function farmCycle()
    local enemy, distance = pickTarget()
    if not enemy or distance > state.farmRange then
        status("farm: sem alvo")
        return false
    end
    status(string.format("farm: %s | %d", enemy.model.Name, math.floor(distance)))

    local owned = false
    if not flyRig.active then
        if not buildRig() then
            return false
        end
        owned = true
    end

    travelTo(enemy.part.Position + Vector3.new(0, 3, 0), state.flySpeed)

    local started = os.clock()
    local killed = false
    while os.clock() - started < 3 and _G.__hubBase == session do
        if not enemy.model.Parent or not aliveRoot(enemy.model) then
            killed = true
            break
        end
        local mine = rootPart()
        if mine and (enemy.part.Position - mine.Position).Magnitude > 16 then
            flyRig.target = enemy.part.Position + Vector3.new(0, 3, 0)
            if flyRig.align then
                flyRig.align.Position = flyRig.target
            end
        end
        activateTool()
        task.wait(state.attackDelay)
    end

    Log.add(killed and "ACAO" or "AVISO", string.format("farm: %s %s | arma %s",
            killed and "matou" or "nao matou", enemy.model.Name,
            currentTool() and currentTool().Name or "NENHUMA"))

    if owned then
        destroyRig()
    end
    return true
end

local hitboxOriginal = {}
local hitboxParts = {}

local function applyHitbox()
    if not state.hitbox then
        for part, original in pairs(hitboxOriginal) do
            pcall(function()
                part.Size = original.size
                part.Transparency = original.transparency
                part.CanCollide = original.collide
            end)
        end
        hitboxOriginal = {}
        for _, extra in pairs(hitboxParts) do
            pcall(function()
                extra:Destroy()
            end)
        end
        hitboxParts = {}
        return
    end
    for _, enemy in ipairs(collectEnemies()) do
        for _, part in ipairs(enemy.model:GetDescendants()) do
            if part:IsA("BasePart") and (part.Name == "HumanoidRootPart" or part.Name == "Torso"
                    or part.Name == "UpperTorso" or part.Name == "LowerTorso"
                    or part.Name == "Head") then
                if not hitboxOriginal[part] then
                    hitboxOriginal[part] = {size = part.Size,
                                            transparency = part.Transparency,
                                            collide = part.CanCollide}
                end
                part.Size = Vector3.new(state.hitboxSize, state.hitboxSize, state.hitboxSize)
                part.Transparency = 0.85
                part.CanCollide = false
            end
        end
        if not hitboxParts[enemy.model] and enemy.part then
            local box = Instance.new("Part")
            box.Name = "hubHitbox"
            box.Size = Vector3.new(state.hitboxSize, state.hitboxSize, state.hitboxSize)
            box.Transparency = 1
            box.CanCollide = false
            box.CanQuery = true
            box.CanTouch = true
            box.Massless = true
            box.Parent = enemy.model
            box.CFrame = enemy.part.CFrame
            local weld = Instance.new("WeldConstraint")
            weld.Part0 = enemy.part
            weld.Part1 = box
            weld.Parent = box
            hitboxParts[enemy.model] = box
        end
    end
end

-- ===== interface =====
local function uiRoot()
    if type(gethui) == "function" then
        local ok, value = pcall(gethui)
        if ok and value then
            return value
        end
    end
    return game:GetService("CoreGui")
end

local playerGui = LocalPlayer:FindFirstChildOfClass("PlayerGui")
    or LocalPlayer:WaitForChild("PlayerGui", 10)

local function makeGui(name, order)
    local gui = Instance.new("ScreenGui")
    gui.Name = name
    gui.ResetOnSpawn = false
    gui.IgnoreGuiInset = true
    gui.DisplayOrder = order
    local placed = pcall(function()
        gui.Parent = playerGui
    end)
    if not placed or not gui.Parent then
        pcall(function()
            gui.Parent = game:GetService("CoreGui")
        end)
    end
    if not gui.Parent then
        pcall(function()
            gui.Parent = uiRoot()
        end)
    end
    return gui
end

local bubbleGui = makeGui("HubBubble", 999999)

local bubble = Instance.new("TextButton")
bubble.Size = UDim2.fromOffset(58, 58)
bubble.Position = UDim2.new(0, 18, 0.45, 0)
bubble.BackgroundColor3 = Color3.fromRGB(14, 17, 23)
bubble.BorderSizePixel = 0
bubble.AutoButtonColor = false
bubble.Text = "H"
bubble.Font = Enum.Font.GothamBold
bubble.TextSize = 24
bubble.TextColor3 = Color3.fromRGB(255, 170, 60)
bubble.Parent = bubbleGui

local bubbleCorner = Instance.new("UICorner")
bubbleCorner.CornerRadius = UDim.new(1, 0)
bubbleCorner.Parent = bubble

local bubbleStroke = Instance.new("UIStroke")
bubbleStroke.Color = Color3.fromRGB(220, 130, 40)
bubbleStroke.Thickness = 2
bubbleStroke.Transparency = 0.15
bubbleStroke.Parent = bubble

session.bubble = bubbleGui

local statusGui = makeGui("HubStatus", 999998)

local statusText = Instance.new("TextLabel")
statusText.Size = UDim2.fromOffset(340, 30)
statusText.Position = UDim2.new(0.5, -170, 1, -70)
statusText.BackgroundColor3 = Color3.fromRGB(14, 17, 23)
statusText.BackgroundTransparency = 0.2
statusText.BorderSizePixel = 0
statusText.Text = "pronto"
statusText.TextColor3 = Color3.fromRGB(255, 200, 140)
statusText.Font = Enum.Font.Gotham
statusText.TextSize = 13
statusText.Parent = statusGui

local statusCorner = Instance.new("UICorner")
statusCorner.CornerRadius = UDim.new(0, 10)
statusCorner.Parent = statusText

statusLabel = statusText
session.statusGui = statusGui

local function findWindow()
    local places = {uiRoot(), playerGui}
    for _, place in ipairs(places) do
        if place then
            for _, child in ipairs(place:GetChildren()) do
                if child:IsA("ScreenGui") and string.find(string.lower(child.Name), "rayfield") then
                    local main = child:FindFirstChild("Main")
                    if main then
                        return child, main
                    end
                    return child, nil
                end
            end
        end
    end
    return nil, nil
end

local function showWindow(show)
    local gui, main = findWindow()
    if gui then
        if main then
            main.Visible = show
        else
            gui.Enabled = show
        end
    end
    local size = show and 42 or 58
    TweenService:Create(bubble, TweenInfo.new(0.2, Enum.EasingStyle.Back),
            {Size = UDim2.fromOffset(size, size)}):Play()
    bubble.TextTransparency = show and 0.45 or 0
    bubble.BackgroundTransparency = show and 0.45 or 0
end

local dragging = false
local dragStart = nil
local startPosition = nil
local moved = false

bubble.InputBegan:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1
            or input.UserInputType == Enum.UserInputType.Touch then
        dragging = true
        moved = false
        dragStart = input.Position
        startPosition = bubble.Position
    end
end)

session.connections[#session.connections + 1] = UserInputService.InputChanged:Connect(function(input)
    if not dragging then
        return
    end
    if input.UserInputType == Enum.UserInputType.MouseMovement
            or input.UserInputType == Enum.UserInputType.Touch then
        local delta = input.Position - dragStart
        if delta.Magnitude > 6 then
            moved = true
        end
        bubble.Position = UDim2.new(startPosition.X.Scale, startPosition.X.Offset + delta.X,
                startPosition.Y.Scale, startPosition.Y.Offset + delta.Y)
    end
end)

session.connections[#session.connections + 1] = UserInputService.InputEnded:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1
            or input.UserInputType == Enum.UserInputType.Touch then
        dragging = false
        if not moved then
            showWindow(true)
        end
    end
end)

-- ===== fps =====
local function disablePostEffects()
    for _, object in ipairs(Lighting:GetChildren()) do
        if object:IsA("PostEffect") or object:IsA("Atmosphere") then
            pcall(function()
                object.Enabled = false
            end)
        end
    end
end

local function applyFpsPack()
    pcall(function()
        settings().Rendering.QualityLevel = Enum.QualityLevel.Level01
    end)
    pcall(function()
        Lighting.GlobalShadows = false
        Lighting.FogEnd = 100000
    end)
    disablePostEffects()
    if type(setfpscap) == "function" then
        pcall(function()
            setfpscap(240)
        end)
    end
    status("fps: pacote aplicado")
end

local function killParticles()
    local count = 0
    for _, object in ipairs(descendants()) do
        if object:IsA("ParticleEmitter") or object:IsA("Trail") or object:IsA("Smoke")
                or object:IsA("Fire") or object:IsA("Sparkles") then
            pcall(function()
                object.Enabled = false
            end)
            count = count + 1
        end
    end
    return count
end

-- ===== UI =====
local Window = Rayfield:CreateWindow({
    Name = "Hub | " .. Game.name,
    LoadingTitle = "carregando",
    ConfigurationSaving = {Enabled = false},
})

session.window = Window

local FarmTab = Window:CreateTab("Farm", 4483362458)

FarmTab:CreateToggle({
    Name = "Auto farm",
    CurrentValue = false,
    Callback = function(value)
        state.autoFarm = value
    end,
})

FarmTab:CreateToggle({
    Name = "Fast attack",
    CurrentValue = false,
    Callback = function(value)
        state.fastAttack = value
    end,
})

FarmTab:CreateToggle({
    Name = "Kill aura",
    CurrentValue = false,
    Callback = function(value)
        state.killAura = value
    end,
})

FarmTab:CreateSlider({
    Name = "Raio da aura",
    Range = {10, 200},
    Increment = 5,
    CurrentValue = state.auraRange,
    Callback = function(value)
        state.auraRange = value
    end,
})

FarmTab:CreateSlider({
    Name = "Alcance do farm",
    Range = {50, 5000},
    Increment = 50,
    CurrentValue = state.farmRange,
    Callback = function(value)
        state.farmRange = value
    end,
})

FarmTab:CreateSlider({
    Name = "Intervalo de ataque",
    Range = {0.01, 0.5},
    Increment = 0.01,
    CurrentValue = state.attackDelay,
    Callback = function(value)
        state.attackDelay = value
    end,
})

FarmTab:CreateToggle({
    Name = "Hitbox expandida",
    CurrentValue = false,
    Callback = function(value)
        state.hitbox = value
        applyHitbox()
    end,
})

FarmTab:CreateSlider({
    Name = "Tamanho da hitbox",
    Range = {6, 40},
    Increment = 1,
    CurrentValue = state.hitboxSize,
    Callback = function(value)
        state.hitboxSize = value
    end,
})

FarmTab:CreateButton({
    Name = "Atacar o mais proximo",
    Callback = function()
        task.spawn(farmCycle)
    end,
})

local MoveTab = Window:CreateTab("Movimento", 4483362458)

MoveTab:CreateToggle({
    Name = "Voo: segurar pulo",
    CurrentValue = state.jumpFly,
    Callback = function(value)
        state.jumpFly = value
        if not value then
            destroyRig()
        end
    end,
})

MoveTab:CreateToggle({
    Name = "Voo continuo",
    CurrentValue = false,
    Callback = function(value)
        state.fly = value
        if not value then
            destroyRig()
        end
    end,
})

MoveTab:CreateSlider({
    Name = "Velocidade do voo",
    Range = {20, 1200},
    Increment = 20,
    CurrentValue = state.flySpeed,
    Callback = function(value)
        state.flySpeed = value
    end,
})

MoveTab:CreateSlider({
    Name = "Velocidade no chao",
    Range = {16, 300},
    Increment = 2,
    CurrentValue = state.speed,
    Callback = function(value)
        state.speed = value
        applyMovement()
    end,
})

MoveTab:CreateSlider({
    Name = "Pulo",
    Range = {50, 200},
    Increment = 5,
    CurrentValue = state.jump,
    Callback = function(value)
        state.jump = value
        applyMovement()
    end,
})

MoveTab:CreateSlider({
    Name = "Altura maxima",
    Range = {50, 800},
    Increment = 25,
    CurrentValue = state.maxFlyHeight,
    Callback = function(value)
        state.maxFlyHeight = value
    end,
})

MoveTab:CreateButton({
    Name = "Pousar",
    Callback = function()
        state.fly = false
        destroyRig()
    end,
})

local EspTab = Window:CreateTab("ESP", 4483362458)

EspTab:CreateToggle({
    Name = "Inimigos",
    CurrentValue = false,
    Callback = function(value)
        state.espEnemy = value
    end,
})

EspTab:CreateToggle({
    Name = "Alvos (fruta, bau, drop)",
    CurrentValue = true,
    Callback = function(value)
        state.espTarget = value
    end,
})

EspTab:CreateToggle({
    Name = "Jogadores",
    CurrentValue = false,
    Callback = function(value)
        state.espPlayer = value
    end,
})

EspTab:CreateToggle({
    Name = "Nome",
    CurrentValue = true,
    Callback = function(value)
        state.espName = value
    end,
})

EspTab:CreateToggle({
    Name = "Vida",
    CurrentValue = true,
    Callback = function(value)
        state.espHealth = value
    end,
})

EspTab:CreateToggle({
    Name = "Distancia",
    CurrentValue = true,
    Callback = function(value)
        state.espDistance = value
    end,
})

EspTab:CreateToggle({
    Name = "Tracer",
    CurrentValue = false,
    Callback = function(value)
        state.espTracer = value
        for model in pairs(espItems) do
            removeEsp(model)
        end
    end,
})

EspTab:CreateToggle({
    Name = "Esqueleto",
    CurrentValue = false,
    Callback = function(value)
        state.espSkeleton = value
    end,
})

EspTab:CreateToggle({
    Name = "Caixa",
    CurrentValue = false,
    Callback = function(value)
        state.espBox = value
    end,
})

EspTab:CreateToggle({
    Name = "ESP 3D (chams)",
    CurrentValue = false,
    Callback = function(value)
        state.espChams = value
        if not value then
            clearChams()
        end
    end,
})

EspTab:CreateSlider({
    Name = "Alcance do ESP",
    Range = {100, 5000},
    Increment = 100,
    CurrentValue = state.espRange,
    Callback = function(value)
        state.espRange = value
    end,
})

local TpTab = Window:CreateTab("Teleporte", 4483362458)

TpTab:CreateInput({
    Name = "Nome do ponto",
    CurrentValue = "",
    PlaceholderText = "ex: ilha",
    RemoveTextAfterFocusLost = false,
    Callback = function(text)
        state.newWaypoint = text
    end,
})

TpTab:CreateButton({
    Name = "Salvar ponto aqui",
    Callback = function()
        local root = rootPart()
        local name = state.newWaypoint
        if not root or not name or name == "" then
            Rayfield:Notify({Title = "Ponto", Content = "Precisa de nome.", Duration = 4})
            return
        end
        state.waypoints[name] = {x = root.Position.X, y = root.Position.Y, z = root.Position.Z}
        Rayfield:Notify({Title = "Ponto", Content = name .. " salvo.", Duration = 3})
    end,
})

TpTab:CreateButton({
    Name = "Ir flutuando ao ponto",
    Callback = function()
        local point = state.waypoints[state.newWaypoint or ""]
        if not point then
            Rayfield:Notify({Title = "Ponto", Content = "Nome nao encontrado.", Duration = 4})
            return
        end
        task.spawn(function()
            travelTo(Vector3.new(point.x, point.y, point.z), state.travelSpeed)
        end)
    end,
})

local playerTpDropdown = TpTab:CreateDropdown({
    Name = "Jogador",
    Options = {"(vazio)"},
    CurrentOption = {"(vazio)"},
    MultipleOptions = false,
    Callback = function(option)
        local name = type(option) == "table" and option[1] or option
        if name and name ~= "(vazio)" then
            state.selectedPlayer = name
        end
    end,
})

TpTab:CreateButton({
    Name = "Ir ate o jogador",
    Callback = function()
        local player = state.selectedPlayer and Players:FindFirstChild(state.selectedPlayer)
        local root = player and player.Character
                and player.Character:FindFirstChild("HumanoidRootPart")
        if not root then
            Rayfield:Notify({Title = "Viagem", Content = "Jogador sem personagem.", Duration = 4})
            return
        end
        task.spawn(function()
            travelTo(root.Position + Vector3.new(0, 6, 0), state.travelSpeed)
        end)
    end,
})

local FpsTab = Window:CreateTab("FPS", 4483362458)

FpsTab:CreateButton({
    Name = "Aplicar pacote FPS",
    Callback = function()
        applyFpsPack()
    end,
})

FpsTab:CreateButton({
    Name = "Desligar particulas",
    Callback = function()
        local count = killParticles()
        Rayfield:Notify({Title = "FPS", Content = count .. " desligados.", Duration = 4})
    end,
})

FpsTab:CreateButton({
    Name = "Teto 240",
    Callback = function()
        if type(setfpscap) == "function" then
            pcall(function()
                setfpscap(240)
            end)
        end
    end,
})

local MiscTab = Window:CreateTab("Misc", 4483362458)

MiscTab:CreateToggle({
    Name = "Anti AFK",
    CurrentValue = true,
    Callback = function(value)
        state.antiAfk = value
    end,
})

MiscTab:CreateToggle({
    Name = "Auto equipar arma",
    CurrentValue = true,
    Callback = function(value)
        state.autoEquip = value
    end,
})

MiscTab:CreateButton({
    Name = "Resumo",
    Callback = function()
        Log.add("INFO", string.format("jogo %s | inimigos %d | alvos %d | nivel %d",
                Game.name, #collectEnemies(), #collectTargets(), playerLevel()))
        setLogPanel(true)
    end,
})

-- ===== loops =====
session.connections[#session.connections + 1] = RunService.Heartbeat:Connect(function(dt)
    updateFly(dt)
end)

local lastAttack = 0

session.connections[#session.connections + 1] = RunService.RenderStepped:Connect(function()
    if not state.fastAttack then
        return
    end
    local now = os.clock()
    if now - lastAttack < state.attackDelay then
        return
    end
    lastAttack = now
    activateTool()
end)

LocalPlayer.CharacterAdded:Connect(function()
    destroyRig()
    task.wait(1)
    applyMovement()
end)

task.spawn(function()
    while _G.__hubBase == session do
        task.wait(0.4)
        pcall(refreshEsp)
        applyMovement()
        if state.hitbox then
            pcall(applyHitbox)
        end
    end
end)

task.spawn(function()
    while _G.__hubBase == session do
        task.wait(0.15)
        if state.killAura then
            local mine = rootPart()
            if mine then
                for _, enemy in ipairs(collectEnemies()) do
                    if (enemy.part.Position - mine.Position).Magnitude <= state.auraRange then
                        activateTool()
                        break
                    end
                end
            end
        end
        if state.autoFarm then
            pcall(farmCycle)
        end
    end
end)

task.spawn(function()
    while _G.__hubBase == session do
        task.wait(6)
        if playerTpDropdown then
            local names = {}
            for _, player in ipairs(Players:GetPlayers()) do
                if player ~= LocalPlayer then
                    names[#names + 1] = player.Name
                end
            end
            if #names > 0 then
                pcall(function()
                    playerTpDropdown:Refresh(names)
                end)
            end
        end
    end
end)

task.spawn(function()
    while _G.__hubBase == session do
        task.wait(0.4)
        if state.showLogPanel and Log.dirtyPanel then
            Log.dirtyPanel = false
            pcall(rebuildLogPanel)
        end
    end
end)

task.spawn(function()
    while _G.__hubBase == session do
        task.wait(60)
        if state.antiAfk then
            pcall(function()
                local vu = game:GetService("VirtualUser")
                vu:CaptureController()
                vu:ClickButton2(Vector2.new())
            end)
        end
    end
end)

applyMovement()
refreshEsp()
Log.add("INFO", "hub base v" .. SCRIPT_VERSION .. " | jogo: " .. Game.name)
Log.add("INFO", string.format("inimigos %d | alvos %d | nivel %d",
        #collectEnemies(), #collectTargets(), playerLevel()))
print("hub base carregado | " .. Game.name)
