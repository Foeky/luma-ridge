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
- A keybind accepts `default`, `callback`, and optional `onChanged`. For a stateful action, supply both `setActive(boolean)` and `toggleActive()`. Click to bind, press **Esc** to cancel or **Backspace** to clear. Right-click or long-press the binding to pick **Hold**, **Toggle**, or **Always**. Supply `onModeChanged` to capture changes.
- Pass the same stateful keybind options as the fifth argument to `AddToggle` to place its binding beside the switch. The toggle handle exposes the binding as `binding`.
- `ui:Use({ name = "Plugin name", setup = function(window, log) ... end })` registers a plugin. Return a cleanup function from `setup` to release your resources at unload.
- **Settings → Keybinds** shows the on-screen shortcut list. **Save config** remembers its visibility, appearance, Debug, and Player keybinds. The built-in **Player** tab requires the [companion scripts](./player/README.md) installed in your experience.
