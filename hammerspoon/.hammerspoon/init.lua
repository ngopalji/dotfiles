require("hs.ipc")

-- Move mouse to center of window when it gains focus (only if mouse is outside the window)
local ignoredApps = { ["CleanShot X"] = true }

hs.window.filter.default:subscribe(hs.window.filter.windowFocused, function(window)
    if window then
        local appName = window:application():name()
        if ignoredApps[appName] then return end
        local frame = window:frame()
        local mouse = hs.mouse.absolutePosition()
        if not hs.geometry.point(mouse):inside(frame) then
            local center = hs.geometry.point(frame.x + frame.w / 2, frame.y + frame.h / 2)
            hs.mouse.absolutePosition(center)
        end
    end
end)

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
