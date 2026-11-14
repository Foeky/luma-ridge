# Luma Ridge

A Roblox executor UI framework with tabs, controls, appearance settings, plugins, and an interactive playground.

## Run in Lynx

Download `LumaRidge.executor.luau`, open it in Lynx, select your joined Roblox client and press **Ctrl+Enter**.

For a local workspace copy, run this loader. It prints before reading or compiling the framework so loader failures appear in Output.

```lua
print("[Luma Ridge loader] Starting")
local ok, err = pcall(function()
    local source = readfile("LumaRidge.executor.luau")
    local run, reason = loadstring(source, "@LumaRidge")
    assert(run, reason)
    run()
end)
if not ok then warn("[Luma Ridge loader] " .. tostring(err)) end
```

When the repository is public, replace the `readfile` line with this.

```lua
local source = game:HttpGet("https://raw.githubusercontent.com/Foeky/luma-ridge/main/LumaRidge.executor.luau")
```

Startup displays progress and downloads `assets/Icons.png` into the executor workspace as `LumaRidge-icons-v2.png`. Later runs reuse the cache. A failed or inaccessible download uses built-in icons and records the reason. For a private repository, download the PNG manually and save it under that cache filename. SVG sources are included for editing.

## Controls

- **Right Shift** hides or opens the panel. The centered ridge icon also reopens it.
- **Settings** contains the playground inputs. **Tests** runs a control smoke test.
- **Appearance** adjusts text size, background speed and detail. Enable **Debug** for the on-screen diagnostic log and console messages.
- **Unload** removes the panel and its event connections and calls plugin cleanup functions.

## Plugins

Set configuration before running the framework. Plugins receive the window and a log function. Return a cleanup function for any connections or objects your plugin creates. Each plugin name can be loaded once per window. A failed plugin is reported while other plugins continue.

```lua
getgenv().LumaRidgeConfig = {
    debug = true,
    plugins = {
        {
            name = "Example",
            setup = function(window, log)
                local tab = window:AddTab("Example", "plus")
                tab:AddButton("Hello", "Test a plugin callback", function()
                    log("Hello from Example")
                end)
                return function() print("Example unloaded") end
            end,
        },
    },
}
```

After startup, `getgenv().LumaRidge:Use(plugin)` loads another plugin. The configuration can optionally supply `assetUrl` for a reachable PNG atlas. The default framework opens freely.

## Build your UI

Edit the `local window = LumaRidge.new({...})` block near the bottom of the script. Use `window:AddTab(name, icon)` and `window:AddAppearanceTab()`.

Tabs support `AddSection`, `AddLabel`, `AddButton`, `AddToggle`, `AddSlider`, `AddInput`, `AddDropdown`, and `AddKeybind`. Examples in the playground show their arguments. Control handles use `get()` and `set(value, silent?)`.

Icons include `ridge`, `hide`, `arrow`, `down`, `check`, `resize`, `grid`, `sliders`, `keyboard`, `play`, `settings`, `plus`, `close`, `info`, `folder`, `search`, and `exit`.
