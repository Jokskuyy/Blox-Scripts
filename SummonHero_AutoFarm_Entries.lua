--[[
    ==========================================================
      SUMMON HERO - AUTO FARM ENTRIES
      Standalone script by Jokskuyy (Blox-Scripts)
    ==========================================================

    Tujuan:
    - Mulai stage dari tombol Ready.
    - Saat RoundEnd:
      - Jika EntriesLeft > 0  -> klik RestartButton
      - Jika EntriesLeft = 0  -> klik NextStageButton
      - Jika EntriesLeft tidak terbaca -> klik NextStageButton
      - Jika NextStageButton tidak ada -> klik LobbyButton

    Path utama yang dipakai:
    - RoundEnd > Frame > Contents > ButtonsHolder > Buttons > RestartButton
    - RoundEnd > Frame > Contents > ButtonsHolder > Buttons > NextStageButton
    - RoundEnd > Frame > Contents > ButtonsHolder > Buttons > LobbyButton
    - EndlessWaveInfo > Frame > Status > ReadyButton
    - WaveInfo > Frame > Status > ReadyButton

    Catatan:
    - Script ini standalone (tidak tergantung BloxHub UI).
    - Script lama dengan nama global sama akan dihentikan dulu agar tidak double loop.
]]

local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local GuiService = game:GetService("GuiService")

local player = Players.LocalPlayer

local CONFIG = {
    AUTO_START = true,
    AUTO_REQUEUE_ON_TELEPORT = true,
    REQUEUE_URL = "https://raw.githubusercontent.com/Jokskuyy/Blox-Scripts/main/SummonHero_AutoFarm_Entries.lua",
    SHOW_STATUS_GUI = true,
    GUI_LOG_LINES = 12,
    MAX_STORED_LOGS = 300,
    STATUS_GUI_TOGGLE_KEY = Enum.KeyCode.RightControl,
    ENABLE_START_BUTTON_FALLBACK = true,
    READY_RECLICK_DELAY = 8.0,
    READY_WAIT_START_WINDOW = 2.0,
    READY_ACTIONABLE_RETRY_AFTER = 9.0,
    READY_LATCH_TIMEOUT = 45.0,
    READY_TARGET_SCAN_LIMIT = 8,
    READY_HOVER_WIGGLE_RADIUS = 8,
    READY_HOVER_WIGGLE_DELAY = 0.025,
    READY_CLICK_HOLD = 0.06,
    READY_ENABLE_EXECUTOR_MOUSE = true,
    READY_EXECUTOR_MOUSE_WIGGLE = 5,
    READY_SWEEP_POINTS = {
        {0.20, 0.50},
        {0.50, 0.50},
        {0.80, 0.50},
        {0.50, 0.30},
        {0.50, 0.70},
    },
    READY_PROBE_PARENT_LEVELS = 2,
    READY_PROBE_SIBLING_LIMIT = 1,
    READY_RAPID_FIRE_ENABLED = true,
    READY_RAPID_FIRE_INTERVAL = 1.0,
    READY_RAPID_FIRE_STEP_DELAY = 0.04,
    READY_RAPID_FIRE_METHODS = {
        "executor_mouse_click",
        "hover_virtual_input",
        "sweep_virtual_input",
        "virtual_input",
        "getconnections_click",
        "getconnections_activated",
        "fireclick",
        "fire_remote_from_connections",
    },
    READY_CLICK_METHODS = {
        "executor_mouse_click",
        "hover_virtual_input",
        "sweep_virtual_input",
        "virtual_input",
        "mouse_down_up",
        "activate",
        "firesignal_click",
        "firesignal_activated",
        "getconnections_click",
        "getconnections_activated",
        "fireclick",
        "fire_remote_from_connections",
    },
    LOOP_INTERVAL = 0.35,
    ACTION_COOLDOWN = 1.0,
    CLICK_RETRY = 2,
    CLICK_RETRY_WAIT = 0.2,
    STOP_ON_LOBBY = true,
}

local state = {
    running = false,
    finished = false,
    lastActionAt = 0,
    lastLogAt = {},
    totalReadyClicks = 0,
    totalStartClicks = 0,
    totalRestartClicks = 0,
    totalNextClicks = 0,
    totalLobbyClicks = 0,
    totalReadyRapidBursts = 0,
    lastReadyClickAt = 0,
    lastReadyRapidAt = 0,
    readyPendingUntil = 0,
    readyLatched = false,
    readyLatchedAt = 0,
    lastReadyTargetPath = "",
    lastEntriesLeft = nil,
    lastEntriesSource = "-",
    lastAction = "Idle",
    uiLogs = {},
    connections = {},
}

local env = (getgenv and getgenv()) or _G
local GLOBAL_KEY = "__SUMMONHERO_AUTOFARM_ENTRIES"
local refs = {}

local function copyToClipboard(text)
    if type(text) ~= "string" or text == "" then
        return false
    end

    if setclipboard then
        local ok = pcall(function() setclipboard(text) end)
        if ok then return true end
    end

    if toclipboard then
        local ok = pcall(function() toclipboard(text) end)
        if ok then return true end
    end

    if Clipboard and Clipboard.set then
        local ok = pcall(function() Clipboard.set(text) end)
        if ok then return true end
    end

    return false
end

local function refreshLogGui()
    if not refs.LogText then
        return
    end

    if #state.uiLogs == 0 then
        refs.LogText.Text = "Belum ada log"
        return
    end

    local startIndex = math.max(1, #state.uiLogs - CONFIG.GUI_LOG_LINES + 1)
    local lines = {}
    for i = startIndex, #state.uiLogs do
        table.insert(lines, state.uiLogs[i])
    end

    refs.LogText.Text = table.concat(lines, "\n")
end

local function log(msg)
    local line = "[" .. os.date("%H:%M:%S") .. "] " .. tostring(msg)
    print("[AutoFarm-Entries]" .. line)

    table.insert(state.uiLogs, line)
    while #state.uiLogs > CONFIG.MAX_STORED_LOGS do
        table.remove(state.uiLogs, 1)
    end
    refreshLogGui()
end

local function throttledLog(key, interval, msg)
    local now = os.clock()
    local last = state.lastLogAt[key] or 0
    if (now - last) >= interval then
        state.lastLogAt[key] = now
        log(msg)
    end
end

local function getPlayerGui()
    return player and player:FindFirstChild("PlayerGui")
end

local function getAllQueueTeleportFunctions()
    local results = {}
    local seen = {}

    local function tryAdd(fn, label)
        if type(fn) == "function" and not seen[fn] then
            seen[fn] = true
            table.insert(results, {func = fn, name = label})
        end
    end

    -- Global functions (berbagai executor)
    pcall(function() tryAdd(queue_on_teleport, "queue_on_teleport") end)
    pcall(function() tryAdd(queueonteleport, "queueonteleport") end)
    pcall(function() tryAdd(queue_on_tp, "queue_on_tp") end)

    -- Executor-specific
    pcall(function() if syn then tryAdd(syn.queue_on_teleport, "syn.queue_on_teleport") end end)
    pcall(function() if fluxus then tryAdd(fluxus.queue_on_teleport, "fluxus.queue_on_teleport") end end)
    pcall(function() if krnl then tryAdd(krnl.queue_on_teleport, "krnl.queue_on_teleport") end end)
    pcall(function() if getexecutorname then tryAdd(queue_on_teleport, "executor:" .. tostring(getexecutorname())) end end)

    return results
end

local function buildRequeueSource()
    local url = CONFIG.REQUEUE_URL
    if type(url) ~= "string" or url == "" then
        url = "https://raw.githubusercontent.com/Jokskuyy/Blox-Scripts/main/SummonHero_AutoFarm_Entries.lua"
    end

    -- Script yang lebih robust: tunggu game load, retry HttpGet, fallback loadfile
    local source = [[
repeat task.wait(1) until game:IsLoaded()
repeat task.wait(0.5) until game:GetService("Players").LocalPlayer
task.wait(2)

local url = "]] .. url .. [["
local maxRetries = 5
local src = nil

for i = 1, maxRetries do
    local ok, result = pcall(function()
        return game:HttpGet(url)
    end)
    if ok and type(result) == "string" and #result > 100 then
        src = result
        break
    end
    task.wait(2)
end

if src then
    local fn, err = loadstring(src)
    if fn then
        fn()
    else
        warn("[AutoFarm-Entries] loadstring error: " .. tostring(err))
    end
else
    warn("[AutoFarm-Entries] Failed to fetch script after " .. tostring(maxRetries) .. " retries")
end
]]
    return source
end

local _queueAlreadySet = false

local function setupTeleportRequeue()
    if not CONFIG.AUTO_REQUEUE_ON_TELEPORT then
        return
    end

    if _queueAlreadySet then
        log("Queue sudah di-set sebelumnya, skip re-queue")
        return
    end

    local queueFuncs = getAllQueueTeleportFunctions()
    if #queueFuncs == 0 then
        log("queue_on_teleport tidak didukung executor")
        return
    end

    local source = buildRequeueSource()
    local successNames = {}

    for _, entry in ipairs(queueFuncs) do
        local ok, err = pcall(function()
            entry.func(source)
        end)
        if ok then
            table.insert(successNames, entry.name)
        else
            log("Queue gagal via " .. entry.name .. ": " .. tostring(err))
        end
    end

    if #successNames > 0 then
        _queueAlreadySet = true
        log("Auto re-execute aktif setelah teleport via: " .. table.concat(successNames, ", "))
    else
        log("Semua queue_on_teleport gagal, auto re-execute tidak aktif")
    end
end

local function trackConnection(conn)
    if conn then
        table.insert(state.connections, conn)
    end
    return conn
end

local function disconnectConnections()
    for _, conn in ipairs(state.connections) do
        pcall(function()
            conn:Disconnect()
        end)
    end
    state.connections = {}
end

local function destroyStatusGui()
    if refs.ScreenGui then
        pcall(function()
            refs.ScreenGui:Destroy()
        end)
    end
    refs = {}
end

local function createStatusGui()
    if not CONFIG.SHOW_STATUS_GUI then
        return
    end

    local pg = getPlayerGui()
    if not pg then
        return
    end

    local old = pg:FindFirstChild("AutoFarmEntriesStatus")
    if old then
        old:Destroy()
    end

    local sg = Instance.new("ScreenGui")
    sg.Name = "AutoFarmEntriesStatus"
    sg.ResetOnSpawn = false
    sg.DisplayOrder = 1200
    sg.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
    sg.Parent = pg
    refs.ScreenGui = sg

    local main = Instance.new("Frame")
    main.Name = "Main"
    main.Size = UDim2.new(0, 360, 0, 262)
    main.Position = UDim2.new(1, -360, 0, 40)
    main.BackgroundColor3 = Color3.fromRGB(12, 16, 28)
    main.BorderSizePixel = 0
    main.Active = true
    main.Draggable = true
    main.Parent = sg
    refs.Main = main

    local mainCorner = Instance.new("UICorner")
    mainCorner.CornerRadius = UDim.new(0, 10)
    mainCorner.Parent = main

    local mainStroke = Instance.new("UIStroke")
    mainStroke.Color = Color3.fromRGB(65, 125, 255)
    mainStroke.Thickness = 1
    mainStroke.Transparency = 0.2
    mainStroke.Parent = main

    local title = Instance.new("TextLabel")
    title.Size = UDim2.new(1, -36, 0, 24)
    title.Position = UDim2.new(0, 10, 0, 6)
    title.BackgroundTransparency = 1
    title.Text = "AUTO FARM ENTRIES"
    title.TextColor3 = Color3.fromRGB(220, 235, 255)
    title.TextSize = 14
    title.Font = Enum.Font.GothamBold
    title.TextXAlignment = Enum.TextXAlignment.Left
    title.Parent = main

    local closeBtn = Instance.new("TextButton")
    closeBtn.Size = UDim2.new(0, 20, 0, 20)
    closeBtn.Position = UDim2.new(1, -24, 0, 8)
    closeBtn.BackgroundColor3 = Color3.fromRGB(48, 60, 88)
    closeBtn.BorderSizePixel = 0
    closeBtn.Text = "x"
    closeBtn.TextColor3 = Color3.fromRGB(215, 225, 240)
    closeBtn.TextSize = 13
    closeBtn.Font = Enum.Font.GothamBold
    closeBtn.Parent = main

    local closeCorner = Instance.new("UICorner")
    closeCorner.CornerRadius = UDim.new(0, 4)
    closeCorner.Parent = closeBtn

    closeBtn.MouseButton1Click:Connect(function()
        main.Visible = false
    end)

    local function createRow(y, key)
        local keyLabel = Instance.new("TextLabel")
        keyLabel.Size = UDim2.new(0, 110, 0, 16)
        keyLabel.Position = UDim2.new(0, 10, 0, y)
        keyLabel.BackgroundTransparency = 1
        keyLabel.Text = key
        keyLabel.TextColor3 = Color3.fromRGB(120, 145, 185)
        keyLabel.TextSize = 11
        keyLabel.Font = Enum.Font.Gotham
        keyLabel.TextXAlignment = Enum.TextXAlignment.Left
        keyLabel.Parent = main

        local valLabel = Instance.new("TextLabel")
        valLabel.Size = UDim2.new(1, -130, 0, 16)
        valLabel.Position = UDim2.new(0, 120, 0, y)
        valLabel.BackgroundTransparency = 1
        valLabel.Text = "-"
        valLabel.TextColor3 = Color3.fromRGB(220, 235, 255)
        valLabel.TextSize = 11
        valLabel.Font = Enum.Font.GothamBold
        valLabel.TextXAlignment = Enum.TextXAlignment.Left
        valLabel.TextTruncate = Enum.TextTruncate.AtEnd
        valLabel.Parent = main

        return valLabel
    end

    refs.StateVal = createRow(34, "State")
    refs.ActionVal = createRow(52, "Action")
    refs.EntriesVal = createRow(70, "Entries")
    refs.SourceVal = createRow(88, "Source")

    local count = Instance.new("TextLabel")
    count.Size = UDim2.new(1, -20, 0, 18)
    count.Position = UDim2.new(0, 10, 0, 110)
    count.BackgroundTransparency = 1
    count.Text = "Rdy:0 | RF:0 | Str:0 | Rst:0 | Nxt:0 | Lby:0"
    count.TextColor3 = Color3.fromRGB(255, 225, 150)
    count.TextSize = 11
    count.Font = Enum.Font.GothamBold
    count.TextXAlignment = Enum.TextXAlignment.Left
    count.Parent = main
    refs.CountVal = count

    local toggleKeyName = tostring(CONFIG.STATUS_GUI_TOGGLE_KEY):gsub("Enum.KeyCode.", "")
    local hint = Instance.new("TextLabel")
    hint.Size = UDim2.new(1, -20, 0, 14)
    hint.Position = UDim2.new(0, 10, 0, 132)
    hint.BackgroundTransparency = 1
    hint.Text = "Toggle GUI: " .. toggleKeyName
    hint.TextColor3 = Color3.fromRGB(100, 120, 150)
    hint.TextSize = 10
    hint.Font = Enum.Font.Gotham
    hint.TextXAlignment = Enum.TextXAlignment.Left
    hint.Parent = main

    local logTitle = Instance.new("TextLabel")
    logTitle.Size = UDim2.new(0.45, 0, 0, 14)
    logTitle.Position = UDim2.new(0, 10, 0, 150)
    logTitle.BackgroundTransparency = 1
    logTitle.Text = "Runtime Log"
    logTitle.TextColor3 = Color3.fromRGB(120, 145, 185)
    logTitle.TextSize = 10
    logTitle.Font = Enum.Font.GothamBold
    logTitle.TextXAlignment = Enum.TextXAlignment.Left
    logTitle.Parent = main

    local copyBtn = Instance.new("TextButton")
    copyBtn.Size = UDim2.new(0, 70, 0, 16)
    copyBtn.Position = UDim2.new(1, -82, 0, 149)
    copyBtn.BackgroundColor3 = Color3.fromRGB(45, 66, 106)
    copyBtn.BorderSizePixel = 0
    copyBtn.Text = "Copy"
    copyBtn.TextColor3 = Color3.fromRGB(222, 236, 255)
    copyBtn.TextSize = 10
    copyBtn.Font = Enum.Font.GothamBold
    copyBtn.Parent = main

    local copyCorner = Instance.new("UICorner")
    copyCorner.CornerRadius = UDim.new(0, 4)
    copyCorner.Parent = copyBtn

    local clearBtn = Instance.new("TextButton")
    clearBtn.Size = UDim2.new(0, 54, 0, 16)
    clearBtn.Position = UDim2.new(1, -138, 0, 149)
    clearBtn.BackgroundColor3 = Color3.fromRGB(58, 52, 78)
    clearBtn.BorderSizePixel = 0
    clearBtn.Text = "Clear"
    clearBtn.TextColor3 = Color3.fromRGB(222, 236, 255)
    clearBtn.TextSize = 10
    clearBtn.Font = Enum.Font.GothamBold
    clearBtn.Parent = main

    local clearCorner = Instance.new("UICorner")
    clearCorner.CornerRadius = UDim.new(0, 4)
    clearCorner.Parent = clearBtn

    local logFrame = Instance.new("Frame")
    logFrame.Size = UDim2.new(1, -20, 0, 96)
    logFrame.Position = UDim2.new(0, 10, 0, 166)
    logFrame.BackgroundColor3 = Color3.fromRGB(18, 24, 40)
    logFrame.BorderSizePixel = 0
    logFrame.Parent = main

    local logCorner = Instance.new("UICorner")
    logCorner.CornerRadius = UDim.new(0, 6)
    logCorner.Parent = logFrame

    local logStroke = Instance.new("UIStroke")
    logStroke.Color = Color3.fromRGB(55, 80, 130)
    logStroke.Thickness = 1
    logStroke.Transparency = 0.45
    logStroke.Parent = logFrame

    local logText = Instance.new("TextLabel")
    logText.Size = UDim2.new(1, -8, 1, -8)
    logText.Position = UDim2.new(0, 4, 0, 4)
    logText.BackgroundTransparency = 1
    logText.Text = "Belum ada log"
    logText.TextColor3 = Color3.fromRGB(205, 220, 245)
    logText.TextSize = 10
    logText.Font = Enum.Font.Code
    logText.TextXAlignment = Enum.TextXAlignment.Left
    logText.TextYAlignment = Enum.TextYAlignment.Top
    logText.TextWrapped = false
    logText.TextTruncate = Enum.TextTruncate.None
    logText.Parent = logFrame
    refs.LogText = logText

    copyBtn.MouseButton1Click:Connect(function()
        if #state.uiLogs == 0 then
            log("Copy log: belum ada isi")
            return
        end

        local payload = table.concat(state.uiLogs, "\n")
        if copyToClipboard(payload) then
            log("Log berhasil disalin ke clipboard (" .. tostring(#state.uiLogs) .. " baris)")
        else
            log("Copy log gagal: clipboard tidak didukung executor")
        end
    end)

    clearBtn.MouseButton1Click:Connect(function()
        state.uiLogs = {}
        refreshLogGui()
        log("Log dibersihkan")
    end)

    trackConnection(UserInputService.InputBegan:Connect(function(inp, gpe)
        if gpe then
            return
        end
        if inp.KeyCode == CONFIG.STATUS_GUI_TOGGLE_KEY and refs.Main then
            refs.Main.Visible = not refs.Main.Visible
        end
    end))

    refreshLogGui()
end

local function refreshStatusGui()
    if not refs.Main then
        return
    end

    local mode
    if state.finished then
        mode = "FINISHED"
    elseif state.running then
        mode = "RUNNING"
    else
        mode = "PAUSED"
    end

    refs.StateVal.Text = mode
    refs.ActionVal.Text = state.lastAction or "-"
    refs.EntriesVal.Text = (state.lastEntriesLeft ~= nil) and tostring(state.lastEntriesLeft) or "-"
    refs.SourceVal.Text = state.lastEntriesSource or "-"
    refs.CountVal.Text = string.format(
        "Rdy:%d | RF:%d | Str:%d | Rst:%d | Nxt:%d | Lby:%d",
        state.totalReadyClicks,
        state.totalReadyRapidBursts,
        state.totalStartClicks,
        state.totalRestartClicks,
        state.totalNextClicks,
        state.totalLobbyClicks
    )
end

local function setAction(text)
    state.lastAction = text
    refreshStatusGui()
end

local function isGuiActuallyVisible(guiObj)
    if not guiObj or not guiObj:IsA("GuiObject") then
        return false
    end
    if guiObj.AbsoluteSize.X <= 0 or guiObj.AbsoluteSize.Y <= 0 then
        return false
    end

    local current = guiObj
    while current do
        if current:IsA("GuiObject") and not current.Visible then
            return false
        end
        if current:IsA("ScreenGui") and not current.Enabled then
            return false
        end
        current = current.Parent
    end
    return true
end

local function findPathFromRootName(rootName, pathSegments)
    local pg = getPlayerGui()
    if not pg then
        return nil
    end

    for _, obj in ipairs(pg:GetDescendants()) do
        if obj.Name == rootName then
            local current = obj
            local ok = true
            for _, segment in ipairs(pathSegments) do
                current = current:FindFirstChild(segment)
                if not current then
                    ok = false
                    break
                end
            end
            if ok then
                return current
            end
        end
    end

    return nil
end

local function getRoundEndRoot()
    local pg = getPlayerGui()
    if not pg then
        return nil
    end

    for _, gui in ipairs(pg:GetChildren()) do
        if gui:IsA("ScreenGui") then
            local roundEnd = gui:FindFirstChild("RoundEnd", true)
            if roundEnd then
                return roundEnd
            end
        end
    end

    return nil
end

local function getRoundEndFrame()
    local roundEnd = getRoundEndRoot()
    if not roundEnd then
        return nil
    end
    return roundEnd:FindFirstChild("Frame")
end

local function getRoundEndContents()
    local frame = getRoundEndFrame()
    if not frame then
        return nil
    end
    return frame:FindFirstChild("Contents")
end

local function getRoundEndButtons()
    local contents = getRoundEndContents()
    if not contents then
        return nil
    end

    local holder = contents:FindFirstChild("ButtonsHolder")
    if not holder then
        return nil
    end

    return holder:FindFirstChild("Buttons")
end

local function getRestartButton()
    local buttons = getRoundEndButtons()
    if not buttons then
        return nil
    end
    return buttons:FindFirstChild("RestartButton")
end

local function getNextStageButton()
    local buttons = getRoundEndButtons()
    if not buttons then
        return nil
    end
    return buttons:FindFirstChild("NextStageButton")
end

local function getLobbyButton()
    local buttons = getRoundEndButtons()
    if not buttons then
        return nil
    end
    return buttons:FindFirstChild("LobbyButton")
end

local function normalizeGuiText(s)
    s = tostring(s or ""):lower()
    s = s:gsub("%s+", "")
    s = s:gsub("[%p%c]", "")
    return s
end

local function isGuiButton(obj)
    return obj and (obj:IsA("TextButton") or obj:IsA("ImageButton"))
end

local function resolveClickableTarget(obj)
    if not obj then
        return nil
    end

    if isGuiButton(obj) then
        return obj
    end

    local best = nil
    local bestArea = -1

    for _, d in ipairs(obj:GetDescendants()) do
        if isGuiButton(d) and isGuiActuallyVisible(d) then
            local area = d.AbsoluteSize.X * d.AbsoluteSize.Y
            if area > bestArea then
                bestArea = area
                best = d
            end
        end
    end

    return best
end

local function getReadyButton()
    local endlessRoot = findPathFromRootName("EndlessWaveInfo", {"Frame", "Status", "ReadyButton"})
    local endlessReady = resolveClickableTarget(endlessRoot) or endlessRoot
    if endlessReady and isGuiActuallyVisible(endlessReady) then
        return endlessReady, "EndlessWaveInfo"
    end

    local waveRoot = findPathFromRootName("WaveInfo", {"Frame", "Status", "ReadyButton"})
    local waveReady = resolveClickableTarget(waveRoot) or waveRoot
    if waveReady and isGuiActuallyVisible(waveReady) then
        return waveReady, "WaveInfo"
    end

    return nil, nil
end

local function safeGetFullName(obj)
    if not obj then
        return "nil"
    end

    local ok, full = pcall(function()
        return obj:GetFullName()
    end)

    if ok and type(full) == "string" and full ~= "" then
        return full
    end

    return tostring(obj.Name or obj.ClassName or "unknown")
end

local function getGuiInsetTop()
    local ok, inset = pcall(function()
        local topLeft, _bottomRight = GuiService:GetGuiInset()
        return topLeft.Y
    end)
    if ok and type(inset) == "number" then
        return inset
    end
    return 0
end

local function guiToScreenCoords(guiObj)
    if not guiObj or not guiObj:IsA("GuiObject") then
        return 0, 0, 0, 0
    end
    local pos = guiObj.AbsolutePosition
    local size = guiObj.AbsoluteSize
    local insetY = getGuiInsetTop()
    return pos.X, pos.Y + insetY, size.X, size.Y
end

local function guiRectText(guiObj)
    if not guiObj or not guiObj:IsA("GuiObject") then
        return "pos=(?,?) size=(?,?)"
    end

    local pos = guiObj.AbsolutePosition
    local size = guiObj.AbsoluteSize
    local z = tonumber(guiObj.ZIndex) or 0
    return string.format("pos=(%d,%d) size=(%d,%d) z=%d", pos.X, pos.Y, size.X, size.Y, z)
end

local function collectReadyCandidates(limit)
    local out = {}
    local pg = getPlayerGui()
    if not pg then
        return out
    end

    for _, obj in ipairs(pg:GetDescendants()) do
        if isGuiButton(obj) and isGuiActuallyVisible(obj) then
            local n = normalizeGuiText(obj.Name)
            local t = obj:IsA("TextButton") and normalizeGuiText(obj.Text) or ""

            if n:find("ready", 1, true)
                or n == "readybutton"
                or t:find("ready", 1, true)
                or t:find("unready", 1, true)
            then
                table.insert(out, obj)
            end
        end
    end

    table.sort(out, function(a, b)
        local aa = a.AbsoluteSize.X * a.AbsoluteSize.Y
        local bb = b.AbsoluteSize.X * b.AbsoluteSize.Y
        return aa > bb
    end)

    local maxItems = math.max(1, tonumber(limit) or 8)
    if #out > maxItems then
        local trimmed = {}
        for i = 1, maxItems do
            trimmed[i] = out[i]
        end
        return trimmed
    end

    return out
end

local function logReadyCandidatesSnapshot(selectedBtn, source)
    local candidates = collectReadyCandidates(CONFIG.READY_TARGET_SCAN_LIMIT)
    if #candidates == 0 then
        log("Ready candidate snapshot: tidak ada kandidat visible")
        return
    end

    log("Ready candidate snapshot: " .. tostring(#candidates) .. " kandidat (source=" .. tostring(source or "-") .. ")")

    for i, cand in ipairs(candidates) do
        local mark = (cand == selectedBtn) and "*" or "-"
        local text = cand:IsA("TextButton") and tostring(cand.Text or "") or ""
        log(string.format("%s ReadyCand #%d | %s | name=%s | text='%s' | %s", mark, i, safeGetFullName(cand), tostring(cand.Name), text, guiRectText(cand)))
    end
end

local function isReadyButtonActionable(btn)
    if not btn or not btn:IsA("TextButton") then
        return true
    end

    local t = normalizeGuiText(btn.Text)
    if t == "" then
        return true
    end

    if t:find("unready", 1, true)
        or t:find("cancel", 1, true)
        or t:find("wait", 1, true)
        or t:find("waiting", 1, true)
    then
        return false
    end

    return true
end

local function getStartButton()
    local roots = {"EndlessWaveInfo", "WaveInfo"}

    for _, rootName in ipairs(roots) do
        local status = findPathFromRootName(rootName, {"Frame", "Status"})
        if status then
            local exact = status:FindFirstChild("StartButton")
            local exactTarget = resolveClickableTarget(exact) or exact
            if exactTarget and isGuiActuallyVisible(exactTarget) then
                return exactTarget, rootName .. ".StartButton"
            end

            for _, obj in ipairs(status:GetDescendants()) do
                if (obj:IsA("TextButton") or obj:IsA("ImageButton")) and isGuiActuallyVisible(obj) then
                    local n = normalizeGuiText(obj.Name)
                    local t = obj:IsA("TextButton") and normalizeGuiText(obj.Text) or ""

                    if n == "startbutton"
                        or n:find("start", 1, true)
                        or t == "start"
                        or t == "mulai"
                        or t == "play"
                        or t == "begin"
                        or t == "go"
                    then
                        return obj, rootName .. "." .. obj.Name
                    end
                end
            end
        end
    end

    local pg = getPlayerGui()
    if pg then
        for _, obj in ipairs(pg:GetDescendants()) do
            if (obj:IsA("TextButton") or obj:IsA("ImageButton")) and isGuiActuallyVisible(obj) then
                local n = normalizeGuiText(obj.Name)
                local t = obj:IsA("TextButton") and normalizeGuiText(obj.Text) or ""

                if n == "startbutton"
                    or t == "start"
                    or t == "mulai"
                    or t == "play"
                    or t == "begin"
                    or t == "go"
                then
                    return obj, obj:GetFullName()
                end
            end
        end
    end

    return nil, nil
end

local function parseEntriesLeftText(text)
    if type(text) ~= "string" then
        return nil
    end

    local lo = text:lower()
    lo = lo:gsub("%s+", " "):gsub("^%s+", ""):gsub("%s+$", "")
    if lo == "" then
        return nil
    end

    if lo:find("no daily rewards left", 1, true) or lo:find("no rewards left", 1, true) then
        return 0
    end

    -- Format seperti 0/5, 3/5, dst.
    local fraction = lo:match("(%d+)%s*/%s*%d+")
    if fraction then
        return tonumber(fraction)
    end

    local num =
        lo:match("(%d+)%s*daily%s*rewards%s*left") or
        lo:match("(%d+)%s*rewards%s*left") or
        lo:match("(%d+)%s*entries%s*left") or
        lo:match("(%d+)%s*left")

    if num then
        return tonumber(num)
    end

    return nil
end

local function getButtonContainerLabelText(btn)
    if not btn then
        return nil, nil
    end

    local container = btn:FindFirstChild("Container")
    if not container then
        return nil, nil
    end

    local label = container:FindFirstChild("Label")
    if label and (label:IsA("TextLabel") or label:IsA("TextButton")) then
        return label.Text or "", label
    end

    return nil, nil
end

local function getEntriesLeft()
    local contents = getRoundEndContents()
    if contents then
        local entriesObj = contents:FindFirstChild("EntriesLeft")
        if entriesObj and (entriesObj:IsA("TextLabel") or entriesObj:IsA("TextButton")) then
            local text = entriesObj.Text or ""
            local parsed = parseEntriesLeftText(text)
            if parsed ~= nil then
                return parsed, text, "Contents.EntriesLeft"
            end
        end
    end

    local frame = getRoundEndFrame()
    if frame then
        for _, obj in ipairs(frame:GetDescendants()) do
            if obj:IsA("TextLabel") or obj:IsA("TextButton") then
                local text = obj.Text or ""
                if text ~= "" and (text:lower():find("left", 1, true) or text:match("%d+%s*/%s*%d+")) then
                    local parsed = parseEntriesLeftText(text)
                    if parsed ~= nil then
                        return parsed, text, "RoundEnd.Descendants"
                    end
                end
            end
        end
    end

    local restartText = getButtonContainerLabelText(getRestartButton())
    if restartText then
        local parsed = parseEntriesLeftText(restartText)
        if parsed ~= nil then
            return parsed, restartText, "RestartButton.Container.Label"
        end
    end

    local nextText = getButtonContainerLabelText(getNextStageButton())
    if nextText then
        local parsed = parseEntriesLeftText(nextText)
        if parsed ~= nil then
            return parsed, nextText, "NextStageButton.Container.Label"
        end
    end

    return nil, nil, nil
end

local function isRoundEndState()
    local frame = getRoundEndFrame()
    if frame and isGuiActuallyVisible(frame) then
        return true
    end

    local restartBtn = getRestartButton()
    if restartBtn and isGuiActuallyVisible(restartBtn) then
        return true
    end

    local nextBtn = getNextStageButton()
    if nextBtn and isGuiActuallyVisible(nextBtn) then
        return true
    end

    local lobbyBtn = getLobbyButton()
    if lobbyBtn and isGuiActuallyVisible(lobbyBtn) then
        return true
    end

    return false
end

local function doHoverWiggle(target)
    if not target or not target:IsA("GuiObject") then
        return false
    end

    local okAny = false
    local vim = game:GetService("VirtualInputManager")

    local sx, sy, sw, sh = guiToScreenCoords(target)
    local cx = math.floor(sx + (sw / 2))
    local cy = math.floor(sy + (sh / 2))
    local r = math.max(2, math.floor(CONFIG.READY_HOVER_WIGGLE_RADIUS or 6))

    local points = {
        {cx - r, cy},
        {cx + r, cy},
        {cx, cy - r},
        {cx, cy + r},
        {cx, cy},
    }

    for _, point in ipairs(points) do
        local mx, my = point[1], point[2]

        local okMove = pcall(function()
            vim:SendMouseMoveEvent(mx, my, game)
        end)
        okAny = okAny or okMove

        if firesignal and target.MouseMoved then
            local okMovedSignal = pcall(function()
                firesignal(target.MouseMoved, mx, my)
            end)
            okAny = okAny or okMovedSignal
        end

        task.wait(CONFIG.READY_HOVER_WIGGLE_DELAY)
    end

    if firesignal and target.MouseEnter then
        local okEnter = pcall(function()
            firesignal(target.MouseEnter)
        end)
        okAny = okAny or okEnter
    end

    return okAny
end

local function doSweepVirtualClick(target)
    if not target or not target:IsA("GuiObject") then
        return false
    end

    local points = CONFIG.READY_SWEEP_POINTS
    if type(points) ~= "table" or #points == 0 then
        points = {
            {0.50, 0.50},
        }
    end

    local okAny = false
    local vim = game:GetService("VirtualInputManager")
    local sx, sy, sw, sh = guiToScreenCoords(target)

    for _, p in ipairs(points) do
        local rx = tonumber(p[1]) or 0.5
        local ry = tonumber(p[2]) or 0.5
        local cx = math.floor(sx + (sw * rx))
        local cy = math.floor(sy + (sh * ry))

        pcall(function()
            vim:SendMouseMoveEvent(cx, cy, game)
        end)

        local okDown = pcall(function()
            vim:SendMouseButtonEvent(cx, cy, 0, true, game, 0)
        end)
        task.wait(CONFIG.READY_CLICK_HOLD)
        local okUp = pcall(function()
            vim:SendMouseButtonEvent(cx, cy, 0, false, game, 0)
        end)

        okAny = okAny or okDown or okUp
        task.wait(0.02)
    end

    return okAny
end

local function getExecutorMouseCapabilitiesText()
    local caps = {}
    if type(mousemoveabs) == "function" then table.insert(caps, "mousemoveabs") end
    if type(mousemoverel) == "function" then table.insert(caps, "mousemoverel") end
    if type(mouse1click) == "function" then table.insert(caps, "mouse1click") end
    if type(mouse1press) == "function" then table.insert(caps, "mouse1press") end
    if type(mouse1release) == "function" then table.insert(caps, "mouse1release") end

    if #caps == 0 then
        return "none"
    end

    return table.concat(caps, ",")
end

local function doExecutorMouseClick(target)
    if not target or not target:IsA("GuiObject") then
        return false
    end

    if not CONFIG.READY_ENABLE_EXECUTOR_MOUSE then
        return false
    end

    local hasMoveAbs = type(mousemoveabs) == "function"
    local hasMoveRel = type(mousemoverel) == "function"
    local hasClick = type(mouse1click) == "function"
    local hasPressRelease = type(mouse1press) == "function" and type(mouse1release) == "function"

    if not (hasMoveAbs or hasMoveRel) then
        return false
    end

    if not (hasClick or hasPressRelease) then
        return false
    end

    local sx, sy, sw, sh = guiToScreenCoords(target)
    local cx = math.floor(sx + (sw / 2))
    local cy = math.floor(sy + (sh / 2))
    local r = math.max(1, math.floor(CONFIG.READY_EXECUTOR_MOUSE_WIGGLE or 3))

    local points = {
        {cx, cy},
        {cx + r, cy},
        {cx - r, cy},
        {cx, cy + r},
        {cx, cy - r},
        {cx, cy},
    }

    local moved = false
    local clicked = false
    local lastX, lastY = nil, nil

    for _, pt in ipairs(points) do
        local x, y = pt[1], pt[2]

        if hasMoveAbs then
            local ok = pcall(function()
                mousemoveabs(x, y)
            end)
            moved = moved or ok
        elseif hasMoveRel then
            local dx, dy = 0, 0
            if lastX and lastY then
                dx = x - lastX
                dy = y - lastY
            end
            local ok = pcall(function()
                mousemoverel(dx, dy)
            end)
            moved = moved or ok
        end

        lastX, lastY = x, y
        task.wait(0.01)
    end

    if hasClick then
        local ok = pcall(function()
            mouse1click()
        end)
        clicked = clicked or ok
    elseif hasPressRelease then
        local ok = pcall(function()
            mouse1press()
            task.wait(CONFIG.READY_CLICK_HOLD)
            mouse1release()
        end)
        clicked = clicked or ok
    end

    return clicked or moved
end

local function doFireClick(target)
    if not target or not isGuiButton(target) then
        return false
    end

    -- fireclick (beberapa executor punya ini)
    if type(fireclick) == "function" then
        local ok = pcall(function()
            fireclick(target)
        end)
        if ok then return true end
    end

    -- clickdetector fallback
    if type(fireclickdetector) == "function" then
        local cd = target:FindFirstChildOfClass("ClickDetector")
        if cd then
            local ok = pcall(function()
                fireclickdetector(cd)
            end)
            if ok then return true end
        end
    end

    return false
end

local function doFireRemoteFromConnections(target)
    if not target or not isGuiButton(target) then
        return false
    end
    if not getconnections then
        return false
    end

    local fired = false

    -- Coba scan connections dari MouseButton1Click dan Activated
    -- dan periksa apakah ada RemoteEvent:FireServer di dalamnya
    local signals = {}
    pcall(function() table.insert(signals, {sig = target.MouseButton1Click, name = "Click"}) end)
    pcall(function() table.insert(signals, {sig = target.Activated, name = "Activated"}) end)

    for _, sigInfo in ipairs(signals) do
        local conns = nil
        pcall(function()
            conns = getconnections(sigInfo.sig)
        end)
        if conns then
            for _, conn in ipairs(conns) do
                -- Fire the connection function directly
                pcall(function()
                    if conn.Function then
                        -- Call the actual handler function
                        conn.Function()
                        fired = true
                    end
                end)
                -- Also try Fire
                pcall(function()
                    conn:Fire()
                    fired = true
                end)
            end
        end
    end

    -- Juga coba cari RemoteEvent di bawah button atau parent terdekat
    local searchRoots = {target, target.Parent}
    for _, root in ipairs(searchRoots) do
        if root then
            pcall(function()
                for _, child in ipairs(root:GetChildren()) do
                    if child:IsA("RemoteEvent") then
                        pcall(function()
                            child:FireServer()
                            fired = true
                        end)
                    elseif child:IsA("RemoteFunction") then
                        pcall(function()
                            child:InvokeServer()
                            fired = true
                        end)
                    end
                end
            end)
        end
    end

    return fired
end

local function collectReadyProbeTargets(readyBtn)
    local out = {}
    local seen = {}

    local function addTarget(obj, label)
        if not obj or seen[obj] then
            return
        end
        if not obj:IsA("GuiObject") then
            return
        end
        if not isGuiActuallyVisible(obj) then
            return
        end

        seen[obj] = true
        table.insert(out, {
            obj = obj,
            label = label,
        })
    end

    addTarget(readyBtn, "ready")

    local parent = readyBtn and readyBtn.Parent
    local maxParents = math.max(0, tonumber(CONFIG.READY_PROBE_PARENT_LEVELS) or 0)
    local level = 1
    while parent and level <= maxParents do
        if parent:IsA("GuiObject") then
            addTarget(parent, "parent" .. tostring(level))
        end
        parent = parent.Parent
        level = level + 1
    end

    local statusRoot = readyBtn and readyBtn.Parent
    local siblingLimit = math.max(0, tonumber(CONFIG.READY_PROBE_SIBLING_LIMIT) or 0)
    if statusRoot and siblingLimit > 0 then
        local siblingButtons = {}
        for _, d in ipairs(statusRoot:GetDescendants()) do
            if isGuiButton(d) and isGuiActuallyVisible(d) and d ~= readyBtn then
                table.insert(siblingButtons, d)
            end
        end

        table.sort(siblingButtons, function(a, b)
            local aa = a.AbsoluteSize.X * a.AbsoluteSize.Y
            local bb = b.AbsoluteSize.X * b.AbsoluteSize.Y
            return aa > bb
        end)

        for i = 1, math.min(#siblingButtons, siblingLimit) do
            addTarget(siblingButtons[i], "sibling" .. tostring(i))
        end
    end

    return out
end

local function logReadyProbeTargets(selectedBtn)
    local probes = collectReadyProbeTargets(selectedBtn)
    if #probes == 0 then
        log("Ready probe chain: tidak ada target")
        return
    end

    log("Ready probe chain: " .. tostring(#probes) .. " target")
    for i, probe in ipairs(probes) do
        log(string.format("Probe #%d | %s | %s | %s", i, tostring(probe.label), safeGetFullName(probe.obj), guiRectText(probe.obj)))
    end
end

local function getReadySnapshot(btn)
    local snap = {
        visible = false,
        actionable = false,
        active = false,
        interactable = nil,
        text = "",
        textNorm = "",
        rect = "nil",
    }

    if not btn or not btn:IsA("GuiObject") then
        return snap
    end

    snap.visible = isGuiActuallyVisible(btn)
    snap.rect = guiRectText(btn)
    snap.active = btn.Active == true

    pcall(function()
        snap.interactable = btn.Interactable
    end)

    if btn:IsA("TextButton") then
        snap.text = tostring(btn.Text or "")
        snap.textNorm = normalizeGuiText(snap.text)
    end

    snap.actionable = isReadyButtonActionable(btn)
    return snap
end

local function getReadySignature(btn)
    local snap = getReadySnapshot(btn)

    return string.format(
        "vis=%s|act=%s|active=%s|interactable=%s|text=%s|rect=%s",
        tostring(snap.visible),
        tostring(snap.actionable),
        tostring(snap.active),
        tostring(snap.interactable),
        snap.text,
        snap.rect
    )
end

local function detectReadyProgress(btn, beforeSnap)
    local before = beforeSnap
    if type(before) ~= "table" then
        before = getReadySnapshot(btn)
    end

    local after = getReadySnapshot(btn)

    if not after.visible then
        return true, "button_hidden"
    end

    local startBtn = getStartButton()
    if startBtn and isGuiActuallyVisible(startBtn) then
        return true, "start_visible"
    end

    if before.actionable and not after.actionable then
        return true, "actionable_to_off"
    end

    if before.active and not after.active then
        return true, "active_to_off"
    end

    if before.interactable == true and after.interactable == false then
        return true, "interactable_to_off"
    end

    if before.textNorm ~= after.textNorm and after.textNorm ~= "" then
        if after.textNorm:find("unready", 1, true)
            or after.textNorm:find("waiting", 1, true)
            or after.textNorm:find("cancel", 1, true)
            or after.textNorm:find("wait", 1, true)
        then
            return true, "text_to_wait"
        end
    end

    return false, "no_change"
end

local function clickButton(btn, methodsOverride, skipResolve)
    if not btn then
        return false, nil
    end

    local target = btn
    if not skipResolve then
        target = resolveClickableTarget(btn) or btn
    end

    local methods = methodsOverride
    if type(methods) ~= "table" or #methods == 0 then
        methods = {
            "activate",
            "getconnections_click",
            "getconnections_activated",
            "firesignal_click",
            "firesignal_activated",
            "mouse_down_up",
            "virtual_input",
        }
    end

    local function tryMethod(method)
        local used = false

        if method == "activate" then
            pcall(function()
                if isGuiButton(target) and target.Activate then
                    target:Activate()
                    used = true
                end
            end)
        elseif method == "executor_mouse_click" then
            pcall(function()
                if target and target:IsA("GuiObject") then
                    used = doExecutorMouseClick(target)
                end
            end)
        elseif method == "getconnections_click" then
            pcall(function()
                if getconnections and isGuiButton(target) then
                    local conns = getconnections(target.MouseButton1Click)
                    if conns and #conns > 0 then
                        for _, conn in ipairs(conns) do
                            pcall(function()
                                conn:Fire()
                            end)
                        end
                        used = true
                    end
                end
            end)
        elseif method == "getconnections_activated" then
            pcall(function()
                if getconnections and isGuiButton(target) then
                    local conns = getconnections(target.Activated)
                    if conns and #conns > 0 then
                        for _, conn in ipairs(conns) do
                            pcall(function()
                                conn:Fire()
                            end)
                        end
                        used = true
                    end
                end
            end)
        elseif method == "firesignal_click" then
            pcall(function()
                if firesignal and isGuiButton(target) then
                    firesignal(target.MouseButton1Click)
                    used = true
                end
            end)
        elseif method == "firesignal_activated" then
            pcall(function()
                if firesignal and isGuiButton(target) and target.Activated then
                    firesignal(target.Activated)
                    used = true
                end
            end)
        elseif method == "mouse_down_up" then
            pcall(function()
                if isGuiButton(target) then
                    target.MouseButton1Down:Fire()
                    task.wait(0.03)
                    target.MouseButton1Up:Fire()
                    used = true
                end
            end)
        elseif method == "hover_virtual_input" then
            pcall(function()
                if target and target:IsA("GuiObject") then
                    doHoverWiggle(target)

                    local vim = game:GetService("VirtualInputManager")
                    local sx, sy, sw, sh = guiToScreenCoords(target)
                    local cx = math.floor(sx + (sw / 2))
                    local cy = math.floor(sy + (sh / 2))

                    vim:SendMouseButtonEvent(cx, cy, 0, true, game, 0)
                    task.wait(CONFIG.READY_CLICK_HOLD)
                    vim:SendMouseButtonEvent(cx, cy, 0, false, game, 0)
                    used = true
                end
            end)
        elseif method == "sweep_virtual_input" then
            pcall(function()
                if target and target:IsA("GuiObject") then
                    doHoverWiggle(target)
                    used = doSweepVirtualClick(target)
                end
            end)
        elseif method == "virtual_input" then
            pcall(function()
                local vim = game:GetService("VirtualInputManager")
                local sx, sy, sw, sh = guiToScreenCoords(target)
                local cx = math.floor(sx + (sw / 2))
                local cy = math.floor(sy + (sh / 2))
                pcall(function()
                    vim:SendMouseMoveEvent(cx, cy, game)
                end)
                task.wait(0.02)
                vim:SendMouseButtonEvent(cx, cy, 0, true, game, 0)
                task.wait(CONFIG.READY_CLICK_HOLD)
                vim:SendMouseButtonEvent(cx, cy, 0, false, game, 0)
                used = true
            end)
        elseif method == "fireclick" then
            pcall(function()
                used = doFireClick(target)
            end)
        elseif method == "fire_remote_from_connections" then
            pcall(function()
                used = doFireRemoteFromConnections(target)
            end)
        end

        return used
    end

    for _, method in ipairs(methods) do
        local used = tryMethod(method)
        if used then
            task.wait(0.06)
            return true, method
        end
    end

    return false, nil
end

local function clickWithRetry(btn, tries, waitAfter, verifyFn, methodsOverride)
    tries = tries or 1
    waitAfter = waitAfter or 0.2
    local lastMethod = nil

    for _ = 1, tries do
        local target = resolveClickableTarget(btn) or btn
        if not target or not isGuiActuallyVisible(target) then
            return false, lastMethod
        end

        local ok, method = clickButton(target, methodsOverride)
        if method then
            lastMethod = method
        end

        if ok and (not verifyFn or verifyFn()) then
            return true, lastMethod
        end

        if verifyFn and verifyFn() then
            return true, lastMethod
        end

        task.wait(waitAfter)
    end

    if verifyFn and verifyFn() then
        return true, lastMethod
    end

    return false, lastMethod
end

local function canAct()
    return (os.clock() - state.lastActionAt) >= CONFIG.ACTION_COOLDOWN
end

local function markAct()
    state.lastActionAt = os.clock()
end

local function rapidFireReady(btn, source)
    local methods = CONFIG.READY_RAPID_FIRE_METHODS
    if type(methods) ~= "table" or #methods == 0 then
        methods = CONFIG.READY_CLICK_METHODS
    end

    local probeTargets = collectReadyProbeTargets(btn)
    if #probeTargets == 0 then
        probeTargets = {
            { obj = btn, label = "ready" },
        }
    end

    local details = {}
    local progressCount = 0
    local execCount = 0
    local reasonHits = {}

    for _, probe in ipairs(probeTargets) do
        local probeObj = probe.obj
        local probeLabel = tostring(probe.label or "probe")
        local probeName = tostring((probeObj and probeObj.Name) or "?")

        for _, method in ipairs(methods) do
            local beforeSnap = getReadySnapshot(btn)
            local ok, usedMethod = clickButton(probeObj, {method}, true)
            local executed = ok and usedMethod ~= nil
            if executed then
                execCount = execCount + 1
            end

            local progressed, reason = detectReadyProgress(btn, beforeSnap)
            if progressed then
                progressCount = progressCount + 1
                reasonHits[reason] = (reasonHits[reason] or 0) + 1
            end

            table.insert(
                details,
                probeLabel .. "(" .. probeName .. "):" .. method .. "=" .. (executed and "EXEC" or "NOEXEC") .. "/" .. (progressed and ("PROG:" .. tostring(reason)) or "NOPROG")
            )

            if (CONFIG.READY_RAPID_FIRE_STEP_DELAY or 0) > 0 then
                task.wait(CONFIG.READY_RAPID_FIRE_STEP_DELAY)
            end
        end
    end

    state.totalReadyRapidBursts = state.totalReadyRapidBursts + 1
    local joined = table.concat(details, ", ")
    if #joined > 320 then
        joined = string.sub(joined, 1, 320) .. "..."
    end

    local reasonParts = {}
    for reason, count in pairs(reasonHits) do
        table.insert(reasonParts, tostring(reason) .. ":" .. tostring(count))
    end
    table.sort(reasonParts)
    local reasonText = (#reasonParts > 0) and table.concat(reasonParts, ",") or "none"

    local totalAttempts = #probeTargets * #methods
    log("RapidFire Ready #" .. tostring(state.totalReadyRapidBursts) .. " src=" .. tostring(source or "-") .. " targets=" .. tostring(#probeTargets) .. " exec=" .. tostring(execCount) .. "/" .. tostring(totalAttempts) .. " prog=" .. tostring(progressCount) .. "/" .. tostring(totalAttempts) .. " reason=" .. reasonText .. " | " .. joined)
    return progressCount > 0, progressCount
end

local function clearReadyLatch(reason)
    if state.readyLatched then
        throttledLog("ready_latch_clear_" .. tostring(reason or "unknown"), 2, "Ready latch reset (" .. tostring(reason or "unknown") .. ")")
    end

    state.readyLatched = false
    state.readyLatchedAt = 0
    state.readyPendingUntil = 0
    state.lastReadyRapidAt = 0
end

local function handleReadyState()
    if (state.readyPendingUntil or 0) > os.clock() then
        local left = state.readyPendingUntil - os.clock()
        setAction("Menunggu Start/Battle " .. string.format("%.1fs", math.max(0, left)))
        return true
    end

    local readyBtn, source = getReadyButton()
    if not readyBtn then
        if state.readyLatched then
            local elapsed = os.clock() - (state.readyLatchedAt or 0)
            if elapsed < CONFIG.READY_LATCH_TIMEOUT then
                setAction("Ready sudah diklik, menunggu lobby match " .. string.format("%.1fs", CONFIG.READY_LATCH_TIMEOUT - elapsed))
                return true
            end

            clearReadyLatch("timeout_no_ready")
            log("Ready latch timeout tanpa tombol Ready -> izinkan retry")
        end
        return false
    end

    local targetPath = safeGetFullName(readyBtn)

    local sx, sy, sw, sh = guiToScreenCoords(readyBtn)
    local insetY = getGuiInsetTop()
    throttledLog("ready_target", 4, "Ready target: " .. tostring(source) .. " | " .. tostring(readyBtn.ClassName) .. " | " .. tostring(readyBtn.Name) .. " | text='" .. tostring(readyBtn.Text or "") .. "'")
    throttledLog("ready_target_detail", 4, "Ready detail: path=" .. targetPath .. " | " .. guiRectText(readyBtn) .. " | screenXY=(" .. sx .. "," .. sy .. ") | insetY=" .. insetY .. " | active=" .. tostring(readyBtn.Active))
    throttledLog("ready_signature", 4, "Ready signature: " .. getReadySignature(readyBtn))

    if state.lastReadyTargetPath ~= targetPath then
        state.lastReadyTargetPath = targetPath
        log("Ready target switch -> " .. targetPath .. " (source=" .. tostring(source or "-") .. ")")
        logReadyCandidatesSnapshot(readyBtn, source)
        logReadyProbeTargets(readyBtn)
    end

    if state.readyLatched then
        local elapsed = os.clock() - (state.readyLatchedAt or 0)

        if not isReadyButtonActionable(readyBtn) then
            setAction("Ready ON, menunggu start")
            return true
        end

        if CONFIG.READY_RAPID_FIRE_ENABLED then
            if elapsed >= CONFIG.READY_LATCH_TIMEOUT then
                clearReadyLatch("rapid_timeout_actionable")
                log("Ready rapid-fire timeout saat tombol masih actionable -> reset")
            else
                local sinceRapid = os.clock() - (state.lastReadyRapidAt or 0)
                if sinceRapid >= CONFIG.READY_RAPID_FIRE_INTERVAL and canAct() then
                    local okBurst, successCount = rapidFireReady(readyBtn, source)
                    markAct()
                    state.lastReadyRapidAt = os.clock()
                    state.readyPendingUntil = os.clock() + CONFIG.READY_WAIT_START_WINDOW

                    if okBurst then
                        setAction("RapidFire Ready burst sukses (" .. tostring(successCount) .. " metode)")
                    else
                        setAction("RapidFire Ready burst gagal")
                    end
                else
                    local waitRapid = math.max(0, CONFIG.READY_RAPID_FIRE_INTERVAL - sinceRapid)
                    setAction("Ready actionable, rapid-fire wait " .. string.format("%.1fs", waitRapid))
                end
                return true
            end
        end

        if elapsed < CONFIG.READY_ACTIONABLE_RETRY_AFTER then
            setAction("Ready dikirim, verifikasi " .. string.format("%.1fs", CONFIG.READY_ACTIONABLE_RETRY_AFTER - elapsed))
            return true
        end

        if elapsed < CONFIG.READY_LATCH_TIMEOUT then
            clearReadyLatch("latched_actionable_retry")
            throttledLog("ready_force_retry", 3, "Ready masih actionable, force retry klik")
            state.lastReadyClickAt = 0
        else
            clearReadyLatch("timeout_actionable")
            log("Ready latch timeout saat tombol masih actionable -> retry")
        end
    end

    if not isReadyButtonActionable(readyBtn) then
        setAction("Ready sudah toggle, tunggu Start/Battle")
        state.readyLatched = true
        state.readyLatchedAt = os.clock()
        return true
    end

    local sinceReadyClick = os.clock() - (state.lastReadyClickAt or 0)
    if sinceReadyClick < CONFIG.READY_RECLICK_DELAY then
        setAction("Ready lock " .. string.format("%.1fs", CONFIG.READY_RECLICK_DELAY - sinceReadyClick))
        return true
    end

    if not canAct() then
        setAction("Ready visible, cooldown")
        return true
    end

    local ok, method = clickWithRetry(
        readyBtn,
        math.max(CONFIG.CLICK_RETRY, 2),
        CONFIG.CLICK_RETRY_WAIT,
        nil,
        CONFIG.READY_CLICK_METHODS
    )

    if ok then
        markAct()
        state.lastReadyClickAt = os.clock()
        state.lastReadyRapidAt = os.clock()
        state.readyPendingUntil = os.clock() + CONFIG.READY_WAIT_START_WINDOW
        state.readyLatched = true
        state.readyLatchedAt = os.clock()
        state.totalReadyClicks = state.totalReadyClicks + 1
        setAction("Click Ready (" .. source .. ", via " .. tostring(method or "?") .. ")")
        log("Ready clicked from " .. source .. " via " .. tostring(method or "unknown") .. " (count=" .. state.totalReadyClicks .. ")")
    else
        clearReadyLatch("click_failed")
        setAction("Ready click failed (method=" .. tostring(method or "none") .. ")")
        throttledLog("ready_click_fail", 2, "Ready terlihat tapi click gagal (method=" .. tostring(method or "none") .. ")")
    end

    return true
end

local function handleStartState()
    if not CONFIG.ENABLE_START_BUTTON_FALLBACK then
        return false
    end

    local startBtn, source = getStartButton()
    if not startBtn then
        return false
    end

    throttledLog("start_target", 4, "Start target: " .. tostring(source) .. " | " .. tostring(startBtn.ClassName) .. " | " .. tostring(startBtn.Name) .. " | text='" .. tostring(startBtn.Text or "") .. "'")

    if not canAct() then
        setAction("Start visible, cooldown")
        return true
    end

    local ok, method = clickWithRetry(startBtn, CONFIG.CLICK_RETRY, CONFIG.CLICK_RETRY_WAIT, function()
        return not isGuiActuallyVisible(startBtn)
    end)

    if ok then
        markAct()
        clearReadyLatch("start_clicked")
        state.totalStartClicks = state.totalStartClicks + 1
        setAction("Click Start (" .. source .. ", via " .. tostring(method or "?") .. ")")
        log("Start clicked from " .. source .. " via " .. tostring(method or "unknown") .. " (count=" .. state.totalStartClicks .. ")")
    else
        setAction("Start click failed (method=" .. tostring(method or "none") .. ")")
        throttledLog("start_click_fail", 2, "Start terlihat tapi click gagal (method=" .. tostring(method or "none") .. ")")
    end

    return true
end

local function handleRoundEndState()
    state.lastReadyClickAt = 0
    clearReadyLatch("round_end")

    local restartBtn = getRestartButton()
    local nextBtn = getNextStageButton()
    local lobbyBtn = getLobbyButton()

    local restartVisible = restartBtn and isGuiActuallyVisible(restartBtn)
    local nextVisible = nextBtn and isGuiActuallyVisible(nextBtn)
    local lobbyVisible = lobbyBtn and isGuiActuallyVisible(lobbyBtn)

    local entriesLeft, entriesText, source = getEntriesLeft()
    if entriesLeft ~= nil then
        state.lastEntriesLeft = entriesLeft
        state.lastEntriesSource = source or "-"
    elseif source then
        state.lastEntriesSource = source
    else
        state.lastEntriesSource = "unreadable"
    end

    if entriesLeft ~= nil and entriesLeft > 0 then
        if restartVisible then
            if canAct() then
                local ok, method = clickWithRetry(restartBtn, CONFIG.CLICK_RETRY, CONFIG.CLICK_RETRY_WAIT)
                if ok then
                    markAct()
                    state.totalRestartClicks = state.totalRestartClicks + 1
                    setAction("Click Restart (entries=" .. entriesLeft .. ", via " .. tostring(method or "?") .. ")")
                    log("Restart clicked via " .. tostring(method or "unknown") .. " (entries=" .. entriesLeft .. ", src=" .. tostring(source) .. ")")
                else
                    setAction("Restart click failed (method=" .. tostring(method or "none") .. ")")
                    throttledLog("restart_click_fail", 2, "Restart terlihat tapi click gagal (method=" .. tostring(method or "none") .. ")")
                end
            else
                setAction("Restart waiting cooldown")
            end
        else
            setAction("Restart missing while entries > 0")
            throttledLog("restart_missing", 2, "Entries > 0 tapi RestartButton tidak terlihat")
        end
        refreshStatusGui()
        return true
    end

    if entriesLeft == nil then
        setAction("Entries unreadable, fallback Next")
        throttledLog("entries_unknown", 3, "EntriesLeft tidak terbaca, fallback ke Next")
    end

    if nextVisible then
        if canAct() then
            local ok, method = clickWithRetry(nextBtn, CONFIG.CLICK_RETRY, CONFIG.CLICK_RETRY_WAIT)
            if ok then
                markAct()
                state.totalNextClicks = state.totalNextClicks + 1
                local entriesInfo = (entriesLeft == nil) and "unknown" or tostring(entriesLeft)
                setAction("Click Next (entries=" .. entriesInfo .. ", via " .. tostring(method or "?") .. ")")
                log("Next clicked via " .. tostring(method or "unknown") .. " (entries=" .. entriesInfo .. ", text='" .. tostring(entriesText) .. "')")
            else
                setAction("Next click failed (method=" .. tostring(method or "none") .. ")")
                throttledLog("next_click_fail", 2, "Next terlihat tapi click gagal (method=" .. tostring(method or "none") .. ")")
            end
        else
            setAction("Next waiting cooldown")
        end
        refreshStatusGui()
        return true
    end

    if lobbyVisible then
        if canAct() then
            local ok, method = clickWithRetry(lobbyBtn, CONFIG.CLICK_RETRY, CONFIG.CLICK_RETRY_WAIT)
            if ok then
                markAct()
                state.totalLobbyClicks = state.totalLobbyClicks + 1
                setAction("Click Lobby (next missing, via " .. tostring(method or "?") .. ")")
                log("Lobby clicked via " .. tostring(method or "unknown") .. " karena NextStageButton tidak tersedia")

                if CONFIG.STOP_ON_LOBBY then
                    state.running = false
                    state.finished = true
                    setAction("Finished in lobby")
                    log("Auto farm stop: masuk lobby (akhir run)")
                end
            else
                setAction("Lobby click failed (method=" .. tostring(method or "none") .. ")")
                throttledLog("lobby_click_fail", 2, "Lobby terlihat tapi click gagal (method=" .. tostring(method or "none") .. ")")
            end
        else
            setAction("Lobby waiting cooldown")
        end
        refreshStatusGui()
        return true
    end

    setAction("RoundEnd active, waiting buttons")
    throttledLog("roundend_wait_buttons", 2, "RoundEnd terdeteksi tapi tombol aksi belum siap")
    refreshStatusGui()
    return true
end

local controller = {}

function controller.pause()
    if state.finished then
        log("Pause diabaikan karena loop sudah selesai")
        return
    end

    state.running = false
    clearReadyLatch("pause")
    setAction("Paused manual")
    log("Pause diminta manual")
end

function controller.resume()
    if state.finished then
        log("Resume gagal: loop sudah selesai, execute ulang script")
        return
    end

    state.running = true
    setAction("Resumed manual")
    log("Resume diminta manual")
end

function controller.stop()
    state.running = false
    state.finished = true
    clearReadyLatch("stop")
    setAction("Stopped manual")
    disconnectConnections()
    destroyStatusGui()
    log("Stop permanen diminta manual")
end

function controller.status()
    return {
        running = state.running,
        finished = state.finished,
        totalReadyClicks = state.totalReadyClicks,
        totalReadyRapidBursts = state.totalReadyRapidBursts,
        totalStartClicks = state.totalStartClicks,
        totalRestartClicks = state.totalRestartClicks,
        totalNextClicks = state.totalNextClicks,
        totalLobbyClicks = state.totalLobbyClicks,
        lastReadyTargetPath = state.lastReadyTargetPath,
        lastEntriesLeft = state.lastEntriesLeft,
        lastEntriesSource = state.lastEntriesSource,
        lastAction = state.lastAction,
    }
end

function controller.inspectReadyTargets()
    local selected, source = getReadyButton()
    if selected then
        log("Inspect Ready selected: " .. safeGetFullName(selected) .. " | source=" .. tostring(source or "-") .. " | " .. guiRectText(selected))
    else
        log("Inspect Ready selected: target utama tidak ditemukan")
    end

    logReadyCandidatesSnapshot(selected, source or "manual_inspect")
    logReadyProbeTargets(selected)
    return true
end

function controller.getLogs()
    return table.concat(state.uiLogs, "\n")
end

function controller.copyLogs()
    local payload = controller.getLogs()
    if payload == "" then
        log("Copy log: belum ada isi")
        return false
    end

    local ok = copyToClipboard(payload)
    if ok then
        log("Log berhasil disalin ke clipboard (" .. tostring(#state.uiLogs) .. " baris)")
    else
        log("Copy log gagal: clipboard tidak didukung executor")
    end
    return ok
end

-- Hentikan instance lama jika ada.
if env[GLOBAL_KEY] and env[GLOBAL_KEY].stop then
    pcall(function()
        env[GLOBAL_KEY].stop()
    end)
    task.wait(0.1)
end

env[GLOBAL_KEY] = controller

setupTeleportRequeue()
trackConnection(player.OnTeleport:Connect(function(teleportState)
    if teleportState == Enum.TeleportState.Started then
        log("Teleport Started detected (queue sudah di-set sebelumnya)")
    elseif teleportState == Enum.TeleportState.InProgress then
        log("Teleport InProgress")
    elseif teleportState == Enum.TeleportState.Failed then
        log("Teleport Failed -> reset queue flag untuk retry")
        _queueAlreadySet = false
        setupTeleportRequeue()
    end
end))

createStatusGui()
refreshStatusGui()
setAction("Initialized")
log("Log tersedia di panel Runtime Log (GUI) dan console executor")
log("Executor mouse capabilities: " .. getExecutorMouseCapabilitiesText())
log("GuiService inset Y: " .. tostring(getGuiInsetTop()) .. "px (coordinate correction active)")
log("Extra methods: fireclick=" .. tostring(type(fireclick) == "function") .. " | getconnections=" .. tostring(type(getconnections) == "function") .. " | firesignal=" .. tostring(type(firesignal) == "function"))

task.spawn(function()
    while true do
        if state.finished then
            break
        end

        if not state.running then
            refreshStatusGui()
            task.wait(0.2)
            continue
        end

        if isRoundEndState() then
            handleRoundEndState()
        else
            local handledStart = handleStartState()
            if not handledStart then
                local handledReady = handleReadyState()
                if not handledReady then
                    setAction("Waiting battle / RoundEnd")
                    throttledLog("battle_idle", 5, "Menunggu battle selesai / RoundEnd muncul")
                end
            end
        end

        refreshStatusGui()
        task.wait(CONFIG.LOOP_INTERVAL)
    end

    disconnectConnections()
    destroyStatusGui()
    log("Loop selesai")
end)

if CONFIG.AUTO_START then
    state.running = true
    setAction("Auto start running")
    log("Auto farm started")
    log("Rule: entries>0 restart | entries=0 next | entries=nil next | next missing lobby")
end

log("Use getgenv()." .. GLOBAL_KEY .. ".stop() untuk stop")
log("Use getgenv()." .. GLOBAL_KEY .. ".pause() untuk pause")
log("Use getgenv()." .. GLOBAL_KEY .. ".resume() untuk lanjut")
log("Use getgenv()." .. GLOBAL_KEY .. ".copyLogs() untuk copy log")
log("Use getgenv()." .. GLOBAL_KEY .. ".inspectReadyTargets() untuk cek target Ready")