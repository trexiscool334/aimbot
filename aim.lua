-- ============================================
-- ULTRA PREMIUM AIM ASSIST v2.0
-- Professional-grade UI + Full Feature Suite
-- ============================================

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local TweenService = game:GetService("TweenService")
local TextService = game:GetService("TextService")
local HttpService = game:GetService("HttpService")

local player = Players.LocalPlayer
local camera = workspace.CurrentCamera
local mouse = player:GetMouse()

-- ================= CONFIG =================
local Config = {
    -- Lock-On
    enabled = false,
    currentTarget = nil,
    aimMode = "Toggle",          -- "Toggle" | "Hold"
    smoothSpeed = 0.12,
    lockRange = 500,
    heightOffset = Vector3.new(0, 1.6, 0),
    fovSize = 120,               -- Degrees for FOV circle
    
    -- Targeting Filters
    teamCheck = false,
    wallCheck = false,
    prioritizeLowHealth = false,
    aimPart = "Head",            -- "Head" | "Torso" | "Random"
    
    -- Triggerbot
    triggerbotEnabled = false,
    triggerbotDelay = 0.05,      -- Seconds before firing
    triggerbotFOV = 5,           -- Degrees within crosshair to trigger
    triggerbotOnKey = false,
    triggerbotKey = Enum.KeyCode.X,
    autoShoot = false,
    
    -- ESP
    espEnabled = true,
    espFillColor = Color3.fromRGB(140, 60, 255),
    espOutlineColor = Color3.fromRGB(255, 255, 255),
    espTargetColor = Color3.fromRGB(0, 255, 180),
    espFillOpacity = 0.35,
    espOutlineOpacity = 0.8,
    showHealthBar = true,
    showDistance = true,
    showBoxes = false,
    
    -- Visuals
    showFOVCircle = true,
    fovCircleColor = Color3.fromRGB(0, 255, 180),
    crosshairEnabled = true,
    crosshairColor = Color3.fromRGB(255, 255, 255),
    
    -- Silkroad / Noise
    silentAim = false,           -- Silent aim toggle (looks legit)
    prediction = 0.0,           -- Movement prediction (0-1)
    
    -- Keybinds
    toggleKey = Enum.KeyCode.F,
    triggerbotToggleKey = Enum.KeyCode.G,
    espToggleKey = Enum.KeyCode.H,
    switchTargetKey = Enum.KeyCode.MouseButton2,
}

-- ================= UI FRAMEWORK =================
local UI = {}
UI.__index = UI

-- Color scheme
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

-- Simple tween wrapper
local function tween(obj, props, dur, easing, dir)
    local t = TweenService:Create(obj, TweenInfo.new(dur or 0.25, easing or Enum.EasingStyle.Quad, dir or Enum.EasingDirection.Out), props)
    t:Play()
    return t
end

-- ================= UI BUILDER =================
function UI:CreateWindow()
    local screenGui = Instance.new("ScreenGui")
    screenGui.Name = "PremiumAimAssist"
    screenGui.ResetOnSpawn = false
    screenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
    screenGui.Parent = player:WaitForChild("PlayerGui")
    
    -- Main container with glassmorphism
    local main = Instance.new("Frame")
    main.Name = "MainWindow"
    main.Size = UDim2.new(0, 360, 0, 520)
    main.Position = UDim2.new(0, 30, 0.5, -260)
    main.BackgroundColor3 = Theme.Background
    main.BorderSizePixel = 0
    main.ClipsDescendants = true
    main.Parent = screenGui
    
    -- Glass border effect
    local border = Instance.new("UIStroke")
    border.Thickness = 1
    border.Color = Theme.Border
    border.Transparency = 0.3
    border.Parent = main
    
    -- Corner round
    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(0, 12)
    corner.Parent = main
    
    -- Drop shadow
    local shadow = Instance.new("ImageLabel")
    shadow.Name = "Shadow"
    shadow.Size = UDim2.new(1, 40, 1, 40)
    shadow.Position = UDim2.new(0, -20, 0, -20)
    shadow.BackgroundTransparency = 1
    shadow.Image = "rbxassetid://13162562082"
    shadow.ImageColor3 = Color3.fromRGB(0, 0, 0)
    shadow.ImageTransparency = 0.6
    shadow.ScaleType = Enum.ScaleType.Slice
    shadow.SliceCenter = Rect.new(20, 54, 272, 346)
    shadow.ZIndex = -1
    shadow.Parent = main
    
    -- Title bar
    local titleBar = Instance.new("Frame")
    titleBar.Size = UDim2.new(1, 0, 0, 50)
    titleBar.BackgroundColor3 = Theme.SurfaceDark
    titleBar.BorderSizePixel = 0
    titleBar.Parent = main
    
    local titleCorner = Instance.new("UICorner")
    titleCorner.CornerRadius = UDim.new(0, 12)
    titleCorner.Parent = titleBar
    
    -- Top-only rounded corners trick
    local titleClip = Instance.new("Frame")
    titleClip.Size = UDim2.new(1, 0, 0, 12)
    titleClip.Position = UDim2.new(0, 0, 1, -12)
    titleClip.BackgroundColor3 = Theme.SurfaceDark
    titleClip.BorderSizePixel = 0
    titleClip.Parent = titleBar
    
    -- Logo / Title
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
    
    -- Version badge
    local badge = Instance.new("Frame")
    badge.Size = UDim2.new(0, 14, 0, 14)
    badge.Position = UDim2.new(1, -25, 0.5, -7)
    badge.BackgroundColor3 = Theme.Success
    badge.BorderSizePixel = 0
    badge.Parent = titleBar
    
    local badgeCorner = Instance.new("UICorner")
    badgeCorner.CornerRadius = UDim.new(1, 0)
    badgeCorner.Parent = badge
    
    -- Status indicator
    local statusDot = Instance.new("Frame")
    statusDot.Size = UDim2.new(0, 8, 0, 8)
    statusDot.Position = UDim2.new(0, 5, 0.5, -4)
    statusDot.BackgroundColor3 = Color3.fromRGB(255, 0, 0)
    statusDot.BorderSizePixel = 0
    statusDot.Parent = titleText
    
    local dotCorner = Instance.new("UICorner")
    dotCorner.CornerRadius = UDim.new(1, 0)
    dotCorner.Parent = statusDot
    
    -- Separator
    local sep = Instance.new("Frame")
    sep.Size = UDim2.new(1, -30, 0, 1)
    sep.Position = UDim2.new(0, 15, 0, 50)
    sep.BackgroundColor3 = Theme.Border
    sep.BorderSizePixel = 0
    sep.Parent = main
    
    -- Tab buttons
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
        btn.ClipsDescendants = true
        btn.Parent = tabBar
        
        table.insert(tabButtons, btn)
        
        -- Tab content container
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
    
    return screenGui, main, tabContents, tabButtons
end

-- ================= UI COMPONENTS =================
function UI:CreateToggle(parent, title, desc, default, callback)
    local frame = Instance.new("Frame")
    frame.Size = UDim2.new(1, -10, 0, 40)
    frame.BackgroundColor3 = Theme.Surface
    frame.BorderSizePixel = 0
    frame.Parent = parent
    
    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(0, 8)
    corner.Parent = frame
    
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
        -- Move title up if desc exists
        lbl.TextYAlignment = Enum.TextYAlignment.Top
        lbl.Size = UDim2.new(1, -55, 0.5, -2)
    end
    
    local togBg = Instance.new("Frame")
    togBg.Size = UDim2.new(0, 34, 0, 18)
    togBg.Position = UDim2.new(1, -42, 0.5, -9)
    togBg.BackgroundColor3 = Color3.fromRGB(60, 60, 80)
    togBg.BorderSizePixel = 0
    togBg.Parent = frame
    
    local togCorner = Instance.new("UICorner")
    togCorner.CornerRadius = UDim.new(1, 0)
    togCorner.Parent = togBg
    
    local knob = Instance.new("Frame")
    knob.Size = UDim2.new(0, 14, 0, 14)
    knob.Position = UDim2.new(0, 2, 0.5, -7)
    knob.BackgroundColor3 = Theme.Text
    knob.BorderSizePixel = 0
    knob.Parent = togBg
    
    local knobCorner = Instance.new("UICorner")
    knobCorner.CornerRadius = UDim.new(1, 0)
    knobCorner.Parent = knob
    
    local state = default or false
    local function setState(newState)
        state = newState
        togBg.BackgroundColor3 = state and Theme.Success or Color3.fromRGB(60, 60, 80)
        tween(knob, {
            Position = state and UDim2.new(1, -16, 0.5, -7) or UDim2.new(0, 2, 0.5, -7)
        }, 0.2)
        if callback then callback(state) end
    end
    
    -- Click handler on whole frame
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

function UI:CreateSlider(parent, title, min, max, default, suffix, callback)
    local frame = Instance.new("Frame")
    frame.Size = UDim2.new(1, -10, 0, 45)
    frame.BackgroundColor3 = Theme.Surface
    frame.BorderSizePixel = 0
    frame.Parent = parent
    
    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(0, 8)
    corner.Parent = frame
    
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
    
    -- Slider track
    local track = Instance.new("Frame")
    track.Size = UDim2.new(1, -24, 0, 3)
    track.Position = UDim2.new(0, 12, baseY, 28)
    track.BackgroundColor3 = Color3.fromRGB(50, 50, 70)
    track.BorderSizePixel = 0
    track.Parent = frame
    
    -- Let's use the correct Y dynamically
    task.wait()
    track.Size = UDim2.new(1, -24, 0, 3)
    track.Position = UDim2.new(0, 12, 0, 28)
    track.Parent = frame
    
    local trackCorner = Instance.new("UICorner")
    trackCorner.CornerRadius = UDim.new(1, 0)
    trackCorner.Parent = track
    
    local fill = Instance.new("Frame")
    fill.Size = UDim2.new(0, 0, 1, 0)
    fill.BackgroundColor3 = Theme.Accent
    fill.BorderSizePixel = 0
    fill.Parent = track
    
    local fillCorner = Instance.new("UICorner")
    fillCorner.CornerRadius = UDim.new(1, 0)
    fillCorner.Parent = fill
    
    local thumb = Instance.new("Frame")
    thumb.Size = UDim2.new(0, 14, 0, 14)
    thumb.Position = UDim2.new(0, -7, 0.5, -7)
    thumb.BackgroundColor3 = Theme.Text
    thumb.BorderSizePixel = 0
    thumb.Parent = fill
    
    local thumbCorner = Instance.new("UICorner")
    thumbCorner.CornerRadius = UDim.new(1, 0)
    thumbCorner.Parent = thumb
    
    local value = default or min
    local dragging = false
    
    local function updateSlider(input)
        local x = math.clamp(input.Position.X - track.AbsolutePosition.X, 0, track.AbsoluteSize.X)
        local ratio = x / track.AbsoluteSize.X
        value = min + (max - min) * ratio
        if suffix == "ms" or suffix == "" then
            value = math.floor(value * 100) / 100
        else
            value = math.floor(value)
        end
        fill.Size = UDim2.new(ratio, 0, 1, 0)
        valueLbl.Text = tostring(value) .. (suffix or "")
        if callback then callback(value) end
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
    
    UserInputService.InputChanged:Connect(function(input)
        if dragging and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then
            updateSlider(input)
        end
    end)
    
    UserInputService.InputEnded:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            endDrag()
        end
    end)
    
    return frame, function() return value end
end

function UI:CreateDropdown(parent, title, options, default, callback)
    local frame = Instance.new("Frame")
    frame.Size = UDim2.new(1, -10, 0, 40)
    frame.BackgroundColor3 = Theme.Surface
    frame.BorderSizePixel = 0
    frame.Parent = parent
    
    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(0, 8)
    corner.Parent = frame
    
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
    
    local current = default or options[1]
    
    local dropBtn = Instance.new("TextButton")
    dropBtn.Size = UDim2.new(0, 70, 0, 26)
    dropBtn.Position = UDim2.new(1, -78, 0.5, -13)
    dropBtn.BackgroundColor3 = Theme.SurfaceDark
    dropBtn.BorderSizePixel = 0
    dropBtn.Text = current
    dropBtn.TextColor3 = Theme.Text
    dropBtn.TextSize = 12
    dropBtn.Font = Enum.Font.GothamBold
    dropBtn.Parent = frame
    
    local btnCorner = Instance.new("UICorner")
    btnCorner.CornerRadius = UDim.new(0, 6)
    btnCorner.Parent = dropBtn
    
    local expanded = false
    local dropdownList = nil
    
    dropBtn.MouseButton1Click:Connect(function()
        expanded = not expanded
        if expanded then
            if dropdownList then dropdownList:Destroy() end
            dropdownList = Instance.new("Frame")
            dropdownList.Size = UDim2.new(0, 148, 0, #options * 28 + 4)
            dropdownList.Position = UDim2.new(1, -78, 1, 4)
            dropdownList.BackgroundColor3 = Theme.SurfaceDark
            dropdownList.BorderSizePixel = 0
            dropdownList.Parent = frame
            
            local listCorner = Instance.new("UICorner")
            listCorner.CornerRadius = UDim.new(0, 6)
            listCorner.Parent = dropdownList
            
            local listStroke = Instance.new("UIStroke")
            listStroke.Thickness = 1
            listStroke.Color = Theme.Border
            listStroke.Parent = dropdownList
            
            for i, opt in ipairs(options) do
                local optBtn = Instance.new("TextButton")
                optBtn.Size = UDim2.new(1, -4, 0, 24)
                optBtn.Position = UDim2.new(0, 2, 0, 2 + (i-1) * 28)
                optBtn.BackgroundColor3 = (opt == current) and Theme.Accent or Color3.fromRGB(30, 30, 50)
                optBtn.BorderSizePixel = 0
                optBtn.Text = opt
                optBtn.TextColor3 = Theme.Text
                optBtn.TextSize = 12
                optBtn.Font = Enum.Font.Gotham
                optBtn.AutoButtonColor = false
                optBtn.Parent = dropdownList
                
                local optCorner = Instance.new("UICorner")
                optCorner.CornerRadius = UDim.new(0, 4)
                optCorner.Parent = optBtn
                
                optBtn.MouseButton1Click:Connect(function()
                    current = opt
                    dropBtn.Text = opt
                    if callback then callback(opt) end
                    expanded = false
                    dropdownList:Destroy()
                end)
            end
        else
            if dropdownList then
                dropdownList:Destroy()
                dropdownList = nil
            end
        end
    end)
    
    return frame
end

function UI:CreateKeybind(parent, title, default, callback)
    local frame = Instance.new("Frame")
    frame.Size = UDim2.new(1, -10, 0, 40)
    frame.BackgroundColor3 = Theme.Surface
    frame.BorderSizePixel = 0
    frame.Parent = parent
    
    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(0, 8)
    corner.Parent = frame
    
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
    
    local btnCorner = Instance.new("UICorner")
    btnCorner.CornerRadius = UDim.new(0, 6)
    btnCorner.Parent = keyBtn
    
    local listening = false
    
    keyBtn.MouseButton1Click:Connect(function()
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
        
        -- Escape listener
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

-- ================= BUILD INTERFACE =================
local screenGui, mainWindow, tabContents, tabButtons = UI:CreateWindow()

-- Populate tabs with actual controls
-- TAB 1: Aim
local aimContent = tabContents[1]

UI:CreateToggle(aimContent, "Aim Assist", "Enable/disable smooth lock-on", false, function(state)
    Config.enabled = state
    if state then
        Config.currentTarget = findBestTarget_Refactored()
        if not Config.currentTarget then
            Config.enabled = false
        end
        RunService:BindToRenderStep("LockOnCamera", Enum.RenderPriority.Camera.Value + 1, updateCamera_Refactored)
    else
        Config.currentTarget = nil
        RunService:UnbindFromRenderStep("LockOnCamera")
    end
end)

UI:CreateDropdown(aimContent, "Aim Mode", {"Toggle", "Hold"}, "Toggle", function(v)
    Config.aimMode = v
end)

UI:CreateSlider(aimContent, "Smoothness", 0.01, 0.5, 0.12, "", function(v)
    Config.smoothSpeed = v
end)

UI:CreateSlider(aimContent, "Lock Range", 50, 1000, 500, " studs", function(v)
    Config.lockRange = v
end)

UI:CreateDropdown(aimContent, "Aim Part", {"Head", "Torso", "Random"}, "Head", function(v)
    Config.aimPart = v
end)

UI:CreateSlider(aimContent, "Prediction", 0, 1, 0, "", function(v)
    Config.prediction = v
end)

UI:CreateToggle(aimContent, "Team Check", "Ignore teammates", false, function(v)
    Config.teamCheck = v
end)

UI:CreateToggle(aimContent, "Wall Check", "Require line of sight", false, function(v)
    Config.wallCheck = v
end)

UI:CreateToggle(aimContent, "Priority Low HP", "Target lowest health first", false, function(v)
    Config.prioritizeLowHealth = v
end)

UI:CreateKeybind(aimContent, "Toggle Key", Enum.KeyCode.F, function(k)
    Config.toggleKey = k
end)

-- Spacer
local spacer = Instance.new("Frame")
spacer.Size = UDim2.new(1, 0, 0, 10)
spacer.BackgroundTransparency = 1
spacer.Parent = aimContent

-- TAB 2: Visuals
local visContent = tabContents[2]

UI:CreateToggle(visContent, "ESP (Wallhack)", "See players through walls", true, function(v)
    Config.espEnabled = v
end)

UI:CreateToggle(visContent, "Health Bar", "Show health on ESP", true, function(v)
    Config.showHealthBar = v
end)

UI:CreateToggle(visContent, "Show Distance", "Distance text on ESP", true, function(v)
    Config.showDistance = v
end)

UI:CreateToggle(visContent, "Show Boxes", "2D bounding boxes", false, function(v)
    Config.showBoxes = v
end)

UI:CreateToggle(visContent, "FOV Circle", "Show aim assist field", true, function(v)
    Config.showFOVCircle = v
end)

UI:CreateSlider(visContent, "FOV Size", 10, 360, 120, "", function(v)
    Config.fovSize = v
end)

UI:CreateToggle(visContent, "Custom Crosshair", "Replace crosshair", true, function(v)
    Config.crosshairEnabled = v
end)

UI:CreateKeybind(visContent, "ESP Toggle Key", Enum.KeyCode.H, function(k)
    Config.espToggleKey = k
end)

-- TAB 3: Trigger
local trigContent = tabContents[3]

UI:CreateToggle(trigContent, "Triggerbot", "Auto-fire on target", false, function(v)
    Config.triggerbotEnabled = v
end)

UI:CreateSlider(trigContent, "Trigger Delay", 0, 0.5, 0.05, "ms", function(v)
    Config.triggerbotDelay = v
end)

UI:CreateSlider(trigContent, "Trigger FOV", 1, 30, 5, "", function(v)
    Config.triggerbotFOV = v
end)

UI:CreateToggle(trigContent, "Trigger on Key", "Only trigger when key held", false, function(v)
    Config.triggerbotOnKey = v
end)

UI:CreateKeybind(trigContent, "Trigger Key", Enum.KeyCode.X, function(k)
    Config.triggerbotKey = k
end)

UI:CreateToggle(trigContent, "Auto Shoot", "Continuous fire on target", false, function(v)
    Config.autoShoot = v
end)

-- TAB 4: Settings
local setContent = tabContents[4]

UI:CreateToggle(setContent, "Silent Aim", "Look legit - no camera movement", false, function(v)
    Config.silentAim = v
end)

UI:CreateToggle(setContent, "Config Auto-Save", "Remember settings", true)

UI:CreateToggle(setContent, "Show Watermark", "Display premium overlay", true)

-- UI Visibility toggle
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

local uiCorner = Instance.new("UICorner")
uiCorner.CornerRadius = UDim.new(0, 8)
uiCorner.Parent = uiToggle

local uiStroke = Instance.new("UIStroke")
uiStroke.Thickness = 1
uiStroke.Color = Theme.Border
uiStroke.Parent = uiToggle

uiToggle.MouseButton1Click:Connect(function()
    mainWindow.Visible = not mainWindow.Visible
end)

-- ================= CORE FUNCTIONS REFACTORED =================
function checkLineOfSight_Refactored(targetPart)
    local origin = camera.CFrame.Position
    local direction = targetPart.Position - origin
    
    local params = RaycastParams.new()
    params.FilterDescendantsInstances = {player.Character, targetPart.Parent}
    params.FilterType = Enum.RaycastFilterType.Exclude
    
    local result = workspace:Raycast(origin, direction, params)
    return result == nil
end

function clearESP_Refactored(char)
    if char then
        local hl = char:FindFirstChild("ESPHighlight")
        if hl then hl:Destroy() end
        local hl2 = char:FindFirstChild("ESPBillboard")
        if hl2 then hl2:Destroy() end
    end
end

function applyESP_Refactored(p)
    if not Config.espEnabled then
        clearESP_Refactored(p.Character)
        return
    end
    
    local char = p.Character
    if not char then return end
    
    if Config.teamCheck and p.Team == player.Team then
        clearESP_Refactored(char)
        return
    end
    
    local root = char:FindFirstChild("HumanoidRootPart")
    local humanoid = char:FindFirstChildOfClass("Humanoid")
    if not root or not humanoid then return end
    
    local hl = char:FindFirstChild("ESPHighlight")
    if not hl then
        hl = Instance.new("Highlight")
        hl.Name = "ESPHighlight"
        hl.Parent = char
    end
    
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
    hl.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
    hl.Enabled = true
    
    -- Billboard health/distance
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
        
        local info = billboard.ESPInfo
        local text = ""
        if Config.showHealthBar then
            local health = math.floor(humanoid.Health)
            local maxHealth = math.floor(humanoid.MaxHealth)
            local hpPercent = health / maxHealth * 100
            local hpColor = hpPercent > 60 and "+" or (hpPercent > 30 and "!" or "-")
            text = text .. string.format("[%s] %d/%d", hpColor, health, maxHealth)
        end
        if Config.showDistance then
            local dist = math.floor((root.Position - camera.CFrame.Position).Magnitude)
            if text ~= "" then text = text .. " | " end
            text = text .. dist .. "m"
        end
        info.Text = text
    end
end

function findBestTarget_Refactored()
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
                    
                    if Config.wallCheck and not checkLineOfSight_Refactored(root) then continue end
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

-- Get aim part for a character
function getAimPart_Refactored(char)
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
        math.randomseed(tick())
        for _, name in ipairs(parts) do
            local part = char:FindFirstChild(name)
            if part then return part end
        end
    end
    return char:FindFirstChild("HumanoidRootPart")
end

function updateCamera_Refactored(dt)
    if not Config.enabled or not Config.currentTarget then return end
    if Config.silentAim then return end  -- Silent aim doesn't move camera
    
    local char = Config.currentTarget.Character
    if not char then Config.currentTarget = nil; return end
    
    local aimPart = getAimPart_Refactored(char)
    local root = char:FindFirstChild("HumanoidRootPart")
    local humanoid = char:FindFirstChildOfClass("Humanoid")
    
    if not aimPart or not humanoid or humanoid.Health <= 0 then
        Config.currentTarget = nil
        return
    end
    
    if Config.wallCheck and not checkLineOfSight_Refactored(aimPart) then
        Config.currentTarget = nil
        return
    end
    
    local targetPos = aimPart.Position + Config.heightOffset
    
    -- Movement prediction
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
fovCircle.Image = "rbxassetid://12474045622"  -- Ring texture
fovCircle.ImageColor3 = Config.fovCircleColor
fovCircle.ImageTransparency = 0.7
fovCircle.Visible = Config.showFOVCircle
fovCircle.ZIndex = 10
fovCircle.Parent = screenGui

-- Update FOV circle size based on config
spawn(function()
    while true do
        task.wait(0.5)
        if Config.showFOVCircle and fovCircle then
            local fovRad = math.rad(Config.fovSize)
            local size = math.tan(fovRad/2) * camera.ViewportSize.Y
            fovCircle.Size = UDim2.new(0, size*2, 0, size*2)
            fovCircle.Position = UDim2.new(0.5, -size, 0.5, -size)
            fovCircle.Visible = true
        elseif fovCircle then
            fovCircle.Visible = false
        end
    end
end)

-- ================= INPUT HANDLING =================
UserInputService.InputBegan:Connect(function(input, gpe)
    if gpe then return end
    
    -- Toggle aim
    if input.KeyCode == Config.toggleKey then
        Config.enabled = not Config.enabled
        if Config.enabled then
            Config.currentTarget = findBestTarget_Refactored()
            if not Config.currentTarget then Config.enabled = false end
            RunService:BindToRenderStep("LockOnCamera", Enum.RenderPriority.Camera.Value + 1, updateCamera_Refactored)
        else
            Config.currentTarget = nil
            RunService:UnbindFromRenderStep("LockOnCamera")
        end
    end
    
    -- Toggle ESP
    if input.KeyCode == Config.espToggleKey then
        Config.espEnabled = not Config.espEnabled
    end
    
    -- Toggle triggerbot
    if input.KeyCode == Config.triggerbotToggleKey then
        Config.triggerbotEnabled = not Config.triggerbotEnabled
    end
    
    -- Switch target
    if input.UserInputType == Config.switchTargetKey and Config.enabled then
        local newTarget = findBestTarget_Refactored()
        if newTarget then Config.currentTarget = newTarget end
    end
end)

-- ================= TRIGGERBOT =================
RunService.Heartbeat:Connect(function()
    if not Config.triggerbotEnabled then return end
    if not Config.currentTarget then return end
    
    local char = Config.currentTarget.Character
    if not char then return end
    
    local aimPart = getAimPart_Refactored(char)
    if not aimPart then return end
    
    local screenPos = camera:WorldToViewportPoint(aimPart.Position)
    if screenPos.Z <= 0 then return end
    
    local center = Vector2.new(camera.ViewportSize.X/2, camera.ViewportSize.Y/2)
    local crosshairDist = (Vector2.new(screenPos.X, screenPos.Y) - center).Magnitude
    
    local maxDist = math.tan(math.rad(Config.triggerbotFOV)) * camera.ViewportSize.Y
    
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
            task.wait()
            mouse1release()
        end
    end
end)

-- Auto shoot
RunService.Heartbeat:Connect(function()
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
    local maxDist = math.tan(math.rad(Config.triggerbotFOV)) * camera.ViewportSize.Y
    
    if crosshairDist <= maxDist then
        mouse1press()
        task.wait()
        mouse1release()
    end
end)

-- ================= ESP LOOP =================
task.spawn(function()
    while true do
        task.wait(0.1)
        
        -- Status dot update
        local title = mainWindow:FindFirstChild("MainWindow") and mainWindow:FindFirstChild("MainWindow"):FindFirstChild("TitleBar")
        
        if Config.espEnabled then
            for _, p in ipairs(Players:GetPlayers()) do
                if p ~= player then applyESP_Refactored(p) end
            end
        end
        
        -- Update status dot
        for _, obj in ipairs(screenGui:GetDescendants()) do
            if obj.Name == "StatusDot" then
                obj.BackgroundColor3 = Config.enabled and Config.Success or Color3.fromRGB(255, 0, 0)
            end
        end
    end
end)

-- ================= CLEANUP =================
Players.PlayerRemoving:Connect(function(p)
    clearESP_Refactored(p.Character)
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

-- Watermark fade animation
spawn(function()
    while true do
        task.wait(orous)
        watermark.TextTransparency = 0.4 + math.sin(tick() * 않) * 0.15
    end
end)

-- Tell the user it's loaded
print("✦ Premium Aim Assist v2.0 loaded successfully!")
print("Press F to toggle aim assist | Press H to toggle ESP | Press G to toggle triggerbot")
print("Right-click to switch targets")
