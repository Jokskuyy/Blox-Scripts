-- Upgrade Trigger Logger loader for Roblox executors
-- Usage: execute this file/script in your executor.

local SCRIPT_URL = "https://raw.githubusercontent.com/Jokskuyy/Blox-Scripts/main/Debug_UpgradeTriggerLogger.lua"

if not game:IsLoaded() then
    game.Loaded:Wait()
end

local function getQueueTeleportFunction()
    return queue_on_teleport
        or queueonteleport
        or queue_on_tp
        or (syn and syn.queue_on_teleport)
        or (fluxus and fluxus.queue_on_teleport)
        or (krnl and krnl.queue_on_teleport)
end

local function loadRemoteScript()
    local okSource, source = pcall(function()
        return game:HttpGet(SCRIPT_URL, true)
    end)

    if not okSource or type(source) ~= "string" or source == "" then
        warn("[UpgradeLogger Loader] Failed to fetch script from URL:", SCRIPT_URL)
        return false
    end

    local chunk, loadErr = loadstring(source)
    if not chunk then
        warn("[UpgradeLogger Loader] loadstring failed:", tostring(loadErr))
        return false
    end

    local okRun, runErr = pcall(chunk)
    if not okRun then
        warn("[UpgradeLogger Loader] runtime error:", tostring(runErr))
        return false
    end

    return true
end

pcall(function()
    local queueFunc = getQueueTeleportFunction()
    if queueFunc then
        queueFunc('loadstring(game:HttpGet("' .. SCRIPT_URL .. '", true))()')
        print("[UpgradeLogger Loader] queue_on_teleport enabled")
    else
        print("[UpgradeLogger Loader] queue_on_teleport not supported by executor")
    end
end)

local ok = loadRemoteScript()
if ok then
    print("[UpgradeLogger Loader] Script executed successfully")
end
