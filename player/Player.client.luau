local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

local player = Players.LocalPlayer
local remote = ReplicatedStorage:WaitForChild("LumaRidgePlayer", 15)
assert(remote and remote:IsA("RemoteEvent"), "Install Player.server.luau in ServerScriptService first")
local playerGui = player:WaitForChild("PlayerGui")
local gui = Instance.new("ScreenGui")
gui.Name = "LumaRidgePlayerPanel"
gui.ResetOnSpawn = false
gui.Parent = playerGui
local panel = Instance.new("Frame")
panel.Position = UDim2.new(1, -280, 0, 80)
panel.Size = UDim2.fromOffset(260, 365)
panel.BackgroundColor3 = Color3.fromRGB(12, 12, 12)
panel.Parent = gui
local layout = Instance.new("UIListLayout")
layout.Padding = UDim.new(0, 5)
layout.SortOrder = Enum.SortOrder.LayoutOrder
layout.Parent = panel
local padding = Instance.new("UIPadding")
padding.PaddingLeft = UDim.new(0, 8)
padding.PaddingRight = UDim.new(0, 8)
padding.PaddingTop = UDim.new(0, 8)
padding.Parent = panel

local connections = {}
local api = {}
local allowed = {
    setWalkSpeed = true, setJump = true, toggleFly = true, setFlySpeed = true,
    toggleNoclip = true, toggleInvisible = true, setGravity = true,
}
local function send(action, value)
    if player:GetAttribute("LRPlayerAllowed") ~= true then return false, "Player controls are not enabled for your user ID" end
    remote:FireServer(action, value)
    return true
end
function api.setWalkSpeed(value) return send("setWalkSpeed", value) end
function api.setJump(value) return send("setJump", value) end
function api.toggleFly() return send("toggleFly") end
function api.setFlySpeed(value) return send("setFlySpeed", value) end
function api.toggleNoclip() return send("toggleNoclip") end
function api.toggleInvisible() return send("toggleInvisible") end
function api.setGravity(value) return send("setGravity", value) end

local bridge = Instance.new("BindableFunction")
bridge.Name = "LumaRidgePlayerActions"
bridge.OnInvoke = function(action, value)
    if allowed[action] then return api[action](value) end
    return false, "Unknown action"
end
bridge.Parent = playerGui

local function widget(class, label, order)
    local item = Instance.new(class)
    item.Size = UDim2.new(1, 0, 0, 36)
    item.BackgroundColor3 = Color3.fromRGB(27, 27, 27)
    item.TextColor3 = Color3.new(1, 1, 1)
    item.Font = Enum.Font.SourceSans
    item.TextSize = 17
    item.Text = label
    item.LayoutOrder = order
    item.Parent = panel
    return item
end
local title = widget("TextLabel", "Player controls", 1)
local function numberInput(label, initial, callback, order)
    local input = widget("TextBox", label .. " = " .. initial, order)
    input.ClearTextOnFocus = true
    input.PlaceholderText = label
    table.insert(connections, input.FocusLost:Connect(function()
        local value = tonumber(input.Text)
        if value then
            local ok, message = callback(value)
            if not ok then title.Text = message end
        end
        input.Text = label .. " = " .. tostring(value or initial)
    end))
end
numberInput("Walk speed", 16, api.setWalkSpeed, 2)
numberInput("Jump power / height", 50, api.setJump, 3)
numberInput("Fly speed", 40, api.setFlySpeed, 4)
for index, entry in ipairs({
    {"Fly", "LRFly", api.toggleFly},
    {"Noclip", "LRNoclip", api.toggleNoclip},
    {"Invisible", "LRInvisible", api.toggleInvisible},
}) do
    local button = widget("TextButton", entry[1] .. " — off", index + 4)
    table.insert(connections, button.Activated:Connect(function()
        local ok, message = entry[3]()
        if not ok then title.Text = message end
    end))
    table.insert(connections, player:GetAttributeChangedSignal(entry[2]):Connect(function()
        button.Text = entry[1] .. (player:GetAttribute(entry[2]) and " — on" or " — off")
    end))
end
widget("TextLabel", "Fly with WASD, Space and Ctrl", 8)

local focused = true
table.insert(connections, UserInputService.WindowFocusReleased:Connect(function() focused = false end))
table.insert(connections, UserInputService.WindowFocused:Connect(function() focused = true end))
local elapsed = 0
table.insert(connections, RunService.Heartbeat:Connect(function(delta)
    elapsed += delta
    if elapsed < 1 / 15 or player:GetAttribute("LRFly") ~= true then return end
    elapsed = 0
    local camera = workspace.CurrentCamera
    if not camera then return end
    local direction = Vector3.zero
    if focused and not UserInputService:GetFocusedTextBox() then
        local function held(key) return UserInputService:IsKeyDown(key) and 1 or 0 end
        local forward = held(Enum.KeyCode.W) - held(Enum.KeyCode.S)
        local sideways = held(Enum.KeyCode.D) - held(Enum.KeyCode.A)
        local vertical = held(Enum.KeyCode.Space) - math.max(held(Enum.KeyCode.LeftControl), held(Enum.KeyCode.RightControl))
        local look = camera.CFrame.LookVector
        local flat = Vector3.new(look.X, 0, look.Z)
        if flat.Magnitude > 0.01 then flat = flat.Unit else flat = Vector3.new(0, 0, -1) end
        direction = flat * forward + camera.CFrame.RightVector * sideways + Vector3.yAxis * vertical
        if direction.Magnitude > 1 then direction = direction.Unit end
    end
    remote:FireServer("flyInput", direction, camera.CFrame.LookVector)
end))

script.Destroying:Connect(function()
    remote:FireServer("stopFly")
    for _, connection in ipairs(connections) do connection:Disconnect() end
    bridge:Destroy()
    gui:Destroy()
end)
