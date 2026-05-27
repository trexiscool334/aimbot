-- Toggle-based smooth lock-on with ESP (Show players through walls)
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

local player = Players.LocalPlayer
local camera = workspace.CurrentCamera

local settings = {
    toggleKey = Enum.KeyCode.F,                -- Press to toggle lock-on
    smoothSpeed = 0.12,                        -- Interpolation speed
    lockRange = 500,
    heightOffset = Vector3.new(0, 1.6, 0),
    
    teamCheck = false,                         -- If true, won't lock on or highlight teammates
    wallCheck = false,                         -- Set to FALSE to allow lock-on through walls
    
    -- ESP Settings (Visuals through walls)
    espEnabled = true,
    espFillColor = Color3.fromRGB(140, 60, 255),    -- Sleek purple/indigo for normal players
    espOutlineColor = Color3.fromRGB(255, 255, 255), -- Clean white outline
    espTargetColor = Color3.fromRGB(0, 255, 180),    -- Vibrant cyan for the locked-on target
    espFillOpacity = 0.35,
    espOutlineOpacity = 0.8,

    enabled = false,
    currentTarget = nil
}

-- Checks if the target is behind cover (Raycasting)
local function checkLineOfSight(targetPart)
    local origin = camera.CFrame.Position
    local direction = targetPart.Position - origin
    
    local params = RaycastParams.new()
    params.FilterDescendantsInstances = {player.Character, targetPart.Parent}
    params.FilterType = Enum.RaycastFilterType.Exclude
    
    local result = workspace:Raycast(origin, direction, params)
    return result == nil -- Returns true if path is clear (no obstruction)
end

-- ESP Highlight Management
local function clearESP(char)
    if char then
        local hl = char:FindFirstChild("ESPHighlight")
        if hl then
            hl:Destroy()
        end
    end
end

local function applyESP(p)
    if not settings.espEnabled then return end
    
    local char = p.Character
    if not char then return end
    
    -- Check team status
    if settings.teamCheck and p.Team == player.Team then
        clearESP(char)
        return
    end
    
    local hl = char:FindFirstChild("ESPHighlight")
    if not hl then
        hl = Instance.new("Highlight")
        hl.Name = "ESPHighlight"
        hl.Parent = char
    end
    
    -- Stylize Highlight based on Lock-on Status
    if p == settings.currentTarget then
        hl.FillColor = settings.espTargetColor
        hl.OutlineColor = settings.espTargetColor
        hl.FillOpacity = settings.espFillOpacity + 0.15
        hl.OutlineOpacity = 1.0
    else
        hl.FillColor = settings.espFillColor
        hl.OutlineColor = settings.espOutlineColor
        hl.FillOpacity = settings.espFillOpacity
        hl.OutlineOpacity = settings.espOutlineOpacity
    end
    
    hl.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop -- Renders through walls!
    hl.Enabled = true
end

-- Smart target selection with prioritization
local function findBestTarget()
    local best, bestScore = nil, -math.huge
    
    for _, p in ipairs(Players:GetPlayers()) do
        if p ~= player and p.Character then
            local root = p.Character:FindFirstChild("HumanoidRootPart")
            local humanoid = p.Character:FindFirstChildOfClass("Humanoid")
            
            -- Validate target health and team
            if root and humanoid and humanoid.Health > 0 then
                if settings.teamCheck and p.Team == player.Team then
                    continue
                end
                
                local distance = (root.Position - camera.CFrame.Position).Magnitude
                if distance <= settings.lockRange then
                    local screenPos, onScreen = camera:WorldToViewportPoint(root.Position)
                    
                    -- If wall check is enabled, ignore targets behind walls
                    if settings.wallCheck and not checkLineOfSight(root) then
                        continue
                    end
                    
                    if onScreen and screenPos.Z > 0 then
                        local centerDist = (Vector2.new(screenPos.X, screenPos.Y) - 
                            Vector2.new(camera.ViewportSize.X/2, camera.ViewportSize.Y/2)).Magnitude
                        
                        -- Prioritize closer targets near the center of the screen
                        local score = -distance - centerDist * 0.5
                        
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

-- Camera updates using RenderPriority to override default camera script smoothly
local function updateCamera(dt)
    if not settings.enabled or not settings.currentTarget then
        return
    end
    
    local char = settings.currentTarget.Character
    local root = char and char:FindFirstChild("HumanoidRootPart")
    local humanoid = char and char:FindFirstChildOfClass("Humanoid")
    
    -- Graceful target loss handling
    if not root or not humanoid or humanoid.Health <= 0 then
        settings.currentTarget = nil
        return
    end
    
    -- If visibility is checked dynamically and target goes behind cover, lose lock
    if settings.wallCheck and not checkLineOfSight(root) then
        settings.currentTarget = nil
        return
    end
    
    local targetPos = root.Position + settings.heightOffset
    local goalCF = CFrame.lookAt(camera.CFrame.Position, targetPos)
    
    -- Frame-independent Lerp
    local alpha = 1 - math.pow(1 - settings.smoothSpeed, dt * 60)
    camera.CFrame = camera.CFrame:Lerp(goalCF, alpha)
end

-- Handle input toggling
UserInputService.InputBegan:Connect(function(input, gpe)
    if gpe then return end
    
    if input.KeyCode == settings.toggleKey then
        settings.enabled = not settings.enabled
        
        if settings.enabled then
            settings.currentTarget = findBestTarget()
            if not settings.currentTarget then
                settings.enabled = false
            end
        else
            settings.currentTarget = nil
        end
        
        -- Manage BindToRenderStep to preserve resources and run at correct priority
        if settings.enabled then
            RunService:BindToRenderStep("LockOnCamera", Enum.RenderPriority.Camera.Value + 1, updateCamera)
        else
            RunService:UnbindFromRenderStep("LockOnCamera")
        end
    end
    
    -- Auto-switch target on right-click
    if input.UserInputType == Enum.UserInputType.MouseButton2 and settings.enabled then
        local newTarget = findBestTarget()
        if newTarget then
            settings.currentTarget = newTarget
        end
    end
end)

-- Periodically refresh/update highlights (Runs on separate thread to maximize frame performance)
task.spawn(function()
    while true do
        task.wait(0.1) -- Refresh 10 times a second (very light on performance)
        
        if settings.espEnabled then
            for _, p in ipairs(Players:GetPlayers()) do
                if p ~= player then
                    applyESP(p)
                end
            end
        else
            for _, p in ipairs(Players:GetPlayers()) do
                if p.Character then
                    clearESP(p.Character)
                end
            end
        end
    end
end)

-- Cleanup Highlight when players leave
Players.PlayerRemoving:Connect(function(p)
    clearESP(p.Character)
end)
