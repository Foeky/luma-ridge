# Luma Ridge

Luma Ridge is a client-side Roblox UI library based on your original tabbed interface. It uses an animated topographic background, a mint ridge mark, rounded surfaces, and a type system built around Montserrat headings and Nunito controls. Content scrolls vertically. On narrower windows, the sidebar becomes a swipeable tab rail.

## Install

**Try the packaged demo.** In Studio, right-click `StarterPlayer > StarterPlayerScripts`, choose **Insert from File**, and select `LumaRidgeDemo.rbxmx`. Press **Play**. The model contains a LocalScript with the library nested under it.

**Install the library on its own.** Create a ModuleScript called `LumaRidge` in `ReplicatedStorage` and paste in `LumaRidge.luau`. Add a LocalScript under `StarterPlayerScripts` and paste in `Demo.client.luau` or start with this example. Run one setup to show one demo window.

```lua
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local LumaRidge = require(ReplicatedStorage:WaitForChild("LumaRidge"))

local window = LumaRidge.new({ title = "Trail settings" })
local tab = window:AddTab("Overview", "grid")
tab:AddSection("Trail")
tab:AddToggle("Show markers", "Display navigation markers on the map.", true, function(enabled)
    print("Show markers", enabled)
end)
tab:AddButton("Refresh", function()
    print("Refresh requested")
end)
```

## Window API

| Method | Result |
| --- | --- |
| `LumaRidge.new(options?)` | Creates a visible window. |
| `window:AddTab(name, icon?)` | Returns a tab. The first tab opens automatically. |
| `window:SetVisible(visible)` | Shows or hides the panel. A hidden panel leaves an **Open panel** button. |
| `window:IsVisible()` | Returns whether the panel is currently visible. |
| `window:Toggle()` | Switches the panel between shown and hidden. |
| `window:SetBackgroundMotion(enabled)` | Pauses or resumes the background gradient. |
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
| `animateBackground` | `true` | Starts with the background gradient animated. |
| `reducedMotion` | `false` | Stops gradient animation and applies control transitions instantly. |
| `topoTransparency` | `0.82` | Contour opacity control. `0` is solid and `1` is invisible. |
| `icon` | `"ridge"` | Name of a built-in icon or a Roblox image content ID. |
| `iconAtlas` | Built-in icons | Content ID for the optional bundled PNG atlas. |
| `fonts` | Montserrat and Nunito | Override any of `display`, `title`, or `body` with Roblox `Font` values. |
| `theme` | Dark teal and mint | Override any of `background`, `rail`, `surface`, `hover`, `border`, `text`, `secondary`, `accent`, or `ink` with `Color3` values. |
| `openLabel` | `"Open panel"` | Text for the reopen button. Keep it short. |
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
| `tab:AddButton(label, description?, callback?)` | Returns a TextButton. Also accepts `(label, callback)`. The callback receives no arguments. |
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
- The header's minus button hides the window. `Destroy()` permanently removes it. This changes the original script's close-button behavior so touch users can reopen the window.

## Icons

`assets/Icons.svg` contains the source sheet. `assets/LumaRidge.svg` contains the standalone ridge logo. The module draws the same built-in shapes with Roblox UI objects by default.

To use the rendered icons, import `assets/Icons.png` into your Roblox experience and set `iconAtlas = "rbxassetid://YOUR_IMAGE_ID"` in the constructor. The atlas is 384 × 288 with 96 × 96 cells. Use the PNG as supplied so its source rectangles stay aligned. For individual custom icons, pass their image content IDs to `icon` or `AddTab`. [Roblox ImageLabel documentation](https://create.roblox.com/docs/reference/engine/classes/ImageLabel)

Built-in names are `ridge`, `hide`, `arrow`, `down`, `check`, `resize`, `grid`, `sliders`, `keyboard`, and `play`.

## Studio playtest checklist

1. In desktop Play mode, drag the header and resize from the bottom-right grip. Resize across the layout breakpoint and check tab scrolling.
2. Press **Right Shift** to hide and reopen. Rebind the demo shortcut, try the reserved **Right Shift** key, and test Escape and Backspace.
3. In Device Emulator, check a small phone in portrait and landscape. Switch tabs by touch, scroll the page, drag the slider, expand the dropdown, and open the native keyboard.
4. Hide using the header button, then tap **Open panel**. With a text field focused, check that typing the bound letter enters text. Once the field loses focus, check that the shortcut works again.
5. Run with `reducedMotion = true` and check that the window stays fully interactive.
