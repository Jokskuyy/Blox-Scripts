--[[
    ==========================================================
      SUMMON HERO - UPGRADE TRIGGER LOGGER
      Debug script untuk melihat trigger saat tombol upgrade ditekan.
      Blox-Scripts by Jokskuyy
    ==========================================================

    Cara pakai:
    1. Execute script.
    2. Klik tombol ARM NEXT CLICK di panel.
    3. Klik tombol upgrade di game satu kali.
    4. Perhatikan log REMOTE_AFTER_TARGET untuk melihat remote yang terpicu.
    5. Tekan RightBracket untuk show/hide panel.
    6. Drag ikon pojok kanan bawah untuk resize panel.
    7. Copas log via tombol COPY LOG atau seleksi teks log.

    Catatan:
    - Script ini untuk debugging, bukan auto upgrade.
    - Hook remote membutuhkan executor yang support hookmetamethod.
]]

local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")

if not game:IsLoaded() then
    pcall(function()
        game.Loaded:Wait()
    end)
end

local function waitForLocalPlayer(timeoutSeconds)
    local timeout = timeoutSeconds or 15
    local deadline = os.clock() + timeout

    repeat
        if Players.LocalPlayer then
            return Players.LocalPlayer
        end
        task.wait(0.1)
    until os.clock() >= deadline

    return nil
end

local player = waitForLocalPlayer(15)
if not player then
    warn("[UpgradeLogger] LocalPlayer tidak ditemukan (timeout)")
    return
end

local env = (getgenv and getgenv()) or _G
local GLOBAL_KEY = "__UPGRADE_TRIGGER_LOGGER"

if env[GLOBAL_KEY] and type(env[GLOBAL_KEY].Stop) == "function" then
    pcall(function()
        env[GLOBAL_KEY].Stop("reloaded")
    end)
end

local CONFIG = {
    PANEL_TOGGLE_KEY = Enum.KeyCode.RightBracket,
    TRIGGER_WINDOW_SECONDS = 2.0,
    MAX_LOG_LINES_ON_PANEL = 0, -- 0 = tampilkan semua baris di panel
    MAX_LOG_HISTORY = 320,
    LOG_NON_TARGET_UI_CLICKS = false,
    LOG_ALL_REMOTE_CALLS_DEFAULT = false,
    UPGRADE_KEYWORDS = {
        "upgrade",
        "levelup",
        "level up",
        "enhance",
        "strengthen",
        "rankup",
        "rank up",
        "evolve",
        "ascend",
        "tierup",
        "tier up",
        "awaken",
        "awakening",
        "boost",
        "improve",
        "promote",
    },
}

local MIN_PANEL_WIDTH = 420
local MIN_PANEL_HEIGHT = 260
local MAX_PANEL_WIDTH = 900
local MAX_PANEL_HEIGHT = 700

local state = {
    running = true,
    panelVisible = true,
    captureNextClick = false,
    logAllRemoteCalls = CONFIG.LOG_ALL_REMOTE_CALLS_DEFAULT,
    hookMode = "not_installed",
    lastTargetClickAt = -math.huge,
    lastTargetButtonPath = "-",
    lastTargetButtonText = "-",
    lastRemote = "-",
    lastButtonMarkPath = "",
    lastButtonMarkAt = 0,
    totalRemotes = 0,
    totalTargetRemotes = 0,
    logs = {},
    connections = {},
    buttonConnections = setmetatable({}, { __mode = "k" }),
    inNamecall = false,
}

local refs = {}

local REMOTE_METHODS = {
    FireServer = true,
    InvokeServer = true,
    Fire = true,
    Invoke = true,
}

local function trackConnection(conn)
    if conn then
        table.insert(state.connections, conn)
    end
    return conn
end

local function disconnectAllConnections()
    for _, conn in ipairs(state.connections) do
        pcall(function()
            conn:Disconnect()
        end)
    end
    state.connections = {}
end

local function copyToClipboard(text)
    if type(text) ~= "string" or text == "" then
        return false
    end

    if setclipboard then
        local ok = pcall(function()
            setclipboard(text)
        end)
        if ok then return true end
    end

    if toclipboard then
        local ok = pcall(function()
            toclipboard(text)
        end)
        if ok then return true end
    end

    if Clipboard and Clipboard.set then
        local ok = pcall(function()
            Clipboard.set(text)
        end)
        if ok then return true end
    end

    return false
end

local function trimText(value, maxLen)
    local txt = tostring(value or "")
    if #txt <= maxLen then
        return txt
    end
    return string.sub(txt, 1, maxLen) .. "..."
end

local function normalize(text)
    local value = string.lower(tostring(text or ""))
    value = value:gsub("%s+", "")
    return value
end

local function getPlayerGui(waitSeconds)
    local pg = player:FindFirstChild("PlayerGui")
    if pg then
        return pg
    end

    local timeout = waitSeconds or 0
    if timeout <= 0 then
        return nil
    end

    local deadline = os.clock() + timeout
    repeat
        pg = player:FindFirstChild("PlayerGui")
        if pg then
            return pg
        end
        task.wait(0.1)
    until os.clock() >= deadline

    return nil
end

local function getGuiParent(waitSeconds)
    if type(gethui) == "function" then
        local ok, hui = pcall(function()
            return gethui()
        end)
        if ok and typeof(hui) == "Instance" then
            return hui
        end
    end

    return getPlayerGui(waitSeconds)
end

local function safeGetFullName(instance)
    if typeof(instance) ~= "Instance" then
        return tostring(instance)
    end

    local ok, name = pcall(function()
        return instance:GetFullName()
    end)

    if ok then
        return name
    end

    return instance.Name
end

local function getButtonText(btn)
    if not btn or not btn:IsA("GuiButton") then
        return ""
    end

    if btn:IsA("TextButton") then
        return btn.Text or ""
    end

    local label = btn:FindFirstChildWhichIsA("TextLabel", true)
    if label then
        return label.Text or ""
    end

    return ""
end

local function isUpgradeCandidate(btn, text)
    if not btn then
        return false, ""
    end

    local nameLower = string.lower(btn.Name or "")
    local nameNorm = normalize(btn.Name or "")
    local textLower = string.lower(text or "")
    local textNorm = normalize(text or "")

    for _, keyword in ipairs(CONFIG.UPGRADE_KEYWORDS) do
        local kwLower = string.lower(keyword)
        local kwNorm = normalize(keyword)

        if nameLower:find(kwLower, 1, true)
            or nameNorm:find(kwNorm, 1, true)
            or textLower:find(kwLower, 1, true)
            or textNorm:find(kwNorm, 1, true)
        then
            return true, keyword
        end
    end

    return false, ""
end

local function serializeValue(value, depth)
    depth = depth or 0

    local valueType = typeof(value)

    if valueType == "nil" then
        return "nil"
    end

    if valueType == "string" then
        local str = value:gsub("\n", "\\n")
        return '"' .. trimText(str, 70) .. '"'
    end

    if valueType == "number" or valueType == "boolean" then
        return tostring(value)
    end

    if valueType == "Instance" then
        return "<" .. value.ClassName .. ":" .. safeGetFullName(value) .. ">"
    end

    if valueType == "Vector3" or valueType == "Vector2" or valueType == "CFrame" then
        return tostring(value)
    end

    if valueType == "table" then
        if depth >= 2 then
            return "{...}"
        end

        local parts = {}
        local count = 0

        for k, v in pairs(value) do
            count = count + 1
            if count > 4 then
                table.insert(parts, "...")
                break
            end
            table.insert(parts, serializeValue(k, depth + 1) .. "=" .. serializeValue(v, depth + 1))
        end

        return "{" .. table.concat(parts, ", ") .. "}"
    end

    return "<" .. valueType .. ">"
end

local function formatArgs(args)
    if #args == 0 then
        return "[]"
    end

    local out = {}
    local limit = math.min(#args, 6)

    for i = 1, limit do
        out[#out + 1] = serializeValue(args[i], 0)
    end

    if #args > limit then
        out[#out + 1] = "..."
    end

    return "[" .. table.concat(out, ", ") .. "]"
end

local function refreshLogText()
    if not refs.LogText then
        return
    end

    if #state.logs == 0 then
        refs.LogText.Text = "Belum ada log"
        return
    end

    local startIndex = 1
    if CONFIG.MAX_LOG_LINES_ON_PANEL and CONFIG.MAX_LOG_LINES_ON_PANEL > 0 then
        startIndex = math.max(1, #state.logs - CONFIG.MAX_LOG_LINES_ON_PANEL + 1)
    end
    local lines = {}

    for i = startIndex, #state.logs do
        table.insert(lines, state.logs[i])
    end

    refs.LogText.Text = table.concat(lines, "\n")
end

local function refreshStatus()
    if not refs.ModeLabel then
        return
    end

    if state.captureNextClick then
        refs.ModeLabel.Text = "Mode: ARM (klik target sekarang)"
        refs.ModeLabel.TextColor3 = Color3.fromRGB(255, 210, 120)
    else
        refs.ModeLabel.Text = "Mode: Monitoring"
        refs.ModeLabel.TextColor3 = Color3.fromRGB(170, 220, 255)
    end

    refs.TargetLabel.Text = "Target: " .. trimText(state.lastTargetButtonPath, 62)
    refs.HookLabel.Text = "Hook: " .. tostring(state.hookMode)
    refs.RemoteLabel.Text = "Remote: " .. state.totalTargetRemotes .. " in-window / " .. state.totalRemotes .. " total"

    if refs.ToggleRemoteBtn then
        refs.ToggleRemoteBtn.Text = state.logAllRemoteCalls and "LOG ALL REMOTE: ON" or "LOG ALL REMOTE: OFF"
        refs.ToggleRemoteBtn.BackgroundColor3 = state.logAllRemoteCalls and Color3.fromRGB(50, 130, 70) or Color3.fromRGB(48, 60, 88)
    end
end

local function addLog(tag, message)
    local line = "[" .. os.date("%H:%M:%S") .. "] [" .. tostring(tag) .. "] " .. tostring(message)
    print("[UpgradeLogger] " .. line)

    table.insert(state.logs, line)
    while #state.logs > CONFIG.MAX_LOG_HISTORY do
        table.remove(state.logs, 1)
    end

    refreshStatus()
    refreshLogText()
end

local function registerTargetClick(btn, source, explicitText)
    if not btn then
        return
    end

    local now = os.clock()
    local path = safeGetFullName(btn)

    if state.lastButtonMarkPath == path and (now - state.lastButtonMarkAt) < 0.08 then
        return
    end

    state.lastButtonMarkPath = path
    state.lastButtonMarkAt = now
    state.lastTargetClickAt = now
    state.lastTargetButtonPath = path
    state.lastTargetButtonText = explicitText ~= "" and explicitText or "[no text]"
    state.captureNextClick = false

    addLog("TARGET_CLICK", source .. " | " .. path .. " | text=\"" .. trimText(state.lastTargetButtonText, 60) .. "\"")
end

local function createPanel()
    local guiParent = getGuiParent(12)
    if not guiParent then
        warn("[UpgradeLogger] Parent GUI tidak ditemukan")
        return false
    end

    local old = guiParent:FindFirstChild("UpgradeTriggerLogger")
    if old then
        old:Destroy()
    end

    local sg = Instance.new("ScreenGui")
    sg.Name = "UpgradeTriggerLogger"
    sg.ResetOnSpawn = false
    sg.DisplayOrder = 1200
    sg.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
    sg.Parent = guiParent
    refs.ScreenGui = sg

    local main = Instance.new("Frame")
    main.Name = "Main"
    main.Size = UDim2.new(0, 470, 0, 320)
    main.Position = UDim2.new(0, 18, 0.5, -160)
    main.BackgroundColor3 = Color3.fromRGB(11, 16, 26)
    main.BorderSizePixel = 0
    main.Active = true
    main.Draggable = true
    main.Parent = sg
    refs.Main = main

    local mainCorner = Instance.new("UICorner")
    mainCorner.CornerRadius = UDim.new(0, 10)
    mainCorner.Parent = main

    local mainStroke = Instance.new("UIStroke")
    mainStroke.Color = Color3.fromRGB(90, 130, 210)
    mainStroke.Thickness = 1
    mainStroke.Transparency = 0.2
    mainStroke.Parent = main

    local title = Instance.new("TextLabel")
    title.Size = UDim2.new(1, -80, 0, 24)
    title.Position = UDim2.new(0, 10, 0, 8)
    title.BackgroundTransparency = 1
    title.Text = "UPGRADE TRIGGER LOGGER"
    title.TextColor3 = Color3.fromRGB(220, 236, 255)
    title.TextSize = 14
    title.Font = Enum.Font.GothamBold
    title.TextXAlignment = Enum.TextXAlignment.Left
    title.Parent = main

    local hint = Instance.new("TextLabel")
    hint.Size = UDim2.new(1, -20, 0, 14)
    hint.Position = UDim2.new(0, 10, 0, 30)
    hint.BackgroundTransparency = 1
    hint.Text = "ARM NEXT CLICK -> klik upgrade -> cek REMOTE_AFTER_TARGET | drag pojok untuk resize"
    hint.TextColor3 = Color3.fromRGB(120, 150, 190)
    hint.TextSize = 10
    hint.Font = Enum.Font.Gotham
    hint.TextXAlignment = Enum.TextXAlignment.Left
    hint.Parent = main

    local resizeHandle = Instance.new("TextButton")
    resizeHandle.Name = "ResizeHandle"
    resizeHandle.Size = UDim2.new(0, 18, 0, 18)
    resizeHandle.Position = UDim2.new(1, -20, 1, -20)
    resizeHandle.BackgroundColor3 = Color3.fromRGB(58, 84, 128)
    resizeHandle.BorderSizePixel = 0
    resizeHandle.Text = "⇲"
    resizeHandle.TextColor3 = Color3.fromRGB(218, 232, 255)
    resizeHandle.TextSize = 12
    resizeHandle.Font = Enum.Font.GothamBold
    resizeHandle.AutoButtonColor = false
    resizeHandle.ZIndex = 8
    resizeHandle.Parent = main

    local resizeCorner = Instance.new("UICorner")
    resizeCorner.CornerRadius = UDim.new(0, 4)
    resizeCorner.Parent = resizeHandle

    local resizing = false
    local resizeStartMouse = nil
    local resizeStartSize = nil

    resizeHandle.MouseButton1Down:Connect(function()
        resizing = true
        main.Draggable = false
        resizeStartMouse = UserInputService:GetMouseLocation()
        resizeStartSize = main.Size
    end)

    trackConnection(UserInputService.InputChanged:Connect(function(input)
        if not resizing then
            return
        end

        if input.UserInputType ~= Enum.UserInputType.MouseMovement then
            return
        end

        local currentMouse = UserInputService:GetMouseLocation()
        local delta = currentMouse - resizeStartMouse

        local newWidth = math.clamp(
            resizeStartSize.X.Offset + delta.X,
            MIN_PANEL_WIDTH,
            MAX_PANEL_WIDTH
        )
        local newHeight = math.clamp(
            resizeStartSize.Y.Offset + delta.Y,
            MIN_PANEL_HEIGHT,
            MAX_PANEL_HEIGHT
        )

        main.Size = UDim2.new(0, newWidth, 0, newHeight)
    end))

    trackConnection(UserInputService.InputEnded:Connect(function(input)
        if input.UserInputType ~= Enum.UserInputType.MouseButton1 then
            return
        end

        if not resizing then
            return
        end

        resizing = false
        main.Draggable = true
    end))

    local hideBtn = Instance.new("TextButton")
    hideBtn.Size = UDim2.new(0, 28, 0, 20)
    hideBtn.Position = UDim2.new(1, -66, 0, 10)
    hideBtn.BackgroundColor3 = Color3.fromRGB(48, 60, 88)
    hideBtn.BorderSizePixel = 0
    hideBtn.Text = "-"
    hideBtn.TextColor3 = Color3.fromRGB(215, 225, 240)
    hideBtn.TextSize = 14
    hideBtn.Font = Enum.Font.GothamBold
    hideBtn.Parent = main

    local hideCorner = Instance.new("UICorner")
    hideCorner.CornerRadius = UDim.new(0, 4)
    hideCorner.Parent = hideBtn

    local closeBtn = Instance.new("TextButton")
    closeBtn.Size = UDim2.new(0, 28, 0, 20)
    closeBtn.Position = UDim2.new(1, -34, 0, 10)
    closeBtn.BackgroundColor3 = Color3.fromRGB(92, 50, 62)
    closeBtn.BorderSizePixel = 0
    closeBtn.Text = "x"
    closeBtn.TextColor3 = Color3.fromRGB(255, 220, 220)
    closeBtn.TextSize = 12
    closeBtn.Font = Enum.Font.GothamBold
    closeBtn.Parent = main

    local closeCorner = Instance.new("UICorner")
    closeCorner.CornerRadius = UDim.new(0, 4)
    closeCorner.Parent = closeBtn

    local function newActionButton(text, xScale, xOffset)
        local btn = Instance.new("TextButton")
        btn.Size = UDim2.new(0.24, 0, 0, 24)
        btn.Position = UDim2.new(xScale, xOffset, 0, 52)
        btn.BackgroundColor3 = Color3.fromRGB(48, 60, 88)
        btn.BorderSizePixel = 0
        btn.Text = text
        btn.TextColor3 = Color3.fromRGB(220, 236, 255)
        btn.TextSize = 10
        btn.Font = Enum.Font.GothamBold
        btn.Parent = main

        local btnCorner = Instance.new("UICorner")
        btnCorner.CornerRadius = UDim.new(0, 6)
        btnCorner.Parent = btn

        return btn
    end

    refs.ArmBtn = newActionButton("ARM NEXT CLICK", 0, 10)
    refs.ClearBtn = newActionButton("CLEAR", 0.26, 0)
    refs.CopyBtn = newActionButton("COPY LOG", 0.52, -10)
    refs.ToggleRemoteBtn = newActionButton("LOG ALL REMOTE: OFF", 0.78, -20)

    refs.ModeLabel = Instance.new("TextLabel")
    refs.ModeLabel.Size = UDim2.new(1, -20, 0, 14)
    refs.ModeLabel.Position = UDim2.new(0, 10, 0, 82)
    refs.ModeLabel.BackgroundTransparency = 1
    refs.ModeLabel.Text = "Mode: Monitoring"
    refs.ModeLabel.TextColor3 = Color3.fromRGB(170, 220, 255)
    refs.ModeLabel.TextSize = 10
    refs.ModeLabel.Font = Enum.Font.GothamBold
    refs.ModeLabel.TextXAlignment = Enum.TextXAlignment.Left
    refs.ModeLabel.Parent = main

    refs.TargetLabel = Instance.new("TextLabel")
    refs.TargetLabel.Size = UDim2.new(1, -20, 0, 14)
    refs.TargetLabel.Position = UDim2.new(0, 10, 0, 98)
    refs.TargetLabel.BackgroundTransparency = 1
    refs.TargetLabel.Text = "Target: -"
    refs.TargetLabel.TextColor3 = Color3.fromRGB(145, 175, 215)
    refs.TargetLabel.TextSize = 10
    refs.TargetLabel.Font = Enum.Font.Code
    refs.TargetLabel.TextXAlignment = Enum.TextXAlignment.Left
    refs.TargetLabel.TextTruncate = Enum.TextTruncate.AtEnd
    refs.TargetLabel.Parent = main

    refs.HookLabel = Instance.new("TextLabel")
    refs.HookLabel.Size = UDim2.new(1, -20, 0, 14)
    refs.HookLabel.Position = UDim2.new(0, 10, 0, 114)
    refs.HookLabel.BackgroundTransparency = 1
    refs.HookLabel.Text = "Hook: not_installed"
    refs.HookLabel.TextColor3 = Color3.fromRGB(145, 175, 215)
    refs.HookLabel.TextSize = 10
    refs.HookLabel.Font = Enum.Font.Code
    refs.HookLabel.TextXAlignment = Enum.TextXAlignment.Left
    refs.HookLabel.Parent = main

    refs.RemoteLabel = Instance.new("TextLabel")
    refs.RemoteLabel.Size = UDim2.new(1, -20, 0, 14)
    refs.RemoteLabel.Position = UDim2.new(0, 10, 0, 130)
    refs.RemoteLabel.BackgroundTransparency = 1
    refs.RemoteLabel.Text = "Remote: 0 in-window / 0 total"
    refs.RemoteLabel.TextColor3 = Color3.fromRGB(145, 175, 215)
    refs.RemoteLabel.TextSize = 10
    refs.RemoteLabel.Font = Enum.Font.Code
    refs.RemoteLabel.TextXAlignment = Enum.TextXAlignment.Left
    refs.RemoteLabel.Parent = main

    local logFrame = Instance.new("Frame")
    logFrame.Size = UDim2.new(1, -20, 1, -160)
    logFrame.Position = UDim2.new(0, 10, 0, 148)
    logFrame.BackgroundColor3 = Color3.fromRGB(16, 24, 38)
    logFrame.BorderSizePixel = 0
    logFrame.Parent = main

    local logCorner = Instance.new("UICorner")
    logCorner.CornerRadius = UDim.new(0, 6)
    logCorner.Parent = logFrame

    local logStroke = Instance.new("UIStroke")
    logStroke.Color = Color3.fromRGB(60, 86, 132)
    logStroke.Thickness = 1
    logStroke.Transparency = 0.25
    logStroke.Parent = logFrame

    refs.LogText = Instance.new("TextBox")
    refs.LogText.Size = UDim2.new(1, -10, 1, -10)
    refs.LogText.Position = UDim2.new(0, 5, 0, 5)
    refs.LogText.BackgroundTransparency = 1
    refs.LogText.Text = "Belum ada log"
    refs.LogText.TextColor3 = Color3.fromRGB(190, 218, 255)
    refs.LogText.TextSize = 10
    refs.LogText.Font = Enum.Font.Code
    refs.LogText.TextXAlignment = Enum.TextXAlignment.Left
    refs.LogText.TextYAlignment = Enum.TextYAlignment.Top
    refs.LogText.ClearTextOnFocus = false
    refs.LogText.MultiLine = true
    refs.LogText.TextWrapped = false
    refs.LogText.Parent = logFrame

    hideBtn.MouseButton1Click:Connect(function()
        state.panelVisible = false
        main.Visible = false
    end)

    refs.ArmBtn.MouseButton1Click:Connect(function()
        state.captureNextClick = true
        addLog("ARM", "Silakan klik tombol upgrade sekarang")
    end)

    refs.ClearBtn.MouseButton1Click:Connect(function()
        state.logs = {}
        addLog("CLEAR", "Log dibersihkan")
    end)

    refs.CopyBtn.MouseButton1Click:Connect(function()
        local payload = table.concat(state.logs, "\n")
        if payload == "" then
            payload = "[UpgradeLogger] log kosong"
        end

        if copyToClipboard(payload) then
            addLog("COPY", "Log berhasil disalin ke clipboard")
        else
            addLog("COPY", "Clipboard tidak tersedia di executor ini")
        end
    end)

    refs.ToggleRemoteBtn.MouseButton1Click:Connect(function()
        state.logAllRemoteCalls = not state.logAllRemoteCalls
        addLog("MODE", state.logAllRemoteCalls and "Semua remote call akan dilog" or "Hanya remote setelah target click yang dilog")
    end)

    closeBtn.MouseButton1Click:Connect(function()
        if env[GLOBAL_KEY] and type(env[GLOBAL_KEY].Stop) == "function" then
            env[GLOBAL_KEY].Stop("closed")
        end
    end)

    refreshStatus()
    refreshLogText()
    return true
end

local function ensurePanel()
    if refs.ScreenGui and refs.ScreenGui.Parent then
        return true
    end

    return createPanel() == true
end

local function processNamecall(self, ...)
    if not state.running or state.inNamecall then
        return
    end

    if typeof(self) ~= "Instance" then
        return
    end

    local okMethod, method = pcall(function()
        return getnamecallmethod()
    end)

    if not okMethod then
        return
    end

    method = tostring(method)
    if not REMOTE_METHODS[method] then
        return
    end

    if not (self:IsA("RemoteEvent") or self:IsA("RemoteFunction") or self:IsA("BindableEvent") or self:IsA("BindableFunction")) then
        return
    end

    if type(checkcaller) == "function" then
        local okCaller, caller = pcall(function()
            return checkcaller()
        end)

        if okCaller and caller then
            return
        end
    end

    local now = os.clock()
    local delta = now - state.lastTargetClickAt
    local inWindow = delta >= 0 and delta <= CONFIG.TRIGGER_WINDOW_SECONDS

    if not inWindow and not state.logAllRemoteCalls then
        return
    end

    state.inNamecall = true

    local ok, err = pcall(function()
        local args = { ... }
        state.totalRemotes = state.totalRemotes + 1

        if inWindow then
            state.totalTargetRemotes = state.totalTargetRemotes + 1
        end

        state.lastRemote = self.Name .. ":" .. method

        local tag = inWindow and "REMOTE_AFTER_TARGET" or "REMOTE"
        local dtText = string.format("%.3f", math.max(delta, 0))

        addLog(tag,
            self.ClassName .. "." .. method
            .. " | " .. safeGetFullName(self)
            .. " | dt=" .. dtText .. "s"
            .. " | args=" .. formatArgs(args)
        )
    end)

    state.inNamecall = false

    if not ok then
        warn("[UpgradeLogger] processNamecall error: " .. tostring(err))
    end
end

local function installRemoteHook()
    if type(hookmetamethod) ~= "function"
        or type(getnamecallmethod) ~= "function"
        or type(newcclosure) ~= "function"
    then
        state.hookMode = "unsupported"
        addLog("HOOK", "Executor belum support hookmetamethod/getnamecallmethod/newcclosure")
        return false
    end

    local oldNamecall

    local ok, err = pcall(function()
        oldNamecall = hookmetamethod(game, "__namecall", newcclosure(function(self, ...)
            processNamecall(self, ...)
            return oldNamecall(self, ...)
        end))
    end)

    if ok and type(oldNamecall) == "function" then
        state.hookMode = "hookmetamethod"
        addLog("HOOK", "Remote hook aktif via hookmetamethod")
        return true
    end

    state.hookMode = "failed"
    addLog("HOOK", "Gagal pasang hook: " .. tostring(err))
    return false
end

local function attachButton(button)
    if not state.running then
        return
    end

    if not button or not button:IsA("GuiButton") then
        return
    end

    if state.buttonConnections[button] then
        return
    end

    local bucket = {}
    state.buttonConnections[button] = bucket

    local function onInteraction(source)
        if not state.running then
            return
        end

        local text = getButtonText(button)

        if state.captureNextClick then
            registerTargetClick(button, "armed_" .. source, text)
            return
        end

        local matched, keyword = isUpgradeCandidate(button, text)
        if matched then
            registerTargetClick(button, "keyword(" .. keyword .. ")_" .. source, text)
            return
        end

        if CONFIG.LOG_NON_TARGET_UI_CLICKS then
            addLog("UI_CLICK", source .. " | " .. safeGetFullName(button) .. " | text=\"" .. trimText(text, 40) .. "\"")
        end
    end

    local okDown, connDown = pcall(function()
        return button.MouseButton1Down:Connect(function()
            onInteraction("down")
        end)
    end)
    if okDown and connDown then
        table.insert(bucket, connDown)
        trackConnection(connDown)
    end

    local okClick, connClick = pcall(function()
        return button.MouseButton1Click:Connect(function()
            onInteraction("click")
        end)
    end)
    if okClick and connClick then
        table.insert(bucket, connClick)
        trackConnection(connClick)
    end

    local okAncestry, connAncestry = pcall(function()
        return button.AncestryChanged:Connect(function(_, parent)
            if parent then
                return
            end

            local btnConns = state.buttonConnections[button]
            if not btnConns then
                return
            end

            for _, c in ipairs(btnConns) do
                pcall(function()
                    c:Disconnect()
                end)
            end

            state.buttonConnections[button] = nil
        end)
    end)
    if okAncestry and connAncestry then
        table.insert(bucket, connAncestry)
        trackConnection(connAncestry)
    end
end

local function scanButtons()
    local pg = getPlayerGui()
    if not pg then
        return 0
    end

    local count = 0

    for _, obj in ipairs(pg:GetDescendants()) do
        if obj:IsA("GuiButton") then
            attachButton(obj)
            count = count + 1
        end
    end

    return count
end

local function watchButtons()
    local pg = getPlayerGui()

    if not pg then
        addLog("SCAN", "PlayerGui belum siap")
        return
    end

    trackConnection(pg.DescendantAdded:Connect(function(obj)
        if obj:IsA("GuiButton") then
            attachButton(obj)
        end
    end))

    local total = scanButtons()
    addLog("SCAN", "GuiButton terdeteksi: " .. tostring(total))
end

local controller = {}

function controller.Stop(reason)
    if not state.running then
        return
    end

    state.running = false
    disconnectAllConnections()

    if refs.ScreenGui then
        pcall(function()
            refs.ScreenGui:Destroy()
        end)
    end

    refs = {}

    print("[UpgradeLogger] stopped" .. (reason and (" (" .. tostring(reason) .. ")") or ""))

    if env[GLOBAL_KEY] == controller then
        env[GLOBAL_KEY] = nil
    end
end

function controller.ArmNextClick()
    if not state.running then
        return
    end

    state.captureNextClick = true
    addLog("ARM", "Silakan klik tombol upgrade sekarang")
end

function controller.GetLogs()
    return table.concat(state.logs, "\n")
end

env[GLOBAL_KEY] = controller

local panelReady = ensurePanel()
if not panelReady then
    warn("[UpgradeLogger] Panel belum bisa dibuat, menunggu PlayerGui/gethui siap")
end

task.spawn(function()
    if refs.ScreenGui and refs.ScreenGui.Parent then
        return
    end

    for _ = 1, 20 do
        if not state.running then
            return
        end

        if ensurePanel() then
            addLog("GUI", "Panel berhasil dibuat setelah retry")
            return
        end

        task.wait(0.5)
    end
end)

watchButtons()
installRemoteHook()

trackConnection(UserInputService.InputBegan:Connect(function(input, gameProcessed)
    if gameProcessed then
        return
    end

    if input.KeyCode == CONFIG.PANEL_TOGGLE_KEY and refs.Main then
        state.panelVisible = not state.panelVisible
        refs.Main.Visible = state.panelVisible
    end
end))

trackConnection(player.ChildAdded:Connect(function(child)
    if child.Name ~= "PlayerGui" then
        return
    end

    task.delay(0.5, function()
        if not state.running then
            return
        end

        if not (refs.ScreenGui and refs.ScreenGui.Parent) then
            ensurePanel()
        end

        local total = scanButtons()
        addLog("SCAN", "PlayerGui refresh, GuiButton terdeteksi: " .. tostring(total))
    end)
end))

addLog("INFO", "Script aktif. ARM NEXT CLICK lalu klik tombol upgrade")
addLog("INFO", "Toggle panel: " .. tostring(CONFIG.PANEL_TOGGLE_KEY))
