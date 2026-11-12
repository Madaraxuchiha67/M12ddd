--// AOT:R - Auto M1 + Auto Retry (Obsidian UI, 2 tabs only)

local Players             = game:GetService("Players")
local GuiService          = game:GetService("GuiService")
local UserInputService    = game:GetService("UserInputService")
local VirtualInputManager = game:GetService("VirtualInputManager")

repeat task.wait() until Players.LocalPlayer
local player = Players.LocalPlayer

--// Obsidian
local repo    = "https://raw.githubusercontent.com/deividcomsono/Obsidian/main/"
local Library = loadstring(game:HttpGet(repo .. "Library.lua"))()

local Window = Library:CreateWindow({
    Title = "AOT:R",
    Footer = "Auto M1 + Auto Retry",
    NotifySide = "Right",
    ShowCustomCursor = false,
    Size = UDim2.fromOffset(520, 380),
    Center = true,
    AutoShow = true,
})

local Tabs = {
    M1    = Window:AddTab("Auto M1", "mouse-pointer-click"),
    Retry = Window:AddTab("Auto Retry", "rotate-cw"),
}

local running = true
Library:OnUnload(function() running = false end)

local function notify(title, desc)
    pcall(function() Library:Notify({ Title = title, Description = desc, Time = 3 }) end)
end

--// ========== Mission end detection ==========
local function IsVisible(obj)
    local cur = obj
    while cur and cur ~= game do
        if cur:IsA("GuiObject") and not cur.Visible then return false end
        if cur:IsA("ScreenGui") and not cur.Enabled then return false end
        cur = cur.Parent
    end
    return true
end

local function GetRewards()
    local pg = player:FindFirstChild("PlayerGui")
    local interface = pg and pg:FindFirstChild("Interface")
    local rewards = interface and interface:FindFirstChild("Rewards")
    local main = rewards and rewards:FindFirstChild("Main")
    return rewards, main
end

local function GetRetryButton()
    local _, main = GetRewards()
    local info = main and main:FindFirstChild("Info")
    local infoMain = info and info:FindFirstChild("Main")
    local buttons = infoMain and infoMain:FindFirstChild("Buttons")
    return buttons and buttons:FindFirstChild("Retry")
end

local RESULT_TITLES = { ["MISSION COMPLETED"] = true, ["RAID COMPLETED"] = true }
local lastScan, lastScanResult = 0, false

local function MissionEnded()
    -- fast check: rewards screen visible
    local rewards, main = GetRewards()
    if rewards and main and IsVisible(rewards) and IsVisible(main) then
        return true
    end
    -- fallback: "MISSION COMPLETED" / "RAID COMPLETED" title (scanned once per second)
    if os.clock() - lastScan >= 1 then
        lastScan = os.clock()
        lastScanResult = false
        local pg = player:FindFirstChild("PlayerGui")
        if pg then
            for _, d in ipairs(pg:GetDescendants()) do
                if d:IsA("TextLabel") or d:IsA("TextButton") then
                    local t = tostring(d.Text or ""):gsub("<[^>]->", "")
                    t = t:gsub("^%s+", ""):gsub("%s+$", "")
                    if RESULT_TITLES[t:upper()] and IsVisible(d) then
                        lastScanResult = true
                        break
                    end
                end
            end
        end
    end
    return lastScanResult
end

--// ========== TAB 1: AUTO M1 ==========
local m1Delay   = 1
local stopOnEnd = true

local function ClickM1()
    pcall(function()
        local cam = workspace.CurrentCamera
        local size = cam and cam.ViewportSize or Vector2.new(800, 600)
        local x, y = size.X / 2, size.Y / 2
        VirtualInputManager:SendMouseButtonEvent(x, y, 0, true, game, 0)
        task.wait(0.03)
        VirtualInputManager:SendMouseButtonEvent(x, y, 0, false, game, 0)
    end)
end

local M1Box = Tabs.M1:AddLeftGroupbox("Auto M1")

M1Box:AddToggle("AutoM1", {
    Text = "Auto Click M1",
    Default = false,
    Tooltip = "Clicks M1 on a timer",
})

M1Box:AddSlider("M1Delay", {
    Text = "Click delay",
    Default = 1,
    Min = 0.1,
    Max = 5,
    Rounding = 1,
    Suffix = "s",
    Callback = function(v) m1Delay = v end,
})

M1Box:AddToggle("StopOnEnd", {
    Text = "Stop when mission ends",
    Default = true,
    Callback = function(v) stopOnEnd = v end,
})

M1Box:AddLabel("Turns Auto M1 off when the MISSION / RAID COMPLETED screen shows. If this is off, M1 just pauses and resumes next mission.", true)

task.spawn(function()
    while running do
        if Library.Toggles.AutoM1 and Library.Toggles.AutoM1.Value then
            if MissionEnded() then
                if stopOnEnd then
                    Library.Toggles.AutoM1:SetValue(false)
                    notify("Auto M1", "Mission ended - M1 stopped.")
                end
                task.wait(0.5)
            else
                ClickM1()
                task.wait(m1Delay)
            end
        else
            task.wait(0.2)
        end
    end
end)

--// ========== TAB 2: AUTO RETRY ==========
local retryDelay = 0.3

local function ClickRetry(btn)
    local pos  = btn.AbsolutePosition
    local size = btn.AbsoluteSize
    local inset = GuiService:GetGuiInset()
    local x = pos.X + size.X / 2 + 20
    local y
    if UserInputService.TouchEnabled and not UserInputService.KeyboardEnabled then
        y = pos.Y + size.Y / 2 + 60
    else
        y = pos.Y + size.Y / 2 + inset.Y
    end
    VirtualInputManager:SendMouseButtonEvent(x, y, 0, true, game, 0)
    task.wait(0.05)
    VirtualInputManager:SendMouseButtonEvent(x, y, 0, false, game, 0)
end

local function CanClickRetry()
    local rewards, main = GetRewards()
    local btn = GetRetryButton()
    return btn
        and rewards and rewards.Visible
        and main and main.Visible
        and btn.Visible
        and btn.AbsoluteSize.Magnitude > 10
        and btn or nil
end

local RetryBox = Tabs.Retry:AddLeftGroupbox("Auto Retry")

RetryBox:AddToggle("AutoRetry", {
    Text = "Auto Retry",
    Default = false,
    Tooltip = "Presses Retry on the rewards screen",
})

RetryBox:AddSlider("RetryDelay", {
    Text = "Delay before retry",
    Default = 0.3,
    Min = 0,
    Max = 10,
    Rounding = 1,
    Suffix = "s",
    Callback = function(v) retryDelay = v end,
})

task.spawn(function()
    while running do
        if Library.Toggles.AutoRetry and Library.Toggles.AutoRetry.Value and CanClickRetry() then
            task.wait(retryDelay)
            local btn = CanClickRetry()
            if btn and Library.Toggles.AutoRetry.Value then
                pcall(ClickRetry, btn)
                task.wait(2)
            end
        end
        task.wait(0.25)
    end
end)

--// UI settings (kept on the second tab so there are only two tabs)
local UIBox = Tabs.Retry:AddRightGroupbox("Menu")
UIBox:AddLabel("Menu keybind"):AddKeyPicker("MenuKeybind", {
    Default = "LeftControl",
    NoUI = true,
    Text = "Menu keybind",
})
Library.ToggleKeybind = Library.Options.MenuKeybind

UIBox:AddButton({
    Text = "Unload",
    Func = function() Library:Unload() end,
})

notify("AOT:R", "Loaded. Auto M1 + Auto Retry ready.")
