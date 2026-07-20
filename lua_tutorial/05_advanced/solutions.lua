----------------------------------------------------------------------
-- solutions.lua — Advanced Lua: worked solutions
----------------------------------------------------------------------
-- HOW TO RUN
--   luajit solutions.lua             (from this directory)
-- Every test prints trues. Read the "key insight" comment on each one.
----------------------------------------------------------------------

local here = arg and arg[0] and arg[0]:match("^(.*)/") or "."
local build_dir = here .. "/build"
os.execute("mkdir -p '" .. build_dir .. "'")

print("== solutions: advanced lua ==\n")

------------------------------------------------------------
-- EXERCISE 1: must_get(t, key)
------------------------------------------------------------
-- Key insight: level 2 makes the "file:line:" prefix point at the call
-- site — the place that PASSED the bad key — which is where the fix
-- goes. This is how vim.* argument errors behave.
local function must_get(t, key)
  local v = t[key]
  if v == nil then
    error("missing key: " .. tostring(key), 2)
  end
  return v
end

local cfg = { border_size = 1 }
local ok, err = pcall(function()
  local v = must_get(cfg, "gaps_in")   -- level 2 blames THIS line
  return v
end)
print("E1:", must_get(cfg, "border_size") == 1, ok == false,
      err:match("missing key: gaps_in") ~= nil)
-- Print `err` itself and check: the line number is the must_get CALL
-- above, not the error() line inside must_get.

------------------------------------------------------------
-- EXERCISE 2: parse_mode(s)
------------------------------------------------------------
-- Key insight: anchors. Without ^...$ the pattern would happily match
-- INSIDE "prefer1920x1080@60x" garbage. match returns nil on failure,
-- and `if not w` covers all three captures at once (they fail together).
local function parse_mode(s)
  local w, h, hz = s:match("^(%d+)x(%d+)@(%d+)$")
  if not w then return nil end
  return tonumber(w), tonumber(h), tonumber(hz)
end

local w, h, hz = parse_mode("2560x1440@60")
print("E2:", w == 2560, h == 1440, hz == 60,
      parse_mode("auto") == nil, parse_mode("1920x1080") == nil)

------------------------------------------------------------
-- EXERCISE 3: expand(s, vars)
------------------------------------------------------------
-- Key insight: with a TABLE replacement, gsub keeps the original text
-- whenever the lookup returns nil — so "unknown names stay untouched"
-- costs nothing. %$ escapes the magic $; the parens around the gsub
-- call drop its second return value (the count).
local function expand(s, vars)
  return (s:gsub("%$([%w_]+)", vars))
end

local out = expand("exec = $term -e $editor $missing",
                   { term = "ghostty", editor = "nvim" })
print("E3:", out == "exec = ghostty -e nvim $missing")

------------------------------------------------------------
-- EXERCISE 4: reverse_ipairs(t)
------------------------------------------------------------
-- Key insight: the for loop feeds the iterator (state, previous_control)
-- every round — for a countdown, the "previous" value before index #t
-- is #t + 1. No closure, no hidden state: one function serves every loop.
local function reverse_iter(t, i)
  i = i - 1
  if i >= 1 then
    return i, t[i]
  end
end

local function reverse_ipairs(t)
  return reverse_iter, t, #t + 1
end

local acc = {}
for i, v in reverse_ipairs({ "a", "b", "c" }) do
  acc[#acc + 1] = i .. v
end
print("E4:", table.concat(acc, " ") == "3c 2b 1a")

------------------------------------------------------------
-- EXERCISE 5: walk(t)
------------------------------------------------------------
-- Key insight: yield works from ANY depth inside the coroutine — even
-- from a recursive helper. Writing this as a plain closure iterator
-- would force you to maintain an explicit stack of positions; the
-- coroutine keeps that stack for you (it IS the call stack).
local function walk(t)
  return coroutine.wrap(function()
    local function go(x)
      for _, v in ipairs(x) do
        if type(v) == "table" then
          go(v)
        else
          coroutine.yield(v)
        end
      end
    end
    go(t)
  end)
end

local got = {}
for v in walk({ 1, { 2, { 3, 4 } }, 5 }) do got[#got + 1] = v end
print("E5:", table.concat(got, " ") == "1 2 3 4 5")

------------------------------------------------------------
-- EXERCISE 6: find_leaks(f)
------------------------------------------------------------
-- Key insight: __newindex fires only for keys _G does NOT have yet —
-- exactly the definition of a NEW global. pcall around f() guarantees
-- the tripwire is disarmed and _G is cleaned even when f crashes;
-- rethrowing with level 0 (lesson 01 §7) preserves the original
-- file:line prefix.
local function find_leaks(f)
  local leaked = {}
  local saved = getmetatable(_G)
  setmetatable(_G, {
    __newindex = function(t, name, v)
      leaked[#leaked + 1] = name
      rawset(t, name, v)         -- rawset skips this metamethod
    end,
  })
  local fok, ferr = pcall(f)
  setmetatable(_G, saved)        -- disarm FIRST, whatever happened
  for _, name in ipairs(leaked) do
    _G[name] = nil               -- undo the damage
  end
  if not fok then error(ferr, 0) end
  table.sort(leaked)
  return leaked
end

local function buggy()
  leak_b = 2                -- oops, no `local`
  local fine = 1
  leak_a = fine + 1         -- oops again
end

local names = find_leaks(buggy)
print("E6:", #names == 2, names[1] == "leak_a", names[2] == "leak_b",
      rawget(_G, "leak_a") == nil, rawget(_G, "leak_b") == nil)

------------------------------------------------------------
-- EXERCISE 7 (the sting): config round-trip through build/
------------------------------------------------------------
-- Key insights:
--   • render: table + concat, never str = str .. line (O(n²), lesson 06 §5).
--   • parse: try the line shapes in order of SPECIFICITY — "name {",
--     then "}", then "key = value" — after stripping comments; error
--     with a TABLE so the catcher gets the line number as data instead
--     of parsing it back out of a message string (lesson 01 §6).
local sections = {
  { name = "general",
    settings = { { "gaps_in", 3 }, { "gaps_out", 3 }, { "border_size", 1 } } },
  { name = "decoration",
    settings = { { "rounding", 10 }, { "active_opacity", "0.75" } } },
}

local function render(secs)
  local lines = {}
  for _, sec in ipairs(secs) do
    lines[#lines + 1] = sec.name .. " {"
    for _, kv in ipairs(sec.settings) do
      lines[#lines + 1] = ("    %s = %s"):format(kv[1], kv[2])
    end
    lines[#lines + 1] = "}"
  end
  return table.concat(lines, "\n") .. "\n"
end

local function parse(path)
  local result = {}
  local current = nil          -- table of the section we're inside, or nil
  local n = 0
  for line in io.lines(path) do
    n = n + 1
    local body = (line:gsub("#.*$", ""))       -- strip comments
    if body:match("^%s*$") then
      -- blank (or comment-only) line: skip
    else
      local sec = body:match("^%s*([%w_-]+)%s*{%s*$")
      if sec then
        current = {}
        result[sec] = current
      elseif body:match("^%s*}%s*$") then
        current = nil
      else
        local k, v = body:match("^%s*([%w_]+)%s*=%s*(.-)%s*$")
        if k and current then
          current[k] = v                       -- values stay strings
        else
          error({ line = n, text = line }, 0)  -- structured error object
        end
      end
    end
  end
  return result
end

local conf_path = build_dir .. "/exercise_roundtrip.conf"
local f = assert(io.open(conf_path, "w"))
f:write(render(sections))
f:close()

local parsed = parse(conf_path)

local bad_path = build_dir .. "/exercise_bad.conf"
local bf = assert(io.open(bad_path, "w"))
bf:write("general {\n    gaps_in = 3\n    what even is this line\n}\n")
bf:close()
local okbad, eobj = pcall(parse, bad_path)

print("E7:", parsed.general.gaps_in == "3",
      parsed.decoration.rounding == "10",
      parsed.decoration.active_opacity == "0.75",
      okbad == false, type(eobj) == "table", eobj.line == 3)

print("\nAll lines above should read true across the board.")
