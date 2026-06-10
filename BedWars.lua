local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")
local StarterGui = game:GetService("StarterGui")
local Lighting = game:GetService("Lighting")
local CoreGui = game:GetService("CoreGui")

local LocalPlayer = Players.LocalPlayer
local Camera = Workspace.CurrentCamera

-- // CẤU HÌNH
local AIM_KEY = Enum.KeyCode.Space   
local DOUBLE_TAP_WINDOW = 0.25       -- ĐÃ SỬA: Chỉ nhận diện nếu bấm 2 lần cách nhau dưới 250 mili giây (Siêu tốc)
local MAX_DISTANCE = 100             
local SMOOTHNESS = 0.1               
local ESP_COLOR = Color3.fromRGB(255, 0, 0) 

-- // BIẾN TRẠNG THÁI
local AimbotEnabled = false          
local CurrentTarget = nil            
local lastSpacePress = 0             

-- // HÀM HIỂN THỊ THÔNG BÁO CHẮC CHẮN HIỆN
local function showNotification(title, text)
    local success = pcall(function()
        StarterGui:SetCore("SendNotification", {
            Title = title;
            Text = text;
            Duration = 2;
        })
    end)
    
    if not success or not game:IsLoaded() then
        local screenGui = Instance.new("ScreenGui")
        screenGui.Name = "ThinhDZ_Notify_Fix"
        pcall(function() screenGui.Parent = CoreGui end)
        if not screenGui.Parent then screenGui.Parent = LocalPlayer:WaitForChild("PlayerGui") end
        
        local textLabel = Instance.new("TextLabel")
        textLabel.Size = UDim2.new(0, 300, 0, 50)
        textLabel.Position = UDim2.new(0.5, -150, 0.4, -25)
        textLabel.BackgroundColor3 = Color3.fromRGB(20, 20, 20)
        textLabel.BackgroundTransparency = 0.2
        textLabel.TextColor3 = (text:find("BẬT") or text:find("ON")) and Color3.fromRGB(0, 255, 0) or Color3.fromRGB(255, 0, 0)
        textLabel.TextSize = 20
        textLabel.Font = Enum.Font.SourceSansBold
        textLabel.Text = title .. ": " .. text
        textLabel.Parent = screenGui
        
        local corner = Instance.new("UICorner")
        corner.CornerRadius = UDim.new(0, 8)
        corner.Parent = textLabel
        
        task.delay(2, function()
            screenGui:Destroy()
        end)
    end
end

-- // =========================================================
-- // --- HỆ THỐNG CLEAN FPS BOOST ---
-- // =========================================================
local function ApplyCleanFPSBoost()
    if setfpscap then setfpscap(9999) end

    local oldSky = Lighting:FindFirstChildOfClass("Sky")
    if oldSky then oldSky:Destroy() end
    
    local cleanSky = Instance.new("Sky")
    cleanSky.SkyboxBk = "rbxassetid://160411130"
    cleanSky.SkyboxDn = "rbxassetid://160411124"
    cleanSky.SkyboxFt = "rbxassetid://160411153"
    cleanSky.SkyboxLf = "rbxassetid://160411145"
    cleanSky.SkyboxRt = "rbxassetid://160411121"
    cleanSky.SkyboxUp = "rbxassetid://160411157"
    cleanSky.CelestialBodiesShown = false 
    cleanSky.Parent = Lighting

    Lighting.GlobalShadows = false 
    Lighting.Brightness = 2
    Lighting.FogEnd = 9e9

    for _, effect in pairs(Lighting:GetChildren()) do
        if effect:IsA("BlurEffect") or effect:IsA("DepthOfFieldEffect") or effect:IsA("SunRaysEffect") then
            effect.Enabled = false
        end
    end

    local function optimizeVisuals(obj)
        if obj:IsA("Decal") or obj:IsA("Texture") then
            obj:Destroy()
        elseif obj:IsA("BasePart") and not obj.Parent:FindFirstChildOfClass("Humanoid") then
            obj.Material = Enum.Material.SmoothPlastic
            obj.CastShadow = false
        end
    end

    for _, obj in pairs(Workspace:GetDescendants()) do
        optimizeVisuals(obj)
    end

    Workspace.DescendantAdded:Connect(optimizeVisuals)
    print("ThinhDZ Script: [ FPS Boost Đã Bật! ]")
end

task.spawn(ApplyCleanFPSBoost)


-- // =========================================================
-- // --- HỆ THỐNG ESP TẦM NHÌN SIÊU XA (X3 KHOẢNG CÁCH) ---
-- // =========================================================
local function applyESP(player)
    if player == LocalPlayer then return end

    local function setupCharacterESP(character)
        local rootPart = character:WaitForChild("HumanoidRootPart", 10) or character.PrimaryPart
        if not rootPart then return end
        
        if character:FindFirstChild("EnemyESP") then
            character.EnemyESP:Destroy()
        end

        if player.Team ~= LocalPlayer.Team then
            local highlight = Instance.new("Highlight")
            highlight.Name = "EnemyESP"
            highlight.FillColor = ESP_COLOR
            highlight.FillTransparency = 0.5    
            highlight.OutlineColor = ESP_COLOR
            highlight.OutlineTransparency = 0   
            highlight.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop 
            highlight.Adornee = character
            highlight.Parent = character
        end
    end

    if player.Character then
        task.spawn(setupCharacterESP, player.Character)
    end
    player.CharacterAdded:Connect(function(character)
        task.spawn(setupCharacterESP, character)
    end)
end

for _, player in pairs(Players:GetPlayers()) do
    applyESP(player)
end
Players.PlayerAdded:Connect(applyESP)

RunService.Heartbeat:Connect(function()
    for _, player in pairs(Players:GetPlayers()) do
        if player ~= LocalPlayer and player.Team ~= LocalPlayer.Team and player.Character then
            local char = player.Character
            if not char:FindFirstChild("EnemyESP") and char:FindFirstChild("HumanoidRootPart") then
                applyESP(player)
            end
        end
    end
end)

LocalPlayer:GetPropertyChangedSignal("Team"):Connect(function()
    for _, player in pairs(Players:GetPlayers()) do
        if player.Character then
            local oldESP = player.Character:FindFirstChild("EnemyESP")
            if oldESP then oldESP:Destroy() end
            if player.Team ~= LocalPlayer.Team and player ~= LocalPlayer then
                applyESP(player)
            end
        end
    end
end)


-- // =========================================================
-- // --- HỆ THỐNG AIMBOT GỐC ---
-- // =========================================================
local function isValidTarget(player)
    if player and player.Parent and player ~= LocalPlayer then
        if player.Team ~= LocalPlayer.Team then 
            local character = player.Character
            if character and character:FindFirstChild("Humanoid") and character:FindFirstChild("HumanoidRootPart") then
                if character.Humanoid.Health > 0 then
                    local distance = (LocalPlayer.Character.HumanoidRootPart.Position - character.HumanoidRootPart.Position).Magnitude
                    if distance <= MAX_DISTANCE then
                        return true
                    end
                end
            end
        end
    end
    return false
end

local function getClosestTarget()
    local closestPlayer = nil
    local shortestDistance = MAX_DISTANCE

    for _, player in pairs(Players:GetPlayers()) do
        if isValidTarget(player) then
            local distance = (LocalPlayer.Character.HumanoidRootPart.Position - player.Character.HumanoidRootPart.Position).Magnitude
            if distance < shortestDistance then
                shortestDistance = distance
                closestPlayer = player
            end
        end
    end
    return closestPlayer
end

-- Nhận diện double tap siêu tốc
UserInputService.InputBegan:Connect(function(input, gameProcessed)
    if gameProcessed then return end 
    
    if input.KeyCode == AIM_KEY then
        local currentTime = os.clock()
        
        if (currentTime - lastSpacePress) <= DOUBLE_TAP_WINDOW then
            AimbotEnabled = not AimbotEnabled 
            
            if AimbotEnabled then
                print("ThinhDZ Aimbot: [ ON ]")
                showNotification("ThinhDZ Aimbot", "Trạng thái: ĐÃ BẬT (ON)")
            else
                print("ThinhDZ Aimbot: [ OFF ]")
                showNotification("ThinhDZ Aimbot", "Trạng thái: ĐÃ TẮT (OFF)")
                CurrentTarget = nil 
            end
            lastSpacePress = 0 
        else
            lastSpacePress = currentTime
        end
    end
end)

RunService.RenderStepped:Connect(function()
    if not AimbotEnabled or not LocalPlayer.Character or not LocalPlayer.Character:FindFirstChild("HumanoidRootPart") then 
        return 
    end

    if CurrentTarget and not isValidTarget(CurrentTarget) then
        CurrentTarget = nil 
    end

    if not CurrentTarget then
        CurrentTarget = getClosestTarget()
    end

    if CurrentTarget and CurrentTarget.Character and CurrentTarget.Character:FindFirstChild("Head") then
        local targetHead = CurrentTarget.Character.Head.Position
        local targetCFrame = CFrame.new(Camera.CFrame.Position, targetHead)
        Camera.CFrame = Camera.CFrame:Lerp(targetCFrame, SMOOTHNESS)
    end
end)
