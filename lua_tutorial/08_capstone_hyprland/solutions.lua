----------------------------------------------------------------------
-- solutions.lua — Complete solutions for module 08
----------------------------------------------------------------------
-- HOW TO RUN
--   luajit solutions.lua                (from this directory)
-- Each solution notes its key insight. Try the exercises first!
----------------------------------------------------------------------

local here = ((arg and arg[0]) or ""):match("^(.*[/\\])") or "./"
local hypr = dofile(here .. "03_dsl.lua")
local bind = hypr.bind

print("== module 08 solutions ==")

------------------------------------------------------------ EXERCISE 1: media keys
-- Key insight: an empty-string mods field is perfectly valid — bind("")
-- tostrings to "", so the line starts ", XF86..." exactly like hyprlang wants.
local function volume_binds()
  return {
    bind("", "XF86AudioRaiseVolume", "exec", "wpctl set-volume @DEFAULT_AUDIO_SINK@ 5%+"),
    bind("", "XF86AudioLowerVolume", "exec", "wpctl set-volume @DEFAULT_AUDIO_SINK@ 5%-"),
    bind("", "XF86AudioMute",        "exec", "wpctl set-mute @DEFAULT_AUDIO_SINK@ toggle"),
  }
end

local vb = volume_binds()
assert(#vb == 3, "want 3 binds, got " .. #vb)
assert(vb[1]:sub(1, 1) == ",", "mods field should be empty -> line starts with a comma")
assert(vb[1]:find("XF86AudioRaiseVolume", 1, true))
assert(vb[3]:find("set-mute", 1, true))
print("exercise 1 OK: " .. vb[1])

------------------------------------------------------------ EXERCISE 2: the workspace loop
-- Key insight: the loop variable is BOTH the key name and the workspace
-- argument, and Var's __concat builds the "SUPER SHIFT" mods. 18 config
-- lines collapse into one pattern — edit the pattern, all 9 follow.
local function workspaces(conf, m, n)
  for i = 1, n do
    conf:add("bind", bind(m, i, "workspace", i))
    conf:add("bind", bind(m .. " SHIFT", i, "movetoworkspace", i))
  end
  return conf
end

local c2 = hypr()
local mod2 = c2:var("mainMod", "SUPER")
workspaces(c2, mod2, 9)
local t2 = c2:render()
assert(t2:find("bind = $mainMod, 7, workspace, 7", 1, true), "switch binds missing")
assert(t2:find("bind = $mainMod SHIFT, 7, movetoworkspace, 7", 1, true), "move binds missing")
assert(select(2, t2:gsub("bind = ", "")) == 18, "expected exactly 18 bind lines")
print("exercise 2 OK — 18 lines of config from one loop")

------------------------------------------------------------ EXERCISE 3: windowrule support
-- Key insight: "extending the DSL" is usually just one more tiny
-- constructor returning a string — the serializer already knows how to
-- emit any repeated key. Assert early so typos die at generation time.
local function windowrule(effect, matcher)
  assert(effect and effect ~= "",   "windowrule needs an effect (float, opacity 0.9, ...)")
  assert(matcher and matcher ~= "", "windowrule needs a matcher (class:^(...)$, title:..., ...)")
  return effect .. ", " .. matcher
end

local c3 = hypr()
c3:add("windowrule",
    windowrule("float", "class:^(pavucontrol)$"),
    windowrule("opacity 0.9", "class:^(ghostty)$"))
assert(c3:render():find("windowrule = float, class:^(pavucontrol)$", 1, true))
assert(not pcall(windowrule, "float"), "windowrule with no matcher should error")
print("exercise 3 OK")

------------------------------------------------------------ EXERCISE 4: env() lines
-- Key insight: nothing fancy — but the helper documents the no-space rule
-- once, instead of you remembering it on every env line forever.
local function env(name, value)
  assert(name and name ~= "", "env needs a variable name")
  return string.format("%s,%s", name, tostring(value))
end

assert(env("XCURSOR_SIZE", 24) == "XCURSOR_SIZE,24")
assert(env("QT_QPA_PLATFORM", "wayland") == "QT_QPA_PLATFORM,wayland")
print("exercise 4 OK")

------------------------------------------------------------ EXERCISE 5: one palette table
-- Key insight: %x matches one hex digit; anchoring ^...$ makes the pattern
-- an exact-format validator. The palette table is the single source of
-- truth — stretch goal 5 aims the same table at waybar and ghostty.
local palette = {
  blue = "7aa2f7",
  bg   = "1a1b26",
  grey = "414868",
}

local function rgba(hex, alpha)
  assert(type(hex) == "string" and hex:match("^" .. ("%x"):rep(6) .. "$"),
         "rgba wants exactly 6 hex digits, got: " .. tostring(hex))
  return string.format("rgba(%s%s)", hex, alpha or "ff")
end

assert(rgba(palette.blue, "ee") == "rgba(7aa2f7ee)")
assert(rgba(palette.grey) == "rgba(414868ff)")
assert(not pcall(rgba, "not-a-color"), "bad hex should error")
local c5 = hypr()
c5:set("general", { ["col.active_border"]   = rgba(palette.blue, "ee"),
                    ["col.inactive_border"] = rgba(palette.grey, "aa") })
assert(c5:render():find("col.active_border = rgba(7aa2f7ee)", 1, true))
print("exercise 5 OK: " .. rgba(palette.blue, "ee"))

------------------------------------------------------------ EXERCISE 6: per-host merge
-- Key insights:
--   • copy base FIRST, then lay override on top — neither input mutates;
--   • recurse only when BOTH sides are section-tables; if either side is
--     an array (t[1] ~= nil) the override wins wholesale, because
--     "the laptop's monitor list" is a replacement, not an addition;
--   • sub-tables untouched by override are shared, not copied — fine for
--     read-only models, worth knowing if you ever mutate the result.
local function is_array(t)
  return type(t) == "table" and t[1] ~= nil
end

local function merge(base, override)
  local out = {}
  for k, v in pairs(base) do out[k] = v end
  for k, v in pairs(override) do
    local b = out[k]
    if type(v) == "table" and type(b) == "table"
       and not is_array(v) and not is_array(b) then
      out[k] = merge(b, v)              -- two sections: recurse
    else
      out[k] = v                        -- scalar or array: override wins
    end
  end
  return out
end

local base = {
  monitor = { "eDP-1, 1920x1080@60, 0x0, 1", "DP-1, 2560x1440@60, auto-up, 1" },
  general = { gaps_in = 3, layout = "dwindle" },
  decoration = { rounding = 10, blur = { enabled = true, size = 3 } },
}
local laptop = {
  monitor = { "eDP-1, 1920x1080@60, 0x0, 1" },
  general = { gaps_in = 8 },
  decoration = { blur = { size = 6 } },
}
local m = merge(base, laptop)
assert(#m.monitor == 1, "laptop should have exactly its own monitor list")
assert(m.general.gaps_in == 8 and m.general.layout == "dwindle")
assert(m.decoration.blur.size == 6 and m.decoration.blur.enabled == true)
assert(m.decoration.rounding == 10)
assert(base.general.gaps_in == 3, "base must not be mutated!")
print("exercise 6 OK — one config, many machines")

-- Bonus: see the merged model as hyprlang (order comes from the sort
-- fallback since merge() built a fresh table with no __order):
print("\nmerged laptop config:\n" .. hypr.serialize(m))

print("all solutions passed")
