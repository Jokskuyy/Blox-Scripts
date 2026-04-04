--[[
    ╔══════════════════════════════════════════════╗
    ║          ESP + TRACKER v1.1                  ║
    ║   Player ESP & Distance Tracker GUI          ║
    ║   Blox-Scripts by Jokskuyy                   ║
    ╠══════════════════════════════════════════════╣
    ║  Fitur:                                      ║
    ║    👁  ESP Box      - Kotak sekeliling player ║
    ║    📝 Nama          - Tampilkan nama player   ║
    ║    ❤  Health Bar   - Bar HP di atas player   ║
    ║    📏 Jarak         - Tampilkan jarak (studs) ║
    ║    📍 Tracer        - Garis ke player         ║
    ║    🏹 Tracker Arrow - Panah arah off-screen   ║
    ╚══════════════════════════════════════════════╝

    Keybinds:
    - RightControl : Toggle ESP On/Off
    - B            : Toggle Tracker Arrows On/Off
    - M            : Show/Hide Panel GUI
]]

-- ============================================
-- CLEANUP: Hapus instance lama jika re-execute
-- ============================================
pcall(function()
    if _G._ESP_CLEANUP then
        _G._ESP_CLEANUP()
    end
end)

-- ============================================
-- SERVICES
-- ============================================
local Players           = game:GetService("Players")
local RunService        = game:GetService("RunService")
local UserInputService  = game:GetService("UserInputService")
local TweenService      = game:GetService("TweenService")
local CoreGui           = game:GetService("CoreGui")

-- ============================================
-- PLAYER
-- ============================================
local player = Players.LocalPlayer
local camera = workspace.CurrentCamera

-- ============================================
-- DRAWING API CHECK
-- ============================================
local HAS_DRAWING = (typeof(Drawing) == "table" or typeof(Drawing) == "userdata")
if not HAS_DRAWING then
    pcall(function()
        HAS_DRAWING = Drawing and Drawing.new and true or false
    end)
end

-- ============================================
-- COLOR PALETTE
-- ============================================
local C = {
    bg           = Color3.fromRGB(12, 12, 20),
    bgCard       = Color3.fromRGB(22, 22, 36),
    bgInput      = Color3.fromRGB(32, 32, 50),
    border       = Color3.fromRGB(55, 55, 80),
    text         = Color3.fromRGB(220, 220, 240),
    textDim      = Color3.fromRGB(120, 120, 150),
    textMuted    = Color3.fromRGB(80, 80, 110),
    accent       = Color3.fromRGB(110, 70, 255),
    accentLight  = Color3.fromRGB(140, 100, 255),
    accentGlow   = Color3.fromRGB(180, 140, 255),
    green        = Color3.fromRGB(80, 255, 140),
    red          = Color3.fromRGB(255, 80, 90),
    orange       = Color3.fromRGB(255, 170, 40),
    gold         = Color3.fromRGB(255, 215, 80),
    white        = Color3.fromRGB(255, 255, 255),
    cyan         = Color3.fromRGB(60, 200, 255),
}

-- ============================================
-- CONFIGURATION — SEMUA ON BY DEFAULT
-- ============================================
local Config = {
    ESPEnabled       = true,
    TrackerEnabled   = true,
    ShowBoxes        = true,
    ShowNames        = true,
    ShowHealth       = true,
    ShowDistance      = true,
    ShowTracers      = true,
    TeamCheck        = false,
    MaxDistance       = 2000,

    -- Enemy ESP (NPC/Mob)
    EnemyESPEnabled  = true,   -- ON by default
    EnemyColor       = Color3.fromRGB(255, 60, 60),

    -- Aimbot
    AimbotEnabled    = false,  -- OFF by default (bahaya)
    AimbotKey        = Enum.KeyCode.Q,  -- Hold Q untuk aim
    AimbotFOV        = 200,    -- Field of View radius (pixels)
    AimbotSmoothing  = 5,      -- Smoothing (1=instant, 10=slow)
    AimbotTarget     = "Head", -- "Head" atau "HumanoidRootPart"
    AimbotTargetNPC  = true,   -- Aim ke NPC juga
    AimbotTargetPlr  = true,   -- Aim ke Player juga

    BoxColor         = Color3.fromRGB(110, 70, 255),
    NameColor        = Color3.fromRGB(220, 220, 240),
    TracerColor      = Color3.fromRGB(60, 200, 255),
    HealthHighColor  = Color3.fromRGB(80, 255, 140),
    HealthMidColor   = Color3.fromRGB(255, 215, 80),
    HealthLowColor   = Color3.fromRGB(255, 80, 90),
    TrackerColor     = Color3.fromRGB(255, 170, 40),
}

-- ============================================
-- STATE
-- ============================================
local espObjects    = {}
local espHighlights = {}
local enemyESPData  = {}  -- NPC/mob highlight+billboard
local guiVisible    = true
local refs          = {}
local connections   = {}
local aimbotHolding = false
local aimbotCurrentTarget = nil
local fovCircle     = nil

-- ============================================
-- HELPERS
-- ============================================
local function tween(obj, props, dur, style, dir)
    dur   = dur or 0.25
    style = style or Enum.EasingStyle.Quart
    dir   = dir or Enum.EasingDirection.Out
    return TweenService:Create(obj, TweenInfo.new(dur, style, dir), props)
end

local function corner(parent, r)
    local c = Instance.new("UICorner")
    c.CornerRadius = UDim.new(0, r or 10)
    c.Parent = parent
    return c
end

local function stroke(parent, col, thick, transp)
    local s = Instance.new("UIStroke")
    s.Color        = col or C.border
    s.Thickness    = thick or 1
    s.Transparency = transp or 0.4
    s.Parent       = parent
    return s
end

-- Safe ScreenGui parent (CoreGui > gethui > PlayerGui)
local function getGuiParent()
    local ok, result = pcall(function()
        if gethui then return gethui() end
    end)
    if ok and result then return result end

    local ok2, result2 = pcall(function()
        return CoreGui
    end)
    if ok2 and result2 then
        -- Test if we can parent to CoreGui
        local testOk = pcall(function()
            local t = Instance.new("Folder")
            t.Parent = result2
            t:Destroy()
        end)
        if testOk then return result2 end
    end

    return player:WaitForChild("PlayerGui")
end

-- ============================================
-- DRAWING API ESP (when Drawing is available)
-- ============================================
local function createDrawingESP(targetPlayer)
    if espObjects[targetPlayer] then return end

    local ok, obj = pcall(function()
        local o = {}

        o.Box = Drawing.new("Square")
        o.Box.Thickness = 1.5
        o.Box.Color = Config.BoxColor
        o.Box.Filled = false
        o.Box.Transparency = 1
        o.Box.Visible = false

        o.BoxFill = Drawing.new("Square")
        o.BoxFill.Thickness = 1
        o.BoxFill.Color = Config.BoxColor
        o.BoxFill.Filled = true
        o.BoxFill.Transparency = 0.8
        o.BoxFill.Visible = false

        o.Name = Drawing.new("Text")
        o.Name.Size = 14
        o.Name.Color = Config.NameColor
        o.Name.Center = true
        o.Name.Outline = true
        o.Name.OutlineColor = Color3.fromRGB(0, 0, 0)
        o.Name.Font = 2
        o.Name.Transparency = 1
        o.Name.Visible = false

        o.Distance = Drawing.new("Text")
        o.Distance.Size = 12
        o.Distance.Color = C.textDim
        o.Distance.Center = true
        o.Distance.Outline = true
        o.Distance.OutlineColor = Color3.fromRGB(0, 0, 0)
        o.Distance.Font = 2
        o.Distance.Transparency = 1
        o.Distance.Visible = false

        o.HealthBg = Drawing.new("Square")
        o.HealthBg.Thickness = 1
        o.HealthBg.Color = Color3.fromRGB(0, 0, 0)
        o.HealthBg.Filled = true
        o.HealthBg.Transparency = 0.4
        o.HealthBg.Visible = false

        o.HealthFill = Drawing.new("Square")
        o.HealthFill.Thickness = 1
        o.HealthFill.Color = Config.HealthHighColor
        o.HealthFill.Filled = true
        o.HealthFill.Transparency = 1
        o.HealthFill.Visible = false

        o.HealthOutline = Drawing.new("Square")
        o.HealthOutline.Thickness = 1
        o.HealthOutline.Color = Color3.fromRGB(0, 0, 0)
        o.HealthOutline.Filled = false
        o.HealthOutline.Transparency = 1
        o.HealthOutline.Visible = false

        o.Tracer = Drawing.new("Line")
        o.Tracer.Thickness = 1.5
        o.Tracer.Color = Config.TracerColor
        o.Tracer.Transparency = 1
        o.Tracer.Visible = false

        o.Arrow = Drawing.new("Triangle")
        o.Arrow.Thickness = 1
        o.Arrow.Color = Config.TrackerColor
        o.Arrow.Filled = true
        o.Arrow.Transparency = 1
        o.Arrow.Visible = false

        o.ArrowDist = Drawing.new("Text")
        o.ArrowDist.Size = 11
        o.ArrowDist.Color = Config.TrackerColor
        o.ArrowDist.Center = true
        o.ArrowDist.Outline = true
        o.ArrowDist.OutlineColor = Color3.fromRGB(0, 0, 0)
        o.ArrowDist.Font = 2
        o.ArrowDist.Transparency = 1
        o.ArrowDist.Visible = false

        return o
    end)

    if ok and obj then
        espObjects[targetPlayer] = obj
    else
        -- Fallback: Drawing API gagal, pakai Highlight + BillboardGui
        HAS_DRAWING = false
        warn("[ESP] Drawing API error, switching to Highlight fallback")
    end
end

-- ============================================
-- HIGHLIGHT/BILLBOARD FALLBACK ESP
-- ============================================
local function createHighlightESP(targetPlayer)
    if espHighlights[targetPlayer] then return end

    local data = {}
    data.Connections = {}
    espHighlights[targetPlayer] = data

    local function setup(char)
        -- Hapus yang lama
        pcall(function()
            if data.Highlight then data.Highlight:Destroy() end
            if data.Billboard then data.Billboard:Destroy() end
        end)

        if not char then return end
        local head = char:WaitForChild("Head", 3)
        local humanoid = char:FindFirstChildOfClass("Humanoid")
        if not head or not humanoid then return end

        -- Highlight (glow sekeliling karakter)
        local hl = Instance.new("Highlight")
        hl.Name = "ESP_HL"
        hl.Adornee = char
        hl.FillColor = Config.BoxColor
        hl.FillTransparency = 0.7
        hl.OutlineColor = Config.BoxColor
        hl.OutlineTransparency = 0.1
        hl.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
        hl.Enabled = Config.ESPEnabled
        hl.Parent = char
        data.Highlight = hl

        -- BillboardGui (nama + distance + health)
        local bb = Instance.new("BillboardGui")
        bb.Name = "ESP_BB"
        bb.Adornee = head
        bb.Size = UDim2.new(0, 200, 0, 60)
        bb.StudsOffset = Vector3.new(0, 3, 0)
        bb.AlwaysOnTop = true
        bb.LightInfluence = 0
        bb.MaxDistance = Config.MaxDistance
        bb.Enabled = Config.ESPEnabled
        bb.Parent = char
        data.Billboard = bb

        -- Name label
        local nameLabel = Instance.new("TextLabel")
        nameLabel.Size = UDim2.new(1, 0, 0, 20)
        nameLabel.Position = UDim2.new(0, 0, 0, 0)
        nameLabel.BackgroundTransparency = 1
        nameLabel.Text = targetPlayer.DisplayName
        nameLabel.TextColor3 = Config.NameColor
        nameLabel.TextSize = 14
        nameLabel.Font = Enum.Font.GothamBold
        nameLabel.TextStrokeTransparency = 0.3
        nameLabel.TextStrokeColor3 = Color3.fromRGB(0, 0, 0)
        nameLabel.Parent = bb
        data.NameLabel = nameLabel

        -- Distance label
        local distLabel = Instance.new("TextLabel")
        distLabel.Size = UDim2.new(1, 0, 0, 16)
        distLabel.Position = UDim2.new(0, 0, 0, 20)
        distLabel.BackgroundTransparency = 1
        distLabel.Text = "[? studs]"
        distLabel.TextColor3 = C.textDim
        distLabel.TextSize = 12
        distLabel.Font = Enum.Font.GothamMedium
        distLabel.TextStrokeTransparency = 0.3
        distLabel.TextStrokeColor3 = Color3.fromRGB(0, 0, 0)
        distLabel.Parent = bb
        data.DistLabel = distLabel

        -- Health bar background
        local hpBg = Instance.new("Frame")
        hpBg.Size = UDim2.new(0.6, 0, 0, 5)
        hpBg.Position = UDim2.new(0.2, 0, 0, 38)
        hpBg.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
        hpBg.BackgroundTransparency = 0.4
        hpBg.BorderSizePixel = 0
        hpBg.Parent = bb
        local hpBgCorner = Instance.new("UICorner")
        hpBgCorner.CornerRadius = UDim.new(0, 3)
        hpBgCorner.Parent = hpBg

        local hpFill = Instance.new("Frame")
        hpFill.Size = UDim2.new(1, 0, 1, 0)
        hpFill.BackgroundColor3 = Config.HealthHighColor
        hpFill.BorderSizePixel = 0
        hpFill.Parent = hpBg
        local hpFillCorner = Instance.new("UICorner")
        hpFillCorner.CornerRadius = UDim.new(0, 3)
        hpFillCorner.Parent = hpFill
        data.HpFill = hpFill
        data.HpBg = hpBg
    end

    -- Setup current character
    local char = targetPlayer.Character
    if char then
        setup(char)
    end

    -- Setup on respawn
    local conn = targetPlayer.CharacterAdded:Connect(function(newChar)
        task.wait(0.5)
        setup(newChar)
    end)
    table.insert(data.Connections, conn)
end

local function removeHighlightESP(targetPlayer)
    local data = espHighlights[targetPlayer]
    if not data then return end
    pcall(function()
        if data.Highlight then data.Highlight:Destroy() end
        if data.Billboard then data.Billboard:Destroy() end
        for _, conn in pairs(data.Connections or {}) do
            pcall(function() conn:Disconnect() end)
        end
    end)
    espHighlights[targetPlayer] = nil
end

-- ============================================
-- UNIFIED CREATE/REMOVE
-- ============================================
local function createESPForPlayer(targetPlayer)
    if HAS_DRAWING then
        createDrawingESP(targetPlayer)
        -- Jika Drawing gagal (flag berubah), coba fallback
        if not HAS_DRAWING then
            createHighlightESP(targetPlayer)
        end
    else
        createHighlightESP(targetPlayer)
    end
end

local function removeESPForPlayer(targetPlayer)
    local obj = espObjects[targetPlayer]
    if obj then
        for _, drawing in pairs(obj) do
            pcall(function() drawing:Remove() end)
        end
        espObjects[targetPlayer] = nil
    end
    removeHighlightESP(targetPlayer)
end

local function clearAllESP()
    for plr, _ in pairs(espObjects) do
        removeESPForPlayer(plr)
    end
    for plr, _ in pairs(espHighlights) do
        removeHighlightESP(plr)
    end
end

-- ============================================
-- HEALTH COLOR
-- ============================================
local function getHealthColor(healthPercent)
    if healthPercent > 0.6 then
        return Config.HealthHighColor
    elseif healthPercent > 0.3 then
        return Config.HealthMidColor
    else
        return Config.HealthLowColor
    end
end

-- ============================================
-- DRAWING ESP UPDATE (jika Drawing API tersedia)
-- ============================================
local function updateDrawingESP()
    local myChar = player.Character
    local myRoot = myChar and myChar:FindFirstChild("HumanoidRootPart")

    for _, targetPlayer in ipairs(Players:GetPlayers()) do
        if targetPlayer ~= player then
            -- Create jika belum ada
            if not espObjects[targetPlayer] then
                createDrawingESP(targetPlayer)
            end

            local obj = espObjects[targetPlayer]
            if obj then
                local targetChar = targetPlayer.Character
                local targetRoot = targetChar and targetChar:FindFirstChild("HumanoidRootPart")
                local targetHumanoid = targetChar and targetChar:FindFirstChildOfClass("Humanoid")
                local targetHead = targetChar and targetChar:FindFirstChild("Head")

                -- Kondisi hide
                local shouldHide = false

                if not Config.ESPEnabled then
                    shouldHide = true
                elseif not targetChar or not targetRoot or not targetHumanoid or not targetHead then
                    shouldHide = true
                elseif targetHumanoid.Health <= 0 then
                    shouldHide = true
                elseif not myRoot then
                    shouldHide = true
                end

                -- Team check
                if not shouldHide and Config.TeamCheck then
                    if targetPlayer.Team and player.Team and targetPlayer.Team == player.Team then
                        shouldHide = true
                    end
                end

                -- Distance check
                local distance = 0
                if not shouldHide and myRoot and targetRoot then
                    distance = math.floor((myRoot.Position - targetRoot.Position).Magnitude)
                    if distance > Config.MaxDistance then
                        shouldHide = true
                    end
                end

                if shouldHide then
                    -- Hide semua
                    for _, drawing in pairs(obj) do
                        pcall(function() drawing.Visible = false end)
                    end
                else
                    -- Hitung posisi layar
                    local rootPos, rootOnScreen = camera:WorldToViewportPoint(targetRoot.Position)
                    local headPos = camera:WorldToViewportPoint(targetHead.Position + Vector3.new(0, 0.5, 0))
                    local legPos = camera:WorldToViewportPoint(targetRoot.Position - Vector3.new(0, 3, 0))

                    if rootOnScreen and rootPos.Z > 0 then
                        local boxHeight = math.abs(headPos.Y - legPos.Y)
                        local boxWidth = boxHeight * 0.55
                        local boxX = rootPos.X - boxWidth / 2
                        local boxY = headPos.Y

                        -- Box
                        if Config.ShowBoxes then
                            obj.Box.Size = Vector2.new(boxWidth, boxHeight)
                            obj.Box.Position = Vector2.new(boxX, boxY)
                            obj.Box.Color = Config.BoxColor
                            obj.Box.Visible = true

                            obj.BoxFill.Size = Vector2.new(boxWidth, boxHeight)
                            obj.BoxFill.Position = Vector2.new(boxX, boxY)
                            obj.BoxFill.Color = Config.BoxColor
                            obj.BoxFill.Visible = true
                        else
                            obj.Box.Visible = false
                            obj.BoxFill.Visible = false
                        end

                        -- Name
                        if Config.ShowNames then
                            obj.Name.Text = targetPlayer.DisplayName
                            obj.Name.Position = Vector2.new(rootPos.X, boxY - 18)
                            obj.Name.Color = Config.NameColor
                            obj.Name.Visible = true
                        else
                            obj.Name.Visible = false
                        end

                        -- Distance
                        if Config.ShowDistance then
                            obj.Distance.Text = "[" .. tostring(distance) .. " studs]"
                            obj.Distance.Position = Vector2.new(rootPos.X, boxY + boxHeight + 2)
                            obj.Distance.Visible = true
                        else
                            obj.Distance.Visible = false
                        end

                        -- Health Bar
                        if Config.ShowHealth then
                            local healthPercent = math.clamp(targetHumanoid.Health / targetHumanoid.MaxHealth, 0, 1)
                            local barWidth = 3
                            local barX = boxX - barWidth - 3
                            local barHeight = boxHeight
                            local fillHeight = barHeight * healthPercent

                            obj.HealthBg.Size = Vector2.new(barWidth, barHeight)
                            obj.HealthBg.Position = Vector2.new(barX, boxY)
                            obj.HealthBg.Visible = true

                            obj.HealthFill.Size = Vector2.new(barWidth, fillHeight)
                            obj.HealthFill.Position = Vector2.new(barX, boxY + barHeight - fillHeight)
                            obj.HealthFill.Color = getHealthColor(healthPercent)
                            obj.HealthFill.Visible = true

                            obj.HealthOutline.Size = Vector2.new(barWidth, barHeight)
                            obj.HealthOutline.Position = Vector2.new(barX, boxY)
                            obj.HealthOutline.Visible = true
                        else
                            obj.HealthBg.Visible = false
                            obj.HealthFill.Visible = false
                            obj.HealthOutline.Visible = false
                        end

                        -- Tracer
                        if Config.ShowTracers then
                            local viewportSize = camera.ViewportSize
                            obj.Tracer.From = Vector2.new(viewportSize.X / 2, viewportSize.Y)
                            obj.Tracer.To = Vector2.new(rootPos.X, rootPos.Y)
                            obj.Tracer.Color = Config.TracerColor
                            obj.Tracer.Visible = true
                        else
                            obj.Tracer.Visible = false
                        end

                        -- Hide tracker arrow (on screen)
                        obj.Arrow.Visible = false
                        obj.ArrowDist.Visible = false

                    else
                        -- Off-screen: hide ESP
                        obj.Box.Visible = false
                        obj.BoxFill.Visible = false
                        obj.Name.Visible = false
                        obj.Distance.Visible = false
                        obj.HealthBg.Visible = false
                        obj.HealthFill.Visible = false
                        obj.HealthOutline.Visible = false
                        obj.Tracer.Visible = false

                        -- Show tracker arrow
                        if Config.TrackerEnabled then
                            local viewportSize = camera.ViewportSize
                            local centerX = viewportSize.X / 2
                            local centerY = viewportSize.Y / 2

                            local screenDir = Vector2.new(rootPos.X - centerX, rootPos.Y - centerY)
                            if rootPos.Z < 0 then
                                screenDir = -screenDir
                            end

                            local angle = math.atan2(screenDir.Y, screenDir.X)
                            local arrowRadius = math.min(centerX, centerY) - 40

                            local arrowX = centerX + math.cos(angle) * arrowRadius
                            local arrowY = centerY + math.sin(angle) * arrowRadius

                            local arrowSize = 12
                            local perpAngle = angle + math.pi / 2
                            local tipX = arrowX + math.cos(angle) * arrowSize
                            local tipY = arrowY + math.sin(angle) * arrowSize
                            local baseLeftX = arrowX + math.cos(perpAngle) * (arrowSize * 0.5)
                            local baseLeftY = arrowY + math.sin(perpAngle) * (arrowSize * 0.5)
                            local baseRightX = arrowX - math.cos(perpAngle) * (arrowSize * 0.5)
                            local baseRightY = arrowY - math.sin(perpAngle) * (arrowSize * 0.5)

                            obj.Arrow.PointA = Vector2.new(tipX, tipY)
                            obj.Arrow.PointB = Vector2.new(baseLeftX, baseLeftY)
                            obj.Arrow.PointC = Vector2.new(baseRightX, baseRightY)
                            obj.Arrow.Color = Config.TrackerColor
                            obj.Arrow.Visible = true

                            obj.ArrowDist.Text = targetPlayer.DisplayName .. " [" .. tostring(distance) .. "]"
                            obj.ArrowDist.Position = Vector2.new(arrowX, arrowY - 18)
                            obj.ArrowDist.Color = Config.TrackerColor
                            obj.ArrowDist.Visible = true
                        else
                            obj.Arrow.Visible = false
                            obj.ArrowDist.Visible = false
                        end
                    end
                end
            end -- if obj
        end -- if not self
    end -- for players
end

-- ============================================
-- HIGHLIGHT FALLBACK UPDATE
-- ============================================
local function updateHighlightESP()
    local myChar = player.Character
    local myRoot = myChar and myChar:FindFirstChild("HumanoidRootPart")

    for targetPlayer, data in pairs(espHighlights) do
        if targetPlayer ~= player then
            local targetChar = targetPlayer.Character
            local targetRoot = targetChar and targetChar:FindFirstChild("HumanoidRootPart")
            local targetHumanoid = targetChar and targetChar:FindFirstChildOfClass("Humanoid")

            local shouldShow = Config.ESPEnabled
            local dist = 0

            if not targetChar or not targetRoot or not targetHumanoid then
                shouldShow = false
            end

            if shouldShow and targetHumanoid and targetHumanoid.Health <= 0 then
                shouldShow = false
            end

            if shouldShow and Config.TeamCheck then
                if targetPlayer.Team and player.Team and targetPlayer.Team == player.Team then
                    shouldShow = false
                end
            end

            if shouldShow and myRoot and targetRoot then
                dist = math.floor((myRoot.Position - targetRoot.Position).Magnitude)
                if dist > Config.MaxDistance then
                    shouldShow = false
                end
            end

            -- Update Highlight
            if data.Highlight then
                data.Highlight.Enabled = shouldShow
                if shouldShow then
                    data.Highlight.FillColor = Config.BoxColor
                    data.Highlight.OutlineColor = Config.BoxColor
                end
            end

            -- Update Billboard
            if data.Billboard then
                data.Billboard.Enabled = shouldShow
                if shouldShow then
                    data.Billboard.MaxDistance = Config.MaxDistance
                end
            end

            -- Update labels
            if shouldShow then
                if data.NameLabel then
                    data.NameLabel.Visible = Config.ShowNames
                    data.NameLabel.Text = targetPlayer.DisplayName
                end
                if data.DistLabel then
                    data.DistLabel.Visible = Config.ShowDistance
                    data.DistLabel.Text = "[" .. tostring(dist) .. " studs]"
                end
                if data.HpFill and targetHumanoid then
                    local hp = math.clamp(targetHumanoid.Health / targetHumanoid.MaxHealth, 0, 1)
                    data.HpFill.Size = UDim2.new(hp, 0, 1, 0)
                    data.HpFill.BackgroundColor3 = getHealthColor(hp)
                    data.HpFill.Visible = Config.ShowHealth
                end
                if data.HpBg then
                    data.HpBg.Visible = Config.ShowHealth
                end
            end
        end
    end
end

-- ============================================
-- MAIN UPDATE DISPATCHER
-- ============================================
local function updateESP()
    pcall(function()
        camera = workspace.CurrentCamera
    end)

    if HAS_DRAWING then
        updateDrawingESP()
    else
        updateHighlightESP()
    end
end

-- ============================================
-- ENEMY (NPC/MOB) ESP — Pakai Highlight+Billboard
-- ============================================
local function isNPC(model)
    -- Cek apakah model adalah NPC (punya Humanoid tapi bukan player)
    if not model:IsA("Model") then return false end
    local hum = model:FindFirstChildOfClass("Humanoid")
    if not hum then return false end
    if hum.Health <= 0 then return false end
    -- Pastikan bukan karakter player
    for _, plr in ipairs(Players:GetPlayers()) do
        if plr.Character == model then return false end
    end
    return true
end

local function createEnemyESP(model)
    if enemyESPData[model] then return end
    local head = model:FindFirstChild("Head")
    local hum = model:FindFirstChildOfClass("Humanoid")
    if not head or not hum then return end

    local data = {}

    -- Highlight
    local hl = Instance.new("Highlight")
    hl.Adornee = model
    hl.FillColor = Config.EnemyColor
    hl.FillTransparency = 0.65
    hl.OutlineColor = Config.EnemyColor
    hl.OutlineTransparency = 0
    hl.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
    hl.Enabled = true
    hl.Parent = model
    data.Highlight = hl

    -- Billboard
    local bb = Instance.new("BillboardGui")
    bb.Adornee = head
    bb.Size = UDim2.new(0, 200, 0, 50)
    bb.StudsOffset = Vector3.new(0, 2.5, 0)
    bb.AlwaysOnTop = true
    bb.MaxDistance = Config.MaxDistance
    bb.Parent = model
    data.Billboard = bb

    local nameL = Instance.new("TextLabel")
    nameL.Size = UDim2.new(1, 0, 0, 18)
    nameL.BackgroundTransparency = 1
    nameL.Text = model.Name
    nameL.TextColor3 = Config.EnemyColor
    nameL.TextSize = 13
    nameL.Font = Enum.Font.GothamBold
    nameL.TextStrokeTransparency = 0.2
    nameL.TextStrokeColor3 = Color3.fromRGB(0, 0, 0)
    nameL.Parent = bb
    data.NameLabel = nameL

    local distL = Instance.new("TextLabel")
    distL.Size = UDim2.new(1, 0, 0, 14)
    distL.Position = UDim2.new(0, 0, 0, 18)
    distL.BackgroundTransparency = 1
    distL.Text = "[? studs]"
    distL.TextColor3 = C.textDim
    distL.TextSize = 11
    distL.Font = Enum.Font.GothamMedium
    distL.TextStrokeTransparency = 0.3
    distL.TextStrokeColor3 = Color3.fromRGB(0, 0, 0)
    distL.Parent = bb
    data.DistLabel = distL

    -- Health bar
    local hpBg = Instance.new("Frame")
    hpBg.Size = UDim2.new(0.5, 0, 0, 4)
    hpBg.Position = UDim2.new(0.25, 0, 0, 34)
    hpBg.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
    hpBg.BackgroundTransparency = 0.4
    hpBg.BorderSizePixel = 0
    hpBg.Parent = bb
    corner(hpBg, 2)
    data.HpBg = hpBg

    local hpFill = Instance.new("Frame")
    hpFill.Size = UDim2.new(1, 0, 1, 0)
    hpFill.BackgroundColor3 = Config.HealthHighColor
    hpFill.BorderSizePixel = 0
    hpFill.Parent = hpBg
    corner(hpFill, 2)
    data.HpFill = hpFill

    -- Auto-remove saat destroyed
    data.DestroyConn = model.AncestryChanged:Connect(function()
        if not model.Parent then
            pcall(function() hl:Destroy() end)
            pcall(function() bb:Destroy() end)
            pcall(function() data.DestroyConn:Disconnect() end)
            enemyESPData[model] = nil
        end
    end)

    enemyESPData[model] = data
end

local function removeEnemyESP(model)
    local data = enemyESPData[model]
    if not data then return end
    pcall(function() if data.Highlight then data.Highlight:Destroy() end end)
    pcall(function() if data.Billboard then data.Billboard:Destroy() end end)
    pcall(function() if data.DestroyConn then data.DestroyConn:Disconnect() end end)
    enemyESPData[model] = nil
end

local function scanAndUpdateEnemyESP()
    if not Config.EnemyESPEnabled then
        for model, _ in pairs(enemyESPData) do
            removeEnemyESP(model)
        end
        return
    end

    local myChar = player.Character
    local myRoot = myChar and myChar:FindFirstChild("HumanoidRootPart")

    -- Scan workspace untuk NPC baru
    for _, obj in ipairs(workspace:GetDescendants()) do
        if obj:IsA("Humanoid") and obj.Health > 0 then
            local model = obj.Parent
            if model and model:IsA("Model") and isNPC(model) then
                if not enemyESPData[model] then
                    createEnemyESP(model)
                end
            end
        end
    end

    -- Update existing
    for model, data in pairs(enemyESPData) do
        local hum = model:FindFirstChildOfClass("Humanoid")
        local root = model:FindFirstChild("HumanoidRootPart") or model:FindFirstChild("Torso") or model:FindFirstChild("Head")

        local shouldShow = Config.EnemyESPEnabled and hum and hum.Health > 0 and root ~= nil

        if shouldShow and myRoot and root then
            local dist = math.floor((myRoot.Position - root.Position).Magnitude)
            if dist > Config.MaxDistance then shouldShow = false end
            if data.DistLabel then data.DistLabel.Text = "[" .. dist .. " studs]" end
        end

        if not shouldShow then
            if hum and hum.Health <= 0 then
                removeEnemyESP(model)
            else
                if data.Highlight then data.Highlight.Enabled = false end
                if data.Billboard then data.Billboard.Enabled = false end
            end
        else
            if data.Highlight then
                data.Highlight.Enabled = true
                data.Highlight.FillColor = Config.EnemyColor
                data.Highlight.OutlineColor = Config.EnemyColor
            end
            if data.Billboard then data.Billboard.Enabled = true end
            if data.HpFill and hum then
                local hp = math.clamp(hum.Health / hum.MaxHealth, 0, 1)
                data.HpFill.Size = UDim2.new(hp, 0, 1, 0)
                data.HpFill.BackgroundColor3 = getHealthColor(hp)
            end
        end
    end
end

-- ============================================
-- AIMBOT SYSTEM
-- ============================================
local function setupFOVCircle()
    if not HAS_DRAWING then return end
    if fovCircle then pcall(function() fovCircle:Remove() end) end
    fovCircle = Drawing.new("Circle")
    fovCircle.Radius = Config.AimbotFOV
    fovCircle.Color = C.red
    fovCircle.Thickness = 1.5
    fovCircle.Filled = false
    fovCircle.Transparency = 0.6
    fovCircle.Visible = false
    fovCircle.NumSides = 60
end

local function getAimbotTargets()
    local targets = {}
    local myChar = player.Character
    local myRoot = myChar and myChar:FindFirstChild("HumanoidRootPart")
    if not myRoot then return targets end

    -- Player targets
    if Config.AimbotTargetPlr then
        for _, plr in ipairs(Players:GetPlayers()) do
            if plr ~= player then
                local ch = plr.Character
                if ch then
                    local hum = ch:FindFirstChildOfClass("Humanoid")
                    local part = ch:FindFirstChild(Config.AimbotTarget) or ch:FindFirstChild("Head")
                    if hum and hum.Health > 0 and part then
                        local dist = (myRoot.Position - part.Position).Magnitude
                        if dist <= Config.MaxDistance then
                            -- Team check
                            local skip = false
                            if Config.TeamCheck and plr.Team and player.Team and plr.Team == player.Team then
                                skip = true
                            end
                            if not skip then
                                table.insert(targets, {Part = part, Dist = dist, Name = plr.DisplayName})
                            end
                        end
                    end
                end
            end
        end
    end

    -- NPC targets
    if Config.AimbotTargetNPC then
        for model, data in pairs(enemyESPData) do
            if model and model.Parent then
                local hum = model:FindFirstChildOfClass("Humanoid")
                local part = model:FindFirstChild(Config.AimbotTarget) or model:FindFirstChild("Head")
                if hum and hum.Health > 0 and part then
                    local dist = (myRoot.Position - part.Position).Magnitude
                    if dist <= Config.MaxDistance then
                        table.insert(targets, {Part = part, Dist = dist, Name = model.Name})
                    end
                end
            end
        end
    end

    return targets
end

local function updateAimbot()
    if not Config.AimbotEnabled then
        if fovCircle then fovCircle.Visible = false end
        aimbotCurrentTarget = nil
        return
    end

    local viewportSize = camera.ViewportSize
    local centerScreen = Vector2.new(viewportSize.X / 2, viewportSize.Y / 2)

    -- Update FOV circle position
    if fovCircle then
        fovCircle.Position = centerScreen
        fovCircle.Radius = Config.AimbotFOV
        fovCircle.Visible = aimbotHolding
    end

    if not aimbotHolding then
        aimbotCurrentTarget = nil
        return
    end

    -- Cari target terdekat ke crosshair
    local targets = getAimbotTargets()
    local bestTarget = nil
    local bestScreenDist = Config.AimbotFOV

    for _, tgt in ipairs(targets) do
        local screenPos, onScreen = camera:WorldToViewportPoint(tgt.Part.Position)
        if onScreen and screenPos.Z > 0 then
            local screenDist = (Vector2.new(screenPos.X, screenPos.Y) - centerScreen).Magnitude
            if screenDist < bestScreenDist then
                bestScreenDist = screenDist
                bestTarget = tgt
            end
        end
    end

    aimbotCurrentTarget = bestTarget

    -- Aim ke target
    if bestTarget and bestTarget.Part and bestTarget.Part.Parent then
        local targetPos = bestTarget.Part.Position
        local camPos = camera.CFrame.Position
        local direction = (targetPos - camPos).Unit
        local targetCF = CFrame.lookAt(camPos, camPos + direction)
        -- Smooth lerp
        local alpha = math.clamp(1 / Config.AimbotSmoothing, 0.05, 1)
        camera.CFrame = camera.CFrame:Lerp(targetCF, alpha)
    end
end

-- ============================================
-- GUI BUILDER
-- ============================================
local function buildGUI()
    -- Cleanup lama
    pcall(function()
        local old = CoreGui:FindFirstChild("ESPTrackerGUI")
        if old then old:Destroy() end
    end)
    pcall(function()
        local old = player.PlayerGui:FindFirstChild("ESPTrackerGUI")
        if old then old:Destroy() end
    end)

    local guiParent = getGuiParent()

    local sg = Instance.new("ScreenGui")
    sg.Name = "ESPTrackerGUI"
    sg.ResetOnSpawn = false
    sg.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
    sg.DisplayOrder = 998
    sg.IgnoreGuiInset = false
    sg.Parent = guiParent
    refs.ScreenGui = sg

    -- Main Frame
    local main = Instance.new("Frame")
    main.Name = "Main"
    main.Size = UDim2.new(0, 260, 0, 480)
    main.Position = UDim2.new(1, -280, 0.5, -240)
    main.BackgroundColor3 = C.bg
    main.BackgroundTransparency = 0.02
    main.BorderSizePixel = 0
    main.Active = true
    main.Draggable = true
    main.ClipsDescendants = true
    main.Parent = sg
    corner(main, 14)
    stroke(main, C.cyan, 2, 0.25)
    refs.Main = main

    -- Glow bar
    local glow = Instance.new("Frame")
    glow.Size = UDim2.new(1, 0, 0, 3)
    glow.BorderSizePixel = 0
    glow.Parent = main
    corner(glow, 14)
    local gg = Instance.new("UIGradient")
    gg.Color = ColorSequence.new{
        ColorSequenceKeypoint.new(0, C.cyan),
        ColorSequenceKeypoint.new(0.5, C.accent),
        ColorSequenceKeypoint.new(1, C.cyan),
    }
    gg.Parent = glow

    -- Header
    local header = Instance.new("Frame")
    header.Size = UDim2.new(1, 0, 0, 52)
    header.Position = UDim2.new(0, 0, 0, 3)
    header.BackgroundTransparency = 1
    header.Parent = main

    local logo = Instance.new("TextLabel")
    logo.Size = UDim2.new(1, -50, 0, 22)
    logo.Position = UDim2.new(0, 14, 0, 8)
    logo.BackgroundTransparency = 1
    logo.Text = "ESP + TRACKER"
    logo.TextColor3 = C.white
    logo.TextSize = 16
    logo.Font = Enum.Font.GothamBlack
    logo.TextXAlignment = Enum.TextXAlignment.Left
    logo.Parent = header

    local versionLbl = Instance.new("TextLabel")
    versionLbl.Size = UDim2.new(1, -14, 0, 14)
    versionLbl.Position = UDim2.new(0, 14, 0, 30)
    versionLbl.BackgroundTransparency = 1
    versionLbl.Text = "v1.1 • Blox-Scripts" .. (HAS_DRAWING and " [Drawing]" or " [Highlight]")
    versionLbl.TextColor3 = C.textDim
    versionLbl.TextSize = 10
    versionLbl.Font = Enum.Font.Gotham
    versionLbl.TextXAlignment = Enum.TextXAlignment.Left
    versionLbl.Parent = header

    -- Status indicator (live dot)
    local statusDot = Instance.new("Frame")
    statusDot.Size = UDim2.new(0, 8, 0, 8)
    statusDot.Position = UDim2.new(1, -48, 0, 14)
    statusDot.BackgroundColor3 = C.green
    statusDot.BorderSizePixel = 0
    statusDot.Parent = header
    corner(statusDot, 4)
    refs.StatusDot = statusDot

    -- Pulse animation on status dot
    spawn(function()
        while refs.StatusDot and refs.StatusDot.Parent do
            local t1 = tween(refs.StatusDot, {BackgroundTransparency = 0.6}, 0.8)
            t1:Play()
            t1.Completed:Wait()
            local t2 = tween(refs.StatusDot, {BackgroundTransparency = 0}, 0.8)
            t2:Play()
            t2.Completed:Wait()
        end
    end)

    -- Minimize button
    local minimizeBtn = Instance.new("TextButton")
    minimizeBtn.Size = UDim2.new(0, 28, 0, 28)
    minimizeBtn.Position = UDim2.new(1, -42, 0, 10)
    minimizeBtn.BackgroundColor3 = C.bgInput
    minimizeBtn.BorderSizePixel = 0
    minimizeBtn.Text = "—"
    minimizeBtn.TextColor3 = C.textDim
    minimizeBtn.TextSize = 14
    minimizeBtn.Font = Enum.Font.GothamBold
    minimizeBtn.Parent = header
    corner(minimizeBtn, 6)

    minimizeBtn.MouseEnter:Connect(function() tween(minimizeBtn, {BackgroundColor3 = C.orange, TextColor3 = C.white}, 0.15):Play() end)
    minimizeBtn.MouseLeave:Connect(function() tween(minimizeBtn, {BackgroundColor3 = C.bgInput, TextColor3 = C.textDim}, 0.15):Play() end)
    minimizeBtn.MouseButton1Click:Connect(function()
        guiVisible = false
        tween(main, {Position = UDim2.new(1.1, 0, 0.5, -240)}, 0.4, Enum.EasingStyle.Back, Enum.EasingDirection.In):Play()
    end)

    -- Separator
    local sep = Instance.new("Frame")
    sep.Size = UDim2.new(1, -20, 0, 1)
    sep.Position = UDim2.new(0, 10, 0, 55)
    sep.BackgroundColor3 = C.border
    sep.BackgroundTransparency = 0.5
    sep.BorderSizePixel = 0
    sep.Parent = main

    -- Scroll Content
    local scrollFrame = Instance.new("ScrollingFrame")
    scrollFrame.Name = "Content"
    scrollFrame.Size = UDim2.new(1, -20, 1, -65)
    scrollFrame.Position = UDim2.new(0, 10, 0, 60)
    scrollFrame.BackgroundTransparency = 1
    scrollFrame.BorderSizePixel = 0
    scrollFrame.ScrollBarThickness = 3
    scrollFrame.ScrollBarImageColor3 = C.cyan
    scrollFrame.AutomaticCanvasSize = Enum.AutomaticSize.Y
    scrollFrame.CanvasSize = UDim2.new(0, 0, 0, 0)
    scrollFrame.Parent = main

    local listLayout = Instance.new("UIListLayout")
    listLayout.Padding = UDim.new(0, 6)
    listLayout.SortOrder = Enum.SortOrder.LayoutOrder
    listLayout.Parent = scrollFrame

    local pad = Instance.new("UIPadding")
    pad.PaddingTop = UDim.new(0, 4)
    pad.PaddingBottom = UDim.new(0, 8)
    pad.Parent = scrollFrame

    -- ═══════════════════════════════════════
    -- TOGGLE BUILDER
    -- ═══════════════════════════════════════
    local function buildToggle(parent, labelText, icon, initialState, order, callback)
        local row = Instance.new("Frame")
        row.Size = UDim2.new(1, 0, 0, 38)
        row.BackgroundColor3 = C.bgCard
        row.BorderSizePixel = 0
        row.LayoutOrder = order
        row.Parent = parent
        corner(row, 8)

        local lbl = Instance.new("TextLabel")
        lbl.Size = UDim2.new(1, -80, 1, 0)
        lbl.Position = UDim2.new(0, 12, 0, 0)
        lbl.BackgroundTransparency = 1
        lbl.Text = icon .. "  " .. labelText
        lbl.TextColor3 = C.text
        lbl.TextSize = 13
        lbl.Font = Enum.Font.GothamMedium
        lbl.TextXAlignment = Enum.TextXAlignment.Left
        lbl.Parent = row

        local toggleBg = Instance.new("Frame")
        toggleBg.Size = UDim2.new(0, 46, 0, 24)
        toggleBg.Position = UDim2.new(1, -58, 0.5, -12)
        toggleBg.BackgroundColor3 = initialState and C.accent or C.bgInput
        toggleBg.BorderSizePixel = 0
        toggleBg.Parent = row
        corner(toggleBg, 12)

        local knob = Instance.new("Frame")
        knob.Size = UDim2.new(0, 20, 0, 20)
        knob.Position = initialState and UDim2.new(1, -22, 0.5, -10) or UDim2.new(0, 2, 0.5, -10)
        knob.BackgroundColor3 = initialState and C.white or C.textDim
        knob.BorderSizePixel = 0
        knob.Parent = toggleBg
        corner(knob, 10)

        local btn = Instance.new("TextButton")
        btn.Size = UDim2.new(1, 0, 1, 0)
        btn.BackgroundTransparency = 1
        btn.Text = ""
        btn.Parent = toggleBg

        local state = initialState

        btn.MouseButton1Click:Connect(function()
            state = not state
            local ti = TweenInfo.new(0.25, Enum.EasingStyle.Quart, Enum.EasingDirection.Out)
            if state then
                TweenService:Create(toggleBg, ti, {BackgroundColor3 = C.accent}):Play()
                TweenService:Create(knob, ti, {Position = UDim2.new(1, -22, 0.5, -10), BackgroundColor3 = C.white}):Play()
            else
                TweenService:Create(toggleBg, ti, {BackgroundColor3 = C.bgInput}):Play()
                TweenService:Create(knob, ti, {Position = UDim2.new(0, 2, 0.5, -10), BackgroundColor3 = C.textDim}):Play()
            end
            if callback then callback(state) end
        end)

        return {
            Row = row, ToggleBg = toggleBg, Knob = knob, Button = btn,
            GetState = function() return state end,
            SetState = function(newState)
                state = newState
                local ti = TweenInfo.new(0.25, Enum.EasingStyle.Quart, Enum.EasingDirection.Out)
                if state then
                    TweenService:Create(toggleBg, ti, {BackgroundColor3 = C.accent}):Play()
                    TweenService:Create(knob, ti, {Position = UDim2.new(1, -22, 0.5, -10), BackgroundColor3 = C.white}):Play()
                else
                    TweenService:Create(toggleBg, ti, {BackgroundColor3 = C.bgInput}):Play()
                    TweenService:Create(knob, ti, {Position = UDim2.new(0, 2, 0.5, -10), BackgroundColor3 = C.textDim}):Play()
                end
                if callback then callback(state) end
            end
        }
    end

    -- Section Header
    local function buildSectionHeader(parent, text, order)
        local hdr = Instance.new("TextLabel")
        hdr.Size = UDim2.new(1, 0, 0, 22)
        hdr.BackgroundTransparency = 1
        hdr.Text = text
        hdr.TextColor3 = C.textDim
        hdr.TextSize = 11
        hdr.Font = Enum.Font.GothamBold
        hdr.TextXAlignment = Enum.TextXAlignment.Left
        hdr.LayoutOrder = order
        hdr.Parent = parent
        return hdr
    end

    -- ── MASTER CONTROLS ─────────────────────
    buildSectionHeader(scrollFrame, "MASTER CONTROLS", 0)

    refs.ESPToggle = buildToggle(scrollFrame, "ESP", "👁", Config.ESPEnabled, 1, function(state)
        Config.ESPEnabled = state
        if not state then
            for _, obj in pairs(espObjects) do
                for _, drawing in pairs(obj) do
                    pcall(function() drawing.Visible = false end)
                end
            end
        end
    end)

    refs.TrackerToggle = buildToggle(scrollFrame, "Tracker Arrows", "🏹", Config.TrackerEnabled, 2, function(state)
        Config.TrackerEnabled = state
    end)

    -- ── ESP COMPONENTS ──────────────────────
    buildSectionHeader(scrollFrame, "ESP COMPONENTS", 10)

    refs.BoxToggle = buildToggle(scrollFrame, "Boxes", "▢", Config.ShowBoxes, 11, function(state)
        Config.ShowBoxes = state
    end)

    refs.NameToggle = buildToggle(scrollFrame, "Names", "📝", Config.ShowNames, 12, function(state)
        Config.ShowNames = state
    end)

    refs.HealthToggle = buildToggle(scrollFrame, "Health Bars", "❤", Config.ShowHealth, 13, function(state)
        Config.ShowHealth = state
    end)

    refs.DistToggle = buildToggle(scrollFrame, "Distance", "📏", Config.ShowDistance, 14, function(state)
        Config.ShowDistance = state
    end)

    refs.TracerToggle = buildToggle(scrollFrame, "Tracers", "📍", Config.ShowTracers, 15, function(state)
        Config.ShowTracers = state
    end)

    -- ── SETTINGS ────────────────────────────
    buildSectionHeader(scrollFrame, "SETTINGS", 20)

    refs.TeamToggle = buildToggle(scrollFrame, "Team Check", "🛡", Config.TeamCheck, 21, function(state)
        Config.TeamCheck = state
    end)

    -- Max Distance Slider
    local distRow = Instance.new("Frame")
    distRow.Size = UDim2.new(1, 0, 0, 56)
    distRow.BackgroundColor3 = C.bgCard
    distRow.BorderSizePixel = 0
    distRow.LayoutOrder = 22
    distRow.Parent = scrollFrame
    corner(distRow, 8)

    local distLabel = Instance.new("TextLabel")
    distLabel.Size = UDim2.new(0.6, 0, 0, 20)
    distLabel.Position = UDim2.new(0, 12, 0, 6)
    distLabel.BackgroundTransparency = 1
    distLabel.Text = "📐  Max Distance"
    distLabel.TextColor3 = C.text
    distLabel.TextSize = 13
    distLabel.Font = Enum.Font.GothamMedium
    distLabel.TextXAlignment = Enum.TextXAlignment.Left
    distLabel.Parent = distRow

    local distValLabel = Instance.new("TextLabel")
    distValLabel.Size = UDim2.new(0.35, 0, 0, 20)
    distValLabel.Position = UDim2.new(0.6, 0, 0, 6)
    distValLabel.BackgroundTransparency = 1
    distValLabel.Text = tostring(Config.MaxDistance) .. " studs"
    distValLabel.TextColor3 = C.cyan
    distValLabel.TextSize = 12
    distValLabel.Font = Enum.Font.GothamBold
    distValLabel.TextXAlignment = Enum.TextXAlignment.Right
    distValLabel.Parent = distRow
    refs.DistValLabel = distValLabel

    local sliderBg = Instance.new("Frame")
    sliderBg.Size = UDim2.new(1, -24, 0, 8)
    sliderBg.Position = UDim2.new(0, 12, 0, 34)
    sliderBg.BackgroundColor3 = C.bgInput
    sliderBg.BorderSizePixel = 0
    sliderBg.Parent = distRow
    corner(sliderBg, 4)

    local sliderFill = Instance.new("Frame")
    sliderFill.Size = UDim2.new(Config.MaxDistance / 5000, 0, 1, 0)
    sliderFill.BackgroundColor3 = C.cyan
    sliderFill.BorderSizePixel = 0
    sliderFill.Parent = sliderBg
    corner(sliderFill, 4)
    refs.DistSliderFill = sliderFill

    local slFillGrad = Instance.new("UIGradient")
    slFillGrad.Color = ColorSequence.new{
        ColorSequenceKeypoint.new(0, C.accent),
        ColorSequenceKeypoint.new(1, C.cyan),
    }
    slFillGrad.Parent = sliderFill

    local sliderKnob = Instance.new("Frame")
    sliderKnob.Size = UDim2.new(0, 14, 0, 14)
    sliderKnob.Position = UDim2.new(Config.MaxDistance / 5000, -7, 0.5, -7)
    sliderKnob.BackgroundColor3 = C.white
    sliderKnob.BorderSizePixel = 0
    sliderKnob.ZIndex = 2
    sliderKnob.Parent = sliderBg
    corner(sliderKnob, 7)
    stroke(sliderKnob, C.cyan, 2, 0)
    refs.DistSliderKnob = sliderKnob

    local sliderHit = Instance.new("TextButton")
    sliderHit.Size = UDim2.new(1, 0, 1, 16)
    sliderHit.Position = UDim2.new(0, 0, 0, -8)
    sliderHit.BackgroundTransparency = 1
    sliderHit.Text = ""
    sliderHit.ZIndex = 3
    sliderHit.Parent = sliderBg

    local dragging = false
    local mouse = player:GetMouse()

    local function updateDistSlider(x)
        local pos  = sliderBg.AbsolutePosition.X
        local size = sliderBg.AbsoluteSize.X
        if size == 0 then return end
        local ratio = math.clamp((x - pos) / size, 0, 1)
        Config.MaxDistance = math.clamp(math.floor(100 + ratio * 4900), 100, 5000)
        refs.DistValLabel.Text = tostring(Config.MaxDistance) .. " studs"
        refs.DistSliderFill.Size = UDim2.new(ratio, 0, 1, 0)
        refs.DistSliderKnob.Position = UDim2.new(ratio, -7, 0.5, -7)
    end

    sliderHit.MouseButton1Down:Connect(function() dragging = true; updateDistSlider(mouse.X) end)
    table.insert(connections, UserInputService.InputChanged:Connect(function(inp)
        if dragging and inp.UserInputType == Enum.UserInputType.MouseMovement then updateDistSlider(inp.Position.X) end
    end))
    table.insert(connections, UserInputService.InputEnded:Connect(function(inp)
        if inp.UserInputType == Enum.UserInputType.MouseButton1 then dragging = false end
    end))

    -- ── ENEMY ESP (NPC/MOB) ─────────────────
    buildSectionHeader(scrollFrame, "ENEMY / NPC ESP", 40)

    refs.EnemyToggle = buildToggle(scrollFrame, "Enemy ESP", "👹", Config.EnemyESPEnabled, 41, function(state)
        Config.EnemyESPEnabled = state
    end)

    -- ── AIMBOT ──────────────────────────────
    buildSectionHeader(scrollFrame, "AIMBOT", 50)

    refs.AimbotToggle = buildToggle(scrollFrame, "Aimbot", "🎯", Config.AimbotEnabled, 51, function(state)
        Config.AimbotEnabled = state
        if not state and fovCircle then fovCircle.Visible = false end
    end)

    refs.AimbotPlrToggle = buildToggle(scrollFrame, "Aim Player", "👤", Config.AimbotTargetPlr, 52, function(state)
        Config.AimbotTargetPlr = state
    end)

    refs.AimbotNPCToggle = buildToggle(scrollFrame, "Aim NPC/Mob", "👹", Config.AimbotTargetNPC, 53, function(state)
        Config.AimbotTargetNPC = state
    end)

    -- Aimbot target label
    local aimTargetLabel = Instance.new("TextLabel")
    aimTargetLabel.Size = UDim2.new(1, 0, 0, 20)
    aimTargetLabel.BackgroundTransparency = 1
    aimTargetLabel.Text = "🎯 Target: —"
    aimTargetLabel.TextColor3 = C.red
    aimTargetLabel.TextSize = 11
    aimTargetLabel.Font = Enum.Font.GothamBold
    aimTargetLabel.TextXAlignment = Enum.TextXAlignment.Left
    aimTargetLabel.LayoutOrder = 54
    aimTargetLabel.Parent = scrollFrame
    refs.AimTargetLabel = aimTargetLabel

    -- ── INFO ────────────────────────────────
    buildSectionHeader(scrollFrame, "INFO", 60)

    local infoCard = Instance.new("Frame")
    infoCard.Size = UDim2.new(1, 0, 0, 50)
    infoCard.BackgroundColor3 = C.bgCard
    infoCard.BorderSizePixel = 0
    infoCard.LayoutOrder = 61
    infoCard.Parent = scrollFrame
    corner(infoCard, 8)
    stroke(infoCard, C.cyan, 1, 0.6)

    local infoIcon = Instance.new("TextLabel")
    infoIcon.Size = UDim2.new(0, 30, 0, 30)
    infoIcon.Position = UDim2.new(0, 10, 0.5, -15)
    infoIcon.BackgroundTransparency = 1
    infoIcon.Text = "👥"
    infoIcon.TextSize = 22
    infoIcon.Parent = infoCard

    local playerCountLabel = Instance.new("TextLabel")
    playerCountLabel.Size = UDim2.new(1, -50, 0, 16)
    playerCountLabel.Position = UDim2.new(0, 44, 0, 6)
    playerCountLabel.BackgroundTransparency = 1
    playerCountLabel.Text = "Players in Server"
    playerCountLabel.TextColor3 = C.textDim
    playerCountLabel.TextSize = 10
    playerCountLabel.Font = Enum.Font.Gotham
    playerCountLabel.TextXAlignment = Enum.TextXAlignment.Left
    playerCountLabel.Parent = infoCard

    local playerCountVal = Instance.new("TextLabel")
    playerCountVal.Size = UDim2.new(1, -50, 0, 20)
    playerCountVal.Position = UDim2.new(0, 44, 0, 22)
    playerCountVal.BackgroundTransparency = 1
    playerCountVal.Text = tostring(#Players:GetPlayers()) .. " / " .. tostring(Players.MaxPlayers)
    playerCountVal.TextColor3 = C.cyan
    playerCountVal.TextSize = 15
    playerCountVal.Font = Enum.Font.GothamBold
    playerCountVal.TextXAlignment = Enum.TextXAlignment.Left
    playerCountVal.Parent = infoCard
    refs.PlayerCountVal = playerCountVal

    -- Keybinds
    local keybindInfo = Instance.new("TextLabel")
    keybindInfo.Size = UDim2.new(1, 0, 0, 75)
    keybindInfo.BackgroundTransparency = 1
    keybindInfo.Text = "⌨ Keybinds:\n  RightCtrl = Toggle ESP\n  B = Toggle Tracker\n  E = Toggle Enemy ESP\n  Q (Hold) = Aimbot Aim\n  T = Toggle Aimbot On/Off\n  M = Show/Hide Panel"
    keybindInfo.TextColor3 = C.textMuted
    keybindInfo.TextSize = 10
    keybindInfo.Font = Enum.Font.Code
    keybindInfo.TextXAlignment = Enum.TextXAlignment.Left
    keybindInfo.TextYAlignment = Enum.TextYAlignment.Top
    keybindInfo.LayoutOrder = 62
    keybindInfo.Parent = scrollFrame

    return sg
end

-- ============================================
-- PLAYER JOIN/LEAVE
-- ============================================
local function onPlayerAdded(targetPlayer)
    if targetPlayer == player then return end
    createESPForPlayer(targetPlayer)
    if refs.PlayerCountVal then
        pcall(function()
            refs.PlayerCountVal.Text = tostring(#Players:GetPlayers()) .. " / " .. tostring(Players.MaxPlayers)
        end)
    end
end

local function onPlayerRemoving(targetPlayer)
    removeESPForPlayer(targetPlayer)
    task.defer(function()
        if refs.PlayerCountVal then
            pcall(function()
                refs.PlayerCountVal.Text = tostring(#Players:GetPlayers()) .. " / " .. tostring(Players.MaxPlayers)
            end)
        end
    end)
end

-- ============================================
-- KEYBIND HANDLER
-- ============================================
local function onInputBegan(input, gameProcessed)
    if gameProcessed then return end

    -- RightControl → Toggle ESP
    if input.KeyCode == Enum.KeyCode.RightControl then
        Config.ESPEnabled = not Config.ESPEnabled
        if refs.ESPToggle then refs.ESPToggle.SetState(Config.ESPEnabled) end
    end

    -- B → Toggle Tracker
    if input.KeyCode == Enum.KeyCode.B then
        Config.TrackerEnabled = not Config.TrackerEnabled
        if refs.TrackerToggle then refs.TrackerToggle.SetState(Config.TrackerEnabled) end
    end

    -- E → Toggle Enemy ESP
    if input.KeyCode == Enum.KeyCode.E then
        Config.EnemyESPEnabled = not Config.EnemyESPEnabled
        if refs.EnemyToggle then refs.EnemyToggle.SetState(Config.EnemyESPEnabled) end
    end

    -- T → Toggle Aimbot On/Off
    if input.KeyCode == Enum.KeyCode.T then
        Config.AimbotEnabled = not Config.AimbotEnabled
        if refs.AimbotToggle then refs.AimbotToggle.SetState(Config.AimbotEnabled) end
        if not Config.AimbotEnabled and fovCircle then fovCircle.Visible = false end
    end

    -- Q (Hold) → Aimbot Aim
    if input.KeyCode == Enum.KeyCode.Q then
        aimbotHolding = true
    end

    -- M → Show/Hide Panel
    if input.KeyCode == Enum.KeyCode.M then
        guiVisible = not guiVisible
        if refs.Main then
            if guiVisible then
                tween(refs.Main, {Position = UDim2.new(1, -280, 0.5, -240)}, 0.4, Enum.EasingStyle.Back, Enum.EasingDirection.Out):Play()
            else
                tween(refs.Main, {Position = UDim2.new(1.1, 0, 0.5, -240)}, 0.4, Enum.EasingStyle.Back, Enum.EasingDirection.In):Play()
            end
        end
    end
end

local function onInputEnded(input, gameProcessed)
    -- Q Release → Stop Aimbot
    if input.KeyCode == Enum.KeyCode.Q then
        aimbotHolding = false
    end
end

-- ============================================
-- CLEANUP FUNCTION
-- ============================================
local function cleanup()
    for _, conn in pairs(connections) do
        pcall(function() conn:Disconnect() end)
    end
    connections = {}
    clearAllESP()
    -- Clear enemy ESP
    for model, _ in pairs(enemyESPData) do
        removeEnemyESP(model)
    end
    -- Remove FOV circle
    if fovCircle then pcall(function() fovCircle:Remove() end) end
    pcall(function()
        if refs.ScreenGui then refs.ScreenGui:Destroy() end
    end)
end

_G._ESP_CLEANUP = cleanup

-- ============================================
-- INITIALIZATION
-- ============================================
local function init()
    print("[Blox-Scripts] ESP + Tracker v2.0 loading...")

    buildGUI()
    setupFOVCircle()

    -- Setup ESP for existing players
    for _, targetPlayer in ipairs(Players:GetPlayers()) do
        if targetPlayer ~= player then
            createESPForPlayer(targetPlayer)
        end
    end

    -- Connect events
    table.insert(connections, Players.PlayerAdded:Connect(onPlayerAdded))
    table.insert(connections, Players.PlayerRemoving:Connect(onPlayerRemoving))
    table.insert(connections, UserInputService.InputBegan:Connect(onInputBegan))
    table.insert(connections, UserInputService.InputEnded:Connect(onInputEnded))

    -- Main update loop (throttle enemy scan tiap 0.5s)
    local enemyScanTimer = 0
    table.insert(connections, RunService.RenderStepped:Connect(function(dt)
        updateESP()
        updateAimbot()

        -- Update aimbot target label
        if refs.AimTargetLabel then
            if aimbotCurrentTarget then
                refs.AimTargetLabel.Text = "🎯 Target: " .. aimbotCurrentTarget.Name .. " [" .. math.floor(aimbotCurrentTarget.Dist) .. "]"
                refs.AimTargetLabel.TextColor3 = C.red
            else
                refs.AimTargetLabel.Text = "🎯 Target: —"
                refs.AimTargetLabel.TextColor3 = C.textMuted
            end
        end

        -- Scan enemies tiap 0.5 detik (hemat performa)
        enemyScanTimer = enemyScanTimer + dt
        if enemyScanTimer >= 0.5 then
            enemyScanTimer = 0
            pcall(scanAndUpdateEnemyESP)
        end
    end))

    -- Handle respawn
    table.insert(connections, player.CharacterAdded:Connect(function()
        task.wait(1)
        if not HAS_DRAWING then
            for _, targetPlayer in ipairs(Players:GetPlayers()) do
                if targetPlayer ~= player then
                    if not espHighlights[targetPlayer] then
                        createHighlightESP(targetPlayer)
                    end
                end
            end
        end
    end))

    -- Entrance animation
    if refs.Main then
        refs.Main.Position = UDim2.new(1.2, 0, 0.5, -240)
        tween(refs.Main, {Position = UDim2.new(1, -280, 0.5, -240)}, 0.6, Enum.EasingStyle.Back, Enum.EasingDirection.Out):Play()
    end

    print("[Blox-Scripts] ✅ ESP + Tracker + Aimbot AKTIF!")
    print("[Blox-Scripts] Keybinds: RCtrl=ESP | B=Tracker | E=Enemy | T=Aimbot | Q=Aim | M=Panel")
end

-- ══ START ══
init()
