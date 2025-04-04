local player = game:GetService("Players").LocalPlayer
local UserInputService = game:GetService("UserInputService")
local aimRadius = 75
local target = nil
local isCamLocked = true

-- 配置参数 --
local AIM_MODES = {"头部", "颈部", "躯干"}
local currentAimMode = 1
local UI_POSITION = UDim2.new(0.5, 0, 0, 10)  -- 初始居中位置
local LOCK_COLORS = {
    [true] = Color3.fromRGB(76, 175, 80),
    [false] = Color3.fromRGB(244, 67, 54)
}
local CHECK_FRIENDS = true
local FRIEND_COLORS = {
    [true] = Color3.fromRGB(255, 193, 7),
    [false] = Color3.fromRGB(158, 158, 158)
}

-- 初始化UI系统 --
local screenGui = Instance.new("ScreenGui")
screenGui.Name = "AimLockUI"
screenGui.ResetOnSpawn = false
screenGui.Parent = player:WaitForChild("PlayerGui")

-- UI创建函数（无边界版）--
local function createControlPanel()
    local mainFrame = Instance.new("Frame")
    mainFrame.Size = UDim2.new(0, 340, 0, 120)
    mainFrame.Position = UI_POSITION
    mainFrame.BackgroundColor3 = Color3.new(0.1, 0.1, 0.1)
    mainFrame.BackgroundTransparency = 0.3
    mainFrame.BorderSizePixel = 0
    mainFrame.Parent = screenGui

    -- 按钮配置 --
    local buttonConfig = {
        {name = "lockBtn", text = "锁定: ON", color = LOCK_COLORS[isCamLocked], pos = UDim2.new(0.03, 0, 0.1, 0)},
        {name = "modeBtn", text = "模式："..AIM_MODES[currentAimMode], color = Color3.fromRGB(33, 150, 243), pos = UDim2.new(0.36, 0, 0.1, 0)},
        {name = "friendBtn", text = "好友检测", color = FRIEND_COLORS[CHECK_FRIENDS], pos = UDim2.new(0.69, 0, 0.1, 0)}
    }

    -- 创建按钮 --
    local buttons = {}
    for _, config in ipairs(buttonConfig) do
        local btn = Instance.new("TextButton")
        btn.Size = UDim2.new(0.3, 0, 0.35, 0)
        btn.Position = config.pos
        btn.Text = config.text
        btn.TextColor3 = Color3.new(1, 1, 1)
        btn.Font = Enum.Font.SourceSansBold
        btn.TextSize = 14
        btn.BackgroundColor3 = config.color
        btn.Parent = mainFrame
        buttons[config.name] = btn
    end

    -- 防穿透层 --
    local hitBox = Instance.new("TextButton")
    hitBox.Size = UDim2.new(1, 0, 1, 0)
    hitBox.BackgroundTransparency = 1
    hitBox.Text = ""
    hitBox.ZIndex = 0
    hitBox.Parent = mainFrame

    -- 精准点击检测 --
    local function isOverlapping(pos, button)
        local absPos = button.AbsolutePosition
        local absSize = button.AbsoluteSize
        return pos.X >= absPos.X and pos.X <= absPos.X + absSize.X and
               pos.Y >= absPos.Y and pos.Y <= absPos.Y + absSize.Y
    end

    -- 无边界拖动系统 --
    local dragStartPos, frameStartPos, isDragging

    hitBox.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or 
           input.UserInputType == Enum.UserInputType.Touch then
            
            -- 检测按钮点击 --
            local hitButton = false
            local clickPos = input.Position
            for _, btn in pairs(buttons) do
                if isOverlapping(clickPos, btn) then
                    hitButton = true
                    break
                end
            end

            if not hitButton then
                isDragging = true
                dragStartPos = input.Position
                frameStartPos = mainFrame.Position
                -- 移动端输入捕获 --
                if input.UserInputType == Enum.UserInputType.Touch then
                    input:Capture()
                end
            end
        end
    end)

    hitBox.InputChanged:Connect(function(input)
        if isDragging then
            if input.UserInputType == Enum.UserInputType.MouseMovement or 
               input.UserInputType == Enum.UserInputType.Touch then
                
                -- 直接应用偏移量（无边界限制）--
                local delta = input.Position - dragStartPos
                mainFrame.Position = UDim2.new(
                    0, frameStartPos.X.Offset + delta.X,
                    0, frameStartPos.Y.Offset + delta.Y
                )
            end
        end
    end)

    UserInputService.InputEnded:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or 
           input.UserInputType == Enum.UserInputType.Touch then
            isDragging = false
        end
    end)

    return mainFrame, buttons.lockBtn, buttons.modeBtn, buttons.friendBtn
end

-- 创建UI元素 --
local mainFrame, lockBtn, modeBtn, friendBtn = createControlPanel()

-- 功能按钮实现 --
lockBtn.MouseButton1Click:Connect(function()
    isCamLocked = not isCamLocked
    lockBtn.Text = "锁定: "..(isCamLocked and "ON" or "OFF")
    lockBtn.BackgroundColor3 = LOCK_COLORS[isCamLocked]
    print("锁定状态已切换")
end)

modeBtn.MouseButton1Click:Connect(function()
    currentAimMode = currentAimMode % #AIM_MODES + 1
    modeBtn.Text = "模式："..AIM_MODES[currentAimMode]
    print("当前瞄准模式："..AIM_MODES[currentAimMode])
end)

friendBtn.MouseButton1Click:Connect(function()
    CHECK_FRIENDS = not CHECK_FRIENDS
    friendBtn.BackgroundColor3 = FRIEND_COLORS[CHECK_FRIENDS]
    print("好友检测 "..(CHECK_FRIENDS and "已启用" or "已禁用"))
end)
friendBtn.MouseButton1Click:Connect(toggleFriendCheck)

-- 队伍检测系统 --
local function getPlayerTeam(targetPlayer)
    local success, team = pcall(function() return targetPlayer.Team end)
    return success and team or nil
end

-- 好友检测系统 --
local function isFriend(targetPlayer)
    if not CHECK_FRIENDS then return false end
    
    local success, result = pcall(function()
        if not targetPlayer:GetAttribute("IsFriend") then
            local isFriend = player:IsFriendsWith(targetPlayer.UserId)
            targetPlayer:SetAttribute("IsFriend", isFriend)
            return isFriend
        end
        return targetPlayer:GetAttribute("IsFriend")
    end)
    
    return success and result or false
end

-- 目标验证系统 --
local function isValidTarget(targetModel)
    local targetPlayer = game.Players:GetPlayerFromCharacter(targetModel)
    if not targetPlayer then return true end
    
    -- 好友检查优先于队伍检查 --
    if isFriend(targetPlayer) then
        return false
    end
    
    -- 队伍检查 --
    local localTeam = getPlayerTeam(player)
    local targetTeam = getPlayerTeam(targetPlayer)
    
    return (not localTeam and not targetTeam) or (localTeam ~= targetTeam)
end

-- 瞄准系统 --
local function getAimPosition(model)
    if not model then return nil end
    
    if AIM_MODES[currentAimMode] == "头部" then
        return model:FindFirstChild("Head") and model.Head.Position
    elseif AIM_MODES[currentAimMode] == "颈部" then
        if model:FindFirstChild("UpperTorso") and model:FindFirstChild("Head") then
            return (model.UpperTorso.Position + model.Head.Position) * 0.5
        end
        return model:FindFirstChild("Head") and model.Head.Position
    elseif AIM_MODES[currentAimMode] == "躯干" then
        return model:FindFirstChild("UpperTorso") and model.UpperTorso.Position 
               or model:FindFirstChild("Torso") and model.Torso.Position
    end
end

-- 视线检测 --
local function hasLineOfSight(model)
    local myChar = player.Character
    local myPos = getAimPosition(myChar)
    local targetPos = getAimPosition(model)
    
    if myPos and targetPos then
        local ray = Ray.new(myPos, (targetPos - myPos).Unit * (targetPos - myPos).Magnitude)
        local hit = workspace:FindPartOnRayWithIgnoreList(ray, {myChar, model})
        return not hit
    end
    return false
end

-- 目标筛选 --
local function getClosestTarget()
    if not isCamLocked then return nil end
    
    local closestDistance = aimRadius
    local closestTarget = nil

    for _, v in ipairs(workspace:GetChildren()) do
        if v:IsA("Model") 
            and v:FindFirstChild("Humanoid") 
            and getAimPosition(v)
            and v ~= player.Character 
            and isValidTarget(v) then
            
            local aimPos = getAimPosition(v)
            local screenPos, onScreen = workspace.CurrentCamera:WorldToScreenPoint(aimPos)

            if onScreen and hasLineOfSight(v) then
                local screenCenter = Vector2.new(
                    workspace.CurrentCamera.ViewportSize.X/2,
                    workspace.CurrentCamera.ViewportSize.Y/2
                )
                local distance = (Vector2.new(screenPos.X, screenPos.Y) - screenCenter).Magnitude
                if distance < closestDistance then
                    closestDistance = distance
                    closestTarget = v
                end
            end
        end
    end
    return closestTarget
end

-- 摄像头控制系统 --
local function lockCameraToTarget()
    if target and target.Parent then
        local aimPos = getAimPosition(target)
        if aimPos then
            workspace.CurrentCamera.CFrame = CFrame.new(
                workspace.CurrentCamera.CFrame.Position,
                aimPos
            )
        end
    end
end

-- 主循环 --
game:GetService("RunService").RenderStepped:Connect(function()
    target = getClosestTarget()
    if isCamLocked and target then
        lockCameraToTarget()
    end
end)

-- 通知系统 --
local function showNotification(text)
    local notification = Instance.new("ScreenGui")
    notification.Name = "AimLockNotification"
    notification.ResetOnSpawn = false
    notification.Parent = player.PlayerGui

    local frame = Instance.new("Frame")
    frame.Size = UDim2.new(0, 200, 0, 40)
    frame.Position = UDim2.new(0, 10, 1, -50)
    frame.AnchorPoint = Vector2.new(0, 1)
    frame.BackgroundTransparency = 0.5
    frame.BackgroundColor3 = Color3.new(0, 0, 0)
    frame.Parent = notification

    local label = Instance.new("TextLabel")
    label.Size = UDim2.new(1, 0, 1, 0)
    label.Text = text
    label.TextColor3 = Color3.new(1, 1, 1)
    label.BackgroundTransparency = 1
    label.TextScaled = true
    label.Parent = frame

    task.delay(3, function() notification:Destroy() end)
end

-- 好友列表刷新系统 --
local function refreshFriendList()
    for _, player in ipairs(game:GetService("Players"):GetPlayers()) do
        if player ~= game.Players.LocalPlayer then
            pcall(function() player:SetAttribute("IsFriend", nil) end)
        end
    end
end

-- 自动刷新线程 --
task.spawn(function()
    while task.wait(60) do
        refreshFriendList()
    end
end)

-- 死亡维持系统 --
local function maintainUIState()
    player.CharacterAdded:Connect(function(char)
        char:WaitForChild("Humanoid").Died:Connect(function()
            screenGui.Enabled = true
        end)
        
        task.wait(0.5)
        if not mainFrame.Parent then
            mainFrame.Parent = screenGui
        end
    end)
end

-- FOV可视化 --
local fovCircle = Drawing.new("Circle")
fovCircle.Visible = isCamLocked
fovCircle.Color = Color3.new(1, 0, 0)
fovCircle.Thickness = 2
fovCircle.Radius = aimRadius
fovCircle.Filled = false
fovCircle.Position = Vector2.new(workspace.CurrentCamera.ViewportSize.X/2, workspace.CurrentCamera.ViewportSize.Y/2)

-- FOV同步更新 --
game:GetService("RunService").RenderStepped:Connect(function()
    fovCircle.Visible = isCamLocked
    fovCircle.Radius = aimRadius
end)
-- ★修改 初始化提示 --

showNotification("智能锁定系统已加载")
showNotification("← 锁定 | 模式 | 好友 | NPC →")