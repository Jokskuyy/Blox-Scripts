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
    5. Klik 📋 untuk copy path ke clipboard
    6. Drag sudut kanan bawah untuk resize window
    7. Gunakan search bar untuk filter hasil
    8. Tekan L untuk toggle show/hide
]]

local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local TweenService = game:GetService("TweenService")

local player = Players.LocalPlayer
local autoScan = false
local scanInterval = 2
local searchQuery = ""

-- Cached scan data for filtering
local cachedButtons = {}
local cachedTexts = {}

-- Min/Max size constraints
local MIN_WIDTH = 300
local MIN_HEIGHT = 300
local MAX_WIDTH = 700
local MAX_HEIGHT = 800

-- ============================================
-- CLIPBOARD UTILITY
-- ============================================
local function copyToClipboard(text)
    local success = false
    -- Try multiple clipboard methods (executor compatibility)
    if setclipboard then
        pcall(function() setclipboard(text) end)
        success = true
    elseif toclipboard then
        pcall(function() toclipboard(text) end)
        success = true
    elseif Clipboard and Clipboard.set then
        pcall(function() Clipboard.set(text) end)
        success = true
    end
    return success
end

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
subtitle.Text = "L = show/hide • 📋 = copy path • ↘ drag = resize"
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

-- ============================================
-- SEARCH BAR
-- ============================================
local searchFrame = Instance.new("Frame")
searchFrame.Size = UDim2.new(1, -20, 0, 28)
searchFrame.Position = UDim2.new(0, 10, 0, 82)
searchFrame.BackgroundColor3 = Color3.fromRGB(22, 22, 38)
searchFrame.BackgroundTransparency = 0.1
searchFrame.BorderSizePixel = 0
searchFrame.Parent = main

local searchFrameCorner = Instance.new("UICorner")
searchFrameCorner.CornerRadius = UDim.new(0, 6)
searchFrameCorner.Parent = searchFrame

local searchStroke = Instance.new("UIStroke")
searchStroke.Color = Color3.fromRGB(80, 80, 120)
searchStroke.Thickness = 1
searchStroke.Transparency = 0.3
searchStroke.Parent = searchFrame

-- Search icon
local searchIcon = Instance.new("TextLabel")
searchIcon.Size = UDim2.new(0, 24, 1, 0)
searchIcon.Position = UDim2.new(0, 4, 0, 0)
searchIcon.BackgroundTransparency = 1
searchIcon.Text = "🔎"
searchIcon.TextColor3 = Color3.fromRGB(120, 120, 160)
searchIcon.TextSize = 12
searchIcon.Font = Enum.Font.Code
searchIcon.Parent = searchFrame

-- Search TextBox
local searchBox = Instance.new("TextBox")
searchBox.Size = UDim2.new(1, -56, 1, -4)
searchBox.Position = UDim2.new(0, 28, 0, 2)
searchBox.BackgroundTransparency = 1
searchBox.Text = ""
searchBox.PlaceholderText = "Search name, text, or path..."
searchBox.PlaceholderColor3 = Color3.fromRGB(70, 70, 100)
searchBox.TextColor3 = Color3.fromRGB(220, 220, 255)
searchBox.TextSize = 11
searchBox.Font = Enum.Font.Gotham
searchBox.TextXAlignment = Enum.TextXAlignment.Left
searchBox.ClearTextOnFocus = false
searchBox.Parent = searchFrame

-- Clear search button
local clearBtn = Instance.new("TextButton")
clearBtn.Size = UDim2.new(0, 22, 0, 22)
clearBtn.Position = UDim2.new(1, -25, 0, 3)
clearBtn.BackgroundColor3 = Color3.fromRGB(255, 80, 80)
clearBtn.BackgroundTransparency = 0.5
clearBtn.BorderSizePixel = 0
clearBtn.Text = "✕"
clearBtn.TextColor3 = Color3.fromRGB(255, 180, 180)
clearBtn.TextSize = 12
clearBtn.Font = Enum.Font.GothamBold
clearBtn.Visible = false
clearBtn.AutoButtonColor = true
clearBtn.Parent = searchFrame

local clearCorner = Instance.new("UICorner")
clearCorner.CornerRadius = UDim.new(0, 4)
clearCorner.Parent = clearBtn

-- Count label
local countLabel = Instance.new("TextLabel")
countLabel.Size = UDim2.new(1, -20, 0, 16)
countLabel.Position = UDim2.new(0, 10, 0, 114)
countLabel.BackgroundTransparency = 1
countLabel.Text = "Tombol ditemukan: 0 | TextLabel: 0"
countLabel.TextColor3 = Color3.fromRGB(160, 160, 180)
countLabel.TextSize = 11
countLabel.Font = Enum.Font.GothamMedium
countLabel.TextXAlignment = Enum.TextXAlignment.Left
countLabel.Parent = main

-- Copy notification label (appears when path is copied)
local notifLabel = Instance.new("TextLabel")
notifLabel.Size = UDim2.new(0, 140, 0, 24)
notifLabel.Position = UDim2.new(1, -150, 0, 114)
notifLabel.BackgroundColor3 = Color3.fromRGB(80, 255, 120)
notifLabel.BackgroundTransparency = 0.2
notifLabel.BorderSizePixel = 0
notifLabel.Text = "✅ Path Copied!"
notifLabel.TextColor3 = Color3.fromRGB(10, 10, 18)
notifLabel.TextSize = 11
notifLabel.Font = Enum.Font.GothamBold
notifLabel.TextXAlignment = Enum.TextXAlignment.Center
notifLabel.Visible = false
notifLabel.ZIndex = 10
notifLabel.Parent = main

local notifCorner = Instance.new("UICorner")
notifCorner.CornerRadius = UDim.new(0, 6)
notifCorner.Parent = notifLabel

-- Results scroll
local scroll = Instance.new("ScrollingFrame")
scroll.Size = UDim2.new(1, -20, 1, -138)
scroll.Position = UDim2.new(0, 10, 0, 134)
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
-- RESIZE HANDLE (bottom-right corner)
-- ============================================
local resizeHandle = Instance.new("TextButton")
resizeHandle.Size = UDim2.new(0, 20, 0, 20)
resizeHandle.Position = UDim2.new(1, -20, 1, -20)
resizeHandle.BackgroundColor3 = Color3.fromRGB(255, 100, 100)
resizeHandle.BackgroundTransparency = 0.4
resizeHandle.BorderSizePixel = 0
resizeHandle.Text = "⇲"
resizeHandle.TextColor3 = Color3.fromRGB(255, 255, 255)
resizeHandle.TextSize = 14
resizeHandle.Font = Enum.Font.GothamBold
resizeHandle.ZIndex = 5
resizeHandle.AutoButtonColor = false
resizeHandle.Parent = main

local resizeCorner = Instance.new("UICorner")
resizeCorner.CornerRadius = UDim.new(0, 4)
resizeCorner.Parent = resizeHandle

-- Resize grip lines (visual indicator)
local gripFrame = Instance.new("Frame")
gripFrame.Size = UDim2.new(0, 30, 0, 30)
gripFrame.Position = UDim2.new(1, -32, 1, -32)
gripFrame.BackgroundTransparency = 1
gripFrame.ZIndex = 4
gripFrame.Parent = main

-- Resize logic
local isResizing = false
local resizeStartPos = nil
local resizeStartSize = nil

resizeHandle.MouseButton1Down:Connect(function()
    isResizing = true
    -- Prevent the main frame from dragging while resizing
    main.Draggable = false
    resizeStartPos = UserInputService:GetMouseLocation()
    resizeStartSize = main.Size
end)

UserInputService.InputChanged:Connect(function(input)
    if isResizing and input.UserInputType == Enum.UserInputType.MouseMovement then
        local currentPos = UserInputService:GetMouseLocation()
        local delta = currentPos - resizeStartPos
        
        local newWidth = math.clamp(
            resizeStartSize.X.Offset + delta.X,
            MIN_WIDTH,
            MAX_WIDTH
        )
        local newHeight = math.clamp(
            resizeStartSize.Y.Offset + delta.Y,
            MIN_HEIGHT,
            MAX_HEIGHT
        )
        
        main.Size = UDim2.new(0, newWidth, 0, newHeight)
    end
end)

UserInputService.InputEnded:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1 then
        if isResizing then
            isResizing = false
            main.Draggable = true
        end
    end
end)

-- Hover effect for resize handle
resizeHandle.MouseEnter:Connect(function()
    TweenService:Create(resizeHandle, TweenInfo.new(0.15), {
        BackgroundTransparency = 0,
        BackgroundColor3 = Color3.fromRGB(255, 130, 130)
    }):Play()
end)

resizeHandle.MouseLeave:Connect(function()
    TweenService:Create(resizeHandle, TweenInfo.new(0.15), {
        BackgroundTransparency = 0.4,
        BackgroundColor3 = Color3.fromRGB(255, 100, 100)
    }):Play()
end)

-- ============================================
-- COPY NOTIFICATION
-- ============================================
local function showCopyNotif(text)
    notifLabel.Text = text or "✅ Path Copied!"
    notifLabel.Visible = true
    notifLabel.BackgroundTransparency = 0.2
    notifLabel.TextTransparency = 0
    
    task.delay(1.2, function()
        local tween = TweenService:Create(notifLabel, TweenInfo.new(0.4, Enum.EasingStyle.Quad), {
            BackgroundTransparency = 1,
            TextTransparency = 1
        })
        tween:Play()
        tween.Completed:Connect(function()
            notifLabel.Visible = false
            notifLabel.BackgroundTransparency = 0.2
            notifLabel.TextTransparency = 0
        end)
    end)
end

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

-- Get script-friendly path (dot notation)
local function getScriptPath(obj)
    local parts = {}
    local current = obj
    while current and current ~= player.PlayerGui do
        local name = current.Name
        -- Use bracket notation if name has special chars
        if name:match("[^%w_]") then
            table.insert(parts, 1, '["' .. name .. '"]')
        else
            table.insert(parts, 1, name)
        end
        current = current.Parent
    end
    -- Build path
    local result = "PlayerGui"
    for i, part in ipairs(parts) do
        if part:sub(1, 1) == "[" then
            result = result .. part
        else
            result = result .. "." .. part
        end
    end
    return result
end

-- ============================================
-- ENTRY & SECTION BUILDERS (shared by scan & filter)
-- ============================================
local function addSection(label, color, order)
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

local function addEntry(data, isButton, order)
    local row = Instance.new("Frame")
    row.Size = UDim2.new(1, 0, 0, 52)
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
    nameLabel.Size = UDim2.new(0.50, -20, 0, 16)
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
    textLabel.Size = UDim2.new(0.40, 0, 0, 16)
    textLabel.Position = UDim2.new(0.50, 0, 0, 2)
    textLabel.BackgroundTransparency = 1
    textLabel.Text = '"' .. (data.text or "") .. '"'
    textLabel.TextColor3 = Color3.fromRGB(255, 220, 100)
    textLabel.TextSize = 11
    textLabel.Font = Enum.Font.Code
    textLabel.TextXAlignment = Enum.TextXAlignment.Left
    textLabel.TextTruncate = Enum.TextTruncate.AtEnd
    textLabel.Parent = row

    -- Path row (with copy button)
    local pathRow = Instance.new("Frame")
    pathRow.Size = UDim2.new(1, -8, 0, 18)
    pathRow.Position = UDim2.new(0, 4, 0, 20)
    pathRow.BackgroundTransparency = 1
    pathRow.BorderSizePixel = 0
    pathRow.Parent = row

    -- Path label
    local pathLabel = Instance.new("TextLabel")
    pathLabel.Size = UDim2.new(1, -58, 0, 14)
    pathLabel.Position = UDim2.new(0, 0, 0, 2)
    pathLabel.BackgroundTransparency = 1
    pathLabel.Text = data.path
    pathLabel.TextColor3 = Color3.fromRGB(80, 80, 110)
    pathLabel.TextSize = 9
    pathLabel.Font = Enum.Font.Code
    pathLabel.TextXAlignment = Enum.TextXAlignment.Left
    pathLabel.TextTruncate = Enum.TextTruncate.AtEnd
    pathLabel.Parent = pathRow

    -- Copy Path button (readable path)
    local copyBtn = Instance.new("TextButton")
    copyBtn.Size = UDim2.new(0, 24, 0, 16)
    copyBtn.Position = UDim2.new(1, -52, 0, 1)
    copyBtn.BackgroundColor3 = Color3.fromRGB(60, 60, 90)
    copyBtn.BackgroundTransparency = 0.3
    copyBtn.BorderSizePixel = 0
    copyBtn.Text = "📋"
    copyBtn.TextSize = 10
    copyBtn.Font = Enum.Font.Code
    copyBtn.ZIndex = 3
    copyBtn.AutoButtonColor = true
    copyBtn.Parent = pathRow

    local copyBtnCorner = Instance.new("UICorner")
    copyBtnCorner.CornerRadius = UDim.new(0, 3)
    copyBtnCorner.Parent = copyBtn

    -- Copy Script Path button (dot notation)
    local copyScriptBtn = Instance.new("TextButton")
    copyScriptBtn.Size = UDim2.new(0, 24, 0, 16)
    copyScriptBtn.Position = UDim2.new(1, -26, 0, 1)
    copyScriptBtn.BackgroundColor3 = Color3.fromRGB(80, 60, 120)
    copyScriptBtn.BackgroundTransparency = 0.3
    copyScriptBtn.BorderSizePixel = 0
    copyScriptBtn.Text = "📝"
    copyScriptBtn.TextSize = 10
    copyScriptBtn.Font = Enum.Font.Code
    copyScriptBtn.ZIndex = 3
    copyScriptBtn.AutoButtonColor = true
    copyScriptBtn.Parent = pathRow

    local copyScriptCorner = Instance.new("UICorner")
    copyScriptCorner.CornerRadius = UDim.new(0, 3)
    copyScriptCorner.Parent = copyScriptBtn

    -- Script path label (shown below readable path)
    local scriptPathLabel = Instance.new("TextLabel")
    scriptPathLabel.Size = UDim2.new(1, -58, 0, 12)
    scriptPathLabel.Position = UDim2.new(0, 0, 0, 36)
    scriptPathLabel.BackgroundTransparency = 1
    scriptPathLabel.Text = data.scriptPath
    scriptPathLabel.TextColor3 = Color3.fromRGB(120, 80, 180)
    scriptPathLabel.TextSize = 8
    scriptPathLabel.Font = Enum.Font.Code
    scriptPathLabel.TextXAlignment = Enum.TextXAlignment.Left
    scriptPathLabel.TextTruncate = Enum.TextTruncate.AtEnd
    scriptPathLabel.Parent = row

    -- Copy button events
    copyBtn.MouseButton1Click:Connect(function()
        local success = copyToClipboard(data.path)
        if success then
            showCopyNotif("✅ Path Copied!")
            copyBtn.BackgroundColor3 = Color3.fromRGB(80, 255, 120)
            task.delay(0.4, function()
                copyBtn.BackgroundColor3 = Color3.fromRGB(60, 60, 90)
            end)
        else
            showCopyNotif("❌ Clipboard unavailable")
        end
        print("[BtnDebugger] Path copied: " .. data.path)
    end)

    copyScriptBtn.MouseButton1Click:Connect(function()
        local success = copyToClipboard(data.scriptPath)
        if success then
            showCopyNotif("✅ Script Path Copied!")
            copyScriptBtn.BackgroundColor3 = Color3.fromRGB(80, 255, 120)
            task.delay(0.4, function()
                copyScriptBtn.BackgroundColor3 = Color3.fromRGB(80, 60, 120)
            end)
        else
            showCopyNotif("❌ Clipboard unavailable")
        end
        print("[BtnDebugger] Script path copied: " .. data.scriptPath)
    end)

    -- Hover effects for copy buttons
    copyBtn.MouseEnter:Connect(function()
        TweenService:Create(copyBtn, TweenInfo.new(0.1), {
            BackgroundTransparency = 0,
            BackgroundColor3 = Color3.fromRGB(100, 100, 150)
        }):Play()
    end)
    copyBtn.MouseLeave:Connect(function()
        TweenService:Create(copyBtn, TweenInfo.new(0.1), {
            BackgroundTransparency = 0.3,
            BackgroundColor3 = Color3.fromRGB(60, 60, 90)
        }):Play()
    end)

    copyScriptBtn.MouseEnter:Connect(function()
        TweenService:Create(copyScriptBtn, TweenInfo.new(0.1), {
            BackgroundTransparency = 0,
            BackgroundColor3 = Color3.fromRGB(120, 80, 180)
        }):Play()
    end)
    copyScriptBtn.MouseLeave:Connect(function()
        TweenService:Create(copyScriptBtn, TweenInfo.new(0.1), {
            BackgroundTransparency = 0.3,
            BackgroundColor3 = Color3.fromRGB(80, 60, 120)
        }):Play()
    end)
end

-- ============================================
-- FILTER / SEARCH LOGIC
-- ============================================
local function matchesQuery(data, query)
    if query == "" then return true end
    local q = query:lower()
    if data.name:lower():find(q, 1, true) then return true end
    if data.text and data.text:lower():find(q, 1, true) then return true end
    if data.path:lower():find(q, 1, true) then return true end
    if data.scriptPath and data.scriptPath:lower():find(q, 1, true) then return true end
    return false
end

local function clearScrollEntries()
    for _, child in ipairs(scroll:GetChildren()) do
        if child:IsA("Frame") then child:Destroy() end
    end
end

local function displayResults(buttons, texts, query)
    clearScrollEntries()
    local order = 0

    -- Filter data
    local filteredVisibleBtns = {}
    local filteredHiddenBtns = {}
    local filteredVisibleTexts = {}

    for _, b in ipairs(buttons) do
        if matchesQuery(b, query) then
            if b.visible then
                table.insert(filteredVisibleBtns, b)
            else
                table.insert(filteredHiddenBtns, b)
            end
        end
    end
    for _, t in ipairs(texts) do
        if t.visible and matchesQuery(t, query) then
            table.insert(filteredVisibleTexts, t)
        end
    end

    -- Update count with filter info
    local totalShown = #filteredVisibleBtns + #filteredHiddenBtns + #filteredVisibleTexts
    local totalAll = #buttons + #texts
    if query ~= "" then
        countLabel.Text = "🔎 " .. totalShown .. " results for \"" .. query .. "\" (" .. totalAll .. " total)"
    else
        local visibleBtns = 0
        local visibleTexts = 0
        for _, b in ipairs(buttons) do if b.visible then visibleBtns = visibleBtns + 1 end end
        for _, t in ipairs(texts) do if t.visible then visibleTexts = visibleTexts + 1 end end
        countLabel.Text = "Buttons: " .. visibleBtns .. "/" .. #buttons .. " | TextLabels: " .. visibleTexts .. "/" .. #texts
    end

    -- Show visible buttons
    order = order + 1
    addSection("✅ VISIBLE BUTTONS (" .. #filteredVisibleBtns .. ")", Color3.fromRGB(40, 120, 60), order)
    for _, b in ipairs(filteredVisibleBtns) do
        order = order + 1
        addEntry(b, true, order)
    end

    -- Show visible text labels
    order = order + 1
    addSection("✅ VISIBLE TEXT LABELS (" .. #filteredVisibleTexts .. ")", Color3.fromRGB(40, 80, 120), order)
    for _, t in ipairs(filteredVisibleTexts) do
        order = order + 1
        addEntry(t, false, order)
    end

    -- Show hidden buttons
    order = order + 1
    addSection("❌ HIDDEN BUTTONS (" .. #filteredHiddenBtns .. ")", Color3.fromRGB(120, 40, 40), order)
    for _, b in ipairs(filteredHiddenBtns) do
        order = order + 1
        addEntry(b, true, order)
    end

    -- No results message
    if totalShown == 0 and query ~= "" then
        order = order + 1
        local noResult = Instance.new("Frame")
        noResult.Size = UDim2.new(1, 0, 0, 40)
        noResult.BackgroundColor3 = Color3.fromRGB(40, 30, 20)
        noResult.BackgroundTransparency = 0.5
        noResult.BorderSizePixel = 0
        noResult.LayoutOrder = order
        noResult.Parent = scroll

        local noResultCorner = Instance.new("UICorner")
        noResultCorner.CornerRadius = UDim.new(0, 4)
        noResultCorner.Parent = noResult

        local noResultLabel = Instance.new("TextLabel")
        noResultLabel.Size = UDim2.new(1, -8, 1, 0)
        noResultLabel.Position = UDim2.new(0, 4, 0, 0)
        noResultLabel.BackgroundTransparency = 1
        noResultLabel.Text = "😕 No results found for \"" .. query .. "\""
        noResultLabel.TextColor3 = Color3.fromRGB(255, 180, 100)
        noResultLabel.TextSize = 12
        noResultLabel.Font = Enum.Font.GothamMedium
        noResultLabel.TextXAlignment = Enum.TextXAlignment.Center
        noResultLabel.Parent = noResult
    end
end

local function scanAllButtons()
    local pg = player:FindFirstChild("PlayerGui")
    if not pg then return end

    cachedButtons = {}
    cachedTexts = {}

    -- Recursive scan
    local function scanRecursive(instance, depth)
        if depth > 12 then return end
        local ok, children = pcall(function() return instance:GetChildren() end)
        if not ok then return end

        for _, child in ipairs(children) do
            if child:IsA("TextButton") or child:IsA("ImageButton") then
                local visible = isFullyVisible(child)
                table.insert(cachedButtons, {
                    obj = child,
                    name = child.Name,
                    text = child:IsA("TextButton") and child.Text or "[Image]",
                    path = getPath(child),
                    scriptPath = getScriptPath(child),
                    visible = visible,
                    className = child.ClassName,
                })
            elseif child:IsA("TextLabel") then
                local visible = isFullyVisible(child)
                if child.Text ~= "" and #child.Text < 100 then
                    table.insert(cachedTexts, {
                        obj = child,
                        name = child.Name,
                        text = child.Text,
                        path = getPath(child),
                        scriptPath = getScriptPath(child),
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

    -- Display with current search filter
    displayResults(cachedButtons, cachedTexts, searchQuery)

    -- Print to console too
    print("\n" .. string.rep("═", 50))
    print("🔍 BUTTON SCAN RESULTS")
    print(string.rep("═", 50))
    print("\n✅ VISIBLE BUTTONS:")
    for _, b in ipairs(cachedButtons) do
        if b.visible then
            print(string.format("  [%s] Name: %-25s Text: %s", b.className, b.name, b.text))
            print(string.format("         Path: %s", b.path))
        end
    end
    print("\n✅ VISIBLE TEXT WITH NUMBERS:")
    for _, t in ipairs(cachedTexts) do
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

-- Search bar events
local searchDebounce = nil
searchBox:GetPropertyChangedSignal("Text"):Connect(function()
    searchQuery = searchBox.Text
    clearBtn.Visible = (searchQuery ~= "")
    
    -- Update search bar stroke color based on state
    if searchQuery ~= "" then
        searchStroke.Color = Color3.fromRGB(255, 120, 120)
    else
        searchStroke.Color = Color3.fromRGB(80, 80, 120)
    end
    
    -- Debounce: wait a tiny bit before filtering to avoid lag
    if searchDebounce then
        task.cancel(searchDebounce)
    end
    searchDebounce = task.delay(0.15, function()
        if #cachedButtons > 0 or #cachedTexts > 0 then
            displayResults(cachedButtons, cachedTexts, searchQuery)
        end
        searchDebounce = nil
    end)
end)

clearBtn.MouseButton1Click:Connect(function()
    searchBox.Text = ""
    searchQuery = ""
    clearBtn.Visible = false
    searchStroke.Color = Color3.fromRGB(80, 80, 120)
    if #cachedButtons > 0 or #cachedTexts > 0 then
        displayResults(cachedButtons, cachedTexts, "")
    end
end)

-- Search bar focus effects
searchBox.Focused:Connect(function()
    TweenService:Create(searchStroke, TweenInfo.new(0.2), {
        Color = Color3.fromRGB(255, 150, 150),
        Transparency = 0
    }):Play()
    TweenService:Create(searchFrame, TweenInfo.new(0.2), {
        BackgroundColor3 = Color3.fromRGB(28, 28, 48)
    }):Play()
end)

searchBox.FocusLost:Connect(function()
    local targetColor = searchQuery ~= "" 
        and Color3.fromRGB(255, 120, 120) 
        or Color3.fromRGB(80, 80, 120)
    TweenService:Create(searchStroke, TweenInfo.new(0.2), {
        Color = targetColor,
        Transparency = 0.3
    }):Play()
    TweenService:Create(searchFrame, TweenInfo.new(0.2), {
        BackgroundColor3 = Color3.fromRGB(22, 22, 38)
    }):Play()
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
print("[Blox-Scripts] 📋 = copy path | 📝 = copy script path")
print("[Blox-Scripts] 🔎 Search bar untuk filter hasil")
print("[Blox-Scripts] Drag ↘ untuk resize window")
