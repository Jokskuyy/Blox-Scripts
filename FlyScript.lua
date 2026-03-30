--[[
    ╔══════════════════════════════════════════╗
    ║          FLY SCRIPT v1.0                 ║
    ║   Toggle On/Off + Speed Control GUI      ║
    ║   Blox-Scripts by Jokskuyy               ║
    ╚══════════════════════════════════════════╝
    
    Cara Pakai:
    - Klik tombol "FLY: OFF" untuk mengaktifkan/menonaktifkan terbang
    - Geser slider untuk mengatur kecepatan terbang (1 - 500)
    - Gunakan WASD / Arrow Keys untuk bergerak saat terbang
    - Spasi untuk naik, Shift untuk turun
    
    Keybind:
    - Tekan F untuk toggle fly (opsional)
]]

-- ============================================
-- SERVICES
-- ============================================
local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

-- ============================================
-- VARIABLES
-- ============================================
local player = Players.LocalPlayer
local mouse = player:GetMouse()

local flying = false
local flySpeed = 50
local MIN_SPEED = 1
local MAX_SPEED = 500

local bodyGyro = nil
local bodyVelocity = nil
local flyConnection = nil

-- ============================================
-- GUI CREATION
-- ============================================
local function createGUI()
    -- Hapus GUI lama jika ada
    if player.PlayerGui:FindFirstChild("FlyGUI") then
        player.PlayerGui:FindFirstChild("FlyGUI"):Destroy()
    end

    local screenGui = Instance.new("ScreenGui")
    screenGui.Name = "FlyGUI"
    screenGui.ResetOnSpawn = false
    screenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
    screenGui.Parent = player.PlayerGui

    -- Main Frame
    local mainFrame = Instance.new("Frame")
    mainFrame.Name = "MainFrame"
    mainFrame.Size = UDim2.new(0, 220, 0, 200)
    mainFrame.Position = UDim2.new(0, 20, 0.5, -100)
    mainFrame.BackgroundColor3 = Color3.fromRGB(20, 20, 30)
    mainFrame.BackgroundTransparency = 0.1
    mainFrame.BorderSizePixel = 0
    mainFrame.Active = true
    mainFrame.Draggable = true
    mainFrame.Parent = screenGui

    local mainCorner = Instance.new("UICorner")
    mainCorner.CornerRadius = UDim.new(0, 12)
    mainCorner.Parent = mainFrame

    local mainStroke = Instance.new("UIStroke")
    mainStroke.Color = Color3.fromRGB(100, 60, 255)
    mainStroke.Thickness = 2
    mainStroke.Transparency = 0.3
    mainStroke.Parent = mainFrame

    -- Gradient accent bar di atas
    local topBar = Instance.new("Frame")
    topBar.Name = "TopBar"
    topBar.Size = UDim2.new(1, 0, 0, 4)
    topBar.Position = UDim2.new(0, 0, 0, 0)
    topBar.BorderSizePixel = 0
    topBar.Parent = mainFrame

    local topBarGradient = Instance.new("UIGradient")
    topBarGradient.Color = ColorSequence.new{
        ColorSequenceKeypoint.new(0, Color3.fromRGB(100, 60, 255)),
        ColorSequenceKeypoint.new(0.5, Color3.fromRGB(180, 80, 255)),
        ColorSequenceKeypoint.new(1, Color3.fromRGB(60, 180, 255))
    }
    topBarGradient.Parent = topBar

    local topBarCorner = Instance.new("UICorner")
    topBarCorner.CornerRadius = UDim.new(0, 12)
    topBarCorner.Parent = topBar

    -- Title
    local title = Instance.new("TextLabel")
    title.Name = "Title"
    title.Size = UDim2.new(1, -20, 0, 30)
    title.Position = UDim2.new(0, 10, 0, 12)
    title.BackgroundTransparency = 1
    title.Text = "✈  FLY SCRIPT"
    title.TextColor3 = Color3.fromRGB(220, 220, 255)
    title.TextSize = 16
    title.Font = Enum.Font.GothamBold
    title.TextXAlignment = Enum.TextXAlignment.Left
    title.Parent = mainFrame

    -- Subtitle / Credits
    local subtitle = Instance.new("TextLabel")
    subtitle.Name = "Subtitle"
    subtitle.Size = UDim2.new(1, -20, 0, 16)
    subtitle.Position = UDim2.new(0, 10, 0, 38)
    subtitle.BackgroundTransparency = 1
    subtitle.Text = "Blox-Scripts • Tekan F untuk toggle"
    subtitle.TextColor3 = Color3.fromRGB(130, 130, 160)
    subtitle.TextSize = 11
    subtitle.Font = Enum.Font.Gotham
    subtitle.TextXAlignment = Enum.TextXAlignment.Left
    subtitle.Parent = mainFrame

    -- Separator
    local separator = Instance.new("Frame")
    separator.Size = UDim2.new(1, -20, 0, 1)
    separator.Position = UDim2.new(0, 10, 0, 58)
    separator.BackgroundColor3 = Color3.fromRGB(60, 60, 80)
    separator.BorderSizePixel = 0
    separator.Parent = mainFrame

    -- ========================================
    -- TOGGLE BUTTON
    -- ========================================
    local toggleContainer = Instance.new("Frame")
    toggleContainer.Name = "ToggleContainer"
    toggleContainer.Size = UDim2.new(1, -20, 0, 36)
    toggleContainer.Position = UDim2.new(0, 10, 0, 68)
    toggleContainer.BackgroundColor3 = Color3.fromRGB(30, 30, 45)
    toggleContainer.BorderSizePixel = 0
    toggleContainer.Parent = mainFrame

    local toggleCorner = Instance.new("UICorner")
    toggleCorner.CornerRadius = UDim.new(0, 8)
    toggleCorner.Parent = toggleContainer

    local toggleLabel = Instance.new("TextLabel")
    toggleLabel.Name = "ToggleLabel"
    toggleLabel.Size = UDim2.new(0.5, 0, 1, 0)
    toggleLabel.Position = UDim2.new(0, 12, 0, 0)
    toggleLabel.BackgroundTransparency = 1
    toggleLabel.Text = "Terbang"
    toggleLabel.TextColor3 = Color3.fromRGB(200, 200, 220)
    toggleLabel.TextSize = 14
    toggleLabel.Font = Enum.Font.GothamMedium
    toggleLabel.TextXAlignment = Enum.TextXAlignment.Left
    toggleLabel.Parent = toggleContainer

    -- Toggle switch background
    local toggleBg = Instance.new("Frame")
    toggleBg.Name = "ToggleBg"
    toggleBg.Size = UDim2.new(0, 50, 0, 24)
    toggleBg.Position = UDim2.new(1, -60, 0.5, -12)
    toggleBg.BackgroundColor3 = Color3.fromRGB(60, 60, 80)
    toggleBg.BorderSizePixel = 0
    toggleBg.Parent = toggleContainer

    local toggleBgCorner = Instance.new("UICorner")
    toggleBgCorner.CornerRadius = UDim.new(1, 0)
    toggleBgCorner.Parent = toggleBg

    -- Toggle circle (knob)
    local toggleKnob = Instance.new("Frame")
    toggleKnob.Name = "ToggleKnob"
    toggleKnob.Size = UDim2.new(0, 20, 0, 20)
    toggleKnob.Position = UDim2.new(0, 2, 0.5, -10)
    toggleKnob.BackgroundColor3 = Color3.fromRGB(180, 180, 200)
    toggleKnob.BorderSizePixel = 0
    toggleKnob.Parent = toggleBg

    local toggleKnobCorner = Instance.new("UICorner")
    toggleKnobCorner.CornerRadius = UDim.new(1, 0)
    toggleKnobCorner.Parent = toggleKnob

    -- Toggle button (invisible, clickable overlay)
    local toggleButton = Instance.new("TextButton")
    toggleButton.Name = "ToggleButton"
    toggleButton.Size = UDim2.new(1, 0, 1, 0)
    toggleButton.BackgroundTransparency = 1
    toggleButton.Text = ""
    toggleButton.Parent = toggleBg

    -- Status label
    local statusLabel = Instance.new("TextLabel")
    statusLabel.Name = "StatusLabel"
    statusLabel.Size = UDim2.new(1, -20, 0, 18)
    statusLabel.Position = UDim2.new(0, 10, 0, 108)
    statusLabel.BackgroundTransparency = 1
    statusLabel.Text = "Status: OFF"
    statusLabel.TextColor3 = Color3.fromRGB(255, 80, 80)
    statusLabel.TextSize = 12
    statusLabel.Font = Enum.Font.GothamMedium
    statusLabel.TextXAlignment = Enum.TextXAlignment.Left
    statusLabel.Parent = mainFrame

    -- ========================================
    -- SPEED CONTROL
    -- ========================================
    local speedTitle = Instance.new("TextLabel")
    speedTitle.Name = "SpeedTitle"
    speedTitle.Size = UDim2.new(0.6, 0, 0, 20)
    speedTitle.Position = UDim2.new(0, 10, 0, 132)
    speedTitle.BackgroundTransparency = 1
    speedTitle.Text = "Kecepatan"
    speedTitle.TextColor3 = Color3.fromRGB(200, 200, 220)
    speedTitle.TextSize = 13
    speedTitle.Font = Enum.Font.GothamMedium
    speedTitle.TextXAlignment = Enum.TextXAlignment.Left
    speedTitle.Parent = mainFrame

    local speedValueLabel = Instance.new("TextLabel")
    speedValueLabel.Name = "SpeedValueLabel"
    speedValueLabel.Size = UDim2.new(0.4, -10, 0, 20)
    speedValueLabel.Position = UDim2.new(0.6, 0, 0, 132)
    speedValueLabel.BackgroundTransparency = 1
    speedValueLabel.Text = tostring(flySpeed)
    speedValueLabel.TextColor3 = Color3.fromRGB(140, 100, 255)
    speedValueLabel.TextSize = 13
    speedValueLabel.Font = Enum.Font.GothamBold
    speedValueLabel.TextXAlignment = Enum.TextXAlignment.Right
    speedValueLabel.Parent = mainFrame

    -- Slider background
    local sliderBg = Instance.new("Frame")
    sliderBg.Name = "SliderBg"
    sliderBg.Size = UDim2.new(1, -20, 0, 8)
    sliderBg.Position = UDim2.new(0, 10, 0, 158)
    sliderBg.BackgroundColor3 = Color3.fromRGB(40, 40, 60)
    sliderBg.BorderSizePixel = 0
    sliderBg.Parent = mainFrame

    local sliderBgCorner = Instance.new("UICorner")
    sliderBgCorner.CornerRadius = UDim.new(1, 0)
    sliderBgCorner.Parent = sliderBg

    -- Slider fill
    local sliderFill = Instance.new("Frame")
    sliderFill.Name = "SliderFill"
    sliderFill.Size = UDim2.new((flySpeed - MIN_SPEED) / (MAX_SPEED - MIN_SPEED), 0, 1, 0)
    sliderFill.BackgroundColor3 = Color3.fromRGB(100, 60, 255)
    sliderFill.BorderSizePixel = 0
    sliderFill.Parent = sliderBg

    local sliderFillCorner = Instance.new("UICorner")
    sliderFillCorner.CornerRadius = UDim.new(1, 0)
    sliderFillCorner.Parent = sliderFill

    local sliderFillGradient = Instance.new("UIGradient")
    sliderFillGradient.Color = ColorSequence.new{
        ColorSequenceKeypoint.new(0, Color3.fromRGB(100, 60, 255)),
        ColorSequenceKeypoint.new(1, Color3.fromRGB(60, 180, 255))
    }
    sliderFillGradient.Parent = sliderFill

    -- Slider knob
    local sliderKnob = Instance.new("Frame")
    sliderKnob.Name = "SliderKnob"
    sliderKnob.Size = UDim2.new(0, 16, 0, 16)
    sliderKnob.Position = UDim2.new((flySpeed - MIN_SPEED) / (MAX_SPEED - MIN_SPEED), -8, 0.5, -8)
    sliderKnob.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
    sliderKnob.BorderSizePixel = 0
    sliderKnob.ZIndex = 2
    sliderKnob.Parent = sliderBg

    local sliderKnobCorner = Instance.new("UICorner")
    sliderKnobCorner.CornerRadius = UDim.new(1, 0)
    sliderKnobCorner.Parent = sliderKnob

    local sliderKnobStroke = Instance.new("UIStroke")
    sliderKnobStroke.Color = Color3.fromRGB(100, 60, 255)
    sliderKnobStroke.Thickness = 2
    sliderKnobStroke.Parent = sliderKnob

    -- Slider input (invisible clickable area)
    local sliderInput = Instance.new("TextButton")
    sliderInput.Name = "SliderInput"
    sliderInput.Size = UDim2.new(1, 0, 1, 16)
    sliderInput.Position = UDim2.new(0, 0, 0, -8)
    sliderInput.BackgroundTransparency = 1
    sliderInput.Text = ""
    sliderInput.ZIndex = 3
    sliderInput.Parent = sliderBg

    -- Speed presets area
    local presetsFrame = Instance.new("Frame")
    presetsFrame.Name = "PresetsFrame"
    presetsFrame.Size = UDim2.new(1, -20, 0, 22)
    presetsFrame.Position = UDim2.new(0, 10, 0, 172)
    presetsFrame.BackgroundTransparency = 1
    presetsFrame.Parent = mainFrame

    local presetSpeeds = {25, 50, 100, 200, 500}
    local presetWidth = 1 / #presetSpeeds
    for i, speed in ipairs(presetSpeeds) do
        local presetBtn = Instance.new("TextButton")
        presetBtn.Name = "Preset_" .. speed
        presetBtn.Size = UDim2.new(presetWidth, -4, 1, 0)
        presetBtn.Position = UDim2.new(presetWidth * (i - 1), 2, 0, 0)
        presetBtn.BackgroundColor3 = Color3.fromRGB(40, 40, 60)
        presetBtn.BorderSizePixel = 0
        presetBtn.Text = tostring(speed)
        presetBtn.TextColor3 = Color3.fromRGB(160, 160, 180)
        presetBtn.TextSize = 10
        presetBtn.Font = Enum.Font.GothamMedium
        presetBtn.Parent = presetsFrame

        local presetCorner = Instance.new("UICorner")
        presetCorner.CornerRadius = UDim.new(0, 4)
        presetCorner.Parent = presetBtn

        presetBtn.MouseButton1Click:Connect(function()
            flySpeed = speed
            speedValueLabel.Text = tostring(flySpeed)
            local ratio = (flySpeed - MIN_SPEED) / (MAX_SPEED - MIN_SPEED)
            sliderFill.Size = UDim2.new(ratio, 0, 1, 0)
            sliderKnob.Position = UDim2.new(ratio, -8, 0.5, -8)

            -- Highlight active preset
            for _, btn in ipairs(presetsFrame:GetChildren()) do
                if btn:IsA("TextButton") then
                    btn.BackgroundColor3 = Color3.fromRGB(40, 40, 60)
                    btn.TextColor3 = Color3.fromRGB(160, 160, 180)
                end
            end
            presetBtn.BackgroundColor3 = Color3.fromRGB(100, 60, 255)
            presetBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
        end)

        -- Hover effect
        presetBtn.MouseEnter:Connect(function()
            if presetBtn.BackgroundColor3 ~= Color3.fromRGB(100, 60, 255) then
                TweenService:Create(presetBtn, TweenInfo.new(0.15), {
                    BackgroundColor3 = Color3.fromRGB(55, 55, 75)
                }):Play()
            end
        end)

        presetBtn.MouseLeave:Connect(function()
            if presetBtn.BackgroundColor3 ~= Color3.fromRGB(100, 60, 255) then
                TweenService:Create(presetBtn, TweenInfo.new(0.15), {
                    BackgroundColor3 = Color3.fromRGB(40, 40, 60)
                }):Play()
            end
        end)
    end

    -- ========================================
    -- SLIDER LOGIC
    -- ========================================
    local draggingSlider = false

    local function updateSlider(inputX)
        local sliderAbsPos = sliderBg.AbsolutePosition.X
        local sliderAbsSize = sliderBg.AbsoluteSize.X
        local relativeX = math.clamp((inputX - sliderAbsPos) / sliderAbsSize, 0, 1)
        
        flySpeed = math.floor(MIN_SPEED + relativeX * (MAX_SPEED - MIN_SPEED))
        flySpeed = math.clamp(flySpeed, MIN_SPEED, MAX_SPEED)
        
        speedValueLabel.Text = tostring(flySpeed)
        sliderFill.Size = UDim2.new(relativeX, 0, 1, 0)
        sliderKnob.Position = UDim2.new(relativeX, -8, 0.5, -8)

        -- Reset preset highlights
        for _, btn in ipairs(presetsFrame:GetChildren()) do
            if btn:IsA("TextButton") then
                btn.BackgroundColor3 = Color3.fromRGB(40, 40, 60)
                btn.TextColor3 = Color3.fromRGB(160, 160, 180)
            end
        end
    end

    sliderInput.MouseButton1Down:Connect(function()
        draggingSlider = true
        updateSlider(mouse.X)
    end)

    UserInputService.InputChanged:Connect(function(input)
        if draggingSlider and input.UserInputType == Enum.UserInputType.MouseMovement then
            updateSlider(input.Position.X)
        end
    end)

    UserInputService.InputEnded:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 then
            draggingSlider = false
        end
    end)

    -- ========================================
    -- RETURN GUI ELEMENTS
    -- ========================================
    return {
        ToggleButton = toggleButton,
        ToggleBg = toggleBg,
        ToggleKnob = toggleKnob,
        StatusLabel = statusLabel,
        MainFrame = mainFrame,
    }
end

-- ============================================
-- FLY MECHANICS
-- ============================================
local function startFlying()
    local character = player.Character
    if not character then return end
    
    local humanoid = character:FindFirstChildOfClass("Humanoid")
    local rootPart = character:FindFirstChild("HumanoidRootPart")
    if not humanoid or not rootPart then return end

    -- Buat BodyGyro untuk rotasi
    bodyGyro = Instance.new("BodyGyro")
    bodyGyro.P = 9e4
    bodyGyro.MaxTorque = Vector3.new(9e9, 9e9, 9e9)
    bodyGyro.CFrame = rootPart.CFrame
    bodyGyro.Parent = rootPart

    -- Buat BodyVelocity untuk pergerakan
    bodyVelocity = Instance.new("BodyVelocity")
    bodyVelocity.Velocity = Vector3.new(0, 0, 0)
    bodyVelocity.MaxForce = Vector3.new(9e9, 9e9, 9e9)
    bodyVelocity.Parent = rootPart

    -- Nonaktifkan gravity secara efektif
    humanoid.PlatformStand = true

    -- Loop pergerakan
    flyConnection = RunService.RenderStepped:Connect(function()
        if not flying then return end
        if not character or not character.Parent then
            stopFlying()
            return
        end
        
        rootPart = character:FindFirstChild("HumanoidRootPart")
        if not rootPart then
            stopFlying()
            return
        end

        local camera = workspace.CurrentCamera
        local direction = Vector3.new(0, 0, 0)

        -- Kontrol arah
        if UserInputService:IsKeyDown(Enum.KeyCode.W) or UserInputService:IsKeyDown(Enum.KeyCode.Up) then
            direction = direction + camera.CFrame.LookVector
        end
        if UserInputService:IsKeyDown(Enum.KeyCode.S) or UserInputService:IsKeyDown(Enum.KeyCode.Down) then
            direction = direction - camera.CFrame.LookVector
        end
        if UserInputService:IsKeyDown(Enum.KeyCode.A) or UserInputService:IsKeyDown(Enum.KeyCode.Left) then
            direction = direction - camera.CFrame.RightVector
        end
        if UserInputService:IsKeyDown(Enum.KeyCode.D) or UserInputService:IsKeyDown(Enum.KeyCode.Right) then
            direction = direction + camera.CFrame.RightVector
        end
        if UserInputService:IsKeyDown(Enum.KeyCode.Space) then
            direction = direction + Vector3.new(0, 1, 0)
        end
        if UserInputService:IsKeyDown(Enum.KeyCode.LeftShift) or UserInputService:IsKeyDown(Enum.KeyCode.RightShift) then
            direction = direction - Vector3.new(0, 1, 0)
        end

        -- Normalisasi dan terapkan kecepatan
        if direction.Magnitude > 0 then
            direction = direction.Unit
        end

        bodyVelocity.Velocity = direction * flySpeed
        bodyGyro.CFrame = camera.CFrame
    end)
end

local function stopFlying()
    local character = player.Character
    if character then
        local humanoid = character:FindFirstChildOfClass("Humanoid")
        if humanoid then
            humanoid.PlatformStand = false
        end
    end

    if bodyGyro then
        bodyGyro:Destroy()
        bodyGyro = nil
    end
    if bodyVelocity then
        bodyVelocity:Destroy()
        bodyVelocity = nil
    end
    if flyConnection then
        flyConnection:Disconnect()
        flyConnection = nil
    end
end

-- ============================================
-- TOGGLE FLY
-- ============================================
local function toggleFly(guiElements)
    flying = not flying
    
    local tweenInfo = TweenInfo.new(0.25, Enum.EasingStyle.Quart, Enum.EasingDirection.Out)
    
    if flying then
        -- Animasi toggle ON
        TweenService:Create(guiElements.ToggleBg, tweenInfo, {
            BackgroundColor3 = Color3.fromRGB(100, 60, 255)
        }):Play()
        TweenService:Create(guiElements.ToggleKnob, tweenInfo, {
            Position = UDim2.new(1, -22, 0.5, -10),
            BackgroundColor3 = Color3.fromRGB(255, 255, 255)
        }):Play()
        
        guiElements.StatusLabel.Text = "Status: ✈ TERBANG"
        guiElements.StatusLabel.TextColor3 = Color3.fromRGB(100, 255, 150)
        
        startFlying()
    else
        -- Animasi toggle OFF
        TweenService:Create(guiElements.ToggleBg, tweenInfo, {
            BackgroundColor3 = Color3.fromRGB(60, 60, 80)
        }):Play()
        TweenService:Create(guiElements.ToggleKnob, tweenInfo, {
            Position = UDim2.new(0, 2, 0.5, -10),
            BackgroundColor3 = Color3.fromRGB(180, 180, 200)
        }):Play()
        
        guiElements.StatusLabel.Text = "Status: OFF"
        guiElements.StatusLabel.TextColor3 = Color3.fromRGB(255, 80, 80)
        
        stopFlying()
    end
end

-- ============================================
-- INITIALIZATION
-- ============================================
local guiElements = createGUI()

-- Toggle button click
guiElements.ToggleButton.MouseButton1Click:Connect(function()
    toggleFly(guiElements)
end)

-- Keybind F untuk toggle
UserInputService.InputBegan:Connect(function(input, gameProcessed)
    if gameProcessed then return end
    if input.KeyCode == Enum.KeyCode.F then
        toggleFly(guiElements)
    end
end)

-- Handle respawn - auto re-create fly jika masih aktif
player.CharacterAdded:Connect(function(character)
    character:WaitForChild("HumanoidRootPart")
    task.wait(0.5)
    
    if flying then
        startFlying()
    end
end)

-- Entrance animation
guiElements.MainFrame.Position = UDim2.new(-0.2, 0, 0.5, -100)
TweenService:Create(guiElements.MainFrame, TweenInfo.new(0.6, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
    Position = UDim2.new(0, 20, 0.5, -100)
}):Play()

print("[Blox-Scripts] ✈ Fly Script loaded! Tekan F atau klik toggle untuk terbang.")
