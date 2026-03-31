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

local player = Players.LocalPlayer

local CONFIG = {
    AUTO_START = true,
    AUTO_REQUEUE_ON_TELEPORT = true,
    REQUEUE_SOURCE = 'pcall(function() local ok,src=pcall(function() return game:HttpGet("https://raw.githubusercontent.com/Jokskuyy/Blox-Scripts/main/SummonHero_AutoFarm_Entries.lua") end); if ok and src and #src>0 then loadstring(src)(); return end; if loadfile then local f=loadfile("SummonHero_AutoFarm_Entries.lua"); if f then f() end end end)',
    SHOW_STATUS_GUI = true,
    GUI_LOG_LINES = 12,
    MAX_STORED_LOGS = 300,
    STATUS_GUI_TOGGLE_KEY = Enum.KeyCode.RightControl,
    ENABLE_START_BUTTON_FALLBACK = true,
    READY_RECLICK_DELAY = 8.0,
    READY_ACTIONABLE_RETRY_AFTER = 9.0,
    READY_LATCH_TIMEOUT = 45.0,
    READY_CLICK_METHODS = {
        "activate",
        "virtual_input",
        "firesignal_click",
        "firesignal_activated",
        "getconnections_click",
        "getconnections_activated",
        "mouse_down_up",
    },
    CLICK_HOLD = 0.06,
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
    lastReadyClickAt = 0,
    readyLatched = false,
    readyLatchedAt = 0,
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

local function getQueueTeleportFunction()
    local candidates = {
        queue_on_teleport,
        queueonteleport,
        queue_on_tp,
        (syn and syn.queue_on_teleport) or nil,
        (fluxus and fluxus.queue_on_teleport) or nil,
        (krnl and krnl.queue_on_teleport) or nil,
    }

    for _, fn in ipairs(candidates) do
        if type(fn) == "function" then
            return fn
        end
    end

    return nil
end

local function setupTeleportRequeue()
    if not CONFIG.AUTO_REQUEUE_ON_TELEPORT then
        return
    end

    local queueFunc = getQueueTeleportFunction()
    if not queueFunc then
        log("queue_on_teleport tidak didukung executor")
        return
    end

    local source = CONFIG.REQUEUE_SOURCE
    if type(source) ~= "string" or source == "" then
        source = 'loadstring(game:HttpGet("https://raw.githubusercontent.com/Jokskuyy/Blox-Scripts/main/SummonHero_AutoFarm_Entries.lua"))()'
    end

    if type(source) ~= "string" or source == "" then
        log("REQUEUE_SOURCE kosong, auto re-execute teleport dilewati")
        return
    end

    local ok, err = pcall(function()
        queueFunc(source)
    end)

    if ok then
        log("Auto re-execute aktif setelah teleport (queue set)")
    else
        log("Gagal set queue_on_teleport: " .. tostring(err))
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
    count.Text = "Rdy:0 | Str:0 | Rst:0 | Nxt:0 | Lby:0"
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
        "Rdy:%d | Str:%d | Rst:%d | Nxt:%d | Lby:%d",
        state.totalReadyClicks,
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

local function doVirtualInputClick(target)
    if not target or not target:IsA("GuiObject") then
        return false
    end

    local vim = game:GetService("VirtualInputManager")
    local pos = target.AbsolutePosition
    local size = target.AbsoluteSize
    local cx = math.floor(pos.X + (size.X / 2))
    local cy = math.floor(pos.Y + (size.Y / 2))

    pcall(function()
        vim:SendMouseMoveEvent(cx, cy, game)
    end)
    task.wait(0.02)

    local okDown = pcall(function()
        vim:SendMouseButtonEvent(cx, cy, 0, true, game, 0)
    end)
    task.wait(CONFIG.CLICK_HOLD)
    local okUp = pcall(function()
        vim:SendMouseButtonEvent(cx, cy, 0, false, game, 0)
    end)

    return okDown or okUp
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
        elseif method == "virtual_input" then
            pcall(function()
                used = doVirtualInputClick(target)
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

local function clearReadyLatch(reason)
    if state.readyLatched then
        throttledLog("ready_latch_clear_" .. tostring(reason or "unknown"), 2, "Ready latch reset (" .. tostring(reason or "unknown") .. ")")
    end

    state.readyLatched = false
    state.readyLatchedAt = 0
end

local function handleReadyState()
    local readyBtn, source = getReadyButton()
    if not readyBtn then
        if state.readyLatched then
            local elapsed = os.clock() - (state.readyLatchedAt or 0)
            if elapsed < CONFIG.READY_LATCH_TIMEOUT then
                setAction("Ready sudah diklik, menunggu start " .. string.format("%.1fs", CONFIG.READY_LATCH_TIMEOUT - elapsed))
                return true
            end

            clearReadyLatch("timeout_no_ready")
            log("Ready latch timeout tanpa tombol Ready -> izinkan retry")
        end
        return false
    end

    throttledLog("ready_target", 5, "Ready target: " .. tostring(source) .. " | " .. tostring(readyBtn.ClassName) .. " | " .. tostring(readyBtn.Name) .. " | path=" .. safeGetFullName(readyBtn))

    if state.readyLatched then
        local elapsed = os.clock() - (state.readyLatchedAt or 0)

        if not isReadyButtonActionable(readyBtn) then
            setAction("Ready ON, menunggu start")
            return true
        end

        if elapsed < CONFIG.READY_ACTIONABLE_RETRY_AFTER then
            setAction("Ready terkirim, verifikasi " .. string.format("%.1fs", CONFIG.READY_ACTIONABLE_RETRY_AFTER - elapsed))
            return true
        end

        clearReadyLatch("actionable_retry")
        state.lastReadyClickAt = 0
        throttledLog("ready_retry", 3, "Ready masih actionable, retry klik")
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
        totalStartClicks = state.totalStartClicks,
        totalRestartClicks = state.totalRestartClicks,
        totalNextClicks = state.totalNextClicks,
        totalLobbyClicks = state.totalLobbyClicks,
        lastEntriesLeft = state.lastEntriesLeft,
        lastEntriesSource = state.lastEntriesSource,
        lastAction = state.lastAction,
    }
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
        log("Teleport Started -> refresh queue")
        setupTeleportRequeue()
    end
end))

createStatusGui()
refreshStatusGui()
setAction("Initialized")
log("Log tersedia di panel Runtime Log (GUI) dan console executor")

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
