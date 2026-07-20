----------------------------------------------------------------------
-- exercises.lua — Extend the DSL yourself
----------------------------------------------------------------------
-- WHAT YOU'LL PRACTICE
--   • Using bind()/monitor{}/Config from 03_dsl.lua as building blocks
--   • Loops that replace hand-typed config (workspaces 1–9)
--   • Adding brand-new keyword support (windowrule, env) to the DSL
--   • A shared palette table and a per-host deep merge
-- HOW TO RUN
--   luajit exercises.lua                (from this directory)
--   It runs clean as-is. Fill in each TODO, then uncomment its CHECK
--   block and re-run. Compare with solutions.lua when you're done.
-- PREREQUISITES: 01–04 of this module
----------------------------------------------------------------------

local here = ((arg and arg[0]) or ""):match("^(.*[/\\])") or "./"
local hypr = dofile(here .. "03_dsl.lua")
local bind, monitor = hypr.bind, hypr.monitor

print("== module 08 exercises ==")

------------------------------------------------------------ EXERCISE 1: media keys
-- Volume keys have NO modifier: the line starts with an empty mods field,
--   bind = , XF86AudioRaiseVolume, exec, wpctl set-volume @DEFAULT_AUDIO_SINK@ 5%+
-- Build the three lines below with bind() and an empty-string mods.
-- (Real configs use `bindel` for these so holding the key repeats — it's
-- just another repeated key name for conf:add.)

local function volume_binds()
  -- TODO: return an array of three bind() strings:
  --   raise 5%+, lower 5%-, and XF86AudioMute -> "... toggle"
  --   commands: wpctl set-volume @DEFAULT_AUDIO_SINK@ 5%+   (and 5%-)
  --             wpctl set-mute @DEFAULT_AUDIO_SINK@ toggle
  return {}
end

-- CHECK 1 — uncomment when ready:
-- local vb = volume_binds()
-- assert(#vb == 3, "want 3 binds, got " .. #vb)
-- assert(vb[1]:sub(1, 1) == ",", "mods field should be empty -> line starts with a comma")
-- assert(vb[1]:find("XF86AudioRaiseVolume", 1, true))
-- assert(vb[3]:find("set-mute", 1, true))
-- print("exercise 1 OK")
print("exercise 1: fill in volume_binds(), then uncomment CHECK 1")

------------------------------------------------------------ EXERCISE 2: the workspace loop
-- Your real config hand-types 18 lines: mod+N -> workspace N, and
-- mod+SHIFT+N -> movetoworkspace N, for N = 1..9. Write them with a loop.
-- Hints: conf:add("bind", ...) appends; `m .. " SHIFT"` works on a Var
-- (that's the __concat metamethod from lesson 03).

local function workspaces(conf, m, n)
  -- TODO: for i = 1, n do ... add BOTH binds ... end
  return conf                          -- keep it chainable
end

-- CHECK 2 — uncomment when ready:
-- local c2 = hypr()
-- local mod2 = c2:var("mainMod", "SUPER")
-- workspaces(c2, mod2, 9)
-- local t2 = c2:render()
-- assert(t2:find("bind = $mainMod, 7, workspace, 7", 1, true), "switch binds missing")
-- assert(t2:find("bind = $mainMod SHIFT, 7, movetoworkspace, 7", 1, true), "move binds missing")
-- assert(select(2, t2:gsub("bind = ", "")) == 18, "expected exactly 18 bind lines")
-- print("exercise 2 OK — 18 lines of config from one loop")
print("exercise 2: fill in workspaces(), then uncomment CHECK 2")

------------------------------------------------------------ EXERCISE 3: windowrule support
-- hyprland windowrules are another repeated key:
--   windowrule = float, class:^(pavucontrol)$
-- Write a constructor windowrule(effect, matcher) -> that string, with an
-- assert that both arguments are present (the DSL should catch mistakes
-- at generation time, remember).

local function windowrule(effect, matcher)
  -- TODO
end

-- CHECK 3 — uncomment when ready:
-- local c3 = hypr()
-- c3:add("windowrule",
--     windowrule("float", "class:^(pavucontrol)$"),
--     windowrule("opacity 0.9", "class:^(ghostty)$"))
-- assert(c3:render():find("windowrule = float, class:^(pavucontrol)$", 1, true))
-- assert(not pcall(windowrule, "float"), "windowrule with no matcher should error")
-- print("exercise 3 OK")
print("exercise 3: fill in windowrule(), then uncomment CHECK 3")

------------------------------------------------------------ EXERCISE 4: env() lines
-- Environment lines look like:  env = XCURSOR_SIZE,24   (comma, NO space —
-- hyprland is picky here). Write env(name, value) -> "XCURSOR_SIZE,24".
-- string.format is your friend; value may be a number.

local function env(name, value)
  -- TODO
end

-- CHECK 4 — uncomment when ready:
-- assert(env("XCURSOR_SIZE", 24) == "XCURSOR_SIZE,24")
-- assert(env("QT_QPA_PLATFORM", "wayland") == "QT_QPA_PLATFORM,wayland")
-- print("exercise 4 OK")
print("exercise 4: fill in env(), then uncomment CHECK 4")

------------------------------------------------------------ EXERCISE 5: one palette table
-- Hyprland colors look like rgba(7aa2f7ee): 6 hex digits + 2 alpha digits.
-- a) Write rgba(hex, alpha) -> "rgba(7aa2f7ee)" (alpha defaults to "ff").
--    Make it validate: 6 hex digits or error. Pattern hint: ^%x%x%x%x%x%x$
-- b) Use it with the palette to set general["col.active_border"] and
--    ["col.inactive_border"] on a Config, and assert the rendered line.

local palette = {                       -- tokyonight-night, like your nvim
  blue = "7aa2f7",
  bg   = "1a1b26",
  grey = "414868",
}

local function rgba(hex, alpha)
  -- TODO (remember: validate hex, default alpha to "ff")
end

-- CHECK 5 — uncomment when ready:
-- assert(rgba(palette.blue, "ee") == "rgba(7aa2f7ee)")
-- assert(rgba(palette.grey) == "rgba(414868ff)")
-- assert(not pcall(rgba, "not-a-color"), "bad hex should error")
-- local c5 = hypr()
-- c5:set("general", { ["col.active_border"] = rgba(palette.blue, "ee") })
-- assert(c5:render():find("col.active_border = rgba(7aa2f7ee)", 1, true))
-- print("exercise 5 OK")
print("exercise 5: fill in rgba(), then uncomment CHECK 5")

------------------------------------------------------------ EXERCISE 6 (the sting): per-host merge
-- Same dotfiles, two machines: docked (all five monitors) and laptop-only.
-- Write merge(base, override) -> NEW model table where:
--   • scalars in override replace scalars in base
--   • ARRAYS in override replace base arrays wholesale (a laptop doesn't
--     want the docked monitor list "appended to")
--   • SECTIONS (non-array tables) merge recursively
--   • base and override are NOT mutated
-- You'll need is_array-style detection (t[1] ~= nil — or hypr's exported
-- helper via 02) and recursion. This is a real dotfiles-framework function.

local function merge(base, override)
  -- TODO
end

-- CHECK 6 — uncomment when ready:
-- local base = {
--   monitor = { "eDP-1, 1920x1080@60, 0x0, 1", "DP-1, 2560x1440@60, auto-up, 1" },
--   general = { gaps_in = 3, layout = "dwindle" },
--   decoration = { rounding = 10, blur = { enabled = true, size = 3 } },
-- }
-- local laptop = {
--   monitor = { "eDP-1, 1920x1080@60, 0x0, 1" },
--   general = { gaps_in = 8 },
--   decoration = { blur = { size = 6 } },
-- }
-- local m = merge(base, laptop)
-- assert(#m.monitor == 1, "laptop should have exactly its own monitor list")
-- assert(m.general.gaps_in == 8 and m.general.layout == "dwindle")
-- assert(m.decoration.blur.size == 6 and m.decoration.blur.enabled == true)
-- assert(m.decoration.rounding == 10)
-- assert(base.general.gaps_in == 3, "base must not be mutated!")
-- print("exercise 6 OK — one config, many machines")
print("exercise 6: fill in merge(), then uncomment CHECK 6")

print("\nAll scaffolding ran. Solve, uncomment, re-run — answers in solutions.lua.")
