# Luma Ridge

Luma Ridge is a client-side Roblox UI library with touch-friendly controls, rebindable keyboard shortcuts, and an animated topographic background.

## Quick start

### Lynx and other executors

**[Download the standalone script](./LumaRidge.executor.luau)** while signed in to GitHub. Use **Download raw file** on the file page.

1. Join an experience where you’re authorized to run scripts. In Lynx, check that the Roblox client is selected under **Clients**.
2. Open `LumaRidge.executor.luau` in Lynx with **Ctrl+O**, then press **Ctrl+Enter** to run the file. [Lynx execution guide](https://getlynx.gg/docs/guides/executing)
3. Use the minus button to hide the panel and the ridge icon at the top center of the screen to reopen it. **Right Shift** also toggles it.

`LumaRidge.executor.luau` bundles the library and playground, creates the UI in the local player's `PlayerGui`, and runs without a network request. Running it again replaces the previous playground window.

If Lynx reports `Unknown require: game/ReplicatedStorage/LumaRidge (Luau 1012)`, open the full standalone file in a fresh tab and run it.

### Run with `loadstring`

In Lynx, open **Settings → Client → Open Workspace** and place the downloaded `LumaRidge.executor.luau` in that folder. Run this in the editor to launch the local copy. [Lynx workspace guide](https://getlynx.gg/docs/guides/workspace)

```lua
local path = "LumaRidge.executor.luau"
assert(loadstring(readfile(path), "@" .. path))()
```

## Try the playground

1. Open **Overview** and select **Run action** or press **F** to update the counter. Rebind the shortcut and try your new key.
2. Open **Settings** and adjust the slider, change the map style, and enter a profile name.
3. Open **Tests** and select **Run smoke test**. It checks slider snapping, dropdown validation, and text input, then restores your values.
4. Drag the header and resize from the bottom-right grip. At a narrow width, try scrolling the tab rail horizontally.
5. Open **Appearance** to adjust text size and background detail. Set motion speed to **Fast**, **Normal**, or **Slow**, or pause the animation. Select **Unload** to remove the panel and its shortcuts. Run the script again to reopen it.

## Features

- Desktop sidebar with drag and resize. Narrow windows use a swipeable tab rail.
- Buttons, toggles, sliders, text inputs, dropdowns, and rebindable shortcuts with touch actions.
- Compact layout with configurable Arimo typography and adjustable background motion.
- Built-in icons drawn by the script.

## Window API

To customize the playground, open [LumaRidge.executor.luau](./LumaRidge.executor.luau) and find `local window = LumaRidge.new({` near the bottom. Edit its options or change the tabs and controls below it, then run the script again.

| Method | Result |
| --- | --- |
| `LumaRidge.new(options?)` | Creates a visible window. |
| `window:AddTab(name, icon?)` | Returns a tab. The first tab opens automatically. |
| `window:SetVisible(visible)` | Shows or hides the panel. The hidden panel leaves a ridge icon at the top center of the screen. |
| `window:IsVisible()` | Returns whether the panel is currently visible. |
| `window:Toggle()` | Switches the panel between shown and hidden. |
| `window:SetBackgroundMotion(enabled)` | Pauses or resumes the background animation. |
| `window:SetBackgroundSpeed(seconds)` | Changes the duration of one background sweep, from 4 to 24 seconds. |
| `window:SetBackgroundDetail(fraction)` | Sets the amount of visible background detail from `0` to `1`. |
| `window:AddAppearanceTab()` | Adds and returns the built-in Appearance tab. Later calls return the same tab. |
| `window:GetGui()` | Returns the root `ScreenGui`. |
| `window:Destroy()` | Removes the UI and disconnects listeners. Safe to call again. |

### Constructor options

| Option | Default | Meaning |
| --- | --- | --- |
| `title` | `"Luma Ridge"` | Header title. |
| `subtitle` | `"Interface library"` | Secondary header text. Set to `""` to hide the copy. |
| `size` | `Vector2.new(780, 540)` | Initial desktop dimensions. |
| `minSize` | `Vector2.new(580, 375)` | Desktop minimum, bounded by the available safe area. |
| `maxSize` | `Vector2.new(1100, 820)` | Desktop maximum, bounded by the available safe area. |
| `toggleKey` | `Enum.KeyCode.RightShift` | Keyboard shortcut for hiding and reopening. Pass `false` to disable it. |
| `animateBackground` | `true` | Starts with the background animated. |
| `backgroundDuration` | `12` | Seconds per sweep, from 4 to 24. |
| `reducedMotion` | `false` | Stops background animation and applies control transitions instantly. |
| `topoTransparency` | `0.90` | Contour opacity control. `0` is solid and `1` is invisible. |
| `icon` | `"ridge"` | Name of a built-in icon or a Roblox image content ID. |
| `fonts` | Arimo | Override any of `display`, `title`, or `body` with Roblox `Font` values. |
| `theme` | Slate and lavender | Override any of `background`, `rail`, `surface`, `hover`, `border`, `text`, `secondary`, `accent`, or `ink` with `Color3` values. |
| `displayOrder` | `100` | Stacking order relative to your other ScreenGuis. |
| `name` | `"LumaRidge"` | Name of the root ScreenGui. |
| `parent` | Local player's `PlayerGui` | Optional custom ScreenGui parent. |

```lua
local window = LumaRidge.new({
    reducedMotion = true,
    theme = { accent = Color3.fromRGB(180, 213, 255) },
    fonts = {
        display = Font.new("rbxasset://fonts/families/SourceSansPro.json", Enum.FontWeight.Bold),
        -- Use Font.fromId(fontFamilyId) for an available Roblox font family.
    },
})
```

## Tabs and controls

| Method | Arguments and return value |
| --- | --- |
| `tab:Select()` | Opens the tab. |
| `tab:AddSection(text)` | Returns the section's TextLabel. |
| `tab:AddLabel(text)` | Returns a wrapping TextLabel. Set its `Text` property to update it. |
| `tab:AddButton(label, description?, callback?, icon?)` | Returns a TextButton. Also accepts `(label, callback)`. The optional icon replaces the default arrow. |
| `tab:AddToggle(label, description, default?, callback?)` | Returns a boolean value handle. Pass `nil` for no description. The callback receives the boolean. |
| `tab:AddSlider(label, config?)` | Returns a number value handle. Config accepts `description`, `min` (0), `max` (100), `step` (1), `default` (min), and `callback(value)`. Values snap to steps starting at min, and max is always reachable. |
| `tab:AddInput(label, config?)` | Returns a string value handle with its TextBox in `handle.input`. Config accepts `description`, `placeholder`, `default`, and `callback(text, enterPressed)`. The callback runs when changed text loses focus or Enter submits it. |
| `tab:AddDropdown(label, config?)` | Returns a string value handle. Config accepts `description`, `options` (an array of unique nonempty strings), `placeholder`, `default`, and `callback(choice)`. Pass `nil` to clear the selection. |
| `tab:AddKeybind(label, config?)` | Returns a shortcut handle. Config accepts `description`, `default`, `callback(key)`, and `onChanged(key)`. The control includes a **Run** button for touch and mouse. |

Use dot calls for handles. Defaults initialize each control silently. Callbacks run in separate tasks, so an event handler can yield.

```lua
local slider = tab:AddSlider("Brightness", { min = 0, max = 1, step = 0.05, default = 0.5 })
print(slider.get())
slider.set(0.75, true) -- The optional second argument suppresses the callback.

local shortcut = tab:AddKeybind("Refresh shortcut", {
    default = Enum.KeyCode.F,
    callback = function(key)
        print("Refresh triggered", key)
    end,
})
local ok, message = shortcut.set(Enum.KeyCode.G)
if not ok then warn(message) end
shortcut.run()
```

- All handles support `get()` and `set(value, silent?)`. Inputs report the text currently in the box. Slider callbacks fire when the snapped value changes.
- Dropdown `set` returns a boolean indicating whether it accepted the supplied value. Keybind `set` returns `true` or `false, message`. Use `nil` to clear either.
- Shortcut capture starts when you select the key readout. **Escape** cancels, **Backspace** clears, and selecting the same readout again cancels. The window's show/hide key and other shortcuts in the same window are reserved. Shortcuts fire while the window is visible and text entry is idle. The **Run** button also works for an unbound shortcut.
- The header's minus button hides the window. The **Unload** control calls `Destroy()`, which removes the UI and disconnects its listeners.

## Icons

Pass a built-in name to `icon` or `AddTab`. The script draws these icons using Roblox UI objects:

`ridge`, `hide`, `arrow`, `down`, `check`, `resize`, `grid`, `sliders`, `keyboard`, `play`, `settings`, `plus`, `close`, `info`, `folder`, `search`, and `exit`.

You can also pass an image content ID such as `rbxassetid://YOUR_IMAGE_ID`. [Roblox ImageLabel documentation](https://create.roblox.com/docs/reference/engine/classes/ImageLabel)
