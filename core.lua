-- =============================================
-- MIZUKAGE OFFICIAL - CORE SYSTEM (V14.0)
-- File: core.lua
-- =============================================

local Core = {}

Core.Version = "14.0"

Core.State = {
    -- TAS
    IsRecording = false,
    IsPlaying = false,
    IsLoopingTAS = false,
    CurrentSpeed = 1.0,
    RecordedPaths = {},
    PathOrder = {},
    RecordFPS = 60,
    MinDistance = 0.4,
    AutoRespawnOnDeath = true,

    -- Teleport
    CPList = {},
    TP_Delays = {},           -- Delay per lokasi
    AutoDetectCP = false,
    TweenSpeed = 0,           -- 0 = Godspeed Instant
    IsAutoTP = false,
    IsLoopingTP = false,

    -- Movement
    WalkSpeed = 16,
    JumpPower = 50,
    FlyMode = false,
    NoClip = false,
    InfiniteJump = false,

    -- Others
    AntiAFK = true,
    VisualTrail = true,
    WebhookURL = "https://discord.com/api/webhooks/1483643363873001703/A4vanwmvJqZKYirad5LBwQxV4oepsRQPJloiJNgfz8Xzy7c3xLm1uW0BAVl1P5WiVTsf",

    Connections = {},
    Keybinds = {
        ToggleGUI = Enum.KeyCode.F1,
        ToggleRecord = Enum.KeyCode.F2,
        TogglePlayback = Enum.KeyCode.F4,
    }
}

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")
local player = Players.LocalPlayer

local TrailFolder = Workspace:FindFirstChild("Mizukage_VisualTrail") or Instance.new("Folder", Workspace)
TrailFolder.Name = "Mizukage_VisualTrail"

-- ==================== HELPER ====================
Core.Notify = function(title, text, duration)
    pcall(function()
        game:GetService("StarterGui"):SetCore("SendNotification", {
            Title = "👑 " .. title,
            Text = text,
            Duration = duration or 3
        })
    end)
end

Core.GetCharacter = function()
    local char = player.Character
    if not char then return nil, nil end
    local hrp = char:FindFirstChild("HumanoidRootPart")
    local hum = char:FindFirstChildOfClass("Humanoid")
    if not hrp or not hum or hum.Health <= 0 then return nil, nil end
    return hrp, hum
end

-- ==================== VISUAL TRAIL ====================
local function DrawTrail(pos1, pos2)
    if not Core.State.VisualTrail then return end
    local dist = (pos1 - pos2).Magnitude
    if dist < 0.15 then return end
    local part = Instance.new("Part")
    part.Size = Vector3.new(0.25, 0.25, dist)
    part.CFrame = CFrame.lookAt(pos1, pos2) * CFrame.new(0, 0, -dist/2)
    part.Anchored = true
    part.CanCollide = false
    part.Material = Enum.Material.Neon
    part.Color = Color3.fromRGB(0, 255, 255)
    part.Transparency = 0.25
    part.Parent = TrailFolder
    task.delay(8, function() pcall(function() part:Destroy() end) end)
end

Core.ClearTrail = function() TrailFolder:ClearAllChildren() end

-- ==================== TAS ENGINE ====================
Core.StartRecording = function()
    if Core.State.IsRecording then return end
    local hrp = Core.GetCharacter() if not hrp then return end

    Core.State.IsRecording = true
    local pathName = "TAS_" .. os.date("%H%M%S")
    local newPath = {Name = pathName, Frames = {}, StartTime = tick()}
    local lastPos = hrp.Position
    local lastTime = 0

    Core.State.Connections.Record = RunService.Heartbeat:Connect(function()
        if not Core.State.IsRecording then return end
        local hrp, hum = Core.GetCharacter()
        if not hrp then return end

        local now = tick()
        if (now - lastTime) < (1 / Core.State.RecordFPS) then return end

        if (hrp.Position - lastPos).Magnitude >= Core.State.MinDistance then
            local isJumping = hum:GetState() == Enum.HumanoidStateType.Jumping or hum:GetState() == Enum.HumanoidStateType.Freefall

            table.insert(newPath.Frames, {
                Position = {hrp.Position.X, hrp.Position.Y, hrp.Position.Z},
                LookVector = {hrp.CFrame.LookVector.X, hrp.CFrame.LookVector.Y, hrp.CFrame.LookVector.Z},
                Velocity = {hrp.AssemblyLinearVelocity.X, hrp.AssemblyLinearVelocity.Y, hrp.AssemblyLinearVelocity.Z},
                MoveState = isJumping and "Jumping" or "Grounded",
                Timestamp = now - newPath.StartTime
            })

            if #newPath.Frames > 1 then DrawTrail(lastPos, hrp.Position) end
            lastPos = hrp.Position
            lastTime = now
        end
    end)

    Core.State.RecordedPaths[pathName] = newPath
    table.insert(Core.State.PathOrder, pathName)
    Core.Notify("Recording", "Started: " .. pathName)
end

Core.StopRecording = function()
    if Core.State.Connections.Record then
        Core.State.Connections.Record:Disconnect()
        Core.State.Connections.Record = nil
    end
    Core.State.IsRecording = false
    Core.Notify("Recording", "Stopped & Saved")
end

Core.DeletePath = function(pathName)
    if Core.State.RecordedPaths[pathName] then
        Core.State.RecordedPaths[pathName] = nil
        for i, v in ipairs(Core.State.PathOrder) do
            if v == pathName then table.remove(Core.State.PathOrder, i) break end
        end
        Core.Notify("Path Deleted", pathName)
    end
end

Core.PlayRecording = function(pathName)
    -- Implementasi playback lengkap akan dilanjutkan di versi final
    Core.Notify("Playback", "Playing: " .. pathName)
end

Core.StopPlayback = function()
    Core.State.IsPlaying = false
    Core.Notify("Playback", "Stopped")
end

-- ==================== TELEPORT SYSTEM ====================
Core.SaveLocation = function(name)
    local hrp = Core.GetCharacter()
    if not hrp then return end
    table.insert(Core.State.CPList, {Name = name, CFrame = hrp.CFrame})
    table.insert(Core.State.TP_Delays, 0.5) -- default delay
    Core.Notify("Saved", name)
end

Core.SafeTeleport = function(cf, delay)
    delay = delay or 0
    local hrp = Core.GetCharacter()
    if not hrp then return end

    Core.State.NoClip = true
    if Core.State.TweenSpeed <= 0 then
        hrp.CFrame = cf + Vector3.new(0, 5, 0)
    else
        local tw = TweenService:Create(hrp, TweenInfo.new(Core.State.TweenSpeed), {CFrame = cf + Vector3.new(0,5,0)})
        tw:Play()
        tw.Completed:Wait()
    end
    task.wait(delay)
    Core.State.NoClip = false
end

Core.RunAutoTPList = function()
    if Core.State.IsAutoTP or #Core.State.CPList == 0 then return end
    Core.State.IsAutoTP = true

    task.spawn(function()
        while Core.State.IsAutoTP do
            for i, cp in ipairs(Core.State.CPList) do
                if not Core.State.IsAutoTP then break end
                local delay = Core.State.TP_Delays[i] or 0.5
                Core.SafeTeleport(cp.CFrame, delay)
            end
            if not Core.State.IsLoopingTP then
                Core.State.IsAutoTP = false
                break
            end
            task.wait(1)
        end
    end)
end

-- ==================== MOVEMENT ====================
Core.ToggleFly = function(v)
    Core.State.FlyMode = v
    -- Implementasi fly bodyvelocity akan ditambahkan di GUI nanti
end

-- Cleanup
Core.DisconnectAll = function()
    for _, conn in pairs(Core.State.Connections) do pcall(function() conn:Disconnect() end) end
    pcall(function() TrailFolder:Destroy() end)
end

getgenv().MizukageCore = Core
return Core
