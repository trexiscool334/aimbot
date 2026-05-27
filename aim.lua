-- ============================================
-- PREMIUM AIM ASSIST v2.0
-- XENO EXECUTOR COMPATIBLE
-- ============================================

-- Xeno compatibility layers
local isXeno = (identifyexecutor and identifyexecutor():find("Xeno")) or pcall(function() return getexecutorname() == "Xeno" end) or false

-- Safe service fetching
local function getService(name)
    local success, sv = pcall(function() return game:GetService(name) end)
    if success then return sv end
    return nil
end

local Players = getService("Players")
local RunService = getService("RunService")
local UserInputService = getService("UserInputService")
local TweenService = getService("TweenService")
local TextService = getService("TextService")
local HttpService = getService("HttpService")

-- Guard: Stop if critical services missing (shouldn't happen but Xeno is weird)
if not Players or not RunService or not UserInputService then
    warn("[PremiumAim] Failed to get core services - script aborted")
    return
end

local player = Players.LocalPlayer
local camera = workspace.CurrentCamera
local mouse = player:GetMouse()

-- ================= FALLBACK FUNCTIONS =================
-- In case Xeno doesn't support newer Luau features

local math_clamp = math.clamp or function(val, min, max)
    if val < min then return min end
    if val > max then return max end
    return val
end

local math_round = function(val, decimals)
    local mult = 10 ^ (decimals or 0)
    return math.floor(val * mult + 0.5) / mult
end

local math_rad = math.rad or function(deg) return deg * 0.01745329252 end
local math_tan = math.tan or function(rad) return math.sin(rad) / math.cos(rad) end

local table_find = table.find or function(tbl, val)
    for i, v in ipairs(tbl) do
        if v == val then return i end
    end
    return nil
end

-- ================= CONFIG =================
local Config = {
    enabled = false,
    currentTarget = nil,
    aimMode = "Toggle",
    smoothSpeed = 0.12,
    lockRange = 500,
    heightOffset = Vector3.new(0, 1.6, 0),
    fovSize = 120,
    
    teamCheck = false,
    wallCheck = false,
    prioritizeLowHealth = false,
    aimPart = "Head",
    
    triggerbotEnabled = false,
    triggerbotDelay = 0.05,
    triggerbotFOV = 5,
    triggerbotOnKey = false,
    triggerbotKey = Enum.KeyCode.X,
    autoShoot = false,
    
    espEnabled = true,
    espFillColor = Color3.fromRGB(140, 60, 255),
    espOutlineColor = Color3.fromRGB(255, 255, 255),
    espTargetColor = Color3.fromRGB(0, 255, 180),
    espFillOpacity = 0.35,
    espOutlineOpacity = 0.8,
    showHealthBar = true,
    showDistance = true,
    showBoxes = false,
    
    showFOVCircle = true,
    fovCircleColor = Color3.fromRGB(0, 255, 180),
    crosshairEnabled = true,
    crosshairColor = Color3.fromRGB(255, 255, 255),
    
    silentAim = false,
    prediction = 0.0,
    
    toggleKey = Enum.KeyCode.F,
    triggerbotToggleKey = Enum.KeyCode.G,
    espToggleKey = Enum.KeyCode.H,
    switchTargetKey = Enum.UserInputType.MouseButton2,
    
    -- UI state
    uiOpen = true,
}

-- ================= THEME =================
local Theme = {
    Background = Color3.fromRGB(15, 15, 25),
    Surface = Color3.fromRGB(22, 22, 40),
    SurfaceDark = Color3.fromRGB(18, 18, 32),
    Accent = Color3.fromRGB(100, 60, 255),
    AccentSecondary = Color3.fromRGB(0, 255, 180),
    Text = Color3.fromRGB(220, 220, 240),
    TextDim = Color3.fromRGB(130, 130, 160),
    Danger = Color3.fromRGB(255, 60, 60),
    Success = Color3.fromRGB(0, 200, 100),
    Border = Color3.fromRGB(40, 40, 65),
}

-- ================= HELPER FUNCTIONS =================
local function safeTween(obj, props, dur)
    if not TweenService then
        for k, v in pairs(props) do
            pcall(function() obj[k] = v end)
        end
        return nil
    end
    local success, t = pcall(function()
        return TweenService:Create(obj, TweenInfo.new(dur or 0.25, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), props)
    end)
    if success then
        t:Play()
        return t
    end
    return nil
end

local function roundRect(obj, radius)
    local r = Instance.new("UICorner")
    r.CornerRadius = UDim.new(0, radius or 8)
    pcall(function() r.Parent = obj end)
end

local function makeStroke(obj, color, thickness)
    local s = Instance.new("UIStroke")
    s.Color = color or Theme.Border
    s.Thickness = thickness or 1
    pcall(function() s.Parent = obj end)
end

-- ================= CREATE GUI =================
local screenGui = Instance.new("ScreenGui")
screenGui.Name = "PremiumAimAssist"
screenGui.ResetOnSpawn = false
screenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling

-- Try to use CoreGui for Xeno compatibility, fall back to PlayerGui
local targetParent = player:FindFirstChild("PlayerGui")
if not targetParent then
    targetParent = player:FindFirstChild("Backpack") or game:GetService("CoreGui")
end

-- Check if we can parent to CoreGui
local success, _ = pcall(function()
    local cg = game:GetService("CoreGui")
    screenGui.Parent = cg
end)
if not success then
    pcall(function() screenGui.Parent = targetParent end)
end

-- ================= MAIN WINDOW =================
local main = Instance.new("Frame")
main.Name = "MainWindow"
main.Size = UDim2.new(0, 360, 0, 520)
main.Position = UDim2.new(0, 30, 0.5, -260)
main.BackgroundColor3 = Theme.Background
main.BorderSizePixel = 0
main.ClipsDescendants = true
main.Parent = screenGui

-- Stroke border
makeStroke(main, Theme.Border)
roundRect(main, 12)

-- Title bar
local titleBar = Instance.new("Frame")
titleBar.Size = UDim2.new(1, 0, 0, 50)
titleBar.BackgroundColor3 = Theme.SurfaceDark
titleBar.BorderSizePixel = 0
titleBar.Parent = main

roundRect(titleBar, 12)

-- Fix for top-only rounded corners
local titleClip = Instance.new("Frame")
titleClip.Size = UDim2.new(1, 0, 0, 12)
titleClip.Position = UDim2.new(0, 0, 1, -12)
titleClip.BackgroundColor3 = Theme.SurfaceDark
titleClip.BorderSizePixel = 0
titleClip.Parent = titleBar

-- Title text
local titleText = Instance.new("TextLabel")
titleText.Size = UDim2.new(1, -50, 1, 0)
titleText.Position = UDim2.new(0, 15, 0, 0)
titleText.BackgroundTransparency = 1
titleText.Text = "✦ AIM ASSIST v2.0"
titleText.TextColor3 = Theme.Text
titleText.TextSize = 16
titleText.Font = Enum.Font.GothamBold
titleText.TextXAlignment = Enum.TextXAlignment.Left
titleText.Parent = titleBar

-- Status dot
local statusDot = Instance.new("Frame")
statusDot.Name = "StatusDot"
statusDot.Size = UDim2.new(0, 8, 0, 8)
statusDot.Position = UDim2.new(0, 5, 0.5, -4)
statusDot.BackgroundColor3 = Color3.fromRGB(255, 0, 0)
statusDot.BorderSizePixel = 0
statusDot.Parent = titleText

roundRect(statusDot, 10)

-- Active badge
local badge = Instance.new("Frame")
badge.Size = UDim2.new(0, 14, 0, 14)
badge.Position = UDim2.new(1, -25, 0.5, -7)
badge.BackgroundColor3 = Theme.Success
badge.BorderSizePixel = 0
badge.Parent = titleBar

roundRect(badge, 14)

-- Separator
local sep = Instance.new("Frame")
sep.Size = UDim2.new(1, -30, 0, 1)
sep.Position = UDim2.new(0, 15, 0, 50)
sep.BackgroundColor3 = Theme.Border
sep.BorderSizePixel = 0
sep.Parent = main

-- ================= TAB SYSTEM =================
local tabBar = Instance.new("Frame")
tabBar.Size = UDim2.new(1, 0, 0, 42)
tabBar.Position = UDim2.new(0, 0, 0, 51)
tabBar.BackgroundColor3 = Theme.SurfaceDark
tabBar.BorderSizePixel = 0
tabBar.Parent = main

local tabs = {"Aim", "Visuals", "Trigger", "Settings"}
local tabButtons = {}
local tabContents = {}

for i, tabName in ipairs(tabs) do
    local btn = Instance.new("TextButton")
    btn.Name = tabName .. "Tab"
    btn.Size = UDim2.new(0.25, 0, 1, 0)
    btn.Position = UDim2.new((i-1) * 0.25, 0, 0, 0)
    btn.BackgroundColor3 = (i == 1) and Theme.Accent or Theme.SurfaceDark
    btn.Text = tabName
    btn.TextColor3 = (i == 1) and Color3.fromRGB(255, 255, 255) or Theme.TextDim
    btn.TextSize = 13
    btn.Font = Enum.Font.GothamBold
    btn.BorderSizePixel = 0
    btn.AutoButtonColor = false
    btn.Parent = tabBar
    
    table.insert(tabButtons, btn)
    
    local content = Instance.new("ScrollingFrame")
    content.Name = tabName .. "Content"
    content.Size = UDim2.new(1, -20, 1, -94)
    content.Position = UDim2.new(0, 10, 0, 94)
    content.BackgroundColor3 = Theme.Background
    content.BackgroundTransparency = 1
    content.BorderSizePixel = 0
    content.ScrollBarThickness = 3
    content.ScrollBarImageColor3 = Theme.Accent
    content.ClipsDescendants = true
    content.Visible = (i == 1)
    content.CanvasSize = UDim2.new(0, 0, 0, 0)
    content.AutomaticCanvasSize = Enum.AutomaticSize.Y
    content.Parent = main
    
    table.insert(tabContents, content)
    
    btn.MouseButton1Click:Connect(function()
        for j, b in ipairs(tabButtons) do
            b.BackgroundColor3 = (j == i) and Theme.Accent or Theme.SurfaceDark
            b.TextColor3 = (j == i) and Color3.fromRGB(255, 255, 255) or Theme.TextDim
            tabContents[j].Visible = (j == i)
        end
    end)
end

-- ================= UI COMPONENTS =================
-- Track components for cleanup
local uiComponents = {}

local function createToggle(parent, title, desc, default, callback)
    local frame = Instance.new("Frame")
    frame.Size = UDim2.new(1, -10, 0, 40)
    frame.BackgroundColor3 = Theme.Surface
    frame.BorderSizePixel = 0
    frame.Parent = parent
    roundRect(frame, 8)
    table.insert(uiComponents, frame)
    
    local lbl = Instance.new("TextLabel")
    lbl.Size = UDim2.new(1, -55, 1, 0)
    lbl.Position = UDim2.new(0, 12, 0, 0)
    lbl.BackgroundTransparency = 1
    lbl.Text = title
    lbl.TextColor3 = Theme.Text
    lbl.TextSize = 14
    lbl.Font = Enum.Font.Gotham
    lbl.TextXAlignment = Enum.TextXAlignment.Left
    lbl.Parent = frame
    
    if desc then
        local descLbl = Instance.new("TextLabel")
        descLbl.Size = UDim2.new(1, -55, 1, 0)
        descLbl.Position = UDim2.new(0, 12, 0, 0)
        descLbl.BackgroundTransparency = 1
        descLbl.Text = desc
        descLbl.TextColor3 = Theme.TextDim
        descLbl.TextSize = 11
        descLbl.Font = Enum.Font.Gotham
        descLbl.TextXAlignment = Enum.TextXAlignment.Left
        descLbl.TextYAlignment = Enum.TextYAlignment.Bottom
        descLbl.Parent = frame
        lbl.TextYAlignment = Enum.TextYAlignment.Top
        lbl.Size = UDim2.new(1, -55, 0.5, -2)
    end
    
    local togBg = Instance.new("Frame")
    togBg.Size = UDim2.new(0, 34, 0, 18)
    togBg.Position = UDim2.new(1, -42, 0.5, -9)
    togBg.BackgroundColor3 = Color3.fromRGB(60, 60, 80)
    togBg.BorderSizePixel = 0
    togBg.Parent = frame
    roundRect(togBg, 20)
    
    local knob = Instance.new("Frame")
    knob.Size = UDim2.new(0, 14, 0, 14)
    knob.Position = UDim2.new(0, 2, 0.5, -7)
    knob.BackgroundColor3 = Theme.Text
    knob.BorderSizePixel = 0
    knob.Parent = togBg
    roundRect(knob, 14)
    
    local state = default or false
    local function setState(newState)
        state = newState
        togBg.BackgroundColor3 = state and Theme.Success or Color3.fromRGB(60, 60, 80)
        safeTween(knob, {
            Position = state and UDim2.new(1, -16, 0.5, -7) or UDim2.new(0, 2, 0.5, -7)
        }, 0.2)
        if callback then callback(state) end
    end
    
    local btn = Instance.new("TextButton")
    btn.Size = UDim2.new(1, 0, 1, 0)
    btn.BackgroundTransparency = 1
    btn.Text = ""
    btn.AutoButtonColor = false
    btn.Parent = frame
    
    btn.MouseButton1Click:Connect(function()
        setState(not state)
    end)
    
    setState(default or false)
    
    return frame, setState
end

local function createSlider(parent, title, min, max, default, suffix, callback)
    local frame = Instance.new("Frame")
    frame.Size = UDim2.new(1, -10, 0, 48)
    frame.BackgroundColor3 = Theme.Surface
    frame.BorderSizePixel = 0
    frame.Parent = parent
    roundRect(frame, 8)
    table.insert(uiComponents, frame)
    
    local lbl = Instance.new("TextLabel")
    lbl.Size = UDim2.new(1, -60, 0, 20)
    lbl.Position = UDim2.new(0, 12, 0, 4)
    lbl.BackgroundTransparency = 1
    lbl.Text = title
    lbl.TextColor3 = Theme.Text
    lbl.TextSize = 14
    lbl.Font = Enum.Font.Gotham
    lbl.TextXAlignment = Enum.TextXAlignment.Left
    lbl.Parent = frame
    
    local valueLbl = Instance.new("TextLabel")
    valueLbl.Size = UDim2.new(0, 48, 0, 20)
    valueLbl.Position = UDim2.new(1, -55, 0, 4)
    valueLbl.BackgroundTransparency = 1
    valueLbl.Text = tostring(default) .. (suffix or "")
    valueLbl.TextColor3 = Theme.AccentSecondary
    valueLbl.TextSize = 13
    valueLbl.Font = Enum.Font.GothamBold
    valueLbl.TextXAlignment = Enum.TextXAlignment.Right
    valueLbl.Parent = frame
    
    local track = Instance.new("Frame")
    track.Size = UDim2.new(1, -24, 0, 3)
    track.Position = UDim2.new(0, 12, 0, 34)
    track.BackgroundColor3 = Color3.fromRGB(50, 50, 70)
    track.BorderSizePixel = 0
    track.Parent = frame
    roundRect(track, 3)
    
    local fill = Instance.new("Frame")
    fill.Size = UDim2.new(0, 0, 1, 0)
    fill.BackgroundColor3 = Theme.Accent
    fill.BorderSizePixel = 0
    fill.Parent = track
    roundRect(fill, 3)
    
    local thumb = Instance.new("Frame")
    thumb.Size = UDim2.new(0, 14, 0, 14)
    thumb.Position = UDim2.new(0, -7, 0.5, -7)
    thumb.BackgroundColor3 = Theme.Text
    thumb.BorderSizePixel = 0
    thumb.Parent = fill
    roundRect(thumb, 14)
    
    local currentValue = default or min
    local dragging = false
    
    local function updateSlider(input)
        local trackAbsPos = track.AbsolutePosition
        local trackSize = track.AbsoluteSize.x
        if trackSize <= 0 then return end
        
        local x = math_clamp(input.Position.X - trackAbsPos.X, 0, trackSize)
        local ratio = x / trackSize
        currentValue = min + (max - min) * ratio
        
        if suffix == "ms" or suffix == "" then
            currentValue = math_round(currentValue, 2)
        else
            currentValue = math_round(currentValue, 0)
        end
        
        fill.Size = UDim2.new(ratio, 0, 1, 0)
        valueLbl.Text = tostring(currentValue) .. (suffix or "")
        if callback then callback(currentValue) end
    end
    
    local function startDrag(input)
        dragging = true
        updateSlider(input)
    end
    
    local function endDrag()
        dragging = false
    end
    
    thumb.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            startDrag(input)
        end
    end)
    
    track.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            startDrag(input)
        end
    end)
    
    local inputChangedCon
    inputChangedCon = UserInputService.InputChanged:Connect(function(input)
        if dragging and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then
            updateSlider(input)
        end
    end)
    
    local inputEndedCon
    inputEndedCon = UserInputService.InputEnded:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            endDrag()
        end
    end)
    
    return frame, function() return currentValue end
end

local function createDropdown(parent, title, options, default, callback)
    local frame = Instance.new("Frame")
    frame.Size = UDim2.new(1, -10, 0, 40)
    frame.BackgroundColor3 = Theme.Surface
    frame.BorderSizePixel = 0
    frame.Parent = parent
    roundRect(frame, 8)
    table.insert(uiComponents, frame)
    
    local lbl = Instance.new("TextLabel")
    lbl.Size = UDim2.new(1, -80, 1, 0)
    lbl.Position = UDim2.new(0, 12, 0, 0)
    lbl.BackgroundTransparency = 1
    lbl.Text = title
    lbl.TextColor3 = Theme.Text
    lbl.TextSize = 14
    lbl.Font = Enum.Font.Gotham
    lbl.TextXAlignment = Enum.TextXAlignment.Left
    lbl.Parent = frame
    
    local currentItem = default or options[1]
    
    local dropBtn = Instance.new("TextButton")
    dropBtn.Size = UDim2.new(0, 70, 0, 26)
    dropBtn.Position = UDim2.new(1, -78, 0.5, -13)
    dropBtn.BackgroundColor3 = Theme.SurfaceDark
    dropBtn.BorderSizePixel = 0
    dropBtn.Text = currentItem
    dropBtn.TextColor3 = Theme.Text
    dropBtn.TextSize = 12
    dropBtn.Font = Enum.Font.GothamBold
    dropBtn.Parent = frame
    roundRect(dropBtn, 6)
    
    local expanded = false
    local dropdownList = nil
    
    dropBtn.MouseButton1Click:Connect(function()
        expanded = not expanded
        if expanded then
            if dropdownList then pcall(function() dropdownList:Destroy() end) end
            dropdownList = Instance.new("Frame")
            dropdownList.Size = UDim2.new(0, 148, 0, #options * 28 + 4)
            dropdownList.Position = UDim2.new(1, -78, 1, 4)
            dropdownList.BackgroundColor3 = Theme.SurfaceDark
            dropdownList.BorderSizePixel = 0
            dropdownList.Parent = frame
            roundRect(dropdownList, 6)
            makeStroke(dropdownList, Theme.Border)
            
            for idx, opt in ipairs(options) do
                local optBtn = Instance.new("TextButton")
                optBtn.Size = UDim2.new(1, -4, 0, 24)
                optBtn.Position = UDim2.new(0, 2, 0, 2 + (idx-1) * 28)
                optBtn.BackgroundColor3 = (opt == currentItem) and Theme.Accent or Color3.fromRGB(30, 30, 50)
                optBtn.BorderSizePixel = 0
                optBtn.Text = opt
                optBtn.TextColor3 = Theme.Text
                optBtn.TextSize = 12
                optBtn.Font = Enum.Font.Gotham
                optBtn.AutoButtonColor = false
                optBtn.Parent = dropdownList
                roundRect(optBtn, 4)
                
                optBtn.MouseButton1Click:Connect(function()
                    currentItem = opt
                    dropBtn.Text = opt
                    if callback then callback(opt) end
                    expanded = false
                    pcall(function() dropdownList:Destroy() end)
                end)
            end
        else
            if dropdownList then
                pcall(function() dropdownList:Destroy() end)
                dropdownList = nil
            end
        end
    end)
    
    return frame
end

local function createKeybind(parent, title, default, callback)
    local frame = Instance.new("Frame")
    frame.Size = UDim2.new(1, -10, 0, 40)
    frame.BackgroundColor3 = Theme.Surface
    frame.BorderSizePixel = 0
    frame.Parent = parent
    roundRect(frame, 8)
    table.insert(uiComponents, frame)
    
    local lbl = Instance.new("TextLabel")
    lbl.Size = UDim2.new(1, -80, 1, 0)
    lbl.Position = UDim2.new(0, 12, 0, 0)
    lbl.BackgroundTransparency = 1
    lbl.Text = title
    lbl.TextColor3 = Theme.Text
    lbl.TextSize = 14
    lbl.Font = Enum.Font.Gotham
    lbl.TextXAlignment = Enum.TextXAlignment.Left
    lbl.Parent = frame
    
    local currentKey = default or Enum.KeyCode.F
    
    local keyBtn = Instance.new("TextButton")
    keyBtn.Size = UDim2.new(0, 70, 0, 26)
    keyBtn.Position = UDim2.new(1, -78, 0.5, -13)
    keyBtn.BackgroundColor3 = Theme.SurfaceDark
    keyBtn.BorderSizePixel = 0
    keyBtn.Text = currentKey.Name
    keyBtn.TextColor3 = Theme.Text
    keyBtn.TextSize = 12
    keyBtn.Font = Enum.Font.GothamBold
    keyBtn.Parent = frame
    roundRect(keyBtn, 6)
    
    local listening = false
    
    keyBtn.MouseButton1Click:Connect(function()
        if listening then return end
        listening = true
        keyBtn.Text = "..."
        keyBtn.TextColor3 = Theme.AccentSecondary
        
        local con
        con = UserInputService.InputBegan:Connect(function(input)
            if input.UserInputType == Enum.UserInputType.Keyboard then
                listening = false
                currentKey = input.KeyCode
                keyBtn.Text = currentKey.Name
                keyBtn.TextColor3 = Theme.Text
                if callback then callback(currentKey) end
                con:Disconnect()
            end
        end)
        
        local escCon
        escCon = UserInputService.InputBegan:Connect(function(input)
            if input.KeyCode == Enum.KeyCode.Escape then
                listening = false
                keyBtn.Text = currentKey.Name
                keyBtn.TextColor3 = Theme.Text
                con:Disconnect()
                escCon:Disconnect()
            end
        end)
    end)
    
    return frame, function() return currentKey end
end

-- ================= POPULATE TABS =================
-- TAB 1: Aim
local aimContent = tabContents[1]

createToggle(aimContent, "Aim Assist", "Enable/disable smooth lock-on", false, function(state)
    Config.enabled = state
    if state then
        Config.currentTarget = findBestTarget_Compat()
        if not Config.currentTarget then Config.enabled = false end
        local success, _ = pcall(function()
            RunService:BindToRenderStep("LockOnCamera", Enum.RenderPriority.Camera.Value + 1, updateCamera_Compat)
        end)
        if not success then
            -- Fallback to RenderStepped if BindToRenderStep fails (Xeno issue)
            Config._renderCon = RunService.RenderStepped:Connect(updateCamera_Compat)
        end
    else
        Config.currentTarget = nil
        pcall(function()
            RunService:UnbindFromRenderStep("LockOnCamera")
        end)
        if Config._renderCon then
            Config._renderCon:Disconnect()
            Config._renderCon = nil
        end
    end
end)

createDropdown(aimContent, "Aim Mode", {"Toggle", "Hold"}, "Toggle", function(v)
    Config.aimMode = v
end)

createSlider(aimContent, "Smoothness", 0.01, 0.5, 0.12, "", function(v)
    Config.smoothSpeed = v
end)

createSlider(aimContent, "Lock Range", 50, 1000, 500, " studs", function(v)
    Config.lockRange = v
end)

createDropdown(aimContent, "Aim Part", {"Head", "Torso", "Random"}, "Head", function(v)
    Config.aimPart = v
end)

createSlider(aimContent, "Prediction", 0, 1, 0, "", function(v)
    Config.prediction = v
end)

createToggle(aimContent, "Team Check", "Ignore teammates", false, function(v)
    Config.teamCheck = v
end)

createToggle(aimContent, "Wall Check", "Require line of sight", false, function(v)
    Config.wallCheck = v
end)

createToggle(aimContent, "Priority Low HP", "Target lowest health first", false, function(v)
    Config.prioritizeLowHealth = v
end)

createKeybind(aimContent, "Toggle Key", Enum.KeyCode.F, function(k)
    Config.toggleKey = k
end)

-- Spacer
local spacer = Instance.new("Frame")
spacer.Size = UDim2.new(1, 0, 0, 10)
spacer.BackgroundTransparency = 1
spacer.Parent = aimContent

-- TAB 2: Visuals
local visContent = tabContents[2]

createToggle(visContent, "ESP (Wallhack)", "See players through walls", true, function(v)
    Config.espEnabled = v
end)

createToggle(visContent, "Health Bar", "Show health on ESP", true, function(v)
    Config.showHealthBar = v
end)

createToggle(visContent, "Show Distance", "Distance text on ESP", true, function(v)
    Config.showDistance = v
end)

createToggle(visContent, "Show Boxes", "2D bounding boxes", false, function(v)
    Config.showBoxes = v
end)

createToggle(visContent, "FOV Circle", "Show aim assist field", true, function(v)
    Config.showFOVCircle = v
end)

createSlider(visContent, "FOV Size", 10, 360, 120, "°", function(v)
    Config.fovSize = v
end)

createKeybind(visContent, "ESP Toggle Key", Enum.KeyCode.H, function(k)
    Config.espToggleKey = k
end)

-- TAB 3: Trigger
local trigContent = tabContents[3]

createToggle(trigContent, "Triggerbot", "Auto-fire on target", false, function(v)
    Config.triggerbotEnabled = v
end)

createSlider(trigContent, "Trigger Delay", 0, 0.5, 0.05, "ms", function(v)
    Config.triggerbotDelay = v
end)

createSlider(trigContent, "Trigger FOV", 1, 30, 5, "°", function(v)
    Config.triggerbotFOV = v
end)

createToggle(trigContent, "Trigger on Key", "Only trigger when key held", false, function(v)
    Config.triggerbotOnKey = v
end)

createKeybind(trigContent, "Trigger Key", Enum.KeyCode.X, function(k)
    Config.triggerbotKey = k
end)

createToggle(trigContent, "Auto Shoot", "Continuous fire on target", false, function(v)
    Config.autoShoot = v
end)

-- TAB 4: Settings
local setContent = tabContents[4]

createToggle(setContent, "Silent Aim", "Look legit - no camera movement", false, function(v)
    Config.silentAim = v
end)

createToggle(setContent, "Show Watermark", "Display premium overlay", true, function(v)
    local wm = screenGui:FindFirstChild("Watermark")
    if wm then wm.Visible = v end
end)

-- UI Toggle Button
local uiToggle = Instance.new("TextButton")
uiToggle.Size = UDim2.new(0, 120, 0, 32)
uiToggle.Position = UDim2.new(1, -140, 1, -40)
uiToggle.BackgroundColor3 = Theme.Surface
uiToggle.BorderSizePixel = 0
uiToggle.Text = "☰ Toggle UI"
uiToggle.TextColor3 = Theme.Text
uiToggle.TextSize = 12
uiToggle.Font = Enum.Font.GothamBold
uiToggle.Parent = screenGui

roundRect(uiToggle, 8)
makeStroke(uiToggle, Theme.Border)

uiToggle.MouseButton1Click:Connect(function()
    Config.uiOpen = not Config.uiOpen
    main.Visible = Config.uiOpen
end)

-- ================= CORE MECHANICS (Xeno Compatible) =================
function checkLineOfSight_Compat(targetPart)
    local origin = camera.CFrame.Position
    local direction = (targetPart.Position - origin).Unit * (targetPart.Position - origin).Magnitude
    
    local success, result = pcall(function()
        local params = RaycastParams.new()
        params.FilterDescendantsInstances = {player.Character, targetPart.Parent}
        params.FilterType = Enum.RaycastFilterType.Exclude
        return workspace:Raycast(origin, direction, params)
    end)
    
    if success then
        return result == nil
    end
    
    -- Fallback: use old raycasting
    local ray = Ray.new(origin, direction)
    local hit, _ = workspace:FindPartOnRayWithIgnoreList(ray, {player.Character})
    return hit == nil or hit:IsDescendantOf(targetPart.Parent)
end

function clearESP_Compat(char)
    if not char then return end
    pcall(function()
        local hl = char:FindFirstChild("ESPHighlight")
        if hl then hl:Destroy() end
        local bb = char:FindFirstChild("ESPBillboard")
        if bb then bb:Destroy() end
    end)
end

function applyESP_Compat(p)
    if not Config.espEnabled then
        clearESP_Compat(p.Character)
        return
    end
    
    local char = p.Character
    if not char then return end
    
    if Config.teamCheck and p.Team == player.Team then
        clearESP_Compat(char)
        return
    end
    
    local root = char:FindFirstChild("HumanoidRootPart")
    local humanoid = char:FindFirstChildOfClass("Humanoid")
    if not root or not humanoid then return end
    
    -- Use Highlight if available
    local hl = char:FindFirstChild("ESPHighlight")
    if not hl then
        local success, newHL = pcall(function()
            local h = Instance.new("Highlight")
            h.Name = "ESPHighlight"
            h.Parent = char
            return h
        end)
        if success then hl = newHL end
    end
    
    if hl then
        if p == Config.currentTarget then
            hl.FillColor = Config.espTargetColor
            hl.OutlineColor = Config.espTargetColor
            hl.FillOpacity = Config.espFillOpacity + 0.15
            hl.OutlineOpacity = 1.0
        else
            hl.FillColor = Config.espFillColor
            hl.OutlineColor = Config.espOutlineColor
            hl.FillOpacity = Config.espFillOpacity
            hl.OutlineOpacity = Config.espOutlineOpacity
        end
        pcall(function()
            hl.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
            hl.Enabled = true
        end)
    end
    
    -- Billboard info
    if Config.showHealthBar or Config.showDistance then
        local billboard = char:FindFirstChild("ESPBillboard")
        if not billboard then
            billboard = Instance.new("BillboardGui")
            billboard.Name = "ESPBillboard"
            billboard.Size = UDim2.new(0, 100, 0, 30)
            billboard.StudsOffset = Vector3.new(0, 3.5, 0)
            billboard.AlwaysOnTop = true
            billboard.Parent = char
            
            local info = Instance.new("TextLabel")
            info.Name = "ESPInfo"
            info.Size = UDim2.new(1, 0, 1, 0)
            info.BackgroundTransparency = 1
            info.TextColor3 = Color3.fromRGB(255, 255, 255)
            info.TextSize = 12
            info.Font = Enum.Font.GothamBold
            info.TextStrokeTransparency = 0.3
            info.Text = ""
            info.Parent = billboard
        end
        
        local info = billboard:FindFirstChild("ESPInfo")
        if info then
            local text = ""
            if Config.showHealthBar then
                local health = math.floor(humanoid.Health)
                local maxHealth = math.floor(humanoid.MaxHealth)
                text = text .. string.format("[%d/%d]", health, maxHealth)
            end
            if Config.showDistance then
                local dist = math.floor((root.Position - camera.CFrame.Position).Magnitude)
                if text ~= "" then text = text .. " | " end
                text = text .. dist .. "m"
            end
            info.Text = text
        end
    end
end

function findBestTarget_Compat()
    local best, bestScore = nil, -math.huge
    
    for _, p in ipairs(Players:GetPlayers()) do
        if p ~= player and p.Character then
            local root = p.Character:FindFirstChild("HumanoidRootPart")
            local humanoid = p.Character:FindFirstChildOfClass("Humanoid")
            
            if root and humanoid and humanoid.Health > 0 then
                if Config.teamCheck and p.Team == player.Team then continue end
                
                local distance = (root.Position - camera.CFrame.Position).Magnitude
                if distance <= Config.lockRange then
                    local screenPos, onScreen = camera:WorldToViewportPoint(root.Position)
                    
                    if Config.wallCheck and not checkLineOfSight_Compat(root) then continue end
                    if onScreen and screenPos.Z > 0 then
                        local centerDist = (Vector2.new(screenPos.X, screenPos.Y) - 
                            Vector2.new(camera.ViewportSize.X/2, camera.ViewportSize.Y/2)).Magnitude
                        
                        local score = -distance - centerDist * 0.5
                        if Config.prioritizeLowHealth then
                            score = score - (humanoid.Health / humanoid.MaxHealth) * 100
                        end
                        
                        if score > bestScore then
                            best = p
                            bestScore = score
                        end
                    end
                end
            end
        end
    end
    
    return best
end

function getAimPart_Compat(char)
    if Config.aimPart == "Head" then
        local head = char:FindFirstChild("Head")
        if head then return head end
        local root = char:FindFirstChild("HumanoidRootPart")
        if root then return root end
    elseif Config.aimPart == "Torso" then
        local torso = char:FindFirstChild("UpperTorso") or char:FindFirstChild("Torso")
        local root = char:FindFirstChild("HumanoidRootPart")
        if torso then return torso end
        if root then return root end
    else -- Random
        local parts = {"Head", "HumanoidRootPart", "UpperTorso", "LowerTorso"}
        for _, name in ipairs(parts) do
            local part = char:FindFirstChild(name)
            if part then return part end
        end
    end
    return char:FindFirstChild("HumanoidRootPart")
end

function updateCamera_Compat(dt)
    if not Config.enabled or not Config.currentTarget then return end
    if Config.silentAim then return end
    
    local char = Config.currentTarget.Character
    if not char then Config.currentTarget = nil; return end
    
    local aimPart = getAimPart_Compat(char)
    local root = char:FindFirstChild("HumanoidRootPart")
    local humanoid = char:FindFirstChildOfClass("Humanoid")
    
    if not aimPart or not humanoid or humanoid.Health <= 0 then
        Config.currentTarget = nil
        return
    end
    
    if Config.wallCheck and not checkLineOfSight_Compat(aimPart) then
        Config.currentTarget = nil
        return
    end
    
    local targetPos = aimPart.Position + Config.heightOffset
    
    if Config.prediction > 0 then
        local rootPart = root or aimPart
        local velocity = rootPart.Velocity
        targetPos = targetPos + velocity * Config.prediction * 0.1
    end
    
    local goalCF = CFrame.lookAt(camera.CFrame.Position, targetPos)
    local alpha = 1 - math.pow(1 - Config.smoothSpeed, dt * 60)
    camera.CFrame = camera.CFrame:Lerp(goalCF, alpha)
end

-- ================= FOV CIRCLE =================
local fovCircle = Instance.new("ImageLabel")
fovCircle.Name = "FOVCircle"
fovCircle.Size = UDim2.new(0, 240, 0, 240)
fovCircle.Position = UDim2.new(0.5, -120, 0.5, -120)
fovCircle.BackgroundTransparency = 1
fovCircle.ImageColor3 = Config.fovCircleColor
fovCircle.ImageTransparency = 0.7
fovCircle.Visible = Config.showFOVCircle
fovCircle.ZIndex = 10
fovCircle.Parent = screenGui

-- Try different ring textures for Xeno compatibility
local ringTextures = {
    "rbxassetid://12474045622",
    "rbxassetid://76328712180",
    "rbxassetid://10383795699",
    "rbxassetid://6062564479",
}
local function tryRingTexture()
    for _, tex in ipairs(ringTextures) do
        local success, _ = pcall(function()
            fovCircle.Image = tex
        end)
        if success then return end
    end
    -- Fallback to nothing
end
tryRingTexture()

spawn(function()
    while fovCircle and fovCircle.Parent do
        task.wait(0.5)
        if Config.showFOVCircle then
            local fovRad = math_rad(Config.fovSize / 2)
            local size = math_tan(fovRad) * camera.ViewportSize.Y
            fovCircle.Size = UDim2.new(0, size*2, 0, size*2)
            fovCircle.Position = UDim2.new(0.5, -size, 0.5, -size)
            fovCircle.Visible = true
        else
            fovCircle.Visible = false
        end
    end
end)

-- ================= INPUT HANDLING =================
UserInputService.InputBegan:Connect(function(input, gpe)
    if gpe then return end
    
    if input.KeyCode == Config.toggleKey then
        Config.enabled = not Config.enabled
        if Config.enabled then
            Config.currentTarget = findBestTarget_Compat()
            if not Config.currentTarget then Config.enabled = false end
            local success, _ = pcall(function()
                RunService:BindToRenderStep("LockOnCamera", Enum.RenderPriority.Camera.Value + 1, updateCamera_Compat)
            end)
            if not success then
                if Config._renderCon then Config._renderCon:Disconnect() end
                Config._renderCon = RunService.RenderStepped:Connect(updateCamera_Compat)
            end
        else
            Config.currentTarget = nil
            pcall(function() RunService:UnbindFromRenderStep("LockOnCamera") end)
            if Config._renderCon then
                Config._renderCon:Disconnect()
                Config._renderCon = nil
            end
        end
    end
    
    if input.KeyCode == Config.espToggleKey then
        Config.espEnabled = not Config.espEnabled
    end
    
    if input.KeyCode == Config.triggerbotToggleKey then
        Config.triggerbotEnabled = not Config.triggerbotEnabled
    end
    
    if input.UserInputType == Config.switchTargetKey and Config.enabled then
        local newTarget = findBestTarget_Compat()
        if newTarget then Config.currentTarget = newTarget end
    end
end)

-- ================= TRIGGERBOT =================
local triggerCon = RunService.Heartbeat:Connect(function()
    if not Config.triggerbotEnabled then return end
    if not Config.currentTarget then return end
    
    local char = Config.currentTarget.Character
    if not char then return end
    
    local aimPart = getAimPart_Compat(char)
    if not aimPart then return end
    
    local screenPos = camera:WorldToViewportPoint(aimPart.Position)
    if screenPos.Z <= 0 then return end
    
    local center = Vector2.new(camera.ViewportSize.X/2, camera.ViewportSize.Y/2)
    local crosshairDist = (Vector2.new(screenPos.X, screenPos.Y) - center).Magnitude
    local maxDist = math_tan(math_rad(Config.triggerbotFOV)) * camera.ViewportSize.Y
    
    if crosshairDist <= maxDist then
        if Config.triggerbotOnKey then
            if UserInputService:IsKeyDown(Config.triggerbotKey) then
                task.wait(Config.triggerbotDelay)
                mouse1press()
                task.wait()
                mouse1release()
            end
        else
            task.wait(Config.triggerbotDelay)
            mouse1press()
            task.wait(0.05)
            mouse1release()
        end
    end
end)

-- ================= AUTO SHOOT =================
local autoShootCon = RunService.Heartbeat:Connect(function()
    if not Config.autoShoot then return end
    if not Config.currentTarget then return end
    
    local char = Config.currentTarget.Character
    if not char then return end
    
    local root = char:FindFirstChild("HumanoidRootPart")
    local humanoid = char:FindFirstChildOfClass("Humanoid")
    if not root or not humanoid or humanoid.Health <= 0 then return end
    
    local screenPos = camera:WorldToViewportPoint(root.Position)
    local center = Vector2.new(camera.ViewportSize.X/2, camera.ViewportSize.Y/2)
    local crosshairDist = (Vector2.new(screenPos.X, screenPos.Y) - center).Magnitude
    local maxDist = math_tan(math_rad(Config.triggerbotFOV)) * camera.ViewportSize.Y
    
    if crosshairDist <= maxDist then
        mouse1press()
        task.wait(0.05)
        mouse1release()
    end
end)

-- ================= ESP LOOP =================
spawn(function()
    while screenGui and screenGui.Parent do
        task.wait(0.1)
        
        -- Update status dot
        local dot = screenGui:FindFirstChild("MainWindow")
        if dot then
            dot = dot:FindFirstChild("TitleBar")
            if dot then
                local st = dot:FindFirstChild("StatusDot") or dot:FindFirstChild("TitleText"):FindFirstChild("StatusDot")
                -- Already handled above - statusDot was parented to titleText
            end
        end
        -- Direct reference
        statusDot.BackgroundColor3 = Config.enabled and Theme.Success or Color3.fromRGB(255, 0, 0)
        
        -- ESP
        if Config.espEnabled then
            for _, p in ipairs(Players:GetPlayers()) do
                if p ~= player then applyESP_Compat(p) end
            end
        end
    end
end)

-- ================= CLEANUP =================
Players.PlayerRemoving:Connect(function(p)
    clearESP_Compat(p.Character)
end)

-- Also cleanup on character removal
game:GetService("CollectionService"):GetInstanceRemovingSignal("Character"):Connect(function()
    -- Passive cleanup handled by loop
end)

-- ================= WATERMARK =================
local watermark = Instance.new("TextLabel")
watermark.Name = "Watermark"
watermark.Size = UDim2.new(0, 200, 0, 20)
watermark.Position = UDim2.new(0.5, -100, 0, 6)
watermark.BackgroundTransparency = 1
watermark.Text = "✦ PREMIUM AIM v2.0 • ACTIVE"
watermark.TextColor3 = Theme.AccentSecondary
watermark.TextSize = 11
watermark.Font = Enum.Font.GothamBold
watermark.TextTransparency = 0.4
watermark.TextStrokeTransparency = 0.8
watermark.Visible = true
watermark.ZIndex = 100
watermark.Parent = screenGui

-- Watermark animation (safe for Xeno)
spawn(function()
    local startTime = tick()
    while watermark and watermark.Parent do
        task.wait(0.05)
        local elapsed = tick() - startTime
        watermark.TextTransparency = 0.4 + math.sin(elapsed * 0.5) * 0.15
    end
end)

-- ================= NOTIFICATION =================
print("✦ Premium Aim Assist v2.0 loaded successfully!")
print("Press F to toggle aim assist | H = ESP | G = Triggerbot")
print("Right-click to switch targets | UI toggle button in bottom-right")
