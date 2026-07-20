----------------------------------------------------------------------
-- 01_model_the_config.lua — Your hyprland.conf as Lua data
----------------------------------------------------------------------
-- WHAT YOU'LL LEARN
--   • How every construct in hyprlang maps onto a Lua table shape
--   • Arrays for repeated keys (monitor =, exec-once =, bind =)
--   • Nested tables for sections (decoration { blur { ... } })
--   • Why we model FIRST and only serialize later (data > strings)
--   • A pairs() gotcha that lesson 02 has to solve
-- HOW TO RUN
--   luajit 01_model_the_config.lua      (from this directory)
--   or inside nvim:  :luafile %          (with this file open)
-- PREREQUISITES: modules 01–05 (tables, strings, io)
----------------------------------------------------------------------

------------------------------------------------------------ 1. The idea
-- Open ~/.config/hypr/hyprland.conf next to this file and squint at it:
--
--   monitor = eDP-1, 1920x1080@60, 0x0, 1     <- repeated key  -> Lua array
--   general {                                  <- section       -> nested table
--       gaps_in = 3                            <- scalar        -> table field
--       resize_on_border = true                <- boolean       -> Lua boolean
--   }
--
-- hyprlang is *structurally* a subset of what Lua tables can express.
-- So step one is NOT printing text — it's capturing your config as data.
-- Once it's data you can loop over it, share it, override it per-machine,
-- and only at the very end flatten it into text (that's lesson 02's job).

------------------------------------------------------------ 2. Variables
-- hyprlang lets you define $mainMod = SUPER and reuse it. We model the
-- variable table separately; bind entries below reference "$mainMod" as a
-- plain string for now (lesson 03 upgrades this to a real object).
local variables = {
  mainMod = "SUPER",
}

------------------------------------------------------------ 3. Monitors
-- Your five real monitor lines, but as records with NAMED fields.
-- Compare with the raw lines: which is easier to edit six months from now?
-- hz is optional (HDMI-A-1 has no @refresh in your config), so it can be
-- nil — Lua tables simply don't store the field then.
local monitors = {
  { name = "eDP-1",    res = "1920x1080", hz = 60,  pos = "0x0",     scale = 1 },
  { name = "DP-1",     res = "2560x1440", hz = 60,  pos = "auto-up", scale = 1 },
  { name = "DP-4",     res = "1920x1080", hz = 180, pos = "1920x0",  scale = 1 },
  { name = "DP-3",     res = "1920x1080", hz = 180, pos = "3840x0",  scale = 1 },
  { name = "HDMI-A-1", res = "1920x1080",           pos = "1920x0",  scale = 1 },
}

------------------------------------------------------------ 4. exec-once
-- Repeated key, order matters (waybar before hyprpaper is fine, but the
-- sleep-then-nvim line depends on the compositor being up). An array keeps
-- that order — ipairs() walks 1, 2, 3, ... deterministically.
local exec_once = {
  "dbus-update-activation-environment --systemd WAYLAND_DISPLAY XDG_CURRENT_DESKTOP",
  "waybar",
  "hyprpaper",
  [[sh -c 'sleep 1 && ghostty -e nvim ~/todos.md']],  -- [[..]] avoids quoting pain
}

------------------------------------------------------------ 5. Sections
-- A hyprlang section is a table; a nested section is a table in a table.
-- These numbers are your real ones (gaps 3/3, border 1, rounding 10,
-- opacities 0.75/0.6). blur/shadow contents are plausible placeholders —
-- you'll true them up against your file when you diff in lesson 04.
local general = {
  gaps_in          = 3,
  gaps_out         = 3,
  border_size      = 1,
  resize_on_border = true,      -- a real Lua boolean, not the string "true"
  layout           = "dwindle",
}

local decoration = {
  rounding         = 10,
  active_opacity   = 0.75,
  inactive_opacity = 0.6,
  blur   = { enabled = true, size = 3, passes = 1 },
  shadow = { enabled = true, range = 4, render_power = 3 },
}

local input = {
  kb_layout    = "us",
  follow_mouse = 1,
  sensitivity  = 0,
  touchpad = { natural_scroll = true },
}

------------------------------------------------------------ 6. Binds
-- A bind line is really a 4-tuple: mods, key, dispatcher, optional arg.
-- Records again. Note the mods field holds the *string* "$mainMod" — the
-- serializer will print it verbatim and hyprlang resolves the $variable.
local binds = {
  { mods = "$mainMod", key = "Q", dispatcher = "exec",           arg = "ghostty" },
  { mods = "$mainMod", key = "C", dispatcher = "killactive" },
  { mods = "$mainMod", key = "M", dispatcher = "exit" },
  { mods = "$mainMod", key = "V", dispatcher = "togglefloating" },
  { mods = "$mainMod", key = "F", dispatcher = "fullscreen",     arg = "1" },
}

------------------------------------------------------------ 7. One model to rule them all
local config = {
  variables  = variables,
  monitors   = monitors,
  exec_once  = exec_once,
  general    = general,
  decoration = decoration,
  input      = input,
  binds      = binds,
}

------------------------------------------------------------ 8. Summarize the model
print("== hyprland.conf, modeled as Lua data ==")

print(string.format("variables:  %d  ($mainMod = %s)", 1, config.variables.mainMod))

print(string.format("monitors:   %d", #config.monitors))
for i, m in ipairs(config.monitors) do
  local hz = m.hz and ("@" .. m.hz) or ""          -- and/or: '' when hz is nil
  print(string.format("  %d. %-9s %s%-5s at %-8s scale %s",
                      i, m.name, m.res, hz, m.pos, m.scale))
end

print(string.format("exec-once:  %d lines", #config.exec_once))
for i, cmd in ipairs(config.exec_once) do
  print(string.format("  %d. %s", i, cmd))
end

print(string.format("binds:      %d (all on %s so far)", #config.binds, "$mainMod"))
for _, b in ipairs(config.binds) do
  print(string.format("  %s + %s -> %s%s",
                      b.mods, b.key, b.dispatcher, b.arg and (" " .. b.arg) or ""))
end

-- Nested access reads like a path — decoration.blur.size, just like the
-- section nesting in the .conf file:
print(string.format("decoration.blur.size = %d, decoration.rounding = %d",
                    config.decoration.blur.size, config.decoration.rounding))

------------------------------------------------------------ 9. The gotcha lesson 02 must solve
-- Hash-part iteration with pairs() has NO guaranteed order (true in every
-- Lua version). Fine for a summary, fatal for a config generator — you
-- want the generated file to be byte-stable so diffs stay meaningful.
print("\ngeneral section via pairs() — order is whatever Lua feels like:")
for k, v in pairs(config.general) do
  print(string.format("  %s = %s", k, tostring(v)))  -- tostring: booleans print as true/false
end
print("(lesson 02 fixes this with sorted keys + an explicit __order list)")

------------------------------------------------------------ TRY IT
-- 1. Add a sixth monitor entry that disables HDMI-A-1 when docked
--    (in hyprlang that's `monitor = HDMI-A-1, disable` — how would you
--    model "disabled" as a field?). Re-run and check the summary.
-- 2. Add two more binds from your real config (grep '^bind' ~/.config/hypr/hyprland.conf)
--    and re-run.
-- 3. Change gaps_in to 10 and print general again — notice you edited ONE
--    number in ONE place. That's the whole pitch of config-as-data.
