----------------------------------------------------------------------
-- 02_serializer.lua — Walk the model, emit hyprlang
----------------------------------------------------------------------
-- WHAT YOU'LL LEARN
--   • Turning a model table into `key = value` lines with string.format
--   • Repeated keys from arrays; nested sections with braces + indent
--   • Deterministic output: sorted keys + an optional __order list
--   • Snapshot-style self-testing with assert + string.find
--   • Writing ONLY into build/ — and finding build/ from arg[0]
-- HOW TO RUN
--   luajit 02_serializer.lua            (from this directory)
--   or inside nvim:  :luafile %          (with this file open)
-- PREREQUISITES: 01_model_the_config.lua
----------------------------------------------------------------------

------------------------------------------------------------ 1. The model convention
-- One table shape, three interpretations of a field's VALUE:
--   scalar  (string/number/boolean)  ->  key = value
--   array   (t[1] ~= nil)            ->  key = v1 \n key = v2 \n ...   (repeated key)
--   table   (no array part)          ->  key { ...recurse... }         (section)
-- Two special string keys, both starting with "__" (skipped as data):
--   __order   = { "k1", "k2" }  -> emit these keys first, in this order
--   __comment = "text"          -> emit "# text" at the top of this scope
-- Variables are just scalar keys spelled "$mainMod" — no special case needed,
-- because `$mainMod = SUPER` already IS a key = value line.

------------------------------------------------------------ 2. Rendering one value
local function render_value(v)
  local t = type(v)
  if t == "boolean" then
    return v and "true" or "false"      -- hyprlang accepts true/false
  elseif t == "string" or t == "number" then
    return tostring(v)
  end
  -- Fail LOUDLY on functions/nil/userdata: a silent "function: 0x..." in
  -- your window manager config would be a miserable bug to track down.
  error("cannot serialize a value of type '" .. t .. "'", 0)
end

------------------------------------------------------------ 3. Telling arrays from sections
local function is_array(t)
  return type(t) == "table" and t[1] ~= nil
end

------------------------------------------------------------ 4. Deterministic key order
-- pairs() order is undefined (lesson 01 showed this). We fix it:
--   a) honor __order for the keys it lists,
--   b) then everything else sorted: scalars/arrays first, sections last,
--      alphabetical within each group — so `blur {` never lands between
--      two scalar lines of decoration.
local function sorted_keys(tbl)
  local keys, listed = {}, {}
  if tbl.__order then
    for _, k in ipairs(tbl.__order) do
      if tbl[k] ~= nil then
        keys[#keys + 1] = k
        listed[k] = true
      end
    end
  end
  local rest = {}
  for k in pairs(tbl) do
    if not listed[k] and not (type(k) == "string" and k:sub(1, 2) == "__") then
      rest[#rest + 1] = k
    end
  end
  table.sort(rest, function(a, b)
    local sa = (type(tbl[a]) == "table" and not is_array(tbl[a])) and 1 or 0
    local sb = (type(tbl[b]) == "table" and not is_array(tbl[b])) and 1 or 0
    if sa ~= sb then return sa < sb end  -- sections sink to the bottom
    return tostring(a) < tostring(b)
  end)
  for _, k in ipairs(rest) do keys[#keys + 1] = k end
  return keys
end

------------------------------------------------------------ 5. The emitter (recursive)
-- We append lines to `out` and concat once at the end — building one giant
-- string with .. in a loop re-copies it every time (O(n^2)); table.concat
-- is the idiomatic fix you met in module 03.
local INDENT = "    "

local function emit(out, tbl, depth)
  local pad = INDENT:rep(depth)
  if tbl.__comment then
    for line in tostring(tbl.__comment):gmatch("[^\n]+") do
      out[#out + 1] = pad .. "# " .. line
    end
  end
  for _, k in ipairs(sorted_keys(tbl)) do
    local v = tbl[k]
    if is_array(v) then
      for _, item in ipairs(v) do                      -- repeated key
        out[#out + 1] = string.format("%s%s = %s", pad, k, render_value(item))
      end
    elseif type(v) == "table" then                     -- nested section
      out[#out + 1] = pad .. k .. " {"
      emit(out, v, depth + 1)
      out[#out + 1] = pad .. "}"
    else                                               -- scalar
      out[#out + 1] = string.format("%s%s = %s", pad, k, render_value(v))
    end
    if depth == 0 then out[#out + 1] = "" end          -- blank line between top-level blocks
  end
end

local function serialize(model)
  local out = {}
  emit(out, model, 0)
  while out[#out] == "" do out[#out] = nil end         -- trim trailing blanks
  return table.concat(out, "\n") .. "\n"
end

------------------------------------------------------------ 6. Writing into build/ (and ONLY build/)
-- arg[0] is the script path luajit was started with. Deriving build/ from
-- it means output lands next to THIS file no matter where you run from.
local function script_dir()
  local src = (arg and arg[0]) or ""
  return src:match("^(.*[/\\])") or "./"
end

local BUILD = script_dir() .. "build/"
os.execute("mkdir -p '" .. BUILD .. "'")
-- Lua version note: os.execute returns a NUMBER exit status on 5.1/LuaJIT,
-- but boolean+string+number on 5.2+. Don't write `if os.execute(...)` and
-- expect it to mean success on both.

local function write(filename, text)
  local path = BUILD .. filename
  local f = assert(io.open(path, "w"))                 -- assert: crash with a real message
  f:write("# Generated by lua_tutorial/08_capstone_hyprland — edit the .lua, not this file.\n\n")
  f:write(text)
  f:close()
  return path
end

------------------------------------------------------------ 7. Snapshot-test the engine
-- Only runs when you execute THIS file directly; lessons 03/04 load this
-- file with dofile() to reuse the functions (arg[0] is theirs, not ours —
-- same trick as Python's `if __name__ == "__main__"`).
local IS_MAIN = ((arg and arg[0]) or ""):find("02_serializer", 1, true) ~= nil

if IS_MAIN then
  local demo = {
    __order   = { "$mainMod", "monitor", "exec-once", "general", "decoration", "bind" },
    __comment = "tiny slice of the real config — the full port happens in lesson 04",
    ["$mainMod"] = "SUPER",
    monitor = {
      "eDP-1, 1920x1080@60, 0x0, 1",
      "DP-1, 2560x1440@60, auto-up, 1",
    },
    ["exec-once"] = { "waybar", "hyprpaper" },
    general = {
      __comment = "gaps and borders",
      gaps_in = 3, gaps_out = 3, border_size = 1,
      resize_on_border = true, layout = "dwindle",
    },
    decoration = {
      rounding = 10, active_opacity = 0.75, inactive_opacity = 0.6,
      blur = { enabled = true, size = 3, passes = 1 },
    },
    bind = {
      "$mainMod, Q, exec, ghostty",
      "$mainMod, C, killactive,",   -- hyprland's own default config keeps this trailing comma
    },
  }

  local text = serialize(demo)
  print("== generated hyprlang ==")
  print(text)

  -- Snapshot assertions: if a refactor of emit() breaks the output shape,
  -- these blow up immediately instead of you finding out via a black screen.
  -- (find(..., 1, true) = PLAIN search: no pattern magic, $ ( ) stay literal.)
  local must_contain = {
    "$mainMod = SUPER",
    "monitor = eDP-1, 1920x1080@60, 0x0, 1",
    "monitor = DP-1, 2560x1440@60, auto-up, 1",
    "exec-once = waybar",
    "general {",
    INDENT .. "gaps_in = 3",
    INDENT .. "resize_on_border = true",             -- boolean rendered bare
    INDENT .. "blur {",                              -- nested section, indented
    INDENT .. INDENT .. "enabled = true",            -- ...twice
    "bind = $mainMod, Q, exec, ghostty",
    "# gaps and borders",
  }
  for _, needle in ipairs(must_contain) do
    assert(text:find(needle, 1, true), "missing line: " .. needle)
  end
  print(string.format("snapshot OK — all %d expected lines present", #must_contain))

  -- Errors are teaching material too — but through pcall, so we still exit 0:
  local ok, err = pcall(serialize, { general = { on_crash = print } })
  print("serializing a function value ->", ok, err)
  assert(not ok, "that should have failed")

  local path = write("hyprland.conf", text)
  print("wrote " .. path)
end

------------------------------------------------------------ TRY IT
-- 1. Add a `shadow` table inside decoration in the demo model, re-run, and
--    extend must_contain with one line that proves it serialized.
-- 2. Delete __order from the demo and re-run: the file is still VALID
--    hyprlang, just ordered by our sort rule. Which order do you prefer?
-- 3. Change INDENT to two spaces and re-run. Nothing breaks — read the
--    assertions to see why: they build their expected lines from INDENT
--    itself, so they survive the refactor. Would hard-coded spaces have?

------------------------------------------------------------ 8. Export for later lessons
return {
  serialize = serialize,
  write     = write,
  is_array  = is_array,
  BUILD     = BUILD,
}
