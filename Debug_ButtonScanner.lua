--[[
    ╔══════════════════════════════════════════════╗
    ║    BUTTON DEBUGGER - Summon Hero             ║
    ║    Scan semua tombol di PlayerGui             ║
    ║    Blox-Scripts by Jokskuyy                  ║
    ╚══════════════════════════════════════════════╝
    
    Cara pakai:
    1. Execute script ini di game
    2. GUI akan muncul di kiri bawah
    3. Klik SCAN untuk scan semua tombol yang VISIBLE
    4. Auto-scan berjalan setiap 2 detik
    5. Copy nama-nama tombol yang muncul
    6. Tekan L untuk toggle show/hide
]]

local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local TweenService = game:GetService("TweenService")

local player = Players.LocalPlayer
local autoScan = false
local scanInterval = 2

-- ============================================
-- GUI
-- ============================================
if player.PlayerGui:FindFirstChild("BtnDebugger") then
    player.PlayerGui:FindFirstChild("BtnDebugger"):Destroy()
end

local sg = Instance.new("ScreenGui")
sg.Name = "BtnDebugger"
sg.ResetOnSpawn = false
sg.DisplayOrder = 1000
sg.Parent = player.PlayerGui

local main = Instance.new("Frame")
main.Size = UDim2.new(0, 380, 0, 500)
main.Position = UDim2.new(0, 15, 1, -515)
main.BackgroundColor3 = Color3.fromRGB(10, 10, 18)
main.BackgroundTransparency = 0.03
main.BorderSizePixel = 0
main.Active = true
main.Draggable = true
main.ClipsDescendants = true
main.Parent = sg

local corner = Instance.new("UICorner")
corner.CornerRadius = UDim.new(0, 12)
corner.Parent = main

local stroke = Instance.new("UIStroke")
stroke.Color = Color3.fromRGB(255, 100, 100)
stroke.Thickness = 2
stroke.Transparency = 0.3
stroke.Parent = main

-- Title
local title = Instance.new("TextLabel")
title.Size = UDim2.new(1, -20, 0, 24)
title.Position = UDim2.new(0, 10, 0, 8)
title.BackgroundTransparency = 1
title.Text = "🔍 BUTTON DEBUGGER"
title.TextColor3 = Color3.fromRGB(255, 120, 120)
title.TextSize = 15
title.Font = Enum.Font.GothamBold
title.TextXAlignment = Enum.TextXAlignment.Left
title.Parent = main

local subtitle = Instance.new("TextLabel")
subtitle.Size = UDim2.new(1, -20, 0, 14)
subtitle.Position = UDim2.new(0, 10, 0, 30)
subtitle.BackgroundTransparency = 1
subtitle.Text = "Tekan L untuk show/hide • Scan semua tombol visible"
subtitle.TextColor3 = Color3.fromRGB(100, 100, 130)
subtitle.TextSize = 10
subtitle.Font = Enum.Font.Gotham
subtitle.TextXAlignment = Enum.TextXAlignment.Left
subtitle.Parent = main

-- Scan button
local scanBtn = Instance.new("TextButton")
scanBtn.Size = UDim2.new(0.48, 0, 0, 28)
scanBtn.Position = UDim2.new(0, 10, 0, 50)
scanBtn.BackgroundColor3 = Color3.fromRGB(255, 80, 80)
scanBtn.BorderSizePixel = 0
scanBtn.Text = "🔍 SCAN NOW"
scanBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
scanBtn.TextSize = 12
scanBtn.Font = Enum.Font.GothamBold
scanBtn.Parent = main

local scanCorner = Instance.new("UICorner")
scanCorner.CornerRadius = UDim.new(0, 6)
scanCorner.Parent = scanBtn

-- Auto scan toggle
local autoBtn = Instance.new("TextButton")
autoBtn.Size = UDim2.new(0.48, 0, 0, 28)
autoBtn.Position = UDim2.new(0.52, 0, 0, 50)
autoBtn.BackgroundColor3 = Color3.fromRGB(40, 40, 60)
autoBtn.BorderSizePixel = 0
autoBtn.Text = "🔄 AUTO: OFF"
autoBtn.TextColor3 = Color3.fromRGB(180, 180, 200)
autoBtn.TextSize = 12
autoBtn.Font = Enum.Font.GothamBold
autoBtn.Parent = main

local autoCorner = Instance.new("UICorner")
autoCorner.CornerRadius = UDim.new(0, 6)
autoCorner.Parent = autoBtn

-- Count label
local countLabel = Instance.new("TextLabel")
countLabel.Size = UDim2.new(1, -20, 0, 16)
countLabel.Position = UDim2.new(0, 10, 0, 82)
countLabel.BackgroundTransparency = 1
countLabel.Text = "Tombol ditemukan: 0 | TextLabel: 0"
countLabel.TextColor3 = Color3.fromRGB(160, 160, 180)
countLabel.TextSize = 11
countLabel.Font = Enum.Font.GothamMedium
countLabel.TextXAlignment = Enum.TextXAlignment.Left
countLabel.Parent = main

-- Results scroll
local scroll = Instance.new("ScrollingFrame")
scroll.Size = UDim2.new(1, -20, 1, -106)
scroll.Position = UDim2.new(0, 10, 0, 102)
scroll.BackgroundColor3 = Color3.fromRGB(18, 18, 30)
scroll.BackgroundTransparency = 0.3
scroll.BorderSizePixel = 0
scroll.ScrollBarThickness = 4
scroll.ScrollBarImageColor3 = Color3.fromRGB(255, 100, 100)
scroll.AutomaticCanvasSize = Enum.AutomaticSize.Y
scroll.CanvasSize = UDim2.new(0, 0, 0, 0)
scroll.Parent = main

local scrollCorner = Instance.new("UICorner")
scrollCorner.CornerRadius = UDim.new(0, 8)
scrollCorner.Parent = scroll

local layout = Instance.new("UIListLayout")
layout.Padding = UDim.new(0, 3)
layout.SortOrder = Enum.SortOrder.LayoutOrder
layout.Parent = scroll

local pad = Instance.new("UIPadding")
pad.PaddingTop = UDim.new(0, 4)
pad.PaddingLeft = UDim.new(0, 4)
pad.PaddingRight = UDim.new(0, 4)
pad.Parent = scroll

-- ============================================
-- SCAN LOGIC
-- ============================================
local function isFullyVisible(obj)
    if not obj.Visible then return false end
    local parent = obj.Parent
    while parent and parent:IsA("GuiObject") do
        if not parent.Visible then return false end
        parent = parent.Parent
    end
    return true
end

local function getPath(obj)
    local parts = {}
    local current = obj
    while current and current ~= player.PlayerGui do
        table.insert(parts, 1, current.Name)
        current = current.Parent
    end
    return table.concat(parts, " > ")
end

local function scanAllButtons()
    -- Clear
    for _, child in ipairs(scroll:GetChildren()) do
        if child:IsA("Frame") then child:Destroy() end
    end

    local pg = player:FindFirstChild("PlayerGui")
    if not pg then return end

    local buttons = {}
    local texts = {}
    local order = 0

    -- Recursive scan
    local function scanRecursive(instance, depth)
        if depth > 12 then return end
        local ok, children = pcall(function() return instance:GetChildren() end)
        if not ok then return end

        for _, child in ipairs(children) do
            if child:IsA("TextButton") or child:IsA("ImageButton") then
                local visible = isFullyVisible(child)
                table.insert(buttons, {
                    obj = child,
                    name = child.Name,
                    text = child:IsA("TextButton") and child.Text or "[Image]",
                    path = getPath(child),
                    visible = visible,
                    className = child.ClassName,
                })
            elseif child:IsA("TextLabel") then
                local visible = isFullyVisible(child)
                if child.Text ~= "" and #child.Text < 100 then
                    table.insert(texts, {
                        obj = child,
                        name = child.Name,
                        text = child.Text,
                        path = getPath(child),
                        visible = visible,
                    })
                end
            end
            scanRecursive(child, depth + 1)
        end
    end

    -- Skip our own GUI
    for _, gui in ipairs(pg:GetChildren()) do
        if gui.Name ~= "BtnDebugger" and gui.Name ~= "BloxHub" then
            scanRecursive(gui, 0)
        end
    end

    -- Count
    local visibleBtns = 0
    local visibleTexts = 0
    for _, b in ipairs(buttons) do if b.visible then visibleBtns = visibleBtns + 1 end end
    for _, t in ipairs(texts) do if t.visible then visibleTexts = visibleTexts + 1 end end
    countLabel.Text = "Buttons: " .. visibleBtns .. "/" .. #buttons .. " | TextLabels: " .. visibleTexts .. "/" .. #texts

    -- ── SECTION: VISIBLE BUTTONS ──
    local function addSection(label, color)
        order = order + 1
        local sec = Instance.new("Frame")
        sec.Size = UDim2.new(1, 0, 0, 22)
        sec.BackgroundColor3 = color
        sec.BackgroundTransparency = 0.7
        sec.BorderSizePixel = 0
        sec.LayoutOrder = order
        sec.Parent = scroll

        local secCorner = Instance.new("UICorner")
        secCorner.CornerRadius = UDim.new(0, 4)
        secCorner.Parent = sec

        local secLabel = Instance.new("TextLabel")
        secLabel.Size = UDim2.new(1, -8, 1, 0)
        secLabel.Position = UDim2.new(0, 4, 0, 0)
        secLabel.BackgroundTransparency = 1
        secLabel.Text = label
        secLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
        secLabel.TextSize = 11
        secLabel.Font = Enum.Font.GothamBold
        secLabel.TextXAlignment = Enum.TextXAlignment.Left
        secLabel.Parent = sec
    end

    local function addEntry(data, isButton)
        order = order + 1
        local row = Instance.new("Frame")
        row.Size = UDim2.new(1, 0, 0, 42)
        row.BackgroundColor3 = data.visible 
            and Color3.fromRGB(25, 40, 25) 
            or Color3.fromRGB(40, 25, 25)
        row.BackgroundTransparency = 0.3
        row.BorderSizePixel = 0
        row.LayoutOrder = order
        row.Parent = scroll

        local rowCorner = Instance.new("UICorner")
        rowCorner.CornerRadius = UDim.new(0, 4)
        rowCorner.Parent = row

        -- Status dot
        local dot = Instance.new("Frame")
        dot.Size = UDim2.new(0, 8, 0, 8)
        dot.Position = UDim2.new(0, 6, 0, 7)
        dot.BackgroundColor3 = data.visible 
            and Color3.fromRGB(80, 255, 120) 
            or Color3.fromRGB(255, 80, 80)
        dot.BorderSizePixel = 0
        dot.Parent = row

        local dotCorner = Instance.new("UICorner")
        dotCorner.CornerRadius = UDim.new(1, 0)
        dotCorner.Parent = dot

        -- Name + Type
        local nameLabel = Instance.new("TextLabel")
        nameLabel.Size = UDim2.new(0.55, -20, 0, 16)
        nameLabel.Position = UDim2.new(0, 20, 0, 2)
        nameLabel.BackgroundTransparency = 1
        nameLabel.Text = data.name
        nameLabel.TextColor3 = data.visible 
            and Color3.fromRGB(100, 255, 150) 
            or Color3.fromRGB(255, 120, 120)
        nameLabel.TextSize = 12
        nameLabel.Font = Enum.Font.GothamBold
        nameLabel.TextXAlignment = Enum.TextXAlignment.Left
        nameLabel.TextTruncate = Enum.TextTruncate.AtEnd
        nameLabel.Parent = row

        -- Text content
        local textLabel = Instance.new("TextLabel")
        textLabel.Size = UDim2.new(0.45, 0, 0, 16)
        textLabel.Position = UDim2.new(0.55, 0, 0, 2)
        textLabel.BackgroundTransparency = 1
        textLabel.Text = '"' .. (data.text or "") .. '"'
        textLabel.TextColor3 = Color3.fromRGB(255, 220, 100)
        textLabel.TextSize = 11
        textLabel.Font = Enum.Font.Code
        textLabel.TextXAlignment = Enum.TextXAlignment.Left
        textLabel.TextTruncate = Enum.TextTruncate.AtEnd
        textLabel.Parent = row

        -- Path
        local pathLabel = Instance.new("TextLabel")
        pathLabel.Size = UDim2.new(1, -8, 0, 14)
        pathLabel.Position = UDim2.new(0, 4, 0, 22)
        pathLabel.BackgroundTransparency = 1
        pathLabel.Text = data.path
        pathLabel.TextColor3 = Color3.fromRGB(80, 80, 110)
        pathLabel.TextSize = 9
        pathLabel.Font = Enum.Font.Code
        pathLabel.TextXAlignment = Enum.TextXAlignment.Left
        pathLabel.TextTruncate = Enum.TextTruncate.AtEnd
        pathLabel.Parent = row
    end

    -- Show visible buttons first
    addSection("✅ VISIBLE BUTTONS (" .. visibleBtns .. ")", Color3.fromRGB(40, 120, 60))
    for _, b in ipairs(buttons) do
        if b.visible then addEntry(b, true) end
    end

    addSection("✅ VISIBLE TEXT LABELS (" .. visibleTexts .. ")", Color3.fromRGB(40, 80, 120))
    for _, t in ipairs(texts) do
        if t.visible then addEntry(t, false) end
    end

    addSection("❌ HIDDEN BUTTONS (" .. (#buttons - visibleBtns) .. ")", Color3.fromRGB(120, 40, 40))
    for _, b in ipairs(buttons) do
        if not b.visible then addEntry(b, true) end
    end

    -- Print to console too
    print("\n" .. string.rep("═", 50))
    print("🔍 BUTTON SCAN RESULTS")
    print(string.rep("═", 50))
    print("\n✅ VISIBLE BUTTONS:")
    for _, b in ipairs(buttons) do
        if b.visible then
            print(string.format("  [%s] Name: %-25s Text: %s", b.className, b.name, b.text))
            print(string.format("         Path: %s", b.path))
        end
    end
    print("\n✅ VISIBLE TEXT WITH NUMBERS:")
    for _, t in ipairs(texts) do
        if t.visible and t.text:match("%d") then
            print(string.format("  Name: %-25s Text: %s", t.name, t.text))
        end
    end
    print(string.rep("═", 50))
end

-- ============================================
-- EVENTS
-- ============================================
scanBtn.MouseButton1Click:Connect(function()
    scanAllButtons()
end)

autoBtn.MouseButton1Click:Connect(function()
    autoScan = not autoScan
    if autoScan then
        autoBtn.BackgroundColor3 = Color3.fromRGB(80, 255, 120)
        autoBtn.TextColor3 = Color3.fromRGB(10, 10, 18)
        autoBtn.Text = "🔄 AUTO: ON"
    else
        autoBtn.BackgroundColor3 = Color3.fromRGB(40, 40, 60)
        autoBtn.TextColor3 = Color3.fromRGB(180, 180, 200)
        autoBtn.Text = "🔄 AUTO: OFF"
    end
end)

-- Toggle visibility
UserInputService.InputBegan:Connect(function(inp, gpe)
    if gpe then return end
    if inp.KeyCode == Enum.KeyCode.L then
        main.Visible = not main.Visible
    end
end)

-- Auto scan loop
task.spawn(function()
    while true do
        if autoScan then
            scanAllButtons()
        end
        task.wait(scanInterval)
    end
end)

-- Initial scan
task.delay(1, scanAllButtons)

print("[Blox-Scripts] 🔍 Button Debugger loaded!")
print("[Blox-Scripts] Tekan L untuk show/hide")
