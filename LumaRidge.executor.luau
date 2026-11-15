print("[Luma Ridge] Script entered")
local environment = type(getgenv) == "function" and getgenv() or _G
local config = type(environment.LumaRidgeConfig) == "table" and environment.LumaRidgeConfig or {}
local debugEnabled = config.debug == true
local messages = {}
local debugLabel
local startupGui
local startupLabel
local activeWindow
local iconAtlas
local function report(message, isError)
    message = tostring(message)
    table.insert(messages, message)
    if #messages > 30 then table.remove(messages, 1) end
    if startupLabel then startupLabel.Text = message end
    if debugLabel then debugLabel.Text = table.concat(messages, "\n") end
    if isError then warn("[Luma Ridge] " .. message)
    elseif debugEnabled or startupLabel then print("[Luma Ridge] " .. message) end
end

local function start()
local http = game:GetService("HttpService")
local configPath = "LumaRidge-settings.json"
local preferences: { [string]: any } = {}
if type(isfile) == "function" and type(readfile) == "function" then
    local ok, data = pcall(function()
        if isfile(configPath) then return http:JSONDecode(readfile(configPath)) end
    end)
    if ok and type(data) == "table" then preferences = data end
    if not ok then report("Could not read saved settings: " .. tostring(data), true) end
end
if config.debug == nil and type(preferences.debug) == "boolean" then
    debugEnabled = preferences.debug
end
local function savePreferences()
    local ok, reason = pcall(function()
        assert(type(writefile) == "function", "Executor file writes are unavailable")
        writefile(configPath, http:JSONEncode(preferences))
    end)
    report(ok and ("Saved " .. configPath) or tostring(reason), not ok)
    return ok
end

local players = game:GetService("Players")
local deadline = os.clock() + 20
while not players.LocalPlayer and os.clock() < deadline do
    task.wait(0.1)
end
assert(players.LocalPlayer, "No local player after 20 seconds. Select a joined Roblox client in Lynx.")
local playerGui = players.LocalPlayer:WaitForChild("PlayerGui", 20)
assert(playerGui, "PlayerGui was not available after 20 seconds")
local previousStartup = playerGui:FindFirstChild("LumaRidgeStartup")
if previousStartup then previousStartup:Destroy() end
startupGui = Instance.new("ScreenGui")
startupGui.Name = "LumaRidgeStartup"
startupGui.ResetOnSpawn = false
startupGui.DisplayOrder = 1000
startupGui.Parent = playerGui
startupLabel = Instance.new("TextLabel")
startupLabel.AnchorPoint = Vector2.new(0.5, 0)
startupLabel.Position = UDim2.new(0.5, 0, 0, 12)
startupLabel.Size = UDim2.new(0.85, 0, 0, 80)
startupLabel.BackgroundColor3 = Color3.fromRGB(8, 8, 8)
startupLabel.TextColor3 = Color3.fromRGB(240, 240, 240)
startupLabel.Font = Enum.Font.SourceSans
startupLabel.TextSize = 17
startupLabel.TextWrapped = true
startupLabel.Parent = startupGui
report("1/3 Preparing icons…")
task.wait()
local assetOk, assetError = pcall(function()
    assert(type(isfile) == "function" and type(readfile) == "function"
        and type(writefile) == "function" and type(getcustomasset) == "function", "Asset file APIs unavailable")
    local path = "LumaRidge-icons-v3.png"
    local valid = isfile(path) and readfile(path):sub(1, 8) == "\137PNG\r\n\26\n"
    if not valid then
        report("1/3 Downloading icon atlas…")
        local done, downloaded, failure = false, nil, nil
        task.spawn(function()
            local ok, body = pcall(function()
                return game:HttpGet(config.assetUrl or "https://raw.githubusercontent.com/Foeky/luma-ridge/main/assets/Icons.png")
            end)
            if ok then downloaded = body else failure = body end
            done = true
        end)
        local timeout = os.clock() + 12
        while not done and os.clock() < timeout do task.wait(0.1) end
        assert(done, "Icon download timed out")
        assert(type(downloaded) == "string" and downloaded:sub(1, 8) == "\137PNG\r\n\26\n",
            tostring(failure or "Icon URL did not return a PNG. Check repository access."))
        writefile(path, downloaded)
        assert(isfile(path) and readfile(path) == downloaded, "Icon cache write failed")
    end
    iconAtlas = getcustomasset(path)
    assert(type(iconAtlas) == "string" and iconAtlas ~= "", "Could not register icon atlas")
end)
if not assetOk then report("Built-in icons enabled. " .. tostring(assetError), true) end
report("2/3 Building interface…")
task.wait()

local function loadLibrary()
    local Players = game:GetService("Players")
    local UserInputService = game:GetService("UserInputService")
    local TweenService = game:GetService("TweenService")

    local Library = {}

    local COLORS = {
        background = Color3.fromRGB(6, 6, 6),
        rail = Color3.fromRGB(10, 10, 10),
        surface = Color3.fromRGB(19, 19, 19),
        hover = Color3.fromRGB(32, 32, 32),
        border = Color3.fromRGB(65, 65, 65),
        text = Color3.fromRGB(240, 240, 240),
        secondary = Color3.fromRGB(175, 175, 175),
        accent = Color3.fromRGB(220, 220, 220),
        ink = Color3.fromRGB(8, 8, 8),
    }

    local DEFAULT_FONTS = {
        display = Font.new("rbxassetid://11598121416", Enum.FontWeight.Bold),
        title = Font.new("rbxassetid://11598121416", Enum.FontWeight.SemiBold),
        body = Font.new("rbxassetid://11598121416"),
    }

    local ICONS = {
        { "ridge", { { 12, 2.5, 21, 7.5, 21, 16.5, 12, 21.5, 3, 16.5, 3, 7.5, 12, 2.5 },
            { 6.5, 14.5, 10.5, 8.5, 13, 12, 15, 9.5, 17.5, 13.5 }, { 10, 16.5, 14, 16.5 } } },
        { "hide", { { 6, 12, 18, 12 } } },
        { "arrow", { { 9, 6, 15, 12, 9, 18 } } },
        { "down", { { 6, 9, 12, 15, 18, 9 } } },
        { "check", { { 5, 12, 10, 17, 19, 8 } } },
        { "resize", { { 7, 19, 19, 7 }, { 13, 19, 19, 13 } } },
        { "grid", { { 5, 5, 10, 5, 10, 10, 5, 10, 5, 5 }, { 14, 5, 19, 5, 19, 10, 14, 10, 14, 5 },
            { 5, 14, 10, 14, 10, 19, 5, 19, 5, 14 }, { 14, 14, 19, 14, 19, 19, 14, 19, 14, 14 } } },
        { "sliders", { { 4, 6, 20, 6 }, { 9, 4, 9, 8 },
            { 4, 12, 20, 12 }, { 16, 10, 16, 14 },
            { 4, 18, 20, 18 }, { 10, 16, 10, 20 } } },
        { "keyboard", { { 5, 6, 19, 6, 21, 8, 21, 16, 19, 18, 5, 18, 3, 16, 3, 8, 5, 6 },
            { 7, 10, 8, 10 }, { 11.5, 10, 12.5, 10 }, { 16, 10, 17, 10 }, { 8, 14, 16, 14 } } },
        { "play", { { 8, 5, 19, 12, 8, 19, 8, 5 } } },
        { "settings", { { 10, 3, 14, 3, 15, 6, 18, 6, 20, 9, 18, 12, 20, 15, 18, 18,
            15, 18, 14, 21, 10, 21, 9, 18, 6, 18, 4, 15, 6, 12, 4, 9, 6, 6, 9, 6, 10, 3 },
            { 12, 9, 15, 12, 12, 15, 9, 12, 12, 9 } } },
        { "plus", { { 5, 12, 19, 12 }, { 12, 5, 12, 19 } } },
        { "close", { { 6, 6, 18, 18 }, { 18, 6, 6, 18 } } },
        { "info", { { 12, 3, 18, 5, 21, 12, 18, 19, 12, 21, 6, 19, 3, 12, 6, 5, 12, 3 },
            { 12, 11, 12, 16 }, { 12, 7.5, 12, 8 } } },
        { "folder", { { 3, 18, 3, 6, 9, 6, 11, 8, 21, 8, 21, 18, 3, 18 } } },
        { "search", { { 10, 4, 14, 5, 16, 8, 16, 12, 13, 15, 9, 16, 5, 14, 4, 10, 5, 6, 10, 4 },
            { 15, 14, 21, 20 } } },
        { "exit", { { 10, 4, 4, 4, 4, 20, 10, 20 }, { 9, 12, 21, 12 }, { 16, 7, 21, 12, 16, 17 } } },
    }

    local function make(class, parent, properties)
        local object = Instance.new(class)
        for name, value in pairs(properties) do
            object[name] = value
        end
        object.Parent = parent
        return object
    end

    local function corner(parent, radius)
        make("UICorner", parent, { CornerRadius = UDim.new(0, radius) })
    end

    local function frame(parent, properties)
        local panel = make("Frame", nil, { BackgroundTransparency = 1, BorderSizePixel = 0 })
        for name, value in pairs(properties) do
            panel[name] = value
        end
        panel.Parent = parent
        return panel
    end

    local function outline(parent, color, transparency)
        return make("UIStroke", parent, {
            ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
            Color = color, Transparency = transparency, Thickness = 1,
        })
    end

    local function list(parent, gap)
        return make("UIListLayout", parent, {
            SortOrder = Enum.SortOrder.LayoutOrder,
            Padding = UDim.new(0, gap),
        })
    end

    local function padding(parent, x, y)
        make("UIPadding", parent, {
            PaddingLeft = UDim.new(0, x), PaddingRight = UDim.new(0, x),
            PaddingTop = UDim.new(0, y), PaddingBottom = UDim.new(0, y),
        })
    end

    local function line(parent, ax, ay, bx, by, thickness, color, transparency)
        local dx, dy = bx - ax, by - ay
        local segment = frame(parent, {
            AnchorPoint = Vector2.new(0.5, 0.5),
            Position = UDim2.fromOffset((ax + bx) / 2, (ay + by) / 2),
            Size = UDim2.fromOffset(math.sqrt(dx * dx + dy * dy) + thickness, thickness),
            Rotation = math.deg(math.atan2(dy, dx)),
            BackgroundColor3 = color,
            BackgroundTransparency = transparency,
        })
        corner(segment, thickness / 2)
    end

    local function addIcon(parent, name, size, color)
        for index, icon in ipairs(ICONS) do
            if icon[1] ~= name then
                continue
            end
            if iconAtlas then
                return make("ImageLabel", parent, {
                    Name = name, BackgroundTransparency = 1, Size = UDim2.fromOffset(size, size),
                    Image = iconAtlas, ImageColor3 = color,
                    ImageRectSize = Vector2.new(96, 96),
                    ImageRectOffset = Vector2.new((index - 1) % 4 * 96, math.floor((index - 1) / 4) * 96),
                })
            end
            local holder = frame(parent, { Name = name, Size = UDim2.fromOffset(size, size) })
            local scale = size / 24
            for _, path in ipairs(icon[2]) do
                for point = 1, #path - 2, 2 do
                    line(holder, path[point] * scale, path[point + 1] * scale,
                        path[point + 2] * scale, path[point + 3] * scale, 2.05 * scale, color, 0)
                end
            end
            return holder
        end
        return make("ImageLabel", parent, {
            Name = "CustomIcon", BackgroundTransparency = 1, Size = UDim2.fromOffset(size, size),
            Image = name, ScaleType = Enum.ScaleType.Fit,
        })
    end

    local function positionRight(object, inset)
        object.AnchorPoint = Vector2.new(1, 0.5)
        object.Position = UDim2.new(1, -inset, 0.5, 0)
    end

    local function scroll(parent, name, axis, color)
        return make("ScrollingFrame", parent, {
            Name = name, BackgroundTransparency = 1, BorderSizePixel = 0, Size = UDim2.fromScale(1, 1),
            CanvasSize = UDim2.new(), AutomaticCanvasSize = axis, ScrollBarThickness = 3,
            ScrollBarImageColor3 = color,
            ScrollingDirection = axis == Enum.AutomaticSize.X and Enum.ScrollingDirection.X or Enum.ScrollingDirection.Y,
        })
    end

    local function merge(defaults, overrides)
        local result = table.clone(defaults)
        for name, value in pairs(overrides or {}) do
            result[name] = value
        end
        return result
    end

    local function pointerType(input)
        return input.UserInputType == Enum.UserInputType.MouseButton1
            or input.UserInputType == Enum.UserInputType.Touch
    end

    local function keyCode(value)
        return typeof(value) == "EnumItem" and value.EnumType == Enum.KeyCode and value.Name ~= "Unknown"
    end

    local function invoke(callback, ...)
        if callback then
            local args = table.pack(...)
            task.spawn(function()
                local ok, reason = xpcall(function() callback(table.unpack(args, 1, args.n)) end, debug.traceback)
                if not ok then report(reason, true) end
            end)
        end
    end

    function Library.new(options)
        options = options or {}
        local color = merge(COLORS, options.theme)
        local font = merge(DEFAULT_FONTS, options.fonts)
        local player = Players.LocalPlayer
        assert(player, "Run Luma Ridge in a Roblox client")
        local parent = options.parent or player:WaitForChild("PlayerGui")
        local targetHeight = UserInputService.TouchEnabled and 52 or 46
        local iconButtonSize = UserInputService.TouchEnabled and 44 or 36
        local headerHeight = targetHeight + 16
        local railWidth = 208
        local desiredSize = options.size or Vector2.new(880, 610)
        local minSize = options.minSize or Vector2.new(580, 375)
        local maxSize = options.maxSize or Vector2.new(1100, 820)
        local toggleKey = options.toggleKey
        if toggleKey == nil then
            toggleKey = Enum.KeyCode.RightShift
        end

        local window = {}
        local connections = {}
        local pluginCleanup = {}
        local pluginNames = {}
        local tabs = {}
        local bindings = {}
        local activeTab, capture, pointer
        local destroyed, visible, compact = false, true, false
        local animated = options.animateBackground ~= false
        local backgroundDuration = math.clamp(options.backgroundDuration or 12, 4, 24)
        local reducedMotion = options.reducedMotion == true
        local transition = TweenInfo.new(0.17, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
        local tweens = setmetatable({}, { __mode = "k" })
        local textSizes = setmetatable({}, { __mode = "k" })
        local textScale = 1.25

        local function sizeText(object, size)
            textSizes[object] = size
            object.TextSize = math.round(size * textScale)
            return object
        end

        local function connect(signal, fn)
            local connection = signal:Connect(function(...)
                if destroyed then return end
                local args = table.pack(...)
                local ok, reason = xpcall(function() fn(table.unpack(args, 1, args.n)) end, debug.traceback)
                if not ok then report(reason, true) end
            end)
            table.insert(connections, connection)
            return connection
        end

        local function animate(target, properties)
            local previous = tweens[target]
            if previous then
                previous:Cancel()
                previous:Destroy()
                tweens[target] = nil
            end
            if reducedMotion then
                for name, value in pairs(properties) do
                    target[name] = value
                end
                return
            end
            local tween = TweenService:Create(target, transition, properties)
            tweens[target] = tween
            tween:Play()
        end

        local function text(parentObject, value, size, face, tint, wrap)
            local label = make("TextLabel", parentObject, {
                BackgroundTransparency = 1, Text = tostring(value), FontFace = face or font.body,
                TextColor3 = tint or color.text,
                TextXAlignment = Enum.TextXAlignment.Left, TextWrapped = wrap == true,
                TextTruncate = wrap and Enum.TextTruncate.None or Enum.TextTruncate.AtEnd,
            })
            return sizeText(label, size)
        end

        local function button(parentObject, name, radius)
            local object = make("TextButton", parentObject, {
                Name = name, Text = "", BackgroundColor3 = color.surface, BorderSizePixel = 0,
                AutoButtonColor = false, Selectable = true,
            })
            corner(object, radius or 5)
            return object
        end

        local function interactive(object, callback, idle)
            local hovered, selected, focused = false, false, false
            local normalColor = idle or color.surface
            local edge = outline(object, color.border, 0.52)
            local function refresh()
                animate(object, { BackgroundColor3 = (hovered or selected or focused) and color.hover or normalColor })
                edge.Color = (selected or focused) and color.accent or color.border
                edge.Transparency = (selected or focused) and 0.15 or 0.52
            end
            object.BackgroundColor3 = normalColor
            connect(object.MouseEnter, function()
                hovered = true
                refresh()
            end)
            connect(object.MouseLeave, function()
                hovered = false
                refresh()
            end)
            connect(object.SelectionGained, function()
                focused = true
                refresh()
            end)
            connect(object.SelectionLost, function()
                focused = false
                refresh()
            end)
            connect(object.Activated, function(...)
                if debugEnabled then report("Activated: " .. object.Name) end
                callback(...)
            end)
            return function(value)
                selected = value
                refresh()
            end
        end

        local gui = make("ScreenGui", nil, {
            Name = options.name or "LumaRidge", ResetOnSpawn = false,
            ScreenInsets = Enum.ScreenInsets.CoreUISafeInsets,
            ZIndexBehavior = Enum.ZIndexBehavior.Sibling, DisplayOrder = options.displayOrder or 100,
        })
        local safeArea = frame(gui, { Name = "SafeArea", Size = UDim2.fromScale(1, 1) })
        local main = frame(safeArea, {
            Name = "Window", BackgroundColor3 = color.background, BackgroundTransparency = 0, Active = true,
        })
        corner(main, 8)
        outline(main, color.border, 0.2)
        local shellGradient = make("UIGradient", nil, {
            Color = ColorSequence.new({
                ColorSequenceKeypoint.new(0, color.background),
                ColorSequenceKeypoint.new(0.5, color.background:Lerp(color.accent, 0.07)),
                ColorSequenceKeypoint.new(1, color.background),
            }),
            Rotation = 25, Offset = Vector2.new(-0.9, 0),
        })
        local backdrop = frame(main, {
            Name = "Background", Size = UDim2.fromScale(1, 1),
            BackgroundColor3 = Color3.new(1, 1, 1), BackgroundTransparency = 0,
        })
        corner(backdrop, 8)
        shellGradient.Parent = backdrop
        local backgroundTween
        local function resetBackgroundTween()
            if backgroundTween then
                backgroundTween:Cancel()
                backgroundTween:Destroy()
            end
            backgroundTween = TweenService:Create(shellGradient,
                TweenInfo.new(backgroundDuration, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true),
                { Offset = Vector2.new(shellGradient.Offset.X < 0 and 0.9 or -0.9, 0) })
        end
        resetBackgroundTween()

        local contours = frame(backdrop, {
            AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5),
            Size = UDim2.fromOffset(550, 460),
        })
        local contourScale = make("UIScale", contours, { Scale = 1 })
        local contourAlpha = math.clamp(options.topoTransparency or 0.90, 0, 1)
        local backgroundStyle = "Contours"
        for level = 0, 6 do
            local rx, ry = 70 + level * 27, 48 + level * 21
            local function point(angle)
                local bend = 1 + 0.14 * math.sin(angle * 3 + 1) + 0.08 * math.cos(angle * 2)
                return 275 + rx * math.cos(angle) * bend, 230 + ry * math.sin(angle) * bend
            end
            local x, y = point(0)
            for step = 1, 32 do
                local nextX, nextY = point(step / 32 * math.pi * 2)
                line(contours, x, y, nextX, nextY, 1, color.accent, contourAlpha)
                x, y = nextX, nextY
            end
        end

        local grid = frame(backdrop, { Name = "Grid", Size = UDim2.fromScale(1, 1), Visible = false })
        local dots = frame(backdrop, { Name = "Dots", Size = UDim2.fromScale(1, 1), Visible = false })
        local patterns = { contours, grid, dots }
        for x = 10, 540, 28 do
            frame(grid, {
                Position = UDim2.fromScale(x / 550, 0.02), Size = UDim2.new(0, 1, 0.96, 0),
                BackgroundColor3 = color.accent, BackgroundTransparency = contourAlpha,
            })
            for y = 6, 454, 28 do
                local dot = frame(dots, {
                    Position = UDim2.fromScale(x / 550, y / 460), Size = UDim2.fromOffset(2, 2),
                    BackgroundColor3 = color.accent, BackgroundTransparency = contourAlpha,
                })
                corner(dot, 1)
            end
        end
        for y = 6, 454, 28 do
            frame(grid, {
                Position = UDim2.fromScale(0.02, y / 460), Size = UDim2.new(0.96, 0, 0, 1),
                BackgroundColor3 = color.accent, BackgroundTransparency = contourAlpha,
            })
        end

        local header = frame(main, {
            Name = "Header", Position = UDim2.fromOffset(1, 1), Size = UDim2.new(1, -2, 0, headerHeight - 1),
            BackgroundColor3 = color.rail, BackgroundTransparency = 0, ZIndex = 2,
        })
        corner(header, 7)
        local logo = frame(header, {
            AnchorPoint = Vector2.new(0, 0.5), Position = UDim2.new(0, 10, 0.5, 0),
            Size = UDim2.fromOffset(40, 40), BackgroundColor3 = color.surface, BackgroundTransparency = 0,
        })
        corner(logo, 9)
        outline(logo, color.border, 0.4)
        local mark = addIcon(logo, options.icon or "ridge", 30, color.text)
        mark.AnchorPoint = Vector2.new(0.5, 0.5)
        mark.Position = UDim2.fromScale(0.5, 0.5)
        local title = text(header, options.title or "Luma Ridge", 18, font.display)
        local hasSubtitle = type(options.subtitle) == "string" and options.subtitle ~= ""
        title.AnchorPoint = Vector2.new(0, 0.5)
        title.Position = UDim2.new(0, 58, 0.5, hasSubtitle and -9 or 0)
        title.Size = UDim2.new(1, -iconButtonSize - 82, 0, 30)
        if hasSubtitle then
            local subtitle = text(header, options.subtitle, 12, font.body, color.secondary)
            subtitle.Position = UDim2.new(0, 58, 0.5, 8)
            subtitle.Size = UDim2.new(1, -iconButtonSize - 82, 0, 20)
        end

        local dragRegion = frame(header, { Name = "DragRegion", Size = UDim2.new(1, -iconButtonSize - 16, 1, 0), Active = true })
        local hide = button(header, "HideWindow")
        hide.Size = UDim2.fromOffset(iconButtonSize, iconButtonSize)
        positionRight(hide, 11)
        local hideIcon = addIcon(hide, "close", 20, color.text)
        hideIcon.AnchorPoint = Vector2.new(0.5, 0.5)
        hideIcon.Position = UDim2.fromScale(0.5, 0.5)

        local rail = frame(main, {
            Name = "TabRail", BackgroundColor3 = color.rail, BackgroundTransparency = 0.18, ZIndex = 2,
        })
        corner(rail, 5)
        local navigation = scroll(rail, "Tabs", Enum.AutomaticSize.Y, color.border)
        navigation.Position = UDim2.fromOffset(6, 5)
        navigation.Size = UDim2.new(1, -12, 1, -10)
        padding(navigation, 3, 3)
        local tabLayout = list(navigation, 4)
        local settingsDock = frame(main, { Name = "SettingsDock", ZIndex = 3, Visible = false })
        local content = frame(main, { Name = "Pages", ZIndex = 2 })
        local resize = button(main, "ResizeWindow", 8)
        resize.AnchorPoint = Vector2.new(1, 1)
        resize.Position = UDim2.new(1, -7, 1, -5)
        resize.Size = UDim2.fromOffset(32, 32)
        resize.Selectable = false
        resize.ZIndex = 3
        addIcon(resize, "resize", 22, color.secondary).Position = UDim2.fromOffset(5, 5)

        local open = button(safeArea, "ShowWindow", 6)
        open.AnchorPoint = Vector2.new(0.5, 0)
        open.Position = UDim2.new(0.5, 0, 0, 6)
        open.Size = UDim2.fromOffset(56, 56)
        open.Visible = false
        local openIcon = addIcon(open, options.icon or "ridge", 35, color.accent)
        openIcon.AnchorPoint = Vector2.new(0.5, 0.5)
        openIcon.Position = UDim2.fromScale(0.5, 0.5)

        local function clearCapture()
            local previous = capture
            capture = nil
            if previous then
                previous.render()
            end
        end

        local function stopPointer()
            local previous = pointer
            pointer = nil
            if previous and previous.finish then
                previous.finish()
            end
        end

        local modes = { "Hold", "Toggle", "Always" }
        local modeTarget
        local modeShield = make("TextButton", main, {
            Name = "DismissKeybindMenu", BackgroundTransparency = 1, Text = "",
            Size = UDim2.fromScale(1, 1), ZIndex = 19, Visible = false, Selectable = false,
        })
        local modeMenu = frame(main, {
            Name = "KeybindMenu", Size = UDim2.fromOffset(86, 78), ZIndex = 20,
            BackgroundColor3 = color.rail, BackgroundTransparency = 0, Visible = false,
        })
        corner(modeMenu, 6)
        outline(modeMenu, color.border, 0.2)
        padding(modeMenu, 4, 4)
        list(modeMenu, 1)
        local menuScale = make("UIScale", modeMenu, { Scale = 1 })
        local modeChoices = {}
        local function closeModeMenu()
            modeTarget = nil
            modeMenu.Visible = false
            modeShield.Visible = false
        end
        connect(modeShield.Activated, closeModeMenu)
        for index, mode in ipairs(modes) do
            local choice = button(modeMenu, mode)
            choice.Size = UDim2.new(1, 0, 0, 22)
            choice.LayoutOrder = index
            local label = text(choice, mode, 10, font.title)
            label.Size = UDim2.fromScale(1, 1)
            label.TextXAlignment = Enum.TextXAlignment.Center
            modeChoices[mode] = interactive(choice, function()
                local target = modeTarget
                closeModeMenu()
                if target then target.setMode(mode) end
            end, color.rail)
        end
        local function openModeMenu(binding, anchor)
            if modeTarget == binding then
                closeModeMenu()
                return
            end
            clearCapture()
            modeTarget = binding
            for name, highlight in pairs(modeChoices) do highlight(name == binding.mode) end
            local offset = anchor.AbsolutePosition - main.AbsolutePosition
            local edge = offset.Y + anchor.AbsoluteSize.Y + 4
            if edge + 78 > main.AbsoluteSize.Y - 4 then edge = offset.Y - 82 end
            modeMenu.Position = UDim2.fromOffset(
                math.clamp(offset.X + anchor.AbsoluteSize.X - 86, 4, math.max(4, main.AbsoluteSize.X - 90)),
                math.clamp(edge, 4, math.max(4, main.AbsoluteSize.Y - 82))
            )
            modeMenu.Visible = true
            modeShield.Visible = true
            menuScale.Scale = reducedMotion and 1 or 0.94
            animate(menuScale, { Scale = 1 })
        end

        local keybindsHud = frame(safeArea, {
            Name = "Keybinds", Position = UDim2.fromOffset(12, 86),
            Size = UDim2.fromOffset(245, 0), AutomaticSize = Enum.AutomaticSize.Y,
            BackgroundColor3 = Color3.fromRGB(12, 12, 16), BackgroundTransparency = 0,
            Visible = preferences.showKeybinds == true, ZIndex = 10,
        })
        corner(keybindsHud, 8)
        outline(keybindsHud, color.border, 0.35)
        padding(keybindsHud, 10, 7)
        list(keybindsHud, 3)
        local hudAccent = Color3.fromRGB(255, 82, 171)
        local hudHeader = text(keybindsHud, "Keybinds", 12, font.title, hudAccent)
        hudHeader.Size = UDim2.new(1, 0, 0, 23)
        local hudOrder = 0

        local function syncAnimation()
            if animated and visible and not reducedMotion and backgroundStyle ~= "Solid" then
                backgroundTween:Play()
            else
                backgroundTween:Pause()
            end
        end

        function window:SetVisible(value)
            if destroyed then return end
            visible = value == true
            main.Visible = visible
            open.Visible = not visible
            syncAnimation()
            if not visible then
                closeModeMenu()
                clearCapture()
                stopPointer()
                local box = UserInputService:GetFocusedTextBox()
                if box and box:IsDescendantOf(main) then
                    box:ReleaseFocus()
                end
            end
        end

        function window:IsVisible()
            return visible and not destroyed
        end

        function window:Toggle()
            self:SetVisible(not visible)
        end

        function window:SetBackgroundMotion(value)
            if destroyed then return end
            animated = value == true
            syncAnimation()
        end

        function window:SetBackgroundSpeed(seconds)
            if destroyed then return end
            assert(type(seconds) == "number" and seconds == seconds, "Background speed must be a number")
            local duration = math.clamp(seconds, 4, 24)
            if duration == backgroundDuration then return end
            backgroundDuration = duration
            resetBackgroundTween()
            syncAnimation()
        end

        function window:SetBackgroundDetail(fraction)
            if destroyed then return end
            assert(type(fraction) == "number" and fraction == fraction, "Background detail must be a number")
            contourAlpha = 1 - math.clamp(fraction, 0, 1)
            for _, pattern in ipairs(patterns) do
                for _, segment in ipairs(pattern:GetChildren()) do
                    if segment:IsA("Frame") then
                        segment.BackgroundTransparency = contourAlpha
                    end
                end
            end
        end

        function window:SetBackgroundStyle(style)
            assert(style == "Contours" or style == "Grid" or style == "Dots"
                or style == "Gradient" or style == "Solid", "Unknown background style")
            if destroyed then return end
            backgroundStyle = style
            grid.Visible = style == "Grid"
            dots.Visible = style == "Dots"
            contours.Visible = style == "Contours"
            backdrop.Visible = style ~= "Solid"
            syncAnimation()
        end

        function window:GetGui()
            return gui
        end

        local function dispose()
            if destroyed then return end
            destroyed = true
            for _, binding in pairs(bindings) do
                if binding.release then binding.release() end
            end
            for _, cleanup in ipairs(pluginCleanup) do
                local ok, reason = pcall(cleanup)
                if not ok then report(reason, true) end
            end
            table.clear(pluginCleanup)
            stopPointer()
            capture = nil
            backgroundTween:Cancel()
            backgroundTween:Destroy()
            for _, tween in pairs(tweens) do
                tween:Cancel()
                tween:Destroy()
            end
            for _, connection in ipairs(connections) do
                connection:Disconnect()
            end
            table.clear(tweens)
            table.clear(connections)
            table.clear(bindings)
        end

        function window:Destroy()
            if destroyed then return end
            dispose()
            gui:Destroy()
            if environment.LumaRidge == self then environment.LumaRidge = nil end
            debugLabel = nil
            print("[Luma Ridge] Unloaded")
        end

        function window:Use(plugin)
            assert(not destroyed, "Window unloaded")
            assert(type(plugin) == "table" and type(plugin.name) == "string"
                and type(plugin.setup) == "function", "Plugin needs a name and setup function")
            assert(not pluginNames[plugin.name], "Plugin already loaded")
            pluginNames[plugin.name] = true
            local ok, cleanup = xpcall(function() return plugin.setup(self, report) end, debug.traceback)
            if not ok then
                report("Plugin " .. plugin.name .. " failed: " .. tostring(cleanup), true)
                return false
            end
            if type(cleanup) == "function" then table.insert(pluginCleanup, cleanup) end
            report("Plugin loaded: " .. plugin.name)
            return true
        end

        connect(gui.Destroying, dispose)
        interactive(hide, function() window:SetVisible(false) end)
        interactive(open, function() window:SetVisible(true) end)

        local manualPosition
        local actualPosition, actualSize
        local MARGIN = 8
        local function layout()
            closeModeMenu()
            local area = safeArea.AbsoluteSize
            if area.X <= 2 * MARGIN or area.Y <= 2 * MARGIN then return end
            local available = area - Vector2.new(2 * MARGIN, 2 * MARGIN)
            local maxX, maxY = math.min(maxSize.X, available.X), math.min(maxSize.Y, available.Y)
            local width = math.clamp(desiredSize.X, math.min(minSize.X, maxX), maxX)
            local height = math.clamp(desiredSize.Y, math.min(minSize.Y, maxY), maxY)
            actualSize = Vector2.new(width, height)
            local fitScreen = area.X < 680 or area.Y < 410
            if fitScreen then
                actualSize = available
            end
            local wasCompact = compact
            compact = actualSize.X < 620
            local centered = (area - actualSize) / 2
            local point = (not fitScreen and manualPosition) or centered
            actualPosition = Vector2.new(
                math.clamp(point.X, MARGIN, area.X - actualSize.X - MARGIN),
                math.clamp(point.Y, MARGIN, area.Y - actualSize.Y - MARGIN)
            )
            main.Position = UDim2.fromOffset(actualPosition.X, actualPosition.Y)
            main.Size = UDim2.fromOffset(actualSize.X, actualSize.Y)
            contourScale.Scale = math.max(0.01, math.min((actualSize.X - 24) / 550, (actualSize.Y - 24) / 460))
            resize.Visible = not fitScreen
            dragRegion.Active = not fitScreen

            if compact then
                local bodyTop = headerHeight + targetHeight + 16
                rail.Position = UDim2.fromOffset(4, headerHeight + 2)
                rail.Size = UDim2.new(1, -8, 0, targetHeight + 11)
                content.Position = UDim2.fromOffset(0, bodyTop)
                content.Size = UDim2.new(1, 0, 1, -bodyTop - (settingsDock.Visible and targetHeight + 12 or 4))
                navigation.Size = UDim2.new(1, -12, 1, -10)
            else
                rail.Position = UDim2.fromOffset(4, headerHeight + 2)
                rail.Size = UDim2.new(0, railWidth, 1, -headerHeight - 6)
                content.Position = UDim2.fromOffset(railWidth + 7, headerHeight + 2)
                content.Size = UDim2.new(1, -railWidth - 7, 1, -headerHeight - 7)
                navigation.Size = UDim2.new(1, -12, 1, -(settingsDock.Visible and targetHeight + 24 or 10))
            end
            settingsDock.Position = UDim2.new(0, 12, 1, -targetHeight - 10)
            settingsDock.Size = UDim2.fromOffset(compact and 154 or railWidth - 16, targetHeight)
            local axis = compact and Enum.AutomaticSize.X or Enum.AutomaticSize.Y
            navigation.AutomaticCanvasSize = axis
            navigation.ScrollingDirection = compact and Enum.ScrollingDirection.X or Enum.ScrollingDirection.Y
            tabLayout.FillDirection = compact and Enum.FillDirection.Horizontal or Enum.FillDirection.Vertical
            if compact ~= wasCompact then
                navigation.CanvasPosition = Vector2.zero
            end
            for _, tab in ipairs(tabs) do
                tab.layout()
            end
        end

        local function beginPointer(input, move, finish)
            if pointer or not pointerType(input) then return false end
            pointer = { input = input, move = move, finish = finish }
            return true
        end

        local function matchesPointer(input, moving)
            if not pointer then return false end
            if pointer.input.UserInputType == Enum.UserInputType.Touch then
                return input == pointer.input
            end
            local inputType = moving and Enum.UserInputType.MouseMovement or Enum.UserInputType.MouseButton1
            return input.UserInputType == inputType
        end

        local function position(input)
            return Vector2.new(input.Position.X, input.Position.Y)
        end

        connect(safeArea:GetPropertyChangedSignal("AbsoluteSize"), function()
            stopPointer()
            layout()
        end)
        connect(dragRegion.InputBegan, function(input)
            if not resize.Visible or not actualPosition then return end
            local start, origin = actualPosition, position(input)
            beginPointer(input, function(current)
                manualPosition = start + position(current) - origin
                layout()
            end)
        end)
        connect(resize.InputBegan, function(input)
            if not actualSize or not resize.Visible then return end
            local start, origin, anchor = actualSize, position(input), actualPosition
            local limit = safeArea.AbsoluteSize - anchor - Vector2.new(MARGIN, MARGIN)
            beginPointer(input, function(current)
                manualPosition = anchor
                local size = start + position(current) - origin
                desiredSize = Vector2.new(math.clamp(size.X, 1, limit.X), math.clamp(size.Y, 1, limit.Y))
                layout()
            end)
        end)
        connect(UserInputService.InputChanged, function(input)
            if matchesPointer(input, true) then
                pointer.move(input)
            end
        end)
        connect(UserInputService.InputEnded, function(input)
            if matchesPointer(input, false) then
                stopPointer()
            end
            if input.UserInputType == Enum.UserInputType.Keyboard then
                local binding = bindings[input.KeyCode]
                if binding and binding.release then binding.release() end
            end
        end)
        connect(UserInputService.WindowFocusReleased, function()
            stopPointer()
            clearCapture()
            closeModeMenu()
            for _, binding in pairs(bindings) do
                if binding.release then binding.release() end
            end
        end)

        connect(UserInputService.InputBegan, function(input, processed)
            if input.UserInputType ~= Enum.UserInputType.Keyboard or UserInputService:GetFocusedTextBox() then return end
            local key = input.KeyCode
            if modeTarget and key == Enum.KeyCode.Escape then
                closeModeMenu()
                return
            end
            if capture then
                local current = capture
                if key == Enum.KeyCode.Escape then
                    clearCapture()
                elseif key == Enum.KeyCode.Backspace then
                    clearCapture()
                    current.set(nil)
                elseif not processed and keyCode(key) then
                    local ok, message = current.set(key)
                    if ok then
                        clearCapture()
                    else
                        current.label.Text = message
                    end
                end
                return
            end
            if processed then return end
            if key == toggleKey then
                window:Toggle()
            elseif bindings[key] and (visible or bindings[key].global) then
                bindings[key].run()
            end
        end)

        local function selectTab(target)
            if activeTab == target then return end
            stopPointer()
            clearCapture()
            closeModeMenu()
            activeTab = target
            for _, tab in ipairs(tabs) do
                local selected = tab == target
                tab.page.Visible = selected
                tab.select(selected)
                tab.label.TextColor3 = selected and color.accent or color.secondary
                if selected and not reducedMotion then
                    tab.stack.Position = UDim2.fromOffset(12, 14)
                    animate(tab.stack, { Position = UDim2.fromOffset(12, 10) })
                end
            end
        end

        function window:AddTab(name, icon, docked)
            assert(not destroyed, "The Luma Ridge window has been destroyed")
            local order = #tabs + 1
            local tabButton = button(docked and settingsDock or navigation, tostring(name))
            tabButton.LayoutOrder = order
            if icon then
                local tabIcon = addIcon(tabButton, icon, 23, color.accent)
                tabIcon.AnchorPoint = Vector2.new(0, 0.5)
                tabIcon.Position = UDim2.new(0, 8, 0.5, 0)
            end
            local tabLabel = text(tabButton, name, 14, font.body, color.secondary)
            local labelInset = icon and 41 or 10
            tabLabel.Position = UDim2.fromOffset(labelInset, 0)
            tabLabel.Size = UDim2.new(1, -labelInset - 8, 1, 0)

            local page = scroll(content, tostring(name) .. "Page", Enum.AutomaticSize.Y, color.border)
            page.Visible = false
            local stack = frame(page, {
                Name = "Controls", Position = UDim2.fromOffset(12, 10),
                Size = UDim2.new(1, -27, 0, 0), AutomaticSize = Enum.AutomaticSize.Y,
            })
            list(stack, 6)
            frame(stack, { Size = UDim2.fromOffset(1, 22), LayoutOrder = 2147483647 })
            local tab = { page = page, label = tabLabel, stack = stack }
            function tab.layout()
                tabButton.Size = docked and UDim2.fromScale(1, 1)
                    or compact and UDim2.fromOffset(154, targetHeight)
                    or UDim2.new(1, -8, 0, targetHeight)
            end
            tab.select = interactive(tabButton, function() selectTab(tab) end, color.rail)
            tabs[order] = tab
            tab.layout()
            if order == 1 then selectTab(tab) end

            local api = {}
            local itemOrder = 0

            local function place(object)
                assert(not destroyed, "The Luma Ridge window has been destroyed")
                itemOrder += 1
                object.LayoutOrder = itemOrder
                object.Parent = stack
                return object
            end

            local function wrapped(parentObject, value, size, face, tint)
                local label = text(parentObject, value, size, face, tint, true)
                label.Size = UDim2.new(1, 0, 0, 0)
                label.AutomaticSize = Enum.AutomaticSize.Y
                return label
            end

            local function copy(parentObject, titleText, description)
                wrapped(parentObject, titleText, 14, font.title).LayoutOrder = 1
                if description and description ~= "" then
                    wrapped(parentObject, description, 13, font.body, color.secondary).LayoutOrder = 2
                end
            end

            local function action(nameText, description, reserved, leading)
                local row = button(nil, tostring(nameText))
                row.Size = UDim2.new(1, 0, 0, targetHeight)
                row.AutomaticSize = Enum.AutomaticSize.Y
                local labels = frame(row, {
                    Size = UDim2.new(1, -reserved - (leading or 10) - 10, 0, targetHeight),
                    Position = UDim2.fromOffset(leading or 10, 0), AutomaticSize = Enum.AutomaticSize.Y,
                })
                local arrangement = list(labels, 1)
                arrangement.VerticalAlignment = Enum.VerticalAlignment.Center
                padding(labels, 0, 5)
                copy(labels, nameText, description)
                return place(row)
            end

            local function card(nameText, description)
                local panel = frame(nil, {
                    Name = tostring(nameText), Size = UDim2.new(1, 0, 0, 0),
                    BackgroundColor3 = color.surface, BackgroundTransparency = 0,
                    AutomaticSize = Enum.AutomaticSize.Y,
                })
                corner(panel, 6)
                outline(panel, color.border, 0.52)
                padding(panel, 10, 7)
                list(panel, 5)
                copy(panel, nameText, description)
                return place(panel)
            end

            function api:Select()
                if not destroyed then selectTab(tab) end
            end

            function api:AddSection(value)
                local heading = wrapped(nil, value, 16, font.display, color.text)
                return place(heading)
            end

            function api:AddLabel(value)
                return place(wrapped(nil, value, 14, font.body, color.secondary))
            end

            function api:AddButton(label, description, callback, icon)
                if type(description) == "function" then
                    callback, description = description, nil
                end
                local row = action(label, description, 25)
                positionRight(addIcon(row, icon or "arrow", 22, color.accent), 12)
                interactive(row, function() invoke(callback) end)
                return row
            end

            function api:AddToggle(label, description, default, callback, keybind)
                local value = default == true
                if keybind then
                    local row = action(label, description, 0, 39)
                    local pair = frame(stack, {
                        Name = label .. " controls", Size = UDim2.new(1, 0, 0, targetHeight),
                        LayoutOrder = row.LayoutOrder, AutomaticSize = Enum.AutomaticSize.Y,
                    })
                    row.Parent = pair
                    row.Size = UDim2.new(1, -112, 0, targetHeight)
                    local check = frame(row, {
                        Size = UDim2.fromOffset(17, 17), AnchorPoint = Vector2.new(0, 0.5),
                        Position = UDim2.new(0, 12, 0.5, 0), BackgroundTransparency = 0,
                    })
                    corner(check, 4)
                    outline(check, color.border, 0.25)
                    local glyph = addIcon(check, "check", 15, color.ink)
                    glyph.Position = UDim2.fromOffset(1, 1)
                    local function set(nextValue, silent)
                        if destroyed then return end
                        value = nextValue == true
                        glyph.Visible = value
                        animate(check, { BackgroundColor3 = value and hudAccent or color.rail })
                        if not silent then invoke(callback, value) end
                    end
                    set(value, true)
                    interactive(row, function() set(not value) end)
                    return {
                        set = set, get = function() return value end,
                        binding = api:AddKeybind(label, keybind, pair),
                    }
                end
                local row = action(label, description, 53)
                local track = frame(row, { Size = UDim2.fromOffset(36, 20), BackgroundTransparency = 0 })
                positionRight(track, 12)
                corner(track, 10)
                outline(track, color.border, 0.25)
                local thumb = frame(track, { Size = UDim2.fromOffset(14, 14), BackgroundTransparency = 0 })
                corner(thumb, 7)
                local function render(instant)
                    local trackColor = value and color.accent or color.rail
                    local thumbColor = value and color.ink or color.secondary
                    local thumbPosition = UDim2.fromOffset(value and 19 or 3, 3)
                    if instant then
                        track.BackgroundColor3 = trackColor
                        thumb.BackgroundColor3 = thumbColor
                        thumb.Position = thumbPosition
                    else
                        animate(track, { BackgroundColor3 = trackColor })
                        animate(thumb, { Position = thumbPosition, BackgroundColor3 = thumbColor })
                    end
                end
                local function set(nextValue, silent)
                    if destroyed then return end
                    value = nextValue == true
                    render(false)
                    if not silent then invoke(callback, value) end
                end
                render(true)
                interactive(row, function() set(not value) end)
                return { set = set, get = function() return value end }
            end

            function api:AddSlider(label, config)
                config = config or {}
                local minimum, maximum, step = config.min or 0, config.max or 100, config.step or 1
                local span = maximum - minimum
                assert(span > 0 and span < math.huge,
                    "Slider requires finite max > min")
                assert(step > 0 and step < math.huge and span / step < math.huge,
                    "Slider requires a positive finite step")
                local panel = card(label, config.description)
                local control = frame(panel, { Size = UDim2.new(1, 0, 0, targetHeight), LayoutOrder = 3 })
                local input = button(control, "SliderTrack")
                input.Size = UDim2.new(1, -66, 1, 0)
                input.BackgroundColor3 = color.rail
                outline(input, color.border, 0.52)
                local track = frame(input, {
                    Position = UDim2.new(0, 12, 0.5, -3), Size = UDim2.new(1, -24, 0, 6),
                    BackgroundColor3 = color.border, BackgroundTransparency = 0,
                })
                corner(track, 3)
                local fill = frame(track, { BackgroundColor3 = color.accent, BackgroundTransparency = 0 })
                corner(fill, 3)
                local knob = frame(track, {
                    AnchorPoint = Vector2.new(0.5, 0.5), Size = UDim2.fromOffset(14, 14),
                    BackgroundColor3 = color.accent, BackgroundTransparency = 0,
                })
                corner(knob, 7)
                local readout = text(control, "", 14, font.title, color.accent)
                positionRight(readout, 0)
                readout.Size = UDim2.fromOffset(61, 40)
                readout.TextXAlignment = Enum.TextXAlignment.Right

                local value
                local function set(nextValue, silent)
                    if destroyed then return end
                    assert(type(nextValue) == "number" and nextValue == nextValue, "Slider value must be a number")
                    local clamped = math.clamp(nextValue, minimum, maximum)
                    local lastStep = math.floor(span / step)
                    local index = math.min(lastStep, math.floor((clamped - minimum) / step + 0.5))
                    local snapped = minimum + index * step
                    if maximum - clamped <= math.abs(clamped - snapped) then snapped = maximum end
                    nextValue = math.clamp(snapped, minimum, maximum)
                    if value == nextValue then return end
                    value = nextValue
                    local fraction = (value - minimum) / span
                    fill.Size = UDim2.fromScale(fraction, 1)
                    knob.Position = UDim2.fromScale(fraction, 0.5)
                    readout.Text = string.format("%.6g", value)
                    if not silent then invoke(config.callback, value) end
                end
                set(config.default or minimum, true)

                local function move(current)
                    if track.AbsoluteSize.X <= 0 then return end
                    local fraction = (current.Position.X - track.AbsolutePosition.X) / track.AbsoluteSize.X
                    set(minimum + fraction * span)
                end
                connect(input.InputBegan, function(event)
                    if beginPointer(event, move, function() page.ScrollingEnabled = true end) then
                        page.ScrollingEnabled = false
                        move(event)
                    end
                end)
                connect(input.Activated, function(event)
                    if not pointerType(event) then
                        set(value >= maximum and minimum or math.min(maximum, value + step))
                    end
                end)
                connect(input.InputBegan, function(event)
                    if event.UserInputType ~= Enum.UserInputType.Keyboard then return end
                    if event.KeyCode == Enum.KeyCode.Left then
                        local lastStep = minimum + math.max(0, math.ceil(span / step) - 1) * step
                        set(value >= maximum and lastStep or value - step)
                    elseif event.KeyCode == Enum.KeyCode.Right then
                        set(value + step)
                    end
                end)
                return { set = set, get = function() return value end }
            end

            function api:AddInput(label, config)
                config = config or {}
                local panel = card(label, config.description)
                local box = make("TextBox", panel, {
                    Name = "Input", LayoutOrder = 3, Size = UDim2.new(1, 0, 0, targetHeight),
                    BackgroundColor3 = color.rail, BorderSizePixel = 0,
                    Text = tostring(config.default or ""), PlaceholderText = config.placeholder or "",
                    PlaceholderColor3 = color.secondary, TextColor3 = color.text, FontFace = font.body,
                    ClearTextOnFocus = false, TextXAlignment = Enum.TextXAlignment.Left,
                    MultiLine = false, Selectable = true,
                })
                sizeText(box, 14)
                corner(box, 5)
                padding(box, 10, 0)
                local edge = outline(box, color.border, 0.45)
                local value = box.Text
                connect(box.Focused, function()
                    clearCapture()
                    edge.Color = color.accent
                end)
                connect(box.FocusLost, function(enterPressed)
                    if destroyed then return end
                    edge.Color = color.border
                    if box.Text ~= value or enterPressed then
                        value = box.Text
                        invoke(config.callback, value, enterPressed)
                    end
                end)
                return {
                    input = box,
                    get = function() return box.Text end,
                    set = function(nextValue, silent)
                        if destroyed then return end
                        value = tostring(nextValue or "")
                        box.Text = value
                        if not silent then invoke(config.callback, value, false) end
                    end,
                }
            end

            function api:AddDropdown(label, config)
                config = config or {}
                local choices = table.clone(config.options or {})
                local checked = {}
                for _, choice in ipairs(choices) do
                    assert(type(choice) == "string" and choice ~= "" and not checked[choice],
                        "Dropdown choices must be unique nonempty strings")
                    checked[choice] = true
                end
                assert(config.default == nil or checked[config.default], "Dropdown default must be in options")
                local value = config.default
                local panel = card(label, config.description)
                local select = button(panel, "Dropdown")
                select.LayoutOrder = 3
                select.Size = UDim2.new(1, 0, 0, targetHeight)
                local readout = text(select, "", 15, font.title)
                readout.Position = UDim2.fromOffset(10, 0)
                readout.Size = UDim2.new(1, -40, 1, 0)
                local chevron = addIcon(select, "down", 21, color.accent)
                positionRight(chevron, 11)
                local menu = frame(panel, {
                    Name = "Choices", LayoutOrder = 4, Size = UDim2.new(1, 0, 0, 0),
                    AutomaticSize = Enum.AutomaticSize.Y, Visible = false,
                })
                list(menu, 4)
                local rows = {}
                local function setExpanded(expanded)
                    menu.Visible = expanded and #choices > 0
                    chevron.Rotation = menu.Visible and 180 or 0
                end
                local function render()
                    readout.Text = value or config.placeholder or (#choices > 0 and "Choose an option" or "No options")
                    for choice, row in pairs(rows) do
                        row.check.Visible = choice == value
                        row.select(choice == value)
                    end
                end
                local function set(nextValue, silent)
                    if destroyed then return false end
                    if nextValue ~= nil and not checked[nextValue] then return false end
                    value = nextValue
                    setExpanded(false)
                    render()
                    if not silent then invoke(config.callback, value) end
                    return true
                end
                for index, choice in ipairs(choices) do
                    local item = button(menu, choice)
                    item.LayoutOrder = index
                    item.Size = UDim2.new(1, 0, 0, targetHeight)
                    local nameLabel = text(item, choice, 15, font.body)
                    nameLabel.Position = UDim2.fromOffset(10, 0)
                    nameLabel.Size = UDim2.new(1, -36, 1, 0)
                    local check = addIcon(item, "check", 20, color.accent)
                    positionRight(check, 10)
                    rows[choice] = { check = check, select = interactive(item, function() set(choice) end, color.rail) }
                end
                interactive(select, function() setExpanded(not menu.Visible) end, color.rail)
                render()
                return { set = set, get = function() return value end }
            end

            function api:AddKeybind(label, config, host)
                config = config or {}
                local value
                local controls = host or frame(card(label, config.description), {
                    Size = UDim2.new(1, 0, 0, targetHeight), LayoutOrder = 3,
                })
                local rebind = button(controls, "Rebind")
                positionRight(rebind, config.setActive and 0 or 62)
                rebind.Size = UDim2.fromOffset(host and 104 or 140, UserInputService.TouchEnabled and 44 or 30)
                local readout = text(rebind, "", 11, font.title, color.accent)
                readout.Position = UDim2.fromOffset(5, 0)
                readout.Size = UDim2.new(1, -10, 1, 0)
                readout.TextXAlignment = Enum.TextXAlignment.Center
                local binding = { label = readout, global = config.setActive ~= nil, mode = "Toggle" }
                local held = false
                hudOrder += 1
                local hudRow = frame(keybindsHud, { Size = UDim2.new(1, 0, 0, 20), LayoutOrder = hudOrder })
                local hudMode = text(hudRow, "", 10, font.title, hudAccent)
                hudMode.Size = UDim2.fromOffset(55, 20)
                local hudName = text(hudRow, label, 10, font.title)
                hudName.Position = UDim2.fromOffset(57, 0)
                hudName.Size = UDim2.new(1, -112, 1, 0)
                local hudKey = text(hudRow, "", 10, font.title, hudAccent)
                positionRight(hudKey, 0)
                hudKey.Size = UDim2.fromOffset(52, 20)
                hudKey.TextXAlignment = Enum.TextXAlignment.Right
                function binding.release()
                    if held then
                        held = false
                        config.setActive(false)
                    end
                end

                function binding.run()
                    if destroyed then return end
                    if config.setActive then
                        if binding.mode == "Always" then return end
                        if binding.mode == "Hold" then
                            if not held then
                                held = true
                                config.setActive(true)
                            end
                        else
                            config.toggleActive()
                        end
                    else
                        invoke(config.callback, value)
                    end
                end

                function binding.render()
                    local name = value and value.Name or "Unbound"
                    hudMode.Text = config.setActive and binding.mode or "Press"
                    hudKey.Text = value and value.Name or "None"
                    if capture == binding then
                        readout.Text = "Press a key…"
                    else
                        readout.Text = name
                    end
                end

                function binding.set(nextValue, silent)
                    if destroyed then return false, "Window closed" end
                    if nextValue ~= nil and (not keyCode(nextValue)
                        or nextValue == Enum.KeyCode.Escape or nextValue == Enum.KeyCode.Backspace) then
                        return false, "Invalid key"
                    end
                    if nextValue ~= nil and (nextValue == toggleKey
                        or (bindings[nextValue] and bindings[nextValue] ~= binding)) then
                        return false, "Key already in use"
                    end
                    binding.release()
                    if value then bindings[value] = nil end
                    value = nextValue
                    if value then bindings[value] = binding end
                    binding.render()
                    if not silent and config.onChanged then config.onChanged(value) end
                    return true
                end

                local ok, errorMessage = binding.set(config.default, true)
                if not ok then
                    binding.render()
                    readout.Text = errorMessage
                end
                interactive(rebind, function()
                    if modeTarget == binding then return end
                    local wasCapturing = capture == binding
                    clearCapture()
                    if not wasCapturing then
                        capture = binding
                        binding.render()
                    end
                end, color.rail)
                if config.setActive then
                    function binding.setMode(nextMode, silent)
                        if not table.find(modes, nextMode) then return end
                        binding.release()
                        if binding.mode == "Always" and nextMode ~= "Always" then config.setActive(false) end
                        binding.mode = nextMode
                        if nextMode == "Always" and not silent then config.setActive(true) end
                        binding.render()
                        if not silent and config.onModeChanged then config.onModeChanged(nextMode) end
                    end
                    connect(rebind.MouseButton2Click, function() openModeMenu(binding, rebind) end)
                    connect(rebind.TouchLongPress, function(_, state)
                        if state == Enum.UserInputState.Begin then openModeMenu(binding, rebind) end
                    end)
                    binding.setMode(config.mode or "Toggle", true)
                else
                    local run = button(controls, "Run")
                    positionRight(run, 0)
                    run.Size = UDim2.fromOffset(56, UserInputService.TouchEnabled and 44 or 30)
                    local runLabel = text(run, "Run", 11, font.title)
                    runLabel.Size = UDim2.fromScale(1, 1)
                    runLabel.TextXAlignment = Enum.TextXAlignment.Center
                    interactive(run, binding.run, color.rail)
                end
                return {
                    set = binding.set, get = function() return value end,
                    run = binding.run, getMode = function() return binding.mode end,
                }
            end

            return api
        end

        local appearance
        function window:AddAppearanceTab()
            assert(not destroyed, "The Luma Ridge window has been destroyed")
            if appearance then return appearance end

            settingsDock.Visible = true
            appearance = self:AddTab("Settings", "settings", true)
            layout()
            appearance:AddSection("Interface")
            appearance:AddToggle("Keybinds", "Show the shortcut list on screen.", keybindsHud.Visible, function(enabled)
                preferences.showKeybinds = enabled
                keybindsHud.Visible = enabled
            end)
            local sizes = { Small = 1, Default = 1.25, Large = 1.4 }
            local function applyTextSize(choice)
                preferences.textSize = choice
                textScale = sizes[choice]
                for object, size in pairs(textSizes) do
                    object.TextSize = math.round(size * textScale)
                end
            end
            local initialSize = sizes[preferences.textSize] and preferences.textSize or "Default"
            applyTextSize(initialSize)
            appearance:AddDropdown("Text size", {
                options = { "Small", "Default", "Large" }, default = initialSize,
                callback = applyTextSize,
            })

            appearance:AddSection("Background")
            local styles = { "Contours", "Grid", "Dots", "Gradient", "Solid" }
            if table.find(styles, preferences.backgroundStyle) then self:SetBackgroundStyle(preferences.backgroundStyle) end
            appearance:AddDropdown("Background style", {
                options = styles, default = backgroundStyle,
                callback = function(style)
                    self:SetBackgroundStyle(style)
                    preferences.backgroundStyle = style
                end,
            })
            local speeds = { Fast = 6, Normal = 12, Slow = 24 }
            if speeds[preferences.motionSpeed] then self:SetBackgroundSpeed(speeds[preferences.motionSpeed]) end
            if type(preferences.detail) == "number" and preferences.detail == preferences.detail then
                self:SetBackgroundDetail(preferences.detail / 100)
            end
            local speed = backgroundDuration == 6 and "Fast"
                or backgroundDuration == 12 and "Normal"
                or backgroundDuration == 24 and "Slow"
                or nil
            if reducedMotion then
                appearance:AddLabel("Reduced motion is enabled. Animation is paused.")
            else
                if type(preferences.animate) == "boolean" then self:SetBackgroundMotion(preferences.animate) end
                appearance:AddToggle("Animate background", nil, animated, function(enabled)
                    self:SetBackgroundMotion(enabled)
                    preferences.animate = enabled
                end)
            end
            appearance:AddDropdown("Motion speed", {
                options = { "Fast", "Normal", "Slow" }, default = speed, placeholder = "Custom speed",
                callback = function(choice)
                    self:SetBackgroundSpeed(speeds[choice])
                    preferences.motionSpeed = choice
                end,
            })
            appearance:AddSlider("Background detail", {
                description = "Adjust pattern visibility.",
                min = 0, max = 100, default = math.round((1 - contourAlpha) * 100),
                callback = function(value)
                    self:SetBackgroundDetail(value / 100)
                    preferences.detail = value
                end,
            })
            appearance:AddSection("Session")
            local saveStatus = appearance:AddLabel("")
            appearance:AddButton("Save config", "Save appearance and Player keybinds to this executor workspace.", function()
                saveStatus.Text = savePreferences() and "Configuration saved." or "Could not save configuration. Check Debug."
            end)
            appearance:AddToggle("Debug", "Show diagnostics and print events.", debugEnabled, function(enabled)
                debugEnabled = enabled
                preferences.debug = enabled
                debugLabel.Visible = enabled
                report("Debug " .. (enabled and "enabled" or "disabled"))
            end)
            debugLabel = appearance:AddLabel(table.concat(messages, "\n"))
            debugLabel.Visible = debugEnabled
            appearance:AddButton("Unload", "Close the panel and release its shortcuts.", function()
                self:Destroy()
            end, "exit")
            return appearance
        end

        gui.Parent = parent
        layout()
        syncAnimation()
        return window
    end

    return Library
end

local LumaRidge = loadLibrary()
local previousDemo = playerGui:FindFirstChild("LumaRidgeExecutorDemo")
if previousDemo and previousDemo:IsA("ScreenGui") then
    previousDemo:Destroy()
end

local window = LumaRidge.new({
    name = "LumaRidgeExecutorDemo",
    title = "Luma Ridge",
    toggleKey = Enum.KeyCode.RightShift,
})
activeWindow = window
environment.LumaRidge = window

local overview = window:AddTab("Overview", "grid")
overview:AddSection("Trail survey")
overview:AddLabel("Record waypoints and configure your map. The survey counter updates as you record.")
local waypoints, recording = 0, true
local status = overview:AddLabel("Waypoints recorded  ·  0")
local function recordWaypoint()
    if not recording then
        status.Text = "Recording is paused."
        return
    end
    waypoints += 1
    status.Text = "Waypoints recorded  ·  " .. waypoints
end
local record = overview:AddToggle("Record waypoints", "Pause or resume manual recording.", recording, function(enabled)
    recording = enabled
    status.Text = enabled and ("Waypoints recorded  ·  " .. waypoints) or "Recording is paused."
end)
overview:AddButton("Record waypoint", "Add one waypoint to the survey.", recordWaypoint, "plus")
overview:AddKeybind("Record waypoint shortcut", { default = Enum.KeyCode.F, callback = recordWaypoint })
overview:AddKeybind("Recording mode shortcut", {
    description = "Click to bind. Right-click or long-press to pick a mode.",
    setActive = function(enabled) record.set(enabled) end,
    toggleActive = function() record.set(not record.get()) end,
})

local settings = window:AddTab("Map", "folder")
settings:AddSection("Map setup")
local selection = settings:AddLabel("Profile: Hiker / Detail: 60% / Map: Terrain")
local profile, detail, map = "Hiker", 60, "Terrain"
local function showSelection()
    selection.Text = string.format("Profile: %s / Detail: %d%% / Map: %s", profile, detail, map)
end

local detailControl = settings:AddSlider("Detail", {
    description = "Set the preferred detail for the survey map.",
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

window:Use({
    name = "Player controls",
    setup = function(ui)
        local tab = ui:AddTab("Player", "sliders")
        local player = players.LocalPlayer
        local connections = {}
        local panel, wasEnabled
        local function observe(attribute, callback)
            table.insert(connections, player:GetAttributeChangedSignal(attribute):Connect(callback))
        end
        local status = tab:AddLabel("")
        local function findBridge()
            local bridge = playerGui:FindFirstChild("LumaRidgePlayerActions")
            if bridge and bridge:IsA("BindableFunction") then return bridge end
        end
        local function action(name, value)
            local bridge = findBridge()
            if not bridge or not player:GetAttribute("LRCharacterReady") then return false end
            local ok, accepted, message = pcall(bridge.Invoke, bridge, name, value)
            if not ok or not accepted then report(ok and message or accepted, true) end
            return ok and accepted
        end
        tab:AddSection("Movement")
        if type(preferences.bindings) ~= "table" then preferences.bindings = {} end
        local features = {
            { name = "Fly", description = "WASD, Space and Ctrl" },
            { name = "Noclip" },
            { name = "Invisible" },
        }
        for _, feature in ipairs(features) do
            local name = feature.name
            local attribute = "LR" .. name
            local function active() return player:GetAttribute(attribute) == true end
            local function setActive(value) return action("set" .. name, value) end
            local saved = preferences.bindings[name]
            if type(saved) ~= "table" then saved = {} end
            preferences.bindings[name] = saved
            local defaultKey
            if type(saved.key) == "string" then
                local ok, key = pcall(function() return Enum.KeyCode[saved.key] end)
                if ok then defaultKey = key end
            end
            local toggle
            toggle = tab:AddToggle(name, feature.description, active(), function(enabled)
                if (not enabled and feature.binding.getMode() == "Always") or not setActive(enabled) then
                    toggle.set(active(), true)
                end
            end, {
                default = defaultKey, mode = saved.mode, setActive = setActive,
                toggleActive = function() action("toggle" .. name) end,
                onChanged = function(key) saved.key = key and key.Name or nil end,
                onModeChanged = function(mode) saved.mode = mode end,
            })
            observe(attribute, function() toggle.set(active(), true) end)
            feature.setActive = setActive
            feature.binding = toggle.binding
        end
        tab:AddSection("Movement settings")
        local walk
        walk = tab:AddSlider("Walk speed", { min = 0, max = 64, default = player:GetAttribute("LRWalkSpeed") or 16,
            callback = function(value)
                if not action("setWalkSpeed", value) then walk.set(player:GetAttribute("LRWalkSpeed") or 16, true) end
            end })
        observe("LRWalkSpeed", function() walk.set(player:GetAttribute("LRWalkSpeed") or 16, true) end)
        local jump
        jump = tab:AddInput("Jump", {
            description = "Enter a value for the current jump mode.",
            default = player:GetAttribute("LRJump"),
            callback = function(value)
                local number = tonumber(value)
                if not number or not action("setJump", number) then jump.set(player:GetAttribute("LRJump"), true) end
            end,
        })
        observe("LRJump", function() jump.set(player:GetAttribute("LRJump"), true) end)
        local jumpMode = tab:AddLabel("")
        local function refreshJumpMode()
            jumpMode.Text = player:GetAttribute("LRUseJumpPower") == false and "Jump height · 0–25" or "Jump power · 0–100"
        end
        observe("LRUseJumpPower", refreshJumpMode)
        refreshJumpMode()
        local flySpeed
        flySpeed = tab:AddSlider("Fly speed", { min = 1, max = 100, default = player:GetAttribute("LRFlySpeed") or 40,
            callback = function(value)
                if not action("setFlySpeed", value) then flySpeed.set(player:GetAttribute("LRFlySpeed") or 40, true) end
            end })
        observe("LRFlySpeed", function() flySpeed.set(player:GetAttribute("LRFlySpeed") or 40, true) end)
        if player:GetAttribute("LRGravityAllowed") then
            tab:AddInput("Experience gravity", {
                description = "Changes gravity for everyone. Server range 0–300.",
                callback = function(value)
                    local number = tonumber(value)
                    if number then action("setGravity", number) end
                end,
            })
        end
        local function refresh()
            local bridge = findBridge()
            local currentPanel = playerGui:FindFirstChild("LumaRidgePlayerPanel")
            if bridge and currentPanel and currentPanel:IsA("ScreenGui") and panel ~= currentPanel then
                panel, wasEnabled = currentPanel, currentPanel.Enabled
                panel.Enabled = false
            end
            if not bridge then
                status.Text = "Install the Player server Script and LocalScript in your experience to enable these controls."
                status.Visible = true
            elseif not player:GetAttribute("LRPlayerAllowed") then
                status.Text = "Your user ID is not enabled for Player controls."
                status.Visible = true
            elseif not player:GetAttribute("LRCharacterReady") then
                status.Text = "Waiting for your character."
                status.Visible = true
            else
                status.Visible = false
                for _, feature in ipairs(features) do
                    if feature.binding.getMode() == "Always" then feature.setActive(true) end
                end
            end
        end
        observe("LRCharacterReady", refresh)
        observe("LRPlayerAllowed", refresh)
        table.insert(connections, playerGui.ChildAdded:Connect(function(child)
            if child.Name == "LumaRidgePlayerActions" or child.Name == "LumaRidgePlayerPanel" then refresh() end
        end))
        table.insert(connections, playerGui.ChildRemoved:Connect(function(child)
            if child.Name == "LumaRidgePlayerActions" then
                if panel and panel.Parent then panel.Enabled = wasEnabled end
                panel = nil
                refresh()
            end
        end))
        refresh()
        return function()
            for _, connection in ipairs(connections) do connection:Disconnect() end
            for _, feature in ipairs(features) do
                if feature.binding.getMode() == "Always" then feature.setActive(false) end
            end
            if panel and panel.Parent then panel.Enabled = wasEnabled end
        end
    end,
})
window:AddAppearanceTab()
report("3/3 Loading plugins…")
for _, plugin in ipairs(config.plugins or {}) do
    local ok, reason = pcall(function() window:Use(plugin) end)
    if not ok then report(reason, true) end
end
report("Ready")
startupLabel = nil
startupGui:Destroy()
startupGui = nil
print("[Luma Ridge] Ready. Right Shift toggles the panel.")
return window
end

local ok, result = xpcall(start, debug.traceback)
if not ok then
    report("Startup failed: " .. tostring(result), true)
    if activeWindow then activeWindow:Destroy() end
end
return ok and result or nil
