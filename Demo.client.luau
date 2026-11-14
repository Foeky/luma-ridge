local ReplicatedStorage = game:GetService("ReplicatedStorage")
local LumaRidge = require(script:FindFirstChild("LumaRidge") or ReplicatedStorage:WaitForChild("LumaRidge"))

local window = LumaRidge.new({
    title = "Luma Ridge",
    subtitle = "Component playground",
    toggleKey = Enum.KeyCode.RightShift,
    -- iconAtlas = "rbxassetid://YOUR_IMAGE_ID",
})

local overview = window:AddTab("Overview", "grid")
overview:AddSection("Quick actions")
local status = overview:AddLabel("Run the action to see its result here.")
local runs = 0
local function runAction()
    runs += 1
    status.Text = string.format("Action run %d %s.", runs, runs == 1 and "time" or "times")
end

overview:AddButton("Run action", "Update the status above.", runAction)
overview:AddToggle("Animate background", "Pause or resume the light moving across the contour map.", true, function(value)
    window:SetBackgroundMotion(value)
end)
overview:AddKeybind("Run action shortcut", {
    description = "Press the assigned key or select Run. Escape cancels rebinding and Backspace clears the key.",
    default = Enum.KeyCode.F,
    callback = runAction,
})

local settings = window:AddTab("Settings", "sliders")
settings:AddSection("Preferences")
local selection = settings:AddLabel("Profile: Hiker / Detail: 60% / Map: Terrain")
local profile, detail, map = "Hiker", 60, "Terrain"
local function showSelection()
    selection.Text = string.format("Profile: %s / Detail: %d%% / Map: %s", profile, detail, map)
end

local detailControl = settings:AddSlider("Detail", {
    description = "Drag the track to set the detail level.",
    min = 0, max = 100, step = 5, default = detail,
    callback = function(value)
        detail = value
        showSelection()
    end,
})
local mapControl = settings:AddDropdown("Map style", {
    options = { "Terrain", "Satellite", "Street" },
    default = map,
    callback = function(value)
        map = value or "None"
        showSelection()
    end,
})
local profileControl = settings:AddInput("Profile name", {
    placeholder = "Name your profile",
    default = profile,
    callback = function(value)
        profile = value ~= "" and value or "Unnamed"
        showSelection()
    end,
})

local tests = window:AddTab("Tests", "play")
tests:AddSection("Playground checks")
local result = tests:AddLabel("Drag the header, switch tabs, or resize until the tab rail moves above the controls.")
tests:AddButton("Run smoke test", "Check slider snapping, dropdown validation, and text input.", function()
    local savedDetail, savedMap, savedProfile = detailControl.get(), mapControl.get(), profileControl.get()
    local ok, reason = pcall(function()
        detailControl.set(63, true)
        assert(detailControl.get() == 65, "Slider should snap 63 to 65")
        assert(mapControl.set("Street", true) and mapControl.get() == "Street", "Dropdown should select Street")
        assert(not mapControl.set("Invalid map", true) and mapControl.get() == "Street", "Dropdown should reject an unknown option")
        profileControl.set("Trail tester", true)
        assert(profileControl.get() == "Trail tester", "Text input should accept a new value")
    end)
    detailControl.set(savedDetail, true)
    mapControl.set(savedMap, true)
    profileControl.set(savedProfile, true)
    result.Text = ok and "Passed all playground checks." or ("Failed: " .. tostring(reason))
end)
tests:AddButton("Back to overview", function()
    overview:Select()
end)
