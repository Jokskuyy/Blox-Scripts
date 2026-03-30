--[[
    ╔══════════════════════════════════════════╗
    ║    SUMMON HERO - LUCK DETECTOR v1.0      ║
    ║    Auto Scan + Real-Time Luck Display     ║
    ║    Blox-Scripts by Jokskuyy               ║
    ╚══════════════════════════════════════════╝
    
    Fitur:
    - Auto scan luck dari leaderstats, attributes, GUI, dan data stores
    - Tampilan real-time luck di GUI overlay
    - Notifikasi saat luck berubah
    - Log history perubahan luck
    - Minimize/maximize GUI
]]

-- ============================================
-- SERVICES
-- ============================================
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

-- ============================================
-- VARIABLES
-- ============================================
local player = Players.LocalPlayer
local currentLuck = "Scanning..."
local luckSource = "Belum ditemukan"
local luckHistory = {}
local MAX_HISTORY = 20
local isMinimized = false
local luckValueObj = nil -- referensi ke value object luck

-- ============================================
-- UTILITY FUNCTIONS
-- ============================================
local function addToHistory(value, source)
    table.insert(luckHistory, 1, {
        value = tostring(value),
        source = source,
        time = os.date("%H:%M:%S")
    })
    if #luckHistory > MAX_HISTORY then
        table.remove(luckHistory)
    end
end

local function deepSearch(instance, keywords, depth, maxDepth)
    depth = depth or 0
    maxDepth = maxDepth or 5
    local results = {}
    
    if depth > maxDepth then return results end
    
    local success, children = pcall(function()
        return instance:GetChildren()
    end)
    
    if not success then return results end
    
    for _, child in ipairs(children) do
        local nameLower = child.Name:lower()
        for _, keyword in ipairs(keywords) do
            if nameLower:find(keyword:lower()) then
                table.insert(results, {
                    object = child,
                    path = instance:GetFullName() .. "." .. child.Name,
                    name = child.Name
                })
            end
        end
        -- Rekursif ke children
        local childResults = deepSearch(child, keywords, depth + 1, maxDepth)
        for _, r in ipairs(childResults) do
            table.insert(results, r)
        end
    end
    
    return results
end

-- ============================================
-- GUI CREATION
-- ============================================
local function createGUI()
    if player.PlayerGui:FindFirstChild("LuckDetectorGUI") then
        player.PlayerGui:FindFirstChild("LuckDetectorGUI"):Destroy()
    end

    local screenGui = Instance.new("ScreenGui")
    screenGui.Name = "LuckDetectorGUI"
    screenGui.ResetOnSpawn = false
    screenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
    screenGui.Parent = player.PlayerGui

    -- Main Frame
    local mainFrame = Instance.new("Frame")
    mainFrame.Name = "MainFrame"
    mainFrame.Size = UDim2.new(0, 260, 0, 340)
    mainFrame.Position = UDim2.new(1, -280, 0, 20)
    mainFrame.BackgroundColor3 = Color3.fromRGB(15, 15, 25)
    mainFrame.BackgroundTransparency = 0.05
    mainFrame.BorderSizePixel = 0
    mainFrame.Active = true
    mainFrame.Draggable = true
    mainFrame.ClipsDescendants = true
    mainFrame.Parent = screenGui

    local mainCorner = Instance.new("UICorner")
    mainCorner.CornerRadius = UDim.new(0, 14)
    mainCorner.Parent = mainFrame

    local mainStroke = Instance.new("UIStroke")
    mainStroke.Color = Color3.fromRGB(255, 180, 0)
    mainStroke.Thickness = 2
    mainStroke.Transparency = 0.3
    mainStroke.Parent = mainFrame

    -- Top gradient bar
    local topBar = Instance.new("Frame")
    topBar.Size = UDim2.new(1, 0, 0, 4)
    topBar.Position = UDim2.new(0, 0, 0, 0)
    topBar.BorderSizePixel = 0
    topBar.Parent = mainFrame

    local topGradient = Instance.new("UIGradient")
    topGradient.Color = ColorSequence.new{
        ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 180, 0)),
        ColorSequenceKeypoint.new(0.5, Color3.fromRGB(255, 100, 50)),
        ColorSequenceKeypoint.new(1, Color3.fromRGB(255, 50, 100))
    }
    topGradient.Parent = topBar

    local topCorner = Instance.new("UICorner")
    topCorner.CornerRadius = UDim.new(0, 14)
    topCorner.Parent = topBar

    -- Header area
    local headerFrame = Instance.new("Frame")
    headerFrame.Name = "Header"
    headerFrame.Size = UDim2.new(1, 0, 0, 50)
    headerFrame.Position = UDim2.new(0, 0, 0, 4)
    headerFrame.BackgroundTransparency = 1
    headerFrame.Parent = mainFrame

    -- Title
    local title = Instance.new("TextLabel")
    title.Name = "Title"
    title.Size = UDim2.new(1, -50, 0, 24)
    title.Position = UDim2.new(0, 14, 0, 6)
    title.BackgroundTransparency = 1
    title.Text = "🍀 LUCK DETECTOR"
    title.TextColor3 = Color3.fromRGB(255, 210, 80)
    title.TextSize = 15
    title.Font = Enum.Font.GothamBold
    title.TextXAlignment = Enum.TextXAlignment.Left
    title.Parent = headerFrame

    -- Subtitle
    local subtitle = Instance.new("TextLabel")
    subtitle.Size = UDim2.new(1, -50, 0, 14)
    subtitle.Position = UDim2.new(0, 14, 0, 30)
    subtitle.BackgroundTransparency = 1
    subtitle.Text = "Summon Hero • Real-Time"
    subtitle.TextColor3 = Color3.fromRGB(120, 120, 150)
    subtitle.TextSize = 10
    subtitle.Font = Enum.Font.Gotham
    subtitle.TextXAlignment = Enum.TextXAlignment.Left
    subtitle.Parent = headerFrame

    -- Minimize button
    local minimizeBtn = Instance.new("TextButton")
    minimizeBtn.Name = "MinimizeBtn"
    minimizeBtn.Size = UDim2.new(0, 30, 0, 30)
    minimizeBtn.Position = UDim2.new(1, -40, 0, 8)
    minimizeBtn.BackgroundColor3 = Color3.fromRGB(40, 40, 55)
    minimizeBtn.BorderSizePixel = 0
    minimizeBtn.Text = "—"
    minimizeBtn.TextColor3 = Color3.fromRGB(180, 180, 200)
    minimizeBtn.TextSize = 14
    minimizeBtn.Font = Enum.Font.GothamBold
    minimizeBtn.Parent = headerFrame

    local minCorner = Instance.new("UICorner")
    minCorner.CornerRadius = UDim.new(0, 6)
    minCorner.Parent = minimizeBtn

    -- Separator
    local sep1 = Instance.new("Frame")
    sep1.Size = UDim2.new(1, -20, 0, 1)
    sep1.Position = UDim2.new(0, 10, 0, 54)
    sep1.BackgroundColor3 = Color3.fromRGB(50, 50, 70)
    sep1.BorderSizePixel = 0
    sep1.Parent = mainFrame

    -- ========================================
    -- LUCK DISPLAY CARD
    -- ========================================
    local luckCard = Instance.new("Frame")
    luckCard.Name = "LuckCard"
    luckCard.Size = UDim2.new(1, -20, 0, 80)
    luckCard.Position = UDim2.new(0, 10, 0, 62)
    luckCard.BackgroundColor3 = Color3.fromRGB(25, 25, 40)
    luckCard.BorderSizePixel = 0
    luckCard.Parent = mainFrame

    local luckCardCorner = Instance.new("UICorner")
    luckCardCorner.CornerRadius = UDim.new(0, 10)
    luckCardCorner.Parent = luckCard

    local luckCardStroke = Instance.new("UIStroke")
    luckCardStroke.Color = Color3.fromRGB(255, 180, 0)
    luckCardStroke.Thickness = 1
    luckCardStroke.Transparency = 0.6
    luckCardStroke.Parent = luckCard

    -- Luck icon + value
    local luckIcon = Instance.new("TextLabel")
    luckIcon.Size = UDim2.new(0, 40, 0, 40)
    luckIcon.Position = UDim2.new(0, 10, 0, 10)
    luckIcon.BackgroundTransparency = 1
    luckIcon.Text = "🎯"
    luckIcon.TextSize = 28
    luckIcon.Parent = luckCard

    local luckValueDisplay = Instance.new("TextLabel")
    luckValueDisplay.Name = "LuckValue"
    luckValueDisplay.Size = UDim2.new(1, -60, 0, 30)
    luckValueDisplay.Position = UDim2.new(0, 55, 0, 8)
    luckValueDisplay.BackgroundTransparency = 1
    luckValueDisplay.Text = "Scanning..."
    luckValueDisplay.TextColor3 = Color3.fromRGB(255, 220, 100)
    luckValueDisplay.TextSize = 22
    luckValueDisplay.Font = Enum.Font.GothamBold
    luckValueDisplay.TextXAlignment = Enum.TextXAlignment.Left
    luckValueDisplay.Parent = luckCard

    local luckSourceDisplay = Instance.new("TextLabel")
    luckSourceDisplay.Name = "LuckSource"
    luckSourceDisplay.Size = UDim2.new(1, -60, 0, 16)
    luckSourceDisplay.Position = UDim2.new(0, 55, 0, 38)
    luckSourceDisplay.BackgroundTransparency = 1
    luckSourceDisplay.Text = "Sumber: Mencari..."
    luckSourceDisplay.TextColor3 = Color3.fromRGB(120, 120, 150)
    luckSourceDisplay.TextSize = 10
    luckSourceDisplay.Font = Enum.Font.Gotham
    luckSourceDisplay.TextXAlignment = Enum.TextXAlignment.Left
    luckSourceDisplay.Parent = luckCard

    -- Scan status indicator
    local scanDot = Instance.new("Frame")
    scanDot.Name = "ScanDot"
    scanDot.Size = UDim2.new(0, 8, 0, 8)
    scanDot.Position = UDim2.new(0, 14, 0, 60)
    scanDot.BackgroundColor3 = Color3.fromRGB(255, 200, 0)
    scanDot.BorderSizePixel = 0
    scanDot.Parent = luckCard

    local scanDotCorner = Instance.new("UICorner")
    scanDotCorner.CornerRadius = UDim.new(1, 0)
    scanDotCorner.Parent = scanDot

    local scanStatus = Instance.new("TextLabel")
    scanStatus.Name = "ScanStatus"
    scanStatus.Size = UDim2.new(1, -30, 0, 14)
    scanStatus.Position = UDim2.new(0, 28, 0, 57)
    scanStatus.BackgroundTransparency = 1
    scanStatus.Text = "Sedang scanning..."
    scanStatus.TextColor3 = Color3.fromRGB(255, 200, 0)
    scanStatus.TextSize = 10
    scanStatus.Font = Enum.Font.Gotham
    scanStatus.TextXAlignment = Enum.TextXAlignment.Left
    scanStatus.Parent = luckCard

    -- ========================================
    -- SCAN BUTTON
    -- ========================================
    local rescanBtn = Instance.new("TextButton")
    rescanBtn.Name = "RescanBtn"
    rescanBtn.Size = UDim2.new(1, -20, 0, 32)
    rescanBtn.Position = UDim2.new(0, 10, 0, 150)
    rescanBtn.BackgroundColor3 = Color3.fromRGB(255, 160, 0)
    rescanBtn.BorderSizePixel = 0
    rescanBtn.Text = "🔄  SCAN ULANG"
    rescanBtn.TextColor3 = Color3.fromRGB(15, 15, 25)
    rescanBtn.TextSize = 13
    rescanBtn.Font = Enum.Font.GothamBold
    rescanBtn.Parent = mainFrame

    local rescanCorner = Instance.new("UICorner")
    rescanCorner.CornerRadius = UDim.new(0, 8)
    rescanCorner.Parent = rescanBtn

    -- Hover effect
    rescanBtn.MouseEnter:Connect(function()
        TweenService:Create(rescanBtn, TweenInfo.new(0.15), {
            BackgroundColor3 = Color3.fromRGB(255, 190, 50)
        }):Play()
    end)
    rescanBtn.MouseLeave:Connect(function()
        TweenService:Create(rescanBtn, TweenInfo.new(0.15), {
            BackgroundColor3 = Color3.fromRGB(255, 160, 0)
        }):Play()
    end)

    -- ========================================
    -- HISTORY LOG SECTION
    -- ========================================
    local sep2 = Instance.new("Frame")
    sep2.Size = UDim2.new(1, -20, 0, 1)
    sep2.Position = UDim2.new(0, 10, 0, 190)
    sep2.BackgroundColor3 = Color3.fromRGB(50, 50, 70)
    sep2.BorderSizePixel = 0
    sep2.Parent = mainFrame

    local historyTitle = Instance.new("TextLabel")
    historyTitle.Size = UDim2.new(1, -20, 0, 20)
    historyTitle.Position = UDim2.new(0, 10, 0, 196)
    historyTitle.BackgroundTransparency = 1
    historyTitle.Text = "📋 Riwayat Perubahan"
    historyTitle.TextColor3 = Color3.fromRGB(180, 180, 200)
    historyTitle.TextSize = 12
    historyTitle.Font = Enum.Font.GothamMedium
    historyTitle.TextXAlignment = Enum.TextXAlignment.Left
    historyTitle.Parent = mainFrame

    -- History scroll frame
    local historyScroll = Instance.new("ScrollingFrame")
    historyScroll.Name = "HistoryScroll"
    historyScroll.Size = UDim2.new(1, -20, 0, 118)
    historyScroll.Position = UDim2.new(0, 10, 0, 218)
    historyScroll.BackgroundColor3 = Color3.fromRGB(20, 20, 35)
    historyScroll.BackgroundTransparency = 0.5
    historyScroll.BorderSizePixel = 0
    historyScroll.ScrollBarThickness = 4
    historyScroll.ScrollBarImageColor3 = Color3.fromRGB(255, 180, 0)
    historyScroll.CanvasSize = UDim2.new(0, 0, 0, 0)
    historyScroll.AutomaticCanvasSize = Enum.AutomaticSize.Y
    historyScroll.Parent = mainFrame

    local historyCorner = Instance.new("UICorner")
    historyCorner.CornerRadius = UDim.new(0, 8)
    historyCorner.Parent = historyScroll

    local historyLayout = Instance.new("UIListLayout")
    historyLayout.Padding = UDim.new(0, 2)
    historyLayout.SortOrder = Enum.SortOrder.LayoutOrder
    historyLayout.Parent = historyScroll

    local historyPadding = Instance.new("UIPadding")
    historyPadding.PaddingTop = UDim.new(0, 4)
    historyPadding.PaddingLeft = UDim.new(0, 6)
    historyPadding.PaddingRight = UDim.new(0, 6)
    historyPadding.Parent = historyScroll

    -- No history placeholder
    local noHistory = Instance.new("TextLabel")
    noHistory.Name = "NoHistory"
    noHistory.Size = UDim2.new(1, 0, 0, 40)
    noHistory.BackgroundTransparency = 1
    noHistory.Text = "Belum ada perubahan luck..."
    noHistory.TextColor3 = Color3.fromRGB(80, 80, 100)
    noHistory.TextSize = 11
    noHistory.Font = Enum.Font.Gotham
    noHistory.Parent = historyScroll

    -- ========================================
    -- MINIMIZE LOGIC
    -- ========================================
    local expandedSize = UDim2.new(0, 260, 0, 340)
    local minimizedSize = UDim2.new(0, 260, 0, 56)

    minimizeBtn.MouseButton1Click:Connect(function()
        isMinimized = not isMinimized
        local tweenInfo = TweenInfo.new(0.3, Enum.EasingStyle.Quart, Enum.EasingDirection.Out)
        
        if isMinimized then
            TweenService:Create(mainFrame, tweenInfo, {Size = minimizedSize}):Play()
            minimizeBtn.Text = "+"
        else
            TweenService:Create(mainFrame, tweenInfo, {Size = expandedSize}):Play()
            minimizeBtn.Text = "—"
        end
    end)

    return {
        MainFrame = mainFrame,
        LuckValue = luckValueDisplay,
        LuckSource = luckSourceDisplay,
        ScanDot = scanDot,
        ScanStatus = scanStatus,
        RescanBtn = rescanBtn,
        HistoryScroll = historyScroll,
        NoHistory = noHistory,
    }
end

-- ============================================
-- LUCK SCANNER
-- ============================================
local function scanForLuck(gui)
    gui.ScanStatus.Text = "Sedang scanning..."
    gui.ScanDot.BackgroundColor3 = Color3.fromRGB(255, 200, 0)
    gui.LuckValue.Text = "Scanning..."
    
    local luckKeywords = {
        "luck", "lucky", "keberuntungan", "fortune", 
        "lck", "multiplier", "mult", "boost", "bonus",
        "chance", "rarity", "rare"
    }
    
    local found = false
    
    -- ========================================
    -- METHOD 1: Cek leaderstats
    -- ========================================
    local leaderstats = player:FindFirstChild("leaderstats")
    if leaderstats then
        for _, stat in ipairs(leaderstats:GetChildren()) do
            local nameLower = stat.Name:lower()
            for _, keyword in ipairs(luckKeywords) do
                if nameLower:find(keyword) then
                    currentLuck = tostring(stat.Value)
                    luckSource = "leaderstats." .. stat.Name
                    luckValueObj = stat
                    found = true
                    
                    -- Listen for changes
                    stat.Changed:Connect(function(newVal)
                        local oldLuck = currentLuck
                        currentLuck = tostring(newVal)
                        gui.LuckValue.Text = "🍀 " .. currentLuck
                        addToHistory(currentLuck, "Dari " .. oldLuck)
                        updateHistoryGUI(gui)
                        flashNotification(gui, oldLuck, currentLuck)
                    end)
                    
                    break
                end
            end
            if found then break end
        end
    end
    
    -- ========================================
    -- METHOD 2: Cek Player Attributes
    -- ========================================
    if not found then
        local attributes = player:GetAttributes()
        for attrName, attrValue in pairs(attributes) do
            local nameLower = attrName:lower()
            for _, keyword in ipairs(luckKeywords) do
                if nameLower:find(keyword) then
                    currentLuck = tostring(attrValue)
                    luckSource = "Player Attribute: " .. attrName
                    found = true
                    
                    player:GetAttributeChangedSignal(attrName):Connect(function()
                        local oldLuck = currentLuck
                        currentLuck = tostring(player:GetAttribute(attrName))
                        gui.LuckValue.Text = "🍀 " .. currentLuck
                        addToHistory(currentLuck, "Dari " .. oldLuck)
                        updateHistoryGUI(gui)
                        flashNotification(gui, oldLuck, currentLuck)
                    end)
                    
                    break
                end
            end
            if found then break end
        end
    end
    
    -- ========================================
    -- METHOD 3: Cek Character Attributes
    -- ========================================
    if not found and player.Character then
        local charAttributes = player.Character:GetAttributes()
        for attrName, attrValue in pairs(charAttributes) do
            local nameLower = attrName:lower()
            for _, keyword in ipairs(luckKeywords) do
                if nameLower:find(keyword) then
                    currentLuck = tostring(attrValue)
                    luckSource = "Character Attribute: " .. attrName
                    found = true
                    
                    player.Character:GetAttributeChangedSignal(attrName):Connect(function()
                        local oldLuck = currentLuck
                        currentLuck = tostring(player.Character:GetAttribute(attrName))
                        gui.LuckValue.Text = "🍀 " .. currentLuck
                        addToHistory(currentLuck, "Dari " .. oldLuck)
                        updateHistoryGUI(gui)
                    end)
                    
                    break
                end
            end
            if found then break end
        end
    end
    
    -- ========================================
    -- METHOD 4: Deep scan ReplicatedStorage
    -- ========================================
    if not found then
        local results = deepSearch(ReplicatedStorage, luckKeywords, 0, 4)
        for _, result in ipairs(results) do
            if result.object:IsA("ValueBase") then
                currentLuck = tostring(result.object.Value)
                luckSource = result.path
                luckValueObj = result.object
                found = true
                
                result.object.Changed:Connect(function(newVal)
                    local oldLuck = currentLuck
                    currentLuck = tostring(newVal)
                    gui.LuckValue.Text = "🍀 " .. currentLuck
                    addToHistory(currentLuck, "Dari " .. oldLuck)
                    updateHistoryGUI(gui)
                end)
                
                break
            end
        end
    end
    
    -- ========================================
    -- METHOD 5: Scan player children (folders, values)
    -- ========================================
    if not found then
        local results = deepSearch(player, luckKeywords, 0, 4)
        for _, result in ipairs(results) do
            if result.object:IsA("ValueBase") then
                currentLuck = tostring(result.object.Value)
                luckSource = result.path
                luckValueObj = result.object
                found = true
                
                result.object.Changed:Connect(function(newVal)
                    local oldLuck = currentLuck
                    currentLuck = tostring(newVal)
                    gui.LuckValue.Text = "🍀 " .. currentLuck
                    addToHistory(currentLuck, "Dari " .. oldLuck)
                    updateHistoryGUI(gui)
                end)
                
                break
            end
        end
    end
    
    -- ========================================
    -- METHOD 6: Scan PlayerGui untuk text yang mengandung luck
    -- ========================================
    if not found then
        local playerGui = player:FindFirstChild("PlayerGui")
        if playerGui then
            local results = deepSearch(playerGui, luckKeywords, 0, 6)
            for _, result in ipairs(results) do
                if result.object:IsA("TextLabel") and result.object.Text ~= "" then
                    currentLuck = result.object.Text
                    luckSource = "GUI: " .. result.name
                    found = true
                    
                    result.object:GetPropertyChangedSignal("Text"):Connect(function()
                        local oldLuck = currentLuck
                        currentLuck = result.object.Text
                        gui.LuckValue.Text = "🍀 " .. currentLuck
                        addToHistory(currentLuck, "GUI berubah")
                        updateHistoryGUI(gui)
                    end)
                    
                    break
                end
            end
        end
    end
    
    -- ========================================
    -- UPDATE GUI SETELAH SCAN
    -- ========================================
    if found then
        gui.LuckValue.Text = "🍀 " .. currentLuck
        gui.LuckSource.Text = "Sumber: " .. luckSource
        gui.ScanStatus.Text = "✅ Luck ditemukan!"
        gui.ScanDot.BackgroundColor3 = Color3.fromRGB(80, 255, 120)
        
        addToHistory(currentLuck, "Scan awal")
        updateHistoryGUI(gui)
        
        -- Animasi found
        TweenService:Create(gui.LuckValue, TweenInfo.new(0.3), {
            TextColor3 = Color3.fromRGB(100, 255, 150)
        }):Play()
        task.wait(0.5)
        TweenService:Create(gui.LuckValue, TweenInfo.new(0.3), {
            TextColor3 = Color3.fromRGB(255, 220, 100)
        }):Play()
    else
        gui.LuckValue.Text = "❌ Tidak ditemukan"
        gui.LuckValue.TextSize = 15
        gui.LuckSource.Text = "Luck mungkin server-side"
        gui.ScanStatus.Text = "⚠ Tidak terdeteksi"
        gui.ScanDot.BackgroundColor3 = Color3.fromRGB(255, 80, 80)
    end
    
    return found
end

-- ============================================
-- HISTORY GUI UPDATE
-- ============================================
function updateHistoryGUI(gui)
    -- Clear existing history items
    for _, child in ipairs(gui.HistoryScroll:GetChildren()) do
        if child:IsA("Frame") then
            child:Destroy()
        end
    end
    
    -- Hide "no history" text
    if #luckHistory > 0 then
        gui.NoHistory.Visible = false
    end
    
    -- Add history items
    for i, entry in ipairs(luckHistory) do
        local item = Instance.new("Frame")
        item.Name = "HistoryItem_" .. i
        item.Size = UDim2.new(1, 0, 0, 24)
        item.BackgroundColor3 = Color3.fromRGB(30, 30, 48)
        item.BackgroundTransparency = 0.3
        item.BorderSizePixel = 0
        item.LayoutOrder = i
        item.Parent = gui.HistoryScroll

        local itemCorner = Instance.new("UICorner")
        itemCorner.CornerRadius = UDim.new(0, 4)
        itemCorner.Parent = item

        -- Time
        local timeLabel = Instance.new("TextLabel")
        timeLabel.Size = UDim2.new(0, 55, 1, 0)
        timeLabel.Position = UDim2.new(0, 4, 0, 0)
        timeLabel.BackgroundTransparency = 1
        timeLabel.Text = entry.time
        timeLabel.TextColor3 = Color3.fromRGB(100, 100, 130)
        timeLabel.TextSize = 10
        timeLabel.Font = Enum.Font.Code
        timeLabel.TextXAlignment = Enum.TextXAlignment.Left
        timeLabel.Parent = item

        -- Value
        local valLabel = Instance.new("TextLabel")
        valLabel.Size = UDim2.new(0, 60, 1, 0)
        valLabel.Position = UDim2.new(0, 60, 0, 0)
        valLabel.BackgroundTransparency = 1
        valLabel.Text = entry.value
        valLabel.TextColor3 = Color3.fromRGB(255, 220, 100)
        valLabel.TextSize = 11
        valLabel.Font = Enum.Font.GothamBold
        valLabel.TextXAlignment = Enum.TextXAlignment.Left
        valLabel.Parent = item

        -- Source
        local srcLabel = Instance.new("TextLabel")
        srcLabel.Size = UDim2.new(1, -125, 1, 0)
        srcLabel.Position = UDim2.new(0, 122, 0, 0)
        srcLabel.BackgroundTransparency = 1
        srcLabel.Text = entry.source
        srcLabel.TextColor3 = Color3.fromRGB(80, 80, 110)
        srcLabel.TextSize = 9
        srcLabel.Font = Enum.Font.Gotham
        srcLabel.TextXAlignment = Enum.TextXAlignment.Right
        srcLabel.TextTruncate = Enum.TextTruncate.AtEnd
        srcLabel.Parent = item
    end
end

-- ============================================
-- FLASH NOTIFICATION (saat luck berubah)
-- ============================================
function flashNotification(gui, oldVal, newVal)
    local flash = Instance.new("Frame")
    flash.Size = UDim2.new(1, 0, 1, 0)
    flash.BackgroundColor3 = Color3.fromRGB(255, 220, 0)
    flash.BackgroundTransparency = 0.85
    flash.BorderSizePixel = 0
    flash.ZIndex = 10
    flash.Parent = gui.MainFrame

    local flashCorner = Instance.new("UICorner")
    flashCorner.CornerRadius = UDim.new(0, 14)
    flashCorner.Parent = flash

    TweenService:Create(flash, TweenInfo.new(0.8, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
        BackgroundTransparency = 1
    }):Play()

    task.delay(0.8, function()
        flash:Destroy()
    end)
    
    -- Pulse luck value text
    TweenService:Create(gui.LuckValue, TweenInfo.new(0.15), {
        TextColor3 = Color3.fromRGB(100, 255, 150),
        TextSize = 26
    }):Play()
    
    task.delay(0.3, function()
        TweenService:Create(gui.LuckValue, TweenInfo.new(0.3), {
            TextColor3 = Color3.fromRGB(255, 220, 100),
            TextSize = 22
        }):Play()
    end)
end

-- ============================================
-- CONTINUOUS MONITORING 
-- ============================================
local function startMonitoring(gui)
    -- Monitor untuk value baru yang ditambahkan
    player.ChildAdded:Connect(function(child)
        task.wait(0.5)
        if currentLuck == "Scanning..." or gui.LuckValue.Text:find("Tidak ditemukan") then
            scanForLuck(gui)
        end
    end)
    
    -- Monitor leaderstats baru
    player:WaitForChild("leaderstats", 10)
    local leaderstats = player:FindFirstChild("leaderstats")
    if leaderstats then
        leaderstats.ChildAdded:Connect(function()
            task.wait(0.3)
            scanForLuck(gui)
        end)
    end
    
    -- Periodic re-check setiap 10 detik jika belum ketemu
    task.spawn(function()
        while task.wait(10) do
            if not luckValueObj and gui.LuckValue.Text:find("Tidak ditemukan") then
                scanForLuck(gui)
            end
        end
    end)
end

-- ============================================
-- INITIALIZATION
-- ============================================
local gui = createGUI()

-- Entrance animation
gui.MainFrame.Position = UDim2.new(1, 20, 0, 20)
TweenService:Create(gui.MainFrame, TweenInfo.new(0.6, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
    Position = UDim2.new(1, -280, 0, 20)
}):Play()

-- Rescan button
gui.RescanBtn.MouseButton1Click:Connect(function()
    luckValueObj = nil
    scanForLuck(gui)
end)

-- Mulai scan setelah delay singkat (biar game load dulu)
task.delay(1, function()
    scanForLuck(gui)
    startMonitoring(gui)
end)

-- Scan ulang saat respawn
player.CharacterAdded:Connect(function()
    task.wait(2)
    scanForLuck(gui)
end)

-- Pulsing scan dot animation
task.spawn(function()
    while true do
        if gui.ScanDot.BackgroundColor3 == Color3.fromRGB(255, 200, 0) then
            TweenService:Create(gui.ScanDot, TweenInfo.new(0.5), {
                BackgroundTransparency = 0.5
            }):Play()
            task.wait(0.5)
            TweenService:Create(gui.ScanDot, TweenInfo.new(0.5), {
                BackgroundTransparency = 0
            }):Play()
            task.wait(0.5)
        else
            task.wait(1)
        end
    end
end)

print("[Blox-Scripts] 🍀 Luck Detector loaded untuk Summon Hero!")
print("[Blox-Scripts] Auto-scanning luck values...")
