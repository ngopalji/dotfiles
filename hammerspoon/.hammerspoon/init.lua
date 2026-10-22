require("hs.ipc")

-- Ctrl+Alt+H/L focuses a window on the left/right monitor.
-- Prefers the frontmost app's window on that screen (handles same app open on both monitors),
-- falls back to any window on that screen, falls back to just moving the mouse there.
local function focusWindowOnScreen(screenIndex)
    local screens = hs.screen.allScreens()
    table.sort(screens, function(a, b) return a:frame().x < b:frame().x end)
    local screen = screens[screenIndex]
    if not screen then return end

    local candidates = {}
    local frontApp = hs.application.frontmostApplication()
    if frontApp then
        for _, w in ipairs(frontApp:allWindows()) do
            if w:isStandard() and w:screen() == screen then
                table.insert(candidates, w)
            end
        end
    end

    if #candidates == 0 then
        for _, w in ipairs(hs.window.allWindows()) do
            if w:isStandard() and w:screen() == screen then
                table.insert(candidates, w)
            end
        end
    end

    if #candidates > 0 then
        candidates[1]:focus()
    else
        local frame = screen:frame()
        hs.mouse.absolutePosition(hs.geometry.point(frame.x + frame.w / 2, frame.y + frame.h / 2))
    end
end

hs.hotkey.bind({ "ctrl", "alt" }, "h", function() focusWindowOnScreen(1) end)
hs.hotkey.bind({ "ctrl", "alt" }, "l", function() focusWindowOnScreen(2) end)

-- Hyper + left-hand letter launches or focuses an app; pressing it again while the app
-- is in front cycles its windows. The mouse follows to the window. Hyper is Right Option
-- (Karabiner), pressed with the right hand. Hyper+hjkl are arrow keys, so apps stay off those.
local hyper = { "ctrl", "alt", "shift", "cmd" }
local appKeys = {
    g = "com.mitchellh.ghostty",
    a = "com.google.Chrome",
    s = "com.tinyspeck.slackmacgap",
    c = "com.anthropic.claudefordesktop",
    x = "com.openai.codex",          -- ChatGPT
    f = "md.obsidian",
    t = "com.spotify.client",        -- "tunes"
    d = "com.apple.finder",          -- "directory"
}

-- Move the mouse to the middle of a window, unless it's already over it
local function centerMouseOn(win)
    local frame = win:frame()
    if not hs.geometry.point(hs.mouse.absolutePosition()):inside(frame) then
        hs.mouse.absolutePosition(hs.geometry.point(frame.x + frame.w / 2, frame.y + frame.h / 2))
    end
end

-- Switching apps is async: wait for the app's window to take focus (up to 5s, enough
-- for a cold start), then move the mouse there. Kept in a variable so it isn't collected.
local pendingCenter
local function centerMouseWhenFocused(bundleID)
    if pendingCenter then pendingCenter:stop() end
    local deadline = hs.timer.secondsSinceEpoch() + 5
    local function focusedWindow()
        local app = hs.application.frontmostApplication()
        return app and app:bundleID() == bundleID and app:focusedWindow()
    end
    pendingCenter = hs.timer.waitUntil(function()
        return focusedWindow() or hs.timer.secondsSinceEpoch() > deadline
    end, function()
        local win = focusedWindow()
        if win then centerMouseOn(win) end
    end, 0.05)
end

local function launchOrCycle(bundleID)
    local app = hs.application.frontmostApplication()
    if not app or app:bundleID() ~= bundleID then
        hs.application.launchOrFocusByBundleID(bundleID)
        centerMouseWhenFocused(bundleID)
        return
    end

    local windows = hs.fnutils.filter(app:allWindows(), function(w)
        return w:isStandard() and w:isVisible()
    end)
    local focused = app:focusedWindow()
    local target = focused
    if #windows > 1 then
        -- Stable order, so repeated presses visit every window instead of flipping between two
        table.sort(windows, function(a, b) return a:id() < b:id() end)
        target = windows[1]
        for i, w in ipairs(windows) do
            if focused and w:id() == focused:id() then
                target = windows[i % #windows + 1]
                break
            end
        end
        target:focus()
    end
    if target then centerMouseOn(target) end
end

for key, bundleID in pairs(appKeys) do
    hs.hotkey.bind(hyper, key, function() launchOrCycle(bundleID) end)
end
