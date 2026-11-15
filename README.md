# Luma Ridge

Save [LumaRidge.executor.luau](./LumaRidge.executor.luau) in your executor workspace, then run:

```lua
assert(loadstring(readfile("LumaRidge.executor.luau"), "@LumaRidge"))()
```

## Add controls

After launch, use `getgenv().LumaRidge` to add a tab. Insert the same code after the window is created if you maintain your own copy of the script.

```lua
local ui = getgenv().LumaRidge
local tab = ui:AddTab("Survey", "grid")
tab:AddSection("Waypoints")
local status = tab:AddLabel("No waypoints")
local count, recording = 0, true

local function record()
    if not recording then return end
    count += 1
    status.Text = "Waypoints: " .. count
end

tab:AddButton("Record", "Add one waypoint", record, "plus")
local enabled = tab:AddToggle("Recording", "Allow new waypoints", true, function(value)
    recording = value
end)
tab:AddSlider("Map detail", {
    min = 0, max = 100, step = 5, default = 60,
    callback = function(value) print("Detail:", value) end,
})
tab:AddInput("Route name", {
    placeholder = "North Ridge",
    callback = function(value) print(value) end,
})
tab:AddDropdown("Map style", {
    options = { "Terrain", "Street" }, default = "Terrain",
    callback = function(value) print(value) end,
})
tab:AddKeybind("Record waypoint", { default = Enum.KeyCode.K, callback = record })
tab:AddKeybind("Recording mode", {
    setActive = function(value) enabled.set(value) end,
    toggleActive = function() enabled.set(not enabled.get()) end,
})
```

- `AddTab(name, icon)` creates a tab. `tab:Select()` opens it.
- Icons include `ridge`, `hide`, `arrow`, `down`, `check`, `resize`, `grid`, `sliders`, `keyboard`, `play`, `settings`, `plus`, `close`, `info`, `folder`, `search`, and `exit`. You can also pass a Roblox image content ID.
- Toggles, sliders, inputs, and dropdowns return handles with `get()` and `set(value, silent?)`. Use `silent = true` to update a control without calling its callback.
- A keybind accepts `default`, `callback`, and optional `onChanged`. For a stateful action, supply both `setActive(boolean)` and `toggleActive()`. Click to bind, press **Esc** to cancel or **Backspace** to clear. Right-click or use **Mode** to choose **Hold**, **Toggle**, or **Always**. Supply `onModeChanged` to capture changes.
- `ui:Use({ name = "Plugin name", setup = function(window, log) ... end })` registers a plugin. Return a cleanup function from `setup` to release your resources at unload.
- **Settings → Save config** persists appearance, Debug, and Player keybinds. The built-in **Player** tab requires the [companion scripts](./player/README.md) installed in your experience.

## Add a one-click farm dashboard (WIP)

The button runs your callback at the configured interval. Use callbacks for your own experience or local simulations. This example generates sample counts.

```lua
local env = getgenv()
env.MySurveyVariables = { route = "North Ridge", samplesPerWaypoint = 3 }

env.LumaRidge:AddTab("Survey run", "play"):AddFarm("Start survey", {
    description = "Count samples on the selected route",
    interval = 1,
    variables = env.MySurveyVariables,
    stats = {
        { key = "route", label = "Route" },
        { key = "waypoints", label = "Waypoints" },
        { key = "samples", label = "Samples" },
        { key = "rate", label = "Samples per waypoint", visible = false },
    },
    step = function(session)
        local waypoints = (session.stats.waypoints or 0) + 1
        session.stats.route = session.variables.route
        session.stats.waypoints = waypoints
        session.stats.samples = waypoints * session.variables.samplesPerWaypoint
        session.stats.rate = session.variables.samplesPerWaypoint
    end,
})
```

- `variables` is shallow-copied each time you start. `getgenv().LumaRidgeFarm` exposes the latest session with `running`, `elapsed` in whole seconds, `variables`, and `stats`. Use the matching `stats.key` to publish each value.
- `step(session)` runs immediately, then waits `interval` seconds between calls (0.1–60, default 1). Return `false` to finish. If your callback yields, check `session.running` before continuing work. Stopping prevents further calls once the current callback returns.
- The dashboard covers the viewport in black and attempts to pause 3D rendering. It shows whether pausing succeeded. Use **Customize stats** to show or hide individual values. **Stop and return**, **Right Shift**, or unloading closes the dashboard and restores rendering if Luma Ridge paused it.
