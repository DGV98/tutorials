----------------------------------------------------------------------
-- 04_port_your_config.lua — The real thing: your config, generated
----------------------------------------------------------------------
-- WHAT YOU'LL LEARN
--   • Assembling a full hyprland.conf through the DSL from lesson 03
--   • The loop payoff: 18 workspace binds from 4 lines of Lua
--   • The port-by-diff workflow against ~/.config/hypr/hyprland.conf
--   • How to test a generated config on a live Hyprland — safely
-- HOW TO RUN
--   luajit 04_port_your_config.lua      (from this directory)
--   or inside nvim:  :luafile %          (with this file open)
-- PREREQUISITES: 03_dsl.lua
----------------------------------------------------------------------
-- THIS FILE IS YOURS. It's the template you'll keep editing until
-- `diff build/hyprland.conf ~/.config/hypr/hyprland.conf` goes quiet.
-- Values marked PLACEHOLDER are educated guesses — the diff will correct them.
----------------------------------------------------------------------

local here = ((arg and arg[0]) or ""):match("^(.*[/\\])") or "./"
local hypr = dofile(here .. "03_dsl.lua")
local bind, monitor = hypr.bind, hypr.monitor

local conf = hypr()                       -- __call sugar from lesson 03

------------------------------------------------------------ 1. Variables
local mod = conf:var("mainMod", "SUPER")

------------------------------------------------------------ 2. Monitors — all five, named fields
-- Your real lines: eDP-1 builtin, DP-1 1440p above, two 180Hz panels
-- side by side, HDMI fallback sharing DP-4's spot.
conf:add("monitor",
    monitor{ name = "eDP-1",    res = "1920x1080", hz = 60,  pos = "0x0"     },
    monitor{ name = "DP-1",     res = "2560x1440", hz = 60,  pos = "auto-up" },
    monitor{ name = "DP-4",     res = "1920x1080", hz = 180, pos = "1920x0"  },
    monitor{ name = "DP-3",     res = "1920x1080", hz = 180, pos = "3840x0"  },
    monitor{ name = "HDMI-A-1", res = "1920x1080",           pos = "1920x0"  })

------------------------------------------------------------ 3. Autostart — your real exec-once lines
conf:add("exec-once",
    "dbus-update-activation-environment --systemd WAYLAND_DISPLAY XDG_CURRENT_DESKTOP",
    "waybar",
    "hyprpaper",
    [[sh -c 'sleep 1 && ghostty -e nvim ~/todos.md']])

------------------------------------------------------------ 4. Sections — your numbers
conf:set("general", {
    gaps_in          = 3,
    gaps_out         = 3,
    border_size      = 1,
    resize_on_border = true,
    layout           = "dwindle",
    -- Your real file likely also sets col.active_border / col.inactive_border.
    -- Dotted keys are fine — they just need bracket syntax in Lua:
    -- ["col.active_border"] = "rgba(7aa2f7ee)",     -- PLACEHOLDER: take yours from the diff
})

conf:set("decoration", {
    rounding         = 10,
    active_opacity   = 0.75,
    inactive_opacity = 0.6,
    blur   = { enabled = true, size = 3, passes = 1 },          -- PLACEHOLDER values
    shadow = { enabled = true, range = 4, render_power = 3 },   -- PLACEHOLDER values
})

conf:set("input", {
    kb_layout    = "us",
    follow_mouse = 1,
    sensitivity  = 0,
    touchpad     = { natural_scroll = true },                   -- PLACEHOLDER section
})

conf:set("dwindle", {                                           -- PLACEHOLDER section
    pseudotile     = true,
    preserve_split = true,
})

------------------------------------------------------------ 5. Binds — the hand-written few
conf:add("bind",
    bind(mod, "Q", "exec", "ghostty"),
    bind(mod, "C", "killactive"),
    bind(mod, "M", "exit"),
    bind(mod, "V", "togglefloating"),
    bind(mod, "F", "fullscreen", 1),
    -- vim-style focus movement — swap for arrow keys if your file uses those:
    bind(mod, "H", "movefocus", "l"),
    bind(mod, "L", "movefocus", "r"),
    bind(mod, "K", "movefocus", "u"),
    bind(mod, "J", "movefocus", "d"))

------------------------------------------------------------ 6. Binds — the loop payoff
-- Your real config has one hand-typed bind line per workspace. Here, a
-- loop writes them. Add "movetoworkspace" (exercise 2) and it's 18 lines
-- of hyprlang from 4 lines of Lua — change the pattern once, all nine
-- workspaces follow. THIS is why generating beats hand-editing.
for i = 1, 9 do
  conf:add("bind", bind(mod, i, "workspace", i))
end

-- Mouse binds are a different keyword (bindm) — a different repeated key:
conf:add("bindm",
    bind(mod, "mouse:272", "movewindow"),
    bind(mod, "mouse:273", "resizewindow"))

------------------------------------------------------------ 7. Generate
local text = conf:render()
print(text)

local _, line_count = text:gsub("\n", "\n")     -- gsub's 2nd return = match count
local path = conf:write("hyprland.conf")

print(string.rep("-", 70))
print(string.format("wrote %s  (%d lines of hyprlang)", path, line_count))

-- A few paranoia checks before you ever load this into a live WM:
assert(select(2, text:gsub("monitor = ", "")) == 5, "expected 5 monitor lines")
assert(text:find("bind = $mainMod, 9, workspace, 9", 1, true), "workspace loop broke")
assert(text:find("exec-once = waybar", 1, true))
print("sanity checks passed")

------------------------------------------------------------ 8. Your porting workflow from here
print(string.rep("-", 70))
print([[
NEXT STEPS (run these yourself — this script will never touch ~/.config):

 1. Inspect:   less build/hyprland.conf

 2. Diff:      diff build/hyprland.conf ~/.config/hypr/hyprland.conf
    (or nicer: diff -u --color=always ... | less -R, or nvim -d file1 file2)

 3. Iterate on the remaining ~390 lines, ONE SECTION at a time:
      - pick the first real difference the diff shows (a missing bind,
        your col.active_border, a misc { } section, windowrules...)
      - add it to 04_port_your_config.lua (or via exercises.lua helpers)
      - re-run:  luajit 04_port_your_config.lua
      - re-diff. Repeat until only harmless noise remains (comment lines,
        blank lines, key order). Perfection is optional — hyprlang doesn't
        care about order for most keys.

 4. Test SAFELY on the live WM (only when the diff looks right):
      cp ~/.config/hypr/hyprland.conf ~/.config/hypr/hyprland.conf.bak
      cp build/hyprland.conf ~/.config/hypr/hyprland.conf
      hyprctl reload
    Broken? Restore and reload:
      cp ~/.config/hypr/hyprland.conf.bak ~/.config/hypr/hyprland.conf
      hyprctl reload

 5. NEVER automate step 4's copy into the generator. build/ is the only
    place Lua writes. You are the deploy step.
]])

------------------------------------------------------------ TRY IT
-- 1. Run the diff in step 2 for real. Port the first section it flags.
-- 2. Extend the workspace loop with the mod+SHIFT movetoworkspace binds
--    (that's exercise 2 — try it here first, `mod .. " SHIFT"` works).
-- 3. Add a `monitor = HDMI-A-1, disable` variant behind a `docked`
--    boolean at the top of this file: one flag, two hardware setups.
