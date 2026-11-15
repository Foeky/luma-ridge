# Player controls for your experience

1. Place `Player.server.luau` in **ServerScriptService** as a Script.
2. Place `Player.client.luau` in **StarterPlayer → StarterPlayerScripts** as a LocalScript.
3. The server creates **ReplicatedStorage → LumaRidgePlayer**, a RemoteEvent. You can also create it beforehand with that exact name.
4. Set `ALLOWED_USER_IDS` in the server script for your developers, for example `{ [12345678] = true }`. The user-owned experience creator and Studio testers are allowed by default. Set `ALLOW_ALL_PLAYERS = true` when these abilities belong to your gameplay.

The LocalScript provides a small control panel and camera-relative keyboard flight. The framework's built-in **Player** tab uses the same LocalScript callbacks when it finds them. It temporarily hides the small panel while attached and restores it when unloaded.

Install the current versions of both scripts for the Player tab's switches and inline keybinds. The tab mirrors server state and sends explicit on or off requests for Hold and Always modes.

All character changes run on the server and target the requesting player's current character. Numeric requests are clamped and requests are rate limited. The LocalScript sends normalized flight direction at 15 Hz, and the server owns the flying assembly. Missing input stops flight after one second.

Walk speed starts at 16 and accepts 0–64. Jump accepts 0–100 for JumpPower or 0–25 for JumpHeight, depending on UseJumpPower. Fly speed accepts 1–100. Toggle states reset on death and respawn. Walk speed survives respawn, while jump uses the new character's defaults.

Noclip restores each part's saved collision state. Invisibility restores saved transparency, effect Enabled flags, and the Humanoid name display setting. Descendants added while enabled are handled too. Character and Humanoid instances are preserved. In the framework, an ability configured as Always is requested again once the new character is ready.

Gravity is disabled by default. To enable it, set `ENABLE_GLOBAL_GRAVITY = true` and list admins in `GRAVITY_ADMIN_IDS`. It accepts 0–300 and changes Workspace.Gravity for the entire experience.

## Callbacks

The LocalScript defines `setWalkSpeed(value)`, `setJump(value)`, `toggleFly()`, `setFlySpeed(value)`, `toggleNoclip()`, `toggleInvisible()`, and `setGravity(value)` on its local api table. Other client UI scripts can call the same functions through the local BindableFunction.

```lua
local playerGui = game:GetService("Players").LocalPlayer:WaitForChild("PlayerGui")
local actions = playerGui:WaitForChild("LumaRidgePlayerActions")
actions:Invoke("setWalkSpeed", 24)
actions:Invoke("toggleFly")
```

## Check in your experience

Test with two players. Confirm one player's requests cannot change the other character. Try both jump modes, repeated toggles, death during flight, respawning, and adding/removing accessories while invisible or noclipping. Verify original collision and visibility values return after toggling off. Confirm an unauthorized user and nonfinite numeric requests produce no changes.
