--[[
    ╔══════════════════════════════════════════════╗
    ║            BLOX HUB v1.1                     ║
    ║     All-in-One General Script Hub            ║
    ║     Blox-Scripts by Jokskuyy                 ║
    ╠══════════════════════════════════════════════╣
    ║  Modules:                                    ║
    ║    ✈  Fly      - Terbang + Speed Control     ║
    ║    🍀 Luck     - Auto Detect Luck Values     ║
    ║    ⚔  Farm     - Auto Replay + Next Stage     ║
    ╚══════════════════════════════════════════════╝

    Keybinds:
    - F          : Toggle Fly
    - RightShift : Show/Hide Hub
    
    Auto-teleport: Script otomatis jalan lagi setelah pindah stage
]]

-- ============================================
-- AUTO RE-EXECUTE AFTER TELEPORT
-- ============================================
local BLOX_URL = "https://raw.githubusercontent.com/Jokskuyy/Blox-Scripts/main/BloxHub.lua"

pcall(function()
    local queueFunc = queue_on_teleport or queueonteleport or queue_on_tp
    if queueFunc then
        queueFunc('loadstring(game:HttpGet("' .. BLOX_URL .. '", true))()')
        print("[✅ Blox Hub] Auto re-execute aktif setelah teleport")
    else
        print("[⚠ Blox Hub] Executor tidak support queue_on_teleport")
    end
end)

-- ============================================
-- SERVICES
-- ============================================
local Players            = game:GetService("Players")
local UserInputService   = game:GetService("UserInputService")
local RunService         = game:GetService("RunService")
local TweenService       = game:GetService("TweenService")
local ReplicatedStorage  = game:GetService("ReplicatedStorage")

-- ============================================
-- PLAYER
-- ============================================
local player = Players.LocalPlayer
local mouse  = player:GetMouse()

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
-- SHARED STATE
-- ============================================
local activeTab     = "fly"   -- "fly" | "luck" | "farm"
local hubVisible    = true

-- Fly state
local flying        = false
local flySpeed      = 50
local MIN_SPEED     = 1
local MAX_SPEED     = 500
local bodyGyro      = nil
local bodyVelocity  = nil
local flyConnection = nil

-- Luck state
local currentLuck   = "—"
local luckSource    = "Belum ditemukan"
local luckHistory   = {}
local MAX_HISTORY   = 20
local luckValueObj  = nil
local monitoring    = false

-- Farm state
local farming          = false
local farmReplaysPerStage = 5
local farmCurrentReplay   = 0
local farmTotalStages     = 0
local farmTotalReplays    = 0
local farmLog             = {}

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

local function addToHistory(value, source)
    table.insert(luckHistory, 1, {
        value  = tostring(value),
        source = source,
        time   = os.date("%H:%M:%S"),
    })
    if #luckHistory > MAX_HISTORY then table.remove(luckHistory) end
end

local function deepSearch(instance, keywords, depth, maxDepth)
    depth    = depth or 0
    maxDepth = maxDepth or 5
    local results = {}
    if depth > maxDepth then return results end
    local ok, children = pcall(function() return instance:GetChildren() end)
    if not ok then return results end
    for _, child in ipairs(children) do
        local lo = child.Name:lower()
        for _, kw in ipairs(keywords) do
            if lo:find(kw:lower()) then
                table.insert(results, { object = child, path = instance:GetFullName().."."..child.Name, name = child.Name })
            end
        end
        for _, r in ipairs(deepSearch(child, keywords, depth+1, maxDepth)) do
            table.insert(results, r)
        end
    end
    return results
end

-- ============================================
-- GUI BUILDER
-- ============================================
local refs = {}  -- store references to GUI elements

local function buildHub()
    if player.PlayerGui:FindFirstChild("BloxHub") then
        player.PlayerGui:FindFirstChild("BloxHub"):Destroy()
    end

    local sg = Instance.new("ScreenGui")
    sg.Name = "BloxHub"
    sg.ResetOnSpawn = false
    sg.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
    sg.DisplayOrder = 999  -- Selalu di atas UI game
    sg.IgnoreGuiInset = false
    sg.Parent = player.PlayerGui
    refs.ScreenGui = sg

    -- ── MAIN FRAME ──────────────────────────
    local main = Instance.new("Frame")
    main.Name = "Main"
    main.Size = UDim2.new(0, 300, 0, 460)
    main.Position = UDim2.new(0.5, -150, 0.5, -230)
    main.BackgroundColor3 = C.bg
    main.BackgroundTransparency = 0.02
    main.BorderSizePixel = 0
    main.Active = true
    main.Draggable = true
    main.ClipsDescendants = true
    main.Parent = sg
    corner(main, 14)
    stroke(main, C.accent, 2, 0.25)
    refs.Main = main

    -- Glow bar top
    local glow = Instance.new("Frame")
    glow.Size = UDim2.new(1, 0, 0, 3)
    glow.BorderSizePixel = 0
    glow.Parent = main
    corner(glow, 14)
    local gg = Instance.new("UIGradient")
    gg.Color = ColorSequence.new{
        ColorSequenceKeypoint.new(0, C.accent),
        ColorSequenceKeypoint.new(0.5, C.cyan),
        ColorSequenceKeypoint.new(1, C.accent),
    }
    gg.Parent = glow

    -- ── HEADER ──────────────────────────────
    local header = Instance.new("Frame")
    header.Size = UDim2.new(1, 0, 0, 52)
    header.Position = UDim2.new(0, 0, 0, 3)
    header.BackgroundTransparency = 1
    header.Parent = main

    local logo = Instance.new("TextLabel")
    logo.Size = UDim2.new(1, -80, 0, 22)
    logo.Position = UDim2.new(0, 14, 0, 8)
    logo.BackgroundTransparency = 1
    logo.Text = "⚡ BLOX HUB"
    logo.TextColor3 = C.white
    logo.TextSize = 17
    logo.Font = Enum.Font.GothamBlack
    logo.TextXAlignment = Enum.TextXAlignment.Left
    logo.Parent = header

    local version = Instance.new("TextLabel")
    version.Size = UDim2.new(1, -14, 0, 14)
    version.Position = UDim2.new(0, 14, 0, 30)
    version.BackgroundTransparency = 1
    version.Text = "v1.0 • Universal Script Hub"
    version.TextColor3 = C.textDim
    version.TextSize = 10
    version.Font = Enum.Font.Gotham
    version.TextXAlignment = Enum.TextXAlignment.Left
    version.Parent = header

    -- Minimize button (hide - bisa reopen pakai RightShift)
    local minimizeBtn = Instance.new("TextButton")
    minimizeBtn.Size = UDim2.new(0, 28, 0, 28)
    minimizeBtn.Position = UDim2.new(1, -74, 0, 10)
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
        hubVisible = false
        tween(main, {Position = UDim2.new(0.5, -150, 1.1, 0)}, 0.4, Enum.EasingStyle.Back, Enum.EasingDirection.In):Play()
    end)

    -- Close button (tutup & hapus script sepenuhnya)
    local closeBtn = Instance.new("TextButton")
    closeBtn.Size = UDim2.new(0, 28, 0, 28)
    closeBtn.Position = UDim2.new(1, -42, 0, 10)
    closeBtn.BackgroundColor3 = C.bgInput
    closeBtn.BorderSizePixel = 0
    closeBtn.Text = "✕"
    closeBtn.TextColor3 = C.textDim
    closeBtn.TextSize = 14
    closeBtn.Font = Enum.Font.GothamBold
    closeBtn.Parent = header
    corner(closeBtn, 6)

    closeBtn.MouseEnter:Connect(function() tween(closeBtn, {BackgroundColor3 = C.red, TextColor3 = C.white}, 0.15):Play() end)
    closeBtn.MouseLeave:Connect(function() tween(closeBtn, {BackgroundColor3 = C.bgInput, TextColor3 = C.textDim}, 0.15):Play() end)
    closeBtn.MouseButton1Click:Connect(function()
        -- Stop fly jika aktif
        if flying then
            flying = false
            stopFlying()
        end
        -- Animasi close lalu destroy
        local closeTween = tween(main, {Size = UDim2.new(0, 300, 0, 0), BackgroundTransparency = 1}, 0.35, Enum.EasingStyle.Back, Enum.EasingDirection.In)
        closeTween:Play()
        closeTween.Completed:Connect(function()
            sg:Destroy()
            print("[Blox Hub] ❌ Script ditutup. Bye!")
        end)
    end)

    -- ── TABS ────────────────────────────────
    local tabBar = Instance.new("Frame")
    tabBar.Size = UDim2.new(1, -20, 0, 34)
    tabBar.Position = UDim2.new(0, 10, 0, 56)
    tabBar.BackgroundColor3 = C.bgCard
    tabBar.BorderSizePixel = 0
    tabBar.Parent = main
    corner(tabBar, 8)

    local tabData = {
        { id = "fly",  icon = "✈",  label = "Fly" },
        { id = "luck", icon = "🍀", label = "Luck" },
        { id = "farm", icon = "⚔",  label = "Farm" },
    }

    local tabButtons = {}
    for i, td in ipairs(tabData) do
        local tb = Instance.new("TextButton")
        tb.Name = "Tab_"..td.id
        tb.Size = UDim2.new(1/#tabData, -4, 1, -6)
        tb.Position = UDim2.new((i-1)/#tabData, 2, 0, 3)
        tb.BackgroundColor3 = (td.id == activeTab) and C.accent or Color3.fromRGB(0,0,0)
        tb.BackgroundTransparency = (td.id == activeTab) and 0 or 1
        tb.BorderSizePixel = 0
        tb.Text = td.icon .. "  " .. td.label
        tb.TextColor3 = (td.id == activeTab) and C.white or C.textDim
        tb.TextSize = 13
        tb.Font = Enum.Font.GothamBold
        tb.Parent = tabBar
        corner(tb, 6)
        tabButtons[td.id] = tb
    end

    -- ── PAGES CONTAINER ─────────────────────
    local pages = Instance.new("Frame")
    pages.Name = "Pages"
    pages.Size = UDim2.new(1, -20, 1, -102)
    pages.Position = UDim2.new(0, 10, 0, 96)
    pages.BackgroundTransparency = 1
    pages.ClipsDescendants = true
    pages.Parent = main

    -- ════════════════════════════════════════
    -- PAGE: FLY
    -- ════════════════════════════════════════
    local flyPage = Instance.new("Frame")
    flyPage.Name = "FlyPage"
    flyPage.Size = UDim2.new(1, 0, 1, 0)
    flyPage.BackgroundTransparency = 1
    flyPage.Visible = (activeTab == "fly")
    flyPage.Parent = pages

    -- Toggle row
    local flyToggleRow = Instance.new("Frame")
    flyToggleRow.Size = UDim2.new(1, 0, 0, 42)
    flyToggleRow.BackgroundColor3 = C.bgCard
    flyToggleRow.BorderSizePixel = 0
    flyToggleRow.Parent = flyPage
    corner(flyToggleRow, 8)

    local flyToggleLabel = Instance.new("TextLabel")
    flyToggleLabel.Size = UDim2.new(0.6, 0, 1, 0)
    flyToggleLabel.Position = UDim2.new(0, 14, 0, 0)
    flyToggleLabel.BackgroundTransparency = 1
    flyToggleLabel.Text = "Terbang"
    flyToggleLabel.TextColor3 = C.text
    flyToggleLabel.TextSize = 14
    flyToggleLabel.Font = Enum.Font.GothamMedium
    flyToggleLabel.TextXAlignment = Enum.TextXAlignment.Left
    flyToggleLabel.Parent = flyToggleRow

    local flyToggleBg = Instance.new("Frame")
    flyToggleBg.Name = "FlyToggleBg"
    flyToggleBg.Size = UDim2.new(0, 50, 0, 26)
    flyToggleBg.Position = UDim2.new(1, -64, 0.5, -13)
    flyToggleBg.BackgroundColor3 = C.bgInput
    flyToggleBg.BorderSizePixel = 0
    flyToggleBg.Parent = flyToggleRow
    corner(flyToggleBg, 13)
    refs.FlyToggleBg = flyToggleBg

    local flyToggleKnob = Instance.new("Frame")
    flyToggleKnob.Name = "FlyKnob"
    flyToggleKnob.Size = UDim2.new(0, 22, 0, 22)
    flyToggleKnob.Position = UDim2.new(0, 2, 0.5, -11)
    flyToggleKnob.BackgroundColor3 = C.textDim
    flyToggleKnob.BorderSizePixel = 0
    flyToggleKnob.Parent = flyToggleBg
    corner(flyToggleKnob, 11)
    refs.FlyToggleKnob = flyToggleKnob

    local flyToggleBtn = Instance.new("TextButton")
    flyToggleBtn.Size = UDim2.new(1, 0, 1, 0)
    flyToggleBtn.BackgroundTransparency = 1
    flyToggleBtn.Text = ""
    flyToggleBtn.Parent = flyToggleBg
    refs.FlyToggleBtn = flyToggleBtn

    -- Status
    local flyStatus = Instance.new("TextLabel")
    flyStatus.Name = "FlyStatus"
    flyStatus.Size = UDim2.new(1, 0, 0, 18)
    flyStatus.Position = UDim2.new(0, 0, 0, 48)
    flyStatus.BackgroundTransparency = 1
    flyStatus.Text = "Status: OFF"
    flyStatus.TextColor3 = C.red
    flyStatus.TextSize = 12
    flyStatus.Font = Enum.Font.GothamMedium
    flyStatus.TextXAlignment = Enum.TextXAlignment.Left
    flyStatus.Parent = flyPage
    refs.FlyStatus = flyStatus

    -- Speed section
    local speedHeader = Instance.new("TextLabel")
    speedHeader.Size = UDim2.new(0.6, 0, 0, 20)
    speedHeader.Position = UDim2.new(0, 0, 0, 76)
    speedHeader.BackgroundTransparency = 1
    speedHeader.Text = "Kecepatan"
    speedHeader.TextColor3 = C.text
    speedHeader.TextSize = 13
    speedHeader.Font = Enum.Font.GothamMedium
    speedHeader.TextXAlignment = Enum.TextXAlignment.Left
    speedHeader.Parent = flyPage

    local speedVal = Instance.new("TextLabel")
    speedVal.Name = "SpeedVal"
    speedVal.Size = UDim2.new(0.4, 0, 0, 20)
    speedVal.Position = UDim2.new(0.6, 0, 0, 76)
    speedVal.BackgroundTransparency = 1
    speedVal.Text = tostring(flySpeed)
    speedVal.TextColor3 = C.accentLight
    speedVal.TextSize = 14
    speedVal.Font = Enum.Font.GothamBold
    speedVal.TextXAlignment = Enum.TextXAlignment.Right
    speedVal.Parent = flyPage
    refs.SpeedVal = speedVal

    -- Slider
    local sliderBg = Instance.new("Frame")
    sliderBg.Name = "SliderBg"
    sliderBg.Size = UDim2.new(1, 0, 0, 8)
    sliderBg.Position = UDim2.new(0, 0, 0, 102)
    sliderBg.BackgroundColor3 = C.bgInput
    sliderBg.BorderSizePixel = 0
    sliderBg.Parent = flyPage
    corner(sliderBg, 4)

    local sliderFill = Instance.new("Frame")
    sliderFill.Name = "SliderFill"
    sliderFill.Size = UDim2.new((flySpeed - MIN_SPEED)/(MAX_SPEED - MIN_SPEED), 0, 1, 0)
    sliderFill.BackgroundColor3 = C.accent
    sliderFill.BorderSizePixel = 0
    sliderFill.Parent = sliderBg
    corner(sliderFill, 4)
    refs.SliderFill = sliderFill

    local slFillGrad = Instance.new("UIGradient")
    slFillGrad.Color = ColorSequence.new{
        ColorSequenceKeypoint.new(0, C.accent),
        ColorSequenceKeypoint.new(1, C.cyan),
    }
    slFillGrad.Parent = sliderFill

    local sliderKnob = Instance.new("Frame")
    sliderKnob.Name = "SliderKnob"
    sliderKnob.Size = UDim2.new(0, 16, 0, 16)
    sliderKnob.Position = UDim2.new((flySpeed - MIN_SPEED)/(MAX_SPEED - MIN_SPEED), -8, 0.5, -8)
    sliderKnob.BackgroundColor3 = C.white
    sliderKnob.BorderSizePixel = 0
    sliderKnob.ZIndex = 2
    sliderKnob.Parent = sliderBg
    corner(sliderKnob, 8)
    stroke(sliderKnob, C.accent, 2, 0)
    refs.SliderKnob = sliderKnob

    local sliderHit = Instance.new("TextButton")
    sliderHit.Size = UDim2.new(1, 0, 1, 16)
    sliderHit.Position = UDim2.new(0, 0, 0, -8)
    sliderHit.BackgroundTransparency = 1
    sliderHit.Text = ""
    sliderHit.ZIndex = 3
    sliderHit.Parent = sliderBg

    -- Presets
    local presetFrame = Instance.new("Frame")
    presetFrame.Size = UDim2.new(1, 0, 0, 26)
    presetFrame.Position = UDim2.new(0, 0, 0, 118)
    presetFrame.BackgroundTransparency = 1
    presetFrame.Parent = flyPage

    local presets = {25, 50, 100, 200, 500}
    for i, sp in ipairs(presets) do
        local pb = Instance.new("TextButton")
        pb.Size = UDim2.new(1/#presets, -4, 1, 0)
        pb.Position = UDim2.new((i-1)/#presets, 2, 0, 0)
        pb.BackgroundColor3 = C.bgInput
        pb.BorderSizePixel = 0
        pb.Text = tostring(sp)
        pb.TextColor3 = C.textDim
        pb.TextSize = 11
        pb.Font = Enum.Font.GothamMedium
        pb.Parent = presetFrame
        corner(pb, 5)

        pb.MouseEnter:Connect(function()
            if pb.BackgroundColor3 ~= C.accent then tween(pb, {BackgroundColor3 = C.border}, 0.12):Play() end
        end)
        pb.MouseLeave:Connect(function()
            if pb.BackgroundColor3 ~= C.accent then tween(pb, {BackgroundColor3 = C.bgInput}, 0.12):Play() end
        end)
        pb.MouseButton1Click:Connect(function()
            flySpeed = sp
            refs.SpeedVal.Text = tostring(sp)
            local ratio = (sp - MIN_SPEED)/(MAX_SPEED - MIN_SPEED)
            refs.SliderFill.Size = UDim2.new(ratio, 0, 1, 0)
            refs.SliderKnob.Position = UDim2.new(ratio, -8, 0.5, -8)
            for _, btn in ipairs(presetFrame:GetChildren()) do
                if btn:IsA("TextButton") then
                    btn.BackgroundColor3 = C.bgInput
                    btn.TextColor3 = C.textDim
                end
            end
            pb.BackgroundColor3 = C.accent
            pb.TextColor3 = C.white
        end)
    end

    -- Controls info
    local ctrlInfo = Instance.new("TextLabel")
    ctrlInfo.Size = UDim2.new(1, 0, 0, 60)
    ctrlInfo.Position = UDim2.new(0, 0, 0, 152)
    ctrlInfo.BackgroundTransparency = 1
    ctrlInfo.Text = "Kontrol:\n  WASD = Gerak  |  Spasi = Naik\n  Shift = Turun  |  F = Toggle Fly"
    ctrlInfo.TextColor3 = C.textMuted
    ctrlInfo.TextSize = 11
    ctrlInfo.Font = Enum.Font.Code
    ctrlInfo.TextXAlignment = Enum.TextXAlignment.Left
    ctrlInfo.TextYAlignment = Enum.TextYAlignment.Top
    ctrlInfo.Parent = flyPage

    -- Slider drag logic
    local dragging = false
    local function updateSlider(x)
        local pos  = sliderBg.AbsolutePosition.X
        local size = sliderBg.AbsoluteSize.X
        local ratio = math.clamp((x - pos) / size, 0, 1)
        flySpeed = math.clamp(math.floor(MIN_SPEED + ratio * (MAX_SPEED - MIN_SPEED)), MIN_SPEED, MAX_SPEED)
        refs.SpeedVal.Text = tostring(flySpeed)
        refs.SliderFill.Size = UDim2.new(ratio, 0, 1, 0)
        refs.SliderKnob.Position = UDim2.new(ratio, -8, 0.5, -8)
        for _, btn in ipairs(presetFrame:GetChildren()) do
            if btn:IsA("TextButton") then btn.BackgroundColor3 = C.bgInput; btn.TextColor3 = C.textDim end
        end
    end
    sliderHit.MouseButton1Down:Connect(function() dragging = true; updateSlider(mouse.X) end)
    UserInputService.InputChanged:Connect(function(inp)
        if dragging and inp.UserInputType == Enum.UserInputType.MouseMovement then updateSlider(inp.Position.X) end
    end)
    UserInputService.InputEnded:Connect(function(inp)
        if inp.UserInputType == Enum.UserInputType.MouseButton1 then dragging = false end
    end)

    -- ════════════════════════════════════════
    -- PAGE: LUCK
    -- ════════════════════════════════════════
    local luckPage = Instance.new("Frame")
    luckPage.Name = "LuckPage"
    luckPage.Size = UDim2.new(1, 0, 1, 0)
    luckPage.BackgroundTransparency = 1
    luckPage.Visible = (activeTab == "luck")
    luckPage.Parent = pages
    refs.LuckPage = luckPage

    -- Luck display card
    local luckCard = Instance.new("Frame")
    luckCard.Size = UDim2.new(1, 0, 0, 80)
    luckCard.BackgroundColor3 = C.bgCard
    luckCard.BorderSizePixel = 0
    luckCard.Parent = luckPage
    corner(luckCard, 10)
    stroke(luckCard, C.orange, 1, 0.5)

    local luckIcon = Instance.new("TextLabel")
    luckIcon.Size = UDim2.new(0, 40, 0, 40)
    luckIcon.Position = UDim2.new(0, 10, 0, 10)
    luckIcon.BackgroundTransparency = 1
    luckIcon.Text = "🎯"
    luckIcon.TextSize = 28
    luckIcon.Parent = luckCard

    local luckValDisp = Instance.new("TextLabel")
    luckValDisp.Name = "LuckVal"
    luckValDisp.Size = UDim2.new(1, -60, 0, 28)
    luckValDisp.Position = UDim2.new(0, 55, 0, 8)
    luckValDisp.BackgroundTransparency = 1
    luckValDisp.Text = "—"
    luckValDisp.TextColor3 = C.gold
    luckValDisp.TextSize = 22
    luckValDisp.Font = Enum.Font.GothamBold
    luckValDisp.TextXAlignment = Enum.TextXAlignment.Left
    luckValDisp.Parent = luckCard
    refs.LuckVal = luckValDisp

    local luckSrcDisp = Instance.new("TextLabel")
    luckSrcDisp.Name = "LuckSrc"
    luckSrcDisp.Size = UDim2.new(1, -60, 0, 14)
    luckSrcDisp.Position = UDim2.new(0, 55, 0, 36)
    luckSrcDisp.BackgroundTransparency = 1
    luckSrcDisp.Text = "Sumber: Mencari..."
    luckSrcDisp.TextColor3 = C.textDim
    luckSrcDisp.TextSize = 10
    luckSrcDisp.Font = Enum.Font.Gotham
    luckSrcDisp.TextXAlignment = Enum.TextXAlignment.Left
    luckSrcDisp.Parent = luckCard
    refs.LuckSrc = luckSrcDisp

    -- scan indicator
    local scanDot = Instance.new("Frame")
    scanDot.Size = UDim2.new(0, 8, 0, 8)
    scanDot.Position = UDim2.new(0, 14, 0, 60)
    scanDot.BackgroundColor3 = C.orange
    scanDot.BorderSizePixel = 0
    scanDot.Parent = luckCard
    corner(scanDot, 4)
    refs.ScanDot = scanDot

    local scanTxt = Instance.new("TextLabel")
    scanTxt.Name = "ScanTxt"
    scanTxt.Size = UDim2.new(1, -30, 0, 14)
    scanTxt.Position = UDim2.new(0, 28, 0, 57)
    scanTxt.BackgroundTransparency = 1
    scanTxt.Text = "Menunggu scan..."
    scanTxt.TextColor3 = C.orange
    scanTxt.TextSize = 10
    scanTxt.Font = Enum.Font.Gotham
    scanTxt.TextXAlignment = Enum.TextXAlignment.Left
    scanTxt.Parent = luckCard
    refs.ScanTxt = scanTxt

    -- Rescan button
    local rescanBtn = Instance.new("TextButton")
    rescanBtn.Size = UDim2.new(1, 0, 0, 32)
    rescanBtn.Position = UDim2.new(0, 0, 0, 88)
    rescanBtn.BackgroundColor3 = C.orange
    rescanBtn.BorderSizePixel = 0
    rescanBtn.Text = "🔄  SCAN LUCK"
    rescanBtn.TextColor3 = C.bg
    rescanBtn.TextSize = 13
    rescanBtn.Font = Enum.Font.GothamBold
    rescanBtn.Parent = luckPage
    corner(rescanBtn, 8)
    refs.RescanBtn = rescanBtn

    rescanBtn.MouseEnter:Connect(function() tween(rescanBtn, {BackgroundColor3 = C.gold}, 0.12):Play() end)
    rescanBtn.MouseLeave:Connect(function() tween(rescanBtn, {BackgroundColor3 = C.orange}, 0.12):Play() end)

    -- ── AUTO MONITOR TOGGLE ─────────────────
    local monitorRow = Instance.new("Frame")
    monitorRow.Size = UDim2.new(1, 0, 0, 36)
    monitorRow.Position = UDim2.new(0, 0, 0, 126)
    monitorRow.BackgroundColor3 = C.bgCard
    monitorRow.BorderSizePixel = 0
    monitorRow.Parent = luckPage
    corner(monitorRow, 8)

    local monLabel = Instance.new("TextLabel")
    monLabel.Size = UDim2.new(0.6, 0, 1, 0)
    monLabel.Position = UDim2.new(0, 12, 0, 0)
    monLabel.BackgroundTransparency = 1
    monLabel.Text = "🔁 Auto Monitor"
    monLabel.TextColor3 = C.text
    monLabel.TextSize = 13
    monLabel.Font = Enum.Font.GothamMedium
    monLabel.TextXAlignment = Enum.TextXAlignment.Left
    monLabel.Parent = monitorRow

    local monInfo = Instance.new("TextLabel")
    monInfo.Size = UDim2.new(0.35, 0, 0, 12)
    monInfo.Position = UDim2.new(0, 12, 1, -14)
    monInfo.BackgroundTransparency = 1
    monInfo.Text = "0.2s interval"
    monInfo.TextColor3 = C.textMuted
    monInfo.TextSize = 9
    monInfo.Font = Enum.Font.Gotham
    monInfo.TextXAlignment = Enum.TextXAlignment.Left
    monInfo.Parent = monitorRow

    local monToggleBg = Instance.new("Frame")
    monToggleBg.Size = UDim2.new(0, 50, 0, 24)
    monToggleBg.Position = UDim2.new(1, -62, 0.5, -12)
    monToggleBg.BackgroundColor3 = C.bgInput
    monToggleBg.BorderSizePixel = 0
    monToggleBg.Parent = monitorRow
    corner(monToggleBg, 12)
    refs.MonToggleBg = monToggleBg

    local monToggleKnob = Instance.new("Frame")
    monToggleKnob.Size = UDim2.new(0, 20, 0, 20)
    monToggleKnob.Position = UDim2.new(0, 2, 0.5, -10)
    monToggleKnob.BackgroundColor3 = C.textDim
    monToggleKnob.BorderSizePixel = 0
    monToggleKnob.Parent = monToggleBg
    corner(monToggleKnob, 10)
    refs.MonToggleKnob = monToggleKnob

    local monToggleBtn = Instance.new("TextButton")
    monToggleBtn.Size = UDim2.new(1, 0, 1, 0)
    monToggleBtn.BackgroundTransparency = 1
    monToggleBtn.Text = ""
    monToggleBtn.Parent = monToggleBg
    refs.MonToggleBtn = monToggleBtn

    -- History (shifted down)
    local histTitle = Instance.new("TextLabel")
    histTitle.Size = UDim2.new(1, 0, 0, 20)
    histTitle.Position = UDim2.new(0, 0, 0, 168)
    histTitle.BackgroundTransparency = 1
    histTitle.Text = "📋 Riwayat Perubahan"
    histTitle.TextColor3 = C.textDim
    histTitle.TextSize = 12
    histTitle.Font = Enum.Font.GothamMedium
    histTitle.TextXAlignment = Enum.TextXAlignment.Left
    histTitle.Parent = luckPage

    local histScroll = Instance.new("ScrollingFrame")
    histScroll.Name = "HistScroll"
    histScroll.Size = UDim2.new(1, 0, 1, -194)
    histScroll.Position = UDim2.new(0, 0, 0, 190)
    histScroll.BackgroundColor3 = C.bgCard
    histScroll.BackgroundTransparency = 0.4
    histScroll.BorderSizePixel = 0
    histScroll.ScrollBarThickness = 3
    histScroll.ScrollBarImageColor3 = C.orange
    histScroll.AutomaticCanvasSize = Enum.AutomaticSize.Y
    histScroll.CanvasSize = UDim2.new(0, 0, 0, 0)
    histScroll.Parent = luckPage
    corner(histScroll, 8)
    refs.HistScroll = histScroll

    local histLayout = Instance.new("UIListLayout")
    histLayout.Padding = UDim.new(0, 2)
    histLayout.SortOrder = Enum.SortOrder.LayoutOrder
    histLayout.Parent = histScroll

    local histPad = Instance.new("UIPadding")
    histPad.PaddingTop = UDim.new(0, 4)
    histPad.PaddingLeft = UDim.new(0, 6)
    histPad.PaddingRight = UDim.new(0, 6)
    histPad.Parent = histScroll

    local noHist = Instance.new("TextLabel")
    noHist.Name = "NoHist"
    noHist.Size = UDim2.new(1, 0, 0, 36)
    noHist.BackgroundTransparency = 1
    noHist.Text = "Belum ada perubahan..."
    noHist.TextColor3 = C.textMuted
    noHist.TextSize = 11
    noHist.Font = Enum.Font.Gotham
    noHist.Parent = histScroll
    refs.NoHist = noHist

    -- ════════════════════════════════════════
    -- PAGE: FARM
    -- ════════════════════════════════════════
    local farmPage = Instance.new("Frame")
    farmPage.Name = "FarmPage"
    farmPage.Size = UDim2.new(1, 0, 1, 0)
    farmPage.BackgroundTransparency = 1
    farmPage.Visible = (activeTab == "farm")
    farmPage.Parent = pages

    -- Farm toggle row
    local farmToggleRow = Instance.new("Frame")
    farmToggleRow.Size = UDim2.new(1, 0, 0, 42)
    farmToggleRow.BackgroundColor3 = C.bgCard
    farmToggleRow.BorderSizePixel = 0
    farmToggleRow.Parent = farmPage
    corner(farmToggleRow, 8)

    local farmToggleLabel = Instance.new("TextLabel")
    farmToggleLabel.Size = UDim2.new(0.6, 0, 1, 0)
    farmToggleLabel.Position = UDim2.new(0, 14, 0, 0)
    farmToggleLabel.BackgroundTransparency = 1
    farmToggleLabel.Text = "⚔ Auto Farm"
    farmToggleLabel.TextColor3 = C.text
    farmToggleLabel.TextSize = 14
    farmToggleLabel.Font = Enum.Font.GothamMedium
    farmToggleLabel.TextXAlignment = Enum.TextXAlignment.Left
    farmToggleLabel.Parent = farmToggleRow

    local farmToggleBg = Instance.new("Frame")
    farmToggleBg.Size = UDim2.new(0, 50, 0, 26)
    farmToggleBg.Position = UDim2.new(1, -64, 0.5, -13)
    farmToggleBg.BackgroundColor3 = C.bgInput
    farmToggleBg.BorderSizePixel = 0
    farmToggleBg.Parent = farmToggleRow
    corner(farmToggleBg, 13)
    refs.FarmToggleBg = farmToggleBg

    local farmToggleKnob = Instance.new("Frame")
    farmToggleKnob.Size = UDim2.new(0, 22, 0, 22)
    farmToggleKnob.Position = UDim2.new(0, 2, 0.5, -11)
    farmToggleKnob.BackgroundColor3 = C.textDim
    farmToggleKnob.BorderSizePixel = 0
    farmToggleKnob.Parent = farmToggleBg
    corner(farmToggleKnob, 11)
    refs.FarmToggleKnob = farmToggleKnob

    local farmToggleBtn = Instance.new("TextButton")
    farmToggleBtn.Size = UDim2.new(1, 0, 1, 0)
    farmToggleBtn.BackgroundTransparency = 1
    farmToggleBtn.Text = ""
    farmToggleBtn.Parent = farmToggleBg
    refs.FarmToggleBtn = farmToggleBtn

    -- Farm status
    local farmStatus = Instance.new("TextLabel")
    farmStatus.Name = "FarmStatus"
    farmStatus.Size = UDim2.new(1, 0, 0, 16)
    farmStatus.Position = UDim2.new(0, 0, 0, 48)
    farmStatus.BackgroundTransparency = 1
    farmStatus.Text = "Status: IDLE"
    farmStatus.TextColor3 = C.textDim
    farmStatus.TextSize = 12
    farmStatus.Font = Enum.Font.GothamMedium
    farmStatus.TextXAlignment = Enum.TextXAlignment.Left
    farmStatus.Parent = farmPage
    refs.FarmStatus = farmStatus

    -- Stats card
    local statsCard = Instance.new("Frame")
    statsCard.Size = UDim2.new(1, 0, 0, 52)
    statsCard.Position = UDim2.new(0, 0, 0, 70)
    statsCard.BackgroundColor3 = C.bgCard
    statsCard.BorderSizePixel = 0
    statsCard.Parent = farmPage
    corner(statsCard, 8)

    -- Replay counter
    local replayLabel = Instance.new("TextLabel")
    replayLabel.Size = UDim2.new(0.5, 0, 0, 16)
    replayLabel.Position = UDim2.new(0, 12, 0, 6)
    replayLabel.BackgroundTransparency = 1
    replayLabel.Text = "Replay"
    replayLabel.TextColor3 = C.textDim
    replayLabel.TextSize = 10
    replayLabel.Font = Enum.Font.Gotham
    replayLabel.TextXAlignment = Enum.TextXAlignment.Left
    replayLabel.Parent = statsCard

    local replayVal = Instance.new("TextLabel")
    replayVal.Name = "ReplayVal"
    replayVal.Size = UDim2.new(0.5, -12, 0, 22)
    replayVal.Position = UDim2.new(0, 12, 0, 22)
    replayVal.BackgroundTransparency = 1
    replayVal.Text = "0 / 5"
    replayVal.TextColor3 = C.cyan
    replayVal.TextSize = 16
    replayVal.Font = Enum.Font.GothamBold
    replayVal.TextXAlignment = Enum.TextXAlignment.Left
    replayVal.Parent = statsCard
    refs.ReplayVal = replayVal

    -- Stage counter
    local stageLabel = Instance.new("TextLabel")
    stageLabel.Size = UDim2.new(0.5, 0, 0, 16)
    stageLabel.Position = UDim2.new(0.5, 0, 0, 6)
    stageLabel.BackgroundTransparency = 1
    stageLabel.Text = "Total Stage"
    stageLabel.TextColor3 = C.textDim
    stageLabel.TextSize = 10
    stageLabel.Font = Enum.Font.Gotham
    stageLabel.TextXAlignment = Enum.TextXAlignment.Left
    stageLabel.Parent = statsCard

    local stageVal = Instance.new("TextLabel")
    stageVal.Name = "StageVal"
    stageVal.Size = UDim2.new(0.5, -12, 0, 22)
    stageVal.Position = UDim2.new(0.5, 0, 0, 22)
    stageVal.BackgroundTransparency = 1
    stageVal.Text = "0"
    stageVal.TextColor3 = C.gold
    stageVal.TextSize = 16
    stageVal.Font = Enum.Font.GothamBold
    stageVal.TextXAlignment = Enum.TextXAlignment.Left
    stageVal.Parent = statsCard
    refs.StageVal = stageVal

    -- Replay setting
    local replaySetting = Instance.new("Frame")
    replaySetting.Size = UDim2.new(1, 0, 0, 34)
    replaySetting.Position = UDim2.new(0, 0, 0, 128)
    replaySetting.BackgroundColor3 = C.bgCard
    replaySetting.BorderSizePixel = 0
    replaySetting.Parent = farmPage
    corner(replaySetting, 8)

    local rpLabel = Instance.new("TextLabel")
    rpLabel.Size = UDim2.new(0.6, 0, 1, 0)
    rpLabel.Position = UDim2.new(0, 12, 0, 0)
    rpLabel.BackgroundTransparency = 1
    rpLabel.Text = "Replay per Stage"
    rpLabel.TextColor3 = C.text
    rpLabel.TextSize = 12
    rpLabel.Font = Enum.Font.GothamMedium
    rpLabel.TextXAlignment = Enum.TextXAlignment.Left
    rpLabel.Parent = replaySetting

    local rpMinus = Instance.new("TextButton")
    rpMinus.Size = UDim2.new(0, 26, 0, 26)
    rpMinus.Position = UDim2.new(1, -90, 0.5, -13)
    rpMinus.BackgroundColor3 = C.bgInput
    rpMinus.BorderSizePixel = 0
    rpMinus.Text = "-"
    rpMinus.TextColor3 = C.text
    rpMinus.TextSize = 16
    rpMinus.Font = Enum.Font.GothamBold
    rpMinus.Parent = replaySetting
    corner(rpMinus, 6)

    local rpValue = Instance.new("TextLabel")
    rpValue.Size = UDim2.new(0, 28, 0, 26)
    rpValue.Position = UDim2.new(1, -62, 0.5, -13)
    rpValue.BackgroundTransparency = 1
    rpValue.Text = "5"
    rpValue.TextColor3 = C.gold
    rpValue.TextSize = 15
    rpValue.Font = Enum.Font.GothamBold
    rpValue.Parent = replaySetting
    refs.RpValue = rpValue

    local rpPlus = Instance.new("TextButton")
    rpPlus.Size = UDim2.new(0, 26, 0, 26)
    rpPlus.Position = UDim2.new(1, -34, 0.5, -13)
    rpPlus.BackgroundColor3 = C.bgInput
    rpPlus.BorderSizePixel = 0
    rpPlus.Text = "+"
    rpPlus.TextColor3 = C.text
    rpPlus.TextSize = 16
    rpPlus.Font = Enum.Font.GothamBold
    rpPlus.Parent = replaySetting
    corner(rpPlus, 6)

    rpMinus.MouseButton1Click:Connect(function()
        farmReplaysPerStage = math.max(1, farmReplaysPerStage - 1)
        rpValue.Text = tostring(farmReplaysPerStage)
    end)
    rpPlus.MouseButton1Click:Connect(function()
        farmReplaysPerStage = math.min(10, farmReplaysPerStage + 1)
        rpValue.Text = tostring(farmReplaysPerStage)
    end)

    -- Farm log scroll
    local logTitle = Instance.new("TextLabel")
    logTitle.Size = UDim2.new(1, 0, 0, 18)
    logTitle.Position = UDim2.new(0, 0, 0, 168)
    logTitle.BackgroundTransparency = 1
    logTitle.Text = "📋 Farm Log"
    logTitle.TextColor3 = C.textDim
    logTitle.TextSize = 11
    logTitle.Font = Enum.Font.GothamMedium
    logTitle.TextXAlignment = Enum.TextXAlignment.Left
    logTitle.Parent = farmPage

    local farmScroll = Instance.new("ScrollingFrame")
    farmScroll.Name = "FarmScroll"
    farmScroll.Size = UDim2.new(1, 0, 1, -192)
    farmScroll.Position = UDim2.new(0, 0, 0, 188)
    farmScroll.BackgroundColor3 = C.bgCard
    farmScroll.BackgroundTransparency = 0.4
    farmScroll.BorderSizePixel = 0
    farmScroll.ScrollBarThickness = 3
    farmScroll.ScrollBarImageColor3 = C.cyan
    farmScroll.AutomaticCanvasSize = Enum.AutomaticSize.Y
    farmScroll.CanvasSize = UDim2.new(0, 0, 0, 0)
    farmScroll.Parent = farmPage
    corner(farmScroll, 8)
    refs.FarmScroll = farmScroll

    local farmLayout = Instance.new("UIListLayout")
    farmLayout.Padding = UDim.new(0, 2)
    farmLayout.SortOrder = Enum.SortOrder.LayoutOrder
    farmLayout.Parent = farmScroll

    local farmPad = Instance.new("UIPadding")
    farmPad.PaddingTop = UDim.new(0, 4)
    farmPad.PaddingLeft = UDim.new(0, 6)
    farmPad.PaddingRight = UDim.new(0, 6)
    farmPad.Parent = farmScroll

    local farmNoLog = Instance.new("TextLabel")
    farmNoLog.Name = "FarmNoLog"
    farmNoLog.Size = UDim2.new(1, 0, 0, 30)
    farmNoLog.BackgroundTransparency = 1
    farmNoLog.Text = "Tekan toggle untuk mulai farming..."
    farmNoLog.TextColor3 = C.textMuted
    farmNoLog.TextSize = 11
    farmNoLog.Font = Enum.Font.Gotham
    farmNoLog.Parent = farmScroll
    refs.FarmNoLog = farmNoLog

    -- ── TAB SWITCHING ───────────────────────
    local function switchTab(id)
        activeTab = id
        flyPage.Visible  = (id == "fly")
        luckPage.Visible = (id == "luck")
        farmPage.Visible = (id == "farm")
        for tid, btn in pairs(tabButtons) do
            if tid == id then
                tween(btn, {BackgroundColor3 = C.accent, BackgroundTransparency = 0}):Play()
                btn.TextColor3 = C.white
            else
                tween(btn, {BackgroundTransparency = 1}):Play()
                btn.TextColor3 = C.textDim
            end
        end
    end

    for id, btn in pairs(tabButtons) do
        btn.MouseButton1Click:Connect(function() switchTab(id) end)
    end

    -- ── BOTTOM CREDIT ───────────────────────
    local credit = Instance.new("TextLabel")
    credit.Size = UDim2.new(1, 0, 0, 16)
    credit.Position = UDim2.new(0, 0, 1, -18)
    credit.BackgroundTransparency = 1
    credit.Text = "Blox-Scripts • RightShift to toggle"
    credit.TextColor3 = C.textMuted
    credit.TextSize = 9
    credit.Font = Enum.Font.Gotham
    credit.Parent = main

    -- ── MINI LUCK BADGE (selalu terlihat) ────
    local miniBadge = Instance.new("Frame")
    miniBadge.Name = "MiniBadge"
    miniBadge.Size = UDim2.new(0, 140, 0, 32)
    miniBadge.Position = UDim2.new(1, -155, 0, 12)
    miniBadge.BackgroundColor3 = Color3.fromRGB(15, 15, 25)
    miniBadge.BackgroundTransparency = 0.1
    miniBadge.BorderSizePixel = 0
    miniBadge.Active = true
    miniBadge.Draggable = true
    miniBadge.Parent = sg
    corner(miniBadge, 16)
    stroke(miniBadge, C.orange, 1.5, 0.3)
    refs.MiniBadge = miniBadge

    local miniIcon = Instance.new("TextLabel")
    miniIcon.Size = UDim2.new(0, 26, 1, 0)
    miniIcon.Position = UDim2.new(0, 6, 0, 0)
    miniIcon.BackgroundTransparency = 1
    miniIcon.Text = "🍀"
    miniIcon.TextSize = 16
    miniIcon.Parent = miniBadge

    local miniVal = Instance.new("TextLabel")
    miniVal.Name = "MiniVal"
    miniVal.Size = UDim2.new(1, -36, 1, 0)
    miniVal.Position = UDim2.new(0, 32, 0, 0)
    miniVal.BackgroundTransparency = 1
    miniVal.Text = "—"
    miniVal.TextColor3 = C.gold
    miniVal.TextSize = 14
    miniVal.Font = Enum.Font.GothamBold
    miniVal.TextXAlignment = Enum.TextXAlignment.Left
    miniVal.TextTruncate = Enum.TextTruncate.AtEnd
    miniVal.Parent = miniBadge
    refs.MiniVal = miniVal

    return tabButtons, flyPage, luckPage
end

-- ============================================
-- FLY MECHANICS
-- ============================================
local function startFlying()
    local ch = player.Character
    if not ch then return end
    local hum = ch:FindFirstChildOfClass("Humanoid")
    local root = ch:FindFirstChild("HumanoidRootPart")
    if not hum or not root then return end

    bodyGyro = Instance.new("BodyGyro")
    bodyGyro.P = 9e4
    bodyGyro.MaxTorque = Vector3.new(9e9,9e9,9e9)
    bodyGyro.CFrame = root.CFrame
    bodyGyro.Parent = root

    bodyVelocity = Instance.new("BodyVelocity")
    bodyVelocity.Velocity = Vector3.zero
    bodyVelocity.MaxForce = Vector3.new(9e9,9e9,9e9)
    bodyVelocity.Parent = root

    hum.PlatformStand = true

    flyConnection = RunService.RenderStepped:Connect(function()
        if not flying then return end
        if not ch or not ch.Parent then return end
        root = ch:FindFirstChild("HumanoidRootPart")
        if not root then return end

        local cam = workspace.CurrentCamera
        local dir = Vector3.zero
        local KD = function(k) return UserInputService:IsKeyDown(k) end

        if KD(Enum.KeyCode.W) or KD(Enum.KeyCode.Up)    then dir = dir + cam.CFrame.LookVector end
        if KD(Enum.KeyCode.S) or KD(Enum.KeyCode.Down)  then dir = dir - cam.CFrame.LookVector end
        if KD(Enum.KeyCode.A) or KD(Enum.KeyCode.Left)  then dir = dir - cam.CFrame.RightVector end
        if KD(Enum.KeyCode.D) or KD(Enum.KeyCode.Right) then dir = dir + cam.CFrame.RightVector end
        if KD(Enum.KeyCode.Space)      then dir = dir + Vector3.new(0,1,0) end
        if KD(Enum.KeyCode.LeftShift) or KD(Enum.KeyCode.RightShift) then dir = dir - Vector3.new(0,1,0) end

        if dir.Magnitude > 0 then dir = dir.Unit end
        bodyVelocity.Velocity = dir * flySpeed
        bodyGyro.CFrame = cam.CFrame
    end)
end

local function stopFlying()
    local ch = player.Character
    if ch then
        local hum = ch:FindFirstChildOfClass("Humanoid")
        if hum then hum.PlatformStand = false end
    end
    if bodyGyro then bodyGyro:Destroy(); bodyGyro = nil end
    if bodyVelocity then bodyVelocity:Destroy(); bodyVelocity = nil end
    if flyConnection then flyConnection:Disconnect(); flyConnection = nil end
end

local function toggleFly()
    flying = not flying
    if flying then
        tween(refs.FlyToggleBg, {BackgroundColor3 = C.accent}):Play()
        tween(refs.FlyToggleKnob, {Position = UDim2.new(1, -24, 0.5, -11), BackgroundColor3 = C.white}):Play()
        refs.FlyStatus.Text = "Status: ✈ TERBANG"
        refs.FlyStatus.TextColor3 = C.green
        startFlying()
    else
        tween(refs.FlyToggleBg, {BackgroundColor3 = C.bgInput}):Play()
        tween(refs.FlyToggleKnob, {Position = UDim2.new(0, 2, 0.5, -11), BackgroundColor3 = C.textDim}):Play()
        refs.FlyStatus.Text = "Status: OFF"
        refs.FlyStatus.TextColor3 = C.red
        stopFlying()
    end
end

-- ============================================
-- LUCK SCANNER
-- ============================================
local function updateHistoryGUI()
    for _, c in ipairs(refs.HistScroll:GetChildren()) do
        if c:IsA("Frame") then c:Destroy() end
    end
    if #luckHistory > 0 then refs.NoHist.Visible = false end

    for i, e in ipairs(luckHistory) do
        local row = Instance.new("Frame")
        row.Size = UDim2.new(1, 0, 0, 22)
        row.BackgroundColor3 = C.bgCard
        row.BackgroundTransparency = 0.3
        row.BorderSizePixel = 0
        row.LayoutOrder = i
        row.Parent = refs.HistScroll
        corner(row, 4)

        local t = Instance.new("TextLabel")
        t.Size = UDim2.new(0, 52, 1, 0)
        t.Position = UDim2.new(0, 4, 0, 0)
        t.BackgroundTransparency = 1
        t.Text = e.time
        t.TextColor3 = C.textMuted
        t.TextSize = 10
        t.Font = Enum.Font.Code
        t.TextXAlignment = Enum.TextXAlignment.Left
        t.Parent = row

        local v = Instance.new("TextLabel")
        v.Size = UDim2.new(0, 55, 1, 0)
        v.Position = UDim2.new(0, 56, 0, 0)
        v.BackgroundTransparency = 1
        v.Text = e.value
        v.TextColor3 = C.gold
        v.TextSize = 11
        v.Font = Enum.Font.GothamBold
        v.TextXAlignment = Enum.TextXAlignment.Left
        v.Parent = row

        local s = Instance.new("TextLabel")
        s.Size = UDim2.new(1, -116, 1, 0)
        s.Position = UDim2.new(0, 114, 0, 0)
        s.BackgroundTransparency = 1
        s.Text = e.source
        s.TextColor3 = C.textMuted
        s.TextSize = 9
        s.Font = Enum.Font.Gotham
        s.TextXAlignment = Enum.TextXAlignment.Right
        s.TextTruncate = Enum.TextTruncate.AtEnd
        s.Parent = row
    end
end

local function flashLuck(old, new)
    local flash = Instance.new("Frame")
    flash.Size = UDim2.new(1, 0, 1, 0)
    flash.BackgroundColor3 = C.gold
    flash.BackgroundTransparency = 0.85
    flash.BorderSizePixel = 0
    flash.ZIndex = 10
    flash.Parent = refs.Main
    corner(flash, 14)
    tween(flash, {BackgroundTransparency = 1}, 0.7):Play()
    task.delay(0.7, function() flash:Destroy() end)

    tween(refs.LuckVal, {TextColor3 = C.green, TextSize = 26}, 0.15):Play()
    task.delay(0.3, function()
        tween(refs.LuckVal, {TextColor3 = C.gold, TextSize = 22}, 0.3):Play()
    end)
end

local function connectLuckChanged(obj, attrName, isAttribute)
    if isAttribute then
        local target = obj
        target:GetAttributeChangedSignal(attrName):Connect(function()
            local old = currentLuck
            currentLuck = tostring(target:GetAttribute(attrName))
            refs.LuckVal.Text = "🍀 " .. currentLuck
            refs.MiniVal.Text = currentLuck
            addToHistory(currentLuck, "Dari " .. old)
            updateHistoryGUI()
            flashLuck(old, currentLuck)
        end)
    else
        obj.Changed:Connect(function(val)
            local old = currentLuck
            currentLuck = tostring(val)
            refs.LuckVal.Text = "🍀 " .. currentLuck
            refs.MiniVal.Text = currentLuck
            addToHistory(currentLuck, "Dari " .. old)
            updateHistoryGUI()
            flashLuck(old, currentLuck)
        end)
    end
end

local function scanForLuck()
    refs.ScanTxt.Text = "Sedang scanning..."
    refs.ScanDot.BackgroundColor3 = C.orange
    refs.LuckVal.Text = "Scanning..."

    local kw = {"luck","lucky","fortune","lck","multiplier","mult","boost","bonus","chance","rarity"}
    local found = false

    -- 1) leaderstats
    local ls = player:FindFirstChild("leaderstats")
    if ls then
        for _, st in ipairs(ls:GetChildren()) do
            for _, k in ipairs(kw) do
                if st.Name:lower():find(k) then
                    currentLuck = tostring(st.Value)
                    luckSource = "leaderstats." .. st.Name
                    luckValueObj = st
                    connectLuckChanged(st)
                    found = true; break
                end
            end
            if found then break end
        end
    end

    -- 2) Player attributes
    if not found then
        for name, val in pairs(player:GetAttributes()) do
            for _, k in ipairs(kw) do
                if name:lower():find(k) then
                    currentLuck = tostring(val)
                    luckSource = "Attribute: " .. name
                    connectLuckChanged(player, name, true)
                    found = true; break
                end
            end
            if found then break end
        end
    end

    -- 3) Character attributes
    if not found and player.Character then
        for name, val in pairs(player.Character:GetAttributes()) do
            for _, k in ipairs(kw) do
                if name:lower():find(k) then
                    currentLuck = tostring(val)
                    luckSource = "Char Attr: " .. name
                    connectLuckChanged(player.Character, name, true)
                    found = true; break
                end
            end
            if found then break end
        end
    end

    -- 4) ReplicatedStorage deep scan
    if not found then
        for _, r in ipairs(deepSearch(ReplicatedStorage, kw, 0, 4)) do
            if r.object:IsA("ValueBase") then
                currentLuck = tostring(r.object.Value)
                luckSource = r.path
                luckValueObj = r.object
                connectLuckChanged(r.object)
                found = true; break
            end
        end
    end

    -- 5) Player children deep scan
    if not found then
        for _, r in ipairs(deepSearch(player, kw, 0, 4)) do
            if r.object:IsA("ValueBase") then
                currentLuck = tostring(r.object.Value)
                luckSource = r.path
                luckValueObj = r.object
                connectLuckChanged(r.object)
                found = true; break
            end
        end
    end

    -- 6) PlayerGui text scan
    if not found then
        local pg = player:FindFirstChild("PlayerGui")
        if pg then
            for _, r in ipairs(deepSearch(pg, kw, 0, 6)) do
                if r.object:IsA("TextLabel") and r.object.Text ~= "" then
                    currentLuck = r.object.Text
                    luckSource = "GUI: " .. r.name
                    r.object:GetPropertyChangedSignal("Text"):Connect(function()
                        local old = currentLuck
                        currentLuck = r.object.Text
                        refs.LuckVal.Text = "🍀 " .. currentLuck
                        refs.MiniVal.Text = currentLuck
                        addToHistory(currentLuck, "GUI update")
                        updateHistoryGUI()
                    end)
                    found = true; break
                end
            end
        end
    end

    -- Result
    if found then
        refs.LuckVal.Text = "🍀 " .. currentLuck
        refs.MiniVal.Text = currentLuck
        refs.LuckSrc.Text = "Sumber: " .. luckSource
        refs.ScanTxt.Text = "✅ Luck ditemukan!"
        refs.ScanDot.BackgroundColor3 = C.green
        addToHistory(currentLuck, "Scan awal")
        updateHistoryGUI()
        tween(refs.LuckVal, {TextColor3 = C.green}, 0.3):Play()
        task.wait(0.4)
        tween(refs.LuckVal, {TextColor3 = C.gold}, 0.3):Play()
    else
        refs.LuckVal.Text = "❌ Tidak ditemukan"
        refs.LuckVal.TextSize = 15
        refs.MiniVal.Text = "N/A"
        refs.LuckSrc.Text = "Luck mungkin server-side"
        refs.ScanTxt.Text = "⚠ Tidak terdeteksi"
        refs.ScanDot.BackgroundColor3 = C.red
    end
end

-- ============================================
-- INIT
-- ============================================
buildHub()

-- Entrance
refs.Main.Position = UDim2.new(0.5, -150, -0.3, 0)
tween(refs.Main, {Position = UDim2.new(0.5, -150, 0.5, -230)}, 0.55, Enum.EasingStyle.Back, Enum.EasingDirection.Out):Play()

-- Fly toggle
refs.FlyToggleBtn.MouseButton1Click:Connect(toggleFly)

-- Rescan
refs.RescanBtn.MouseButton1Click:Connect(function()
    luckValueObj = nil
    scanForLuck()
end)

-- ============================================
-- AUTO MONITOR TOGGLE + LOOP
-- ============================================
local function toggleMonitor()
    monitoring = not monitoring
    if monitoring then
        tween(refs.MonToggleBg, {BackgroundColor3 = C.green}):Play()
        tween(refs.MonToggleKnob, {Position = UDim2.new(1, -22, 0.5, -10), BackgroundColor3 = C.white}):Play()
        refs.ScanTxt.Text = "🔁 Monitoring aktif (0.2s)"
        refs.ScanTxt.TextColor3 = C.green
        refs.ScanDot.BackgroundColor3 = C.green
    else
        tween(refs.MonToggleBg, {BackgroundColor3 = C.bgInput}):Play()
        tween(refs.MonToggleKnob, {Position = UDim2.new(0, 2, 0.5, -10), BackgroundColor3 = C.textDim}):Play()
        refs.ScanTxt.Text = "Monitor dihentikan"
        refs.ScanTxt.TextColor3 = C.orange
    end
end

refs.MonToggleBtn.MouseButton1Click:Connect(toggleMonitor)

-- Continuous monitoring loop (0.2s interval)
task.spawn(function()
    while true do
        if monitoring and luckValueObj then
            local newVal
            -- Baca value berdasarkan tipe objek
            local ok, result = pcall(function()
                if luckValueObj:IsA("ValueBase") then
                    return tostring(luckValueObj.Value)
                elseif luckValueObj:IsA("TextLabel") then
                    return luckValueObj.Text
                else
                    return tostring(luckValueObj.Value)
                end
            end)

            if ok and result then
                newVal = result
            end

            -- Jika value berubah
            if newVal and newVal ~= currentLuck then
                local old = currentLuck
                currentLuck = newVal
                refs.LuckVal.Text = "🍀 " .. currentLuck
                refs.MiniVal.Text = currentLuck
                addToHistory(currentLuck, "Dari " .. old)
                updateHistoryGUI()

                -- Flash mini badge
                tween(refs.MiniVal, {TextColor3 = C.green}, 0.1):Play()
                task.delay(0.3, function()
                    tween(refs.MiniVal, {TextColor3 = C.gold}, 0.2):Play()
                end)
            end

            task.wait(0.2)
        elseif monitoring and not luckValueObj then
            -- Belum ada objek, coba scan dulu
            scanForLuck()
            task.wait(1)
        else
            task.wait(0.5)
        end
    end
end)

-- ============================================
-- AUTO FARM SYSTEM
-- ============================================
local farmLogOrder = 0

local function addFarmLog(msg, color)
    farmLogOrder = farmLogOrder + 1
    refs.FarmNoLog.Visible = false
    
    local row = Instance.new("Frame")
    row.Size = UDim2.new(1, 0, 0, 20)
    row.BackgroundColor3 = C.bgCard
    row.BackgroundTransparency = 0.3
    row.BorderSizePixel = 0
    row.LayoutOrder = farmLogOrder
    row.Parent = refs.FarmScroll
    corner(row, 4)

    local t = Instance.new("TextLabel")
    t.Size = UDim2.new(0, 50, 1, 0)
    t.Position = UDim2.new(0, 4, 0, 0)
    t.BackgroundTransparency = 1
    t.Text = os.date("%H:%M:%S")
    t.TextColor3 = C.textMuted
    t.TextSize = 9
    t.Font = Enum.Font.Code
    t.TextXAlignment = Enum.TextXAlignment.Left
    t.Parent = row

    local m = Instance.new("TextLabel")
    m.Size = UDim2.new(1, -58, 1, 0)
    m.Position = UDim2.new(0, 54, 0, 0)
    m.BackgroundTransparency = 1
    m.Text = msg
    m.TextColor3 = color or C.text
    m.TextSize = 10
    m.Font = Enum.Font.Gotham
    m.TextXAlignment = Enum.TextXAlignment.Left
    m.TextTruncate = Enum.TextTruncate.AtEnd
    m.Parent = row
end

-- Cari tombol di PlayerGui berdasarkan keywords (generic)
local function findButton(keywords)
    local pg = player:FindFirstChild("PlayerGui")
    if not pg then return nil end
    
    local results = deepSearch(pg, keywords, 0, 8)
    for _, r in ipairs(results) do
        if r.object:IsA("TextButton") or r.object:IsA("ImageButton") then
            local visible = r.object.Visible
            if visible then
                local parent = r.object.Parent
                while parent and parent:IsA("GuiObject") do
                    if not parent.Visible then
                        visible = false
                        break
                    end
                    parent = parent.Parent
                end
            end
            if visible then
                return r.object, r.name
            end
        end
    end
    return nil, nil
end

-- Navigate ke RoundEnd > Frame (shared helper)
local function getRoundEndFrame()
    local pg = player:FindFirstChild("PlayerGui")
    if not pg then return nil end
    for _, gui in ipairs(pg:GetChildren()) do
        if gui:IsA("ScreenGui") then
            local roundEnd = gui:FindFirstChild("RoundEnd", true)
            if roundEnd then
                local frame = roundEnd:FindFirstChild("Frame")
                if frame then return frame end
            end
        end
    end
    return nil
end

-- Ambil tombol exact dari RoundEnd > Frame > Contents > ButtonsHolder > Buttons
local function getRestartButton()
    local frame = getRoundEndFrame()
    if not frame then return nil end
    local contents = frame:FindFirstChild("Contents")
    if not contents then return nil end
    local holder = contents:FindFirstChild("ButtonsHolder")
    if not holder then return nil end
    local buttons = holder:FindFirstChild("Buttons")
    if not buttons then return nil end
    return buttons:FindFirstChild("RestartButton")
end

local function getNextStageButton()
    local frame = getRoundEndFrame()
    if not frame then return nil end
    local contents = frame:FindFirstChild("Contents")
    if not contents then return nil end
    local holder = contents:FindFirstChild("ButtonsHolder")
    if not holder then return nil end
    local buttons = holder:FindFirstChild("Buttons")
    if not buttons then return nil end
    return buttons:FindFirstChild("NextStageButton")
end

-- Baca EntriesLeft → "4 daily rewards left for..." → return angka
local function getEntriesLeft()
    local frame = getRoundEndFrame()
    if not frame then return nil end
    local contents = frame:FindFirstChild("Contents")
    if not contents then return nil end
    local entriesLeft = contents:FindFirstChild("EntriesLeft")
    if not entriesLeft then return nil end
    if entriesLeft:IsA("TextLabel") then
        local text = entriesLeft.Text
        local num = text:match("(%d+)")
        if num then return tonumber(num), text end
    end
    return nil
end

-- Cek apakah RoundEnd visible (multi-signal)
local function isRoundEndVisible()
    local frame = getRoundEndFrame()
    if not frame then return false end
    
    -- Signal 1: Cek Visible property
    local visCheck = true
    local current = frame
    while current and current:IsA("GuiObject") do
        if not current.Visible then visCheck = false; break end
        current = current.Parent
    end
    if visCheck then return true end
    
    -- Signal 2: RestartButton atau NextStageButton ada & visible (tombol hanya ada saat RoundEnd muncul)
    local restartBtn = getRestartButton()
    if restartBtn and restartBtn.Visible then return true end
    local nextBtn = getNextStageButton()
    if nextBtn and nextBtn.Visible then return true end
    
    -- Signal 3: EntriesLeft punya teks (hanya ada saat RoundEnd)
    local entries, txt = getEntriesLeft()
    if entries ~= nil then return true end
    
    return false
end

-- Tunggu RoundEnd muncul
local function waitForRoundEnd(timeout, statusMsg)
    timeout = timeout or 180
    local elapsed = 0
    local lastDebugAt = 0
    while farming and elapsed < timeout do
        if isRoundEndVisible() then return true end
        if statusMsg then
            refs.FarmStatus.Text = statusMsg .. " (" .. elapsed .. "s)"
        end
        -- Debug log setiap 15 detik
        if elapsed - lastDebugAt >= 15 then
            lastDebugAt = elapsed
            local frame = getRoundEndFrame()
            if frame then
                addFarmLog("⏳ Frame ada, tunggu visible... (" .. elapsed .. "s)", C.textDim)
            end
        end
        task.wait(1)
        elapsed = elapsed + 1
    end
    return false
end

-- Tunggu tombol generic muncul (untuk Start/Ready)
local function waitForButton(keywords, timeout, statusMsg)
    timeout = timeout or 60
    local elapsed = 0
    while farming and elapsed < timeout do
        local btn, name = findButton(keywords)
        if btn then return btn, name end
        if statusMsg then
            refs.FarmStatus.Text = statusMsg .. " (" .. elapsed .. "s)"
        end
        task.wait(1)
        elapsed = elapsed + 1
    end
    return nil, nil
end

-- Klik tombol secara programmatik (multi-method)
local function clickButton(btn)
    if not btn then return false end
    
    local clicked = false
    
    -- Method 1: firesignal (paling reliable di banyak executor)
    pcall(function()
        if firesignal then
            firesignal(btn.MouseButton1Click)
            clicked = true
        end
    end)
    
    -- Method 2: firesignal Activated
    pcall(function()
        if firesignal and btn.Activated then
            firesignal(btn.Activated)
            clicked = true
        end
    end)
    
    -- Method 3: Fire event langsung
    pcall(function()
        btn.MouseButton1Click:Fire()
        clicked = true
    end)
    
    -- Method 4: Simulate mouse down + up
    pcall(function()
        btn.MouseButton1Down:Fire()
        task.wait(0.05)
        btn.MouseButton1Up:Fire()
        clicked = true
    end)
    
    -- Method 5: Virtual Input (HANYA jika posisi valid — cegah klik di taskbar)
    pcall(function()
        local VIM = game:GetService("VirtualInputManager")
        local pos = btn.AbsolutePosition
        local size = btn.AbsoluteSize
        local cx = pos.X + size.X / 2
        local cy = pos.Y + size.Y / 2
        -- Safety: jangan klik jika posisi di (0,0) atau terlalu kecil
        if cx > 10 and cy > 10 and size.X > 5 and size.Y > 5 then
            VIM:SendMouseButtonEvent(cx, cy, 0, true, game, 1)
            task.wait(0.05)
            VIM:SendMouseButtonEvent(cx, cy, 0, false, game, 1)
            clicked = true
        end
    end)
    
    -- Method 6: fireproximityprompt / click detector fallback
    pcall(function()
        if fireclickdetector then
            fireclickdetector(btn)
            clicked = true
        end
    end)
    
    return clicked
end

local function toggleFarm()
    farming = not farming
    if farming then
        tween(refs.FarmToggleBg, {BackgroundColor3 = C.green}):Play()
        tween(refs.FarmToggleKnob, {Position = UDim2.new(1, -24, 0.5, -11), BackgroundColor3 = C.white}):Play()
        refs.FarmStatus.Text = "Status: ⚔ FARMING"
        refs.FarmStatus.TextColor3 = C.green
        farmCurrentReplay = 0
        addFarmLog("▶ Farm dimulai!", C.green)
        
        -- Debug: cek EntriesLeft
        local entries, txt = getEntriesLeft()
        if entries then
            addFarmLog("📋 EntriesLeft: " .. entries .. " (" .. txt .. ")", C.gold)
        else
            addFarmLog("ℹ EntriesLeft belum tersedia", C.textDim)
        end
    else
        tween(refs.FarmToggleBg, {BackgroundColor3 = C.bgInput}):Play()
        tween(refs.FarmToggleKnob, {Position = UDim2.new(0, 2, 0.5, -11), BackgroundColor3 = C.textDim}):Play()
        refs.FarmStatus.Text = "Status: STOPPED"
        refs.FarmStatus.TextColor3 = C.red
        addFarmLog("⏹ Farm dihentikan", C.red)
    end
end

refs.FarmToggleBtn.MouseButton1Click:Connect(toggleFarm)

-- Auto farm ON saat inisialisasi (berguna setelah teleport)
task.delay(1.5, function()
    if not farming then
        toggleFarm()
        addFarmLog("🤖 Auto Farm ON (init)", C.green)
    end
end)

-- ============================================
-- MAIN FARM LOOP
-- Exact paths from game:
--   RestartButton: RoundEnd > Frame > Contents > ButtonsHolder > Buttons > RestartButton
--   NextStageButton: RoundEnd > Frame > Contents > ButtonsHolder > Buttons > NextStageButton
--   EntriesLeft: RoundEnd > Frame > Contents > EntriesLeft ("X daily rewards left...")
-- ============================================
task.spawn(function()
    local isFirstRun = true

    while true do
        if not farming then
            task.wait(0.5)
            isFirstRun = true
            continue
        end

        -- ════════════════════════════════════
        -- STEP 1: Tombol Start (hanya pertama kali)
        -- ════════════════════════════════════
        if isFirstRun then
            refs.FarmStatus.Text = "Status: Mencari Start..."
            refs.FarmStatus.TextColor3 = C.orange

            local startBtn, startName = findButton({"start", "play", "enter", "mulai", "battle"})
            if startBtn then
                addFarmLog("🎮 Start: " .. startName, C.cyan)
                clickButton(startBtn)
                task.wait(2)
            else
                addFarmLog("ℹ Start tidak ada (sudah di stage)", C.textDim)
            end
            isFirstRun = false
        end

        if not farming then continue end

        -- ════════════════════════════════════
        -- STEP 2: Tombol Ready
        -- ════════════════════════════════════
        refs.FarmStatus.Text = "Status: Mencari Ready..."
        refs.FarmStatus.TextColor3 = C.orange

        local readyBtn, readyName = waitForButton(
            {"ready", "siap", "go", "fight", "confirm"},
            30,
            "Mencari Ready..."
        )

        if readyBtn and farming then
            addFarmLog("✅ Ready: " .. readyName, C.green)
            clickButton(readyBtn)
            task.wait(2)
        elseif farming then
            addFarmLog("⚠ Ready tidak ditemukan, lanjut...", C.orange)
        end

        if not farming then continue end

        -- ════════════════════════════════════
        -- STEP 3: Tunggu Battle Selesai (RoundEnd muncul)
        -- ════════════════════════════════════
        refs.FarmStatus.Text = "Status: ⚔ Battle..."
        refs.FarmStatus.TextColor3 = C.gold

        local roundEndAppeared = waitForRoundEnd(180, "⚔ Battle...")

        if not farming then continue end

        if roundEndAppeared then
            task.wait(1.5) -- tunggu animasi RoundEnd

            farmCurrentReplay = farmCurrentReplay + 1
            farmTotalReplays = farmTotalReplays + 1
            addFarmLog("⚔ Battle selesai! (#" .. farmCurrentReplay .. ")", C.green)

            -- ════════════════════════════════════
            -- STEP 4: Baca EntriesLeft (reward tersisa)
            -- ════════════════════════════════════
            local entriesLeft, entriesText = getEntriesLeft()
            
            if entriesLeft then
                addFarmLog("📦 Entries left: " .. entriesLeft .. " — " .. entriesText, C.gold)
                refs.ReplayVal.Text = entriesLeft .. " left"
            else
                -- Fallback counter manual
                local remaining = farmReplaysPerStage - farmCurrentReplay
                addFarmLog("📦 Counter: " .. remaining .. " tersisa (manual)", C.gold)
                refs.ReplayVal.Text = farmCurrentReplay .. " / " .. farmReplaysPerStage
            end

            task.wait(0.5)

            -- ════════════════════════════════════
            -- STEP 5: Keputusan → Retry atau Next
            -- ════════════════════════════════════
            local shouldNext = false
            
            if entriesLeft then
                -- Pakai EntriesLeft dari game
                shouldNext = (entriesLeft <= 0)
            else
                -- Fallback: pakai counter manual
                shouldNext = (farmCurrentReplay >= farmReplaysPerStage)
            end

            if shouldNext then
                -- ── NEXT STAGE ──
                addFarmLog("🔄 Reward habis → Next Stage", C.gold)
                task.wait(1)

                local nextBtn = getNextStageButton()
                if nextBtn then
                    clickButton(nextBtn)
                    addFarmLog("➡ Klik NextStageButton!", C.cyan)
                    farmTotalStages = farmTotalStages + 1
                    refs.StageVal.Text = tostring(farmTotalStages)
                else
                    -- Fallback generic
                    local btn, name = findButton({"next", "continue", "lanjut"})
                    if btn then
                        clickButton(btn)
                        addFarmLog("➡ Next (fallback): " .. name, C.cyan)
                        farmTotalStages = farmTotalStages + 1
                        refs.StageVal.Text = tostring(farmTotalStages)
                    else
                        addFarmLog("⚠ NextStageButton tidak ditemukan!", C.red)
                    end
                end

                farmCurrentReplay = 0
                refs.ReplayVal.Text = "0"
                task.wait(3) -- tunggu transisi stage
            else
                -- ── RESTART/RETRY ──
                local restartBtn = getRestartButton()
                if restartBtn then
                    clickButton(restartBtn)
                    addFarmLog("🔁 Klik RestartButton!", C.cyan)
                else
                    -- Fallback generic
                    local btn, name = findButton({"restart", "retry", "replay", "again"})
                    if btn then
                        clickButton(btn)
                        addFarmLog("🔁 Restart (fallback): " .. name, C.cyan)
                    else
                        addFarmLog("⚠ RestartButton tidak ditemukan!", C.red)
                    end
                end

                task.wait(2)
            end
        else
            addFarmLog("⚠ Timeout (3min), retry...", C.orange)
            task.wait(2)
        end

        task.wait(1)
    end
end)

-- Keybinds
UserInputService.InputBegan:Connect(function(inp, gpe)
    if gpe then return end
    if inp.KeyCode == Enum.KeyCode.F then
        toggleFly()
    elseif inp.KeyCode == Enum.KeyCode.RightShift then
        hubVisible = not hubVisible
        if hubVisible then
            tween(refs.Main, {Position = UDim2.new(0.5, -150, 0.5, -230)}, 0.4, Enum.EasingStyle.Back, Enum.EasingDirection.Out):Play()
        else
            tween(refs.Main, {Position = UDim2.new(0.5, -150, 1.1, 0)}, 0.4, Enum.EasingStyle.Back, Enum.EasingDirection.In):Play()
        end
    end
end)

-- Respawn handler
player.CharacterAdded:Connect(function(ch)
    ch:WaitForChild("HumanoidRootPart")
    task.wait(0.5)
    if flying then startFlying() end
    task.wait(1.5)
    scanForLuck()
end)

-- Initial luck scan
task.delay(1.5, function()
    scanForLuck()
    task.spawn(function()
        while task.wait(10) do
            if not monitoring and not luckValueObj and refs.LuckVal.Text:find("Tidak ditemukan") then
                scanForLuck()
            end
        end
    end)
end)

-- Scan dot pulse
task.spawn(function()
    while true do
        if monitoring then
            tween(refs.ScanDot, {BackgroundTransparency = 0.5}, 0.2):Play(); task.wait(0.2)
            tween(refs.ScanDot, {BackgroundTransparency = 0}, 0.2):Play(); task.wait(0.2)
        elseif refs.ScanDot.BackgroundColor3 == C.orange then
            tween(refs.ScanDot, {BackgroundTransparency = 0.5}, 0.5):Play(); task.wait(0.5)
            tween(refs.ScanDot, {BackgroundTransparency = 0}, 0.5):Play(); task.wait(0.5)
        else
            task.wait(1)
        end
    end
end)

print("═══════════════════════════════════════")
print("  ⚡ BLOX HUB v1.1 Loaded!")
print("  ✈  F          = Toggle Fly")
print("  🍀 Auto-scan  = Luck Detector")
print("  🔁 Monitor    = 0.2s Interval")
print("  ⚔  Farm       = Auto Replay")
print("  👁  RightShift = Show/Hide Hub")
print("  🚀 Teleport   = Auto re-execute")
print("═══════════════════════════════════════")
