local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local ALLOWED_USER_IDS = {} -- Add developer user IDs for group-owned experiences.
local ALLOW_ALL_PLAYERS = false
local ENABLE_GLOBAL_GRAVITY = false
local GRAVITY_ADMIN_IDS = {}

local remote = ReplicatedStorage:FindFirstChild("LumaRidgePlayer")
if not remote then
    remote = Instance.new("RemoteEvent")
    remote.Name = "LumaRidgePlayer"
    remote.Parent = ReplicatedStorage
end
assert(remote:IsA("RemoteEvent"), "LumaRidgePlayer must be a RemoteEvent")

local states = {}
local function permitted(player)
    return ALLOW_ALL_PLAYERS or RunService:IsStudio() or ALLOWED_USER_IDS[player.UserId] == true
        or (game.CreatorType == Enum.CreatorType.User and player.UserId == game.CreatorId)
end

local function finite(value)
    return type(value) == "number" and value == value and math.abs(value) < math.huge
end

local function restore(saved)
    for object, properties in pairs(saved) do
        if object.Parent then
            for property, value in pairs(properties) do object[property] = value end
        end
    end
    table.clear(saved)
end

local function saveAndSet(saved, object, property, value)
    saved[object] = saved[object] or {}
    if saved[object][property] == nil then saved[object][property] = object[property] end
    object[property] = value
end

local function applyPart(state, object)
    if state.noclip and object:IsA("BasePart") then
        saveAndSet(state.collision, object, "CanCollide", false)
    end
    if not state.invisible then return end
    if object:IsA("BasePart") or object:IsA("Decal") or object:IsA("Texture") then
        saveAndSet(state.visibility, object, "Transparency", 1)
    elseif object:IsA("ParticleEmitter") or object:IsA("Trail") or object:IsA("Beam")
        or object:IsA("Light") or object:IsA("BillboardGui") or object:IsA("SurfaceGui")
        or object:IsA("Highlight") or object:IsA("Smoke") or object:IsA("Fire") or object:IsA("Sparkles") then
        saveAndSet(state.visibility, object, "Enabled", false)
    elseif object:IsA("Humanoid") then
        saveAndSet(state.visibility, object, "DisplayDistanceType", Enum.HumanoidDisplayDistanceType.None)
    end
end

local function stopFly(state)
    if not state.flight then return end
    local flight = state.flight
    state.flight = nil
    for _, object in ipairs(flight.objects) do object:Destroy() end
    if flight.root.Parent then
        flight.root.AssemblyLinearVelocity = Vector3.zero
        pcall(function()
            if flight.root:CanSetNetworkOwnership() then
                if flight.autoOwnership then flight.root:SetNetworkOwnershipAuto()
                else flight.root:SetNetworkOwner(flight.owner) end
            end
        end)
    end
    local humanoid = state.humanoid
    if humanoid and humanoid.Parent then
        humanoid.PlatformStand = flight.platformStand
        humanoid.AutoRotate = flight.autoRotate
        if humanoid.Health > 0 and not flight.platformStand then
            humanoid:ChangeState(flight.humanoidState)
        end
    end
    state.player:SetAttribute("LRFly", false)
end

local function cleanupCharacter(state)
    stopFly(state)
    restore(state.collision)
    restore(state.visibility)
    state.noclip, state.invisible = false, false
    state.player:SetAttribute("LRNoclip", false)
    state.player:SetAttribute("LRInvisible", false)
    for _, connection in ipairs(state.characterConnections) do connection:Disconnect() end
    table.clear(state.characterConnections)
    state.character, state.humanoid = nil, nil
end

local function startFly(state)
    if state.flight then return end
    local root = state.character:FindFirstChild("HumanoidRootPart")
    if not root or not root:IsA("BasePart") or root.Anchored or state.humanoid.Sit then return end
    if not root:CanSetNetworkOwnership() then return end
    local flight = {
        root = root, objects = {}, platformStand = state.humanoid.PlatformStand,
        autoRotate = state.humanoid.AutoRotate, owner = root:GetNetworkOwner(),
        humanoidState = state.humanoid:GetState(),
        autoOwnership = root:GetNetworkOwnershipAuto(), lastInput = os.clock(),
    }
    state.flight = flight
    root:SetNetworkOwner(nil)
    local attachment = Instance.new("Attachment")
    table.insert(flight.objects, attachment)
    attachment.Parent = root
    local velocity = Instance.new("LinearVelocity")
    table.insert(flight.objects, velocity)
    velocity.Attachment0 = attachment
    velocity.RelativeTo = Enum.ActuatorRelativeTo.World
    velocity.VelocityConstraintMode = Enum.VelocityConstraintMode.Vector
    velocity.ForceLimitsEnabled = false
    velocity.VectorVelocity = Vector3.zero
    velocity.Parent = root
    flight.velocity = velocity
    local orientation = Instance.new("AlignOrientation")
    table.insert(flight.objects, orientation)
    orientation.Mode = Enum.OrientationAlignmentMode.OneAttachment
    orientation.Attachment0 = attachment
    orientation.CFrame = root.CFrame.Rotation
    orientation.MaxTorque = 100000
    orientation.Responsiveness = 20
    orientation.Parent = root
    flight.orientation = orientation
    state.humanoid.AutoRotate = false
    state.humanoid.PlatformStand = true
    state.player:SetAttribute("LRFly", true)
end

local function bindCharacter(state, character)
    cleanupCharacter(state)
    state.character = character
    task.spawn(function()
        local humanoid = character:WaitForChild("Humanoid", 10)
        if state.character ~= character or not humanoid or not humanoid:IsA("Humanoid") then return end
        state.humanoid = humanoid
        if not permitted(state.player) then return end
        humanoid.WalkSpeed = state.walkSpeed
        state.player:SetAttribute("LRUseJumpPower", humanoid.UseJumpPower)
        table.insert(state.characterConnections, humanoid:GetPropertyChangedSignal("UseJumpPower"):Connect(function()
            state.player:SetAttribute("LRUseJumpPower", humanoid.UseJumpPower)
        end))
        table.insert(state.characterConnections, humanoid.Died:Connect(function() cleanupCharacter(state) end))
        table.insert(state.characterConnections, character.DescendantAdded:Connect(function(object) applyPart(state, object) end))
        table.insert(state.characterConnections, character.DescendantRemoving:Connect(function(object)
            for _, saved in ipairs({ state.collision, state.visibility }) do
                local properties = saved[object]
                if properties then
                    for property, value in pairs(properties) do object[property] = value end
                    saved[object] = nil
                end
            end
        end))
    end)
end

local function addPlayer(player)
    if states[player] then return end
    local state = {
        player = player, walkSpeed = 16, flySpeed = 40, collision = {}, visibility = {},
        characterConnections = {}, connections = {}, tokens = 40, updated = os.clock(),
    }
    states[player] = state
    player:SetAttribute("LRPlayerAllowed", permitted(player))
    player:SetAttribute("LRGravityAllowed", ENABLE_GLOBAL_GRAVITY and GRAVITY_ADMIN_IDS[player.UserId] == true)
    player:SetAttribute("LRFly", false)
    table.insert(state.connections, player.CharacterAdded:Connect(function(character) bindCharacter(state, character) end))
    table.insert(state.connections, player.CharacterRemoving:Connect(function() cleanupCharacter(state) end))
    if player.Character then bindCharacter(state, player.Character) end
end

Players.PlayerAdded:Connect(addPlayer)
Players.PlayerRemoving:Connect(function(player)
    local state = states[player]
    if not state then return end
    cleanupCharacter(state)
    for _, connection in ipairs(state.connections) do connection:Disconnect() end
    states[player] = nil
end)
for _, player in ipairs(Players:GetPlayers()) do addPlayer(player) end

remote.OnServerEvent:Connect(function(player, action, value, facing)
    local state = states[player]
    if not state or not permitted(player) or type(action) ~= "string" then return end
    local now = os.clock()
    state.tokens = math.min(40, state.tokens + (now - state.updated) * 25)
    state.updated = now
    if state.tokens < 1 then return end
    state.tokens -= 1
    local humanoid = state.humanoid
    if not humanoid or not humanoid.Parent or humanoid.Health <= 0 or state.character ~= player.Character then return end
    if action == "setWalkSpeed" and finite(value) then
        state.walkSpeed = math.clamp(value, 0, 64)
        humanoid.WalkSpeed = state.walkSpeed
    elseif action == "setJump" and finite(value) then
        if humanoid.UseJumpPower then humanoid.JumpPower = math.clamp(value, 0, 100)
        else humanoid.JumpHeight = math.clamp(value, 0, 25) end
    elseif action == "setFlySpeed" and finite(value) then
        state.flySpeed = math.clamp(value, 1, 100)
    elseif action == "toggleFly" then
        if state.flight then stopFly(state) else startFly(state) end
    elseif action == "toggleNoclip" then
        state.noclip = not state.noclip
        if state.noclip then
            for _, object in ipairs(state.character:GetDescendants()) do applyPart(state, object) end
        else restore(state.collision) end
        player:SetAttribute("LRNoclip", state.noclip)
    elseif action == "toggleInvisible" then
        state.invisible = not state.invisible
        if state.invisible then
            for _, object in ipairs(state.character:GetDescendants()) do applyPart(state, object) end
        else restore(state.visibility) end
        player:SetAttribute("LRInvisible", state.invisible)
    elseif action == "setGravity" and ENABLE_GLOBAL_GRAVITY and GRAVITY_ADMIN_IDS[player.UserId] and finite(value) then
        workspace.Gravity = math.clamp(value, 0, 300)
    elseif action == "stopFly" then
        stopFly(state)
    elseif action == "flyInput" and state.flight and typeof(value) == "Vector3" and finite(value.X)
        and finite(value.Y) and finite(value.Z) and value.Magnitude <= 1.01
        and typeof(facing) == "Vector3" and finite(facing.X) and finite(facing.Y) and finite(facing.Z)
        and facing.Magnitude > 0.01 and facing.Magnitude <= 1.01 then
        state.flight.lastInput = now
        state.flight.velocity.VectorVelocity = value * state.flySpeed
        local flat = Vector3.new(facing.X, 0, facing.Z)
        if flat.Magnitude > 0.01 then
            state.flight.orientation.CFrame = CFrame.lookAt(Vector3.zero, flat.Unit)
        end
    end
end)

RunService.PreSimulation:Connect(function()
    for _, state in pairs(states) do
        if state.noclip then
            for part in pairs(state.collision) do if part.Parent then part.CanCollide = false end end
        end
        if state.flight and (os.clock() - state.flight.lastInput > 1
            or not state.flight.root:IsDescendantOf(state.character)) then stopFly(state) end
    end
end)
