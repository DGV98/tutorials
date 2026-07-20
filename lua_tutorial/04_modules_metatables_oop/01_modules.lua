----------------------------------------------------------------------
-- 01_modules.lua — Modules, require, package.path, and the loaded-cache
----------------------------------------------------------------------
-- WHAT YOU'LL LEARN
--   • The `local M = {}` module pattern — how every plugin file is built
--   • What require() actually does, step by step
--   • package.path: how "mylib.greet" becomes "mylib/greet.lua"
--   • package.loaded: why requiring twice does NOT re-run the file,
--     and why editing your nvim config sometimes "doesn't take effect"
--   • How require("me.opts") finds lua/me/opts.lua in Neovim
-- HOW TO RUN
--   luajit 01_modules.lua            (from this directory)
--   or inside nvim:  :luafile %      (with this file open)
-- PREREQUISITES: modules 02–03 (functions, tables)
----------------------------------------------------------------------

------------------------------------------------------------ 1. The module pattern
-- A Lua "module" is nothing magical. It is a file that:
--   1. creates a LOCAL table,
--   2. hangs functions/values on it,
--   3. returns it as the last statement.
-- That's it. No `module` keyword, no exports list. (Old Lua had a
-- module() function — it's deprecated and you'll only see it in ancient
-- code. Ignore it.)
--
-- Everything is `local` so the file leaks NOTHING into the global table
-- _G. This matters enormously in Neovim: every plugin shares one _G, so
-- a plugin that forgets `local` can silently overwrite another plugin's
-- variable. The M-table pattern is the fence between neighbors.

-- Here's the shape, inline (open mylib/greet.lua to see it as a real file):
local function make_module()
  local M = {}            -- the conventional name; some code uses the file's name
  function M.double(n) return n * 2 end
  M.answer = 42
  return M
end
local demo = make_module()
print("module pattern:", demo.double(21), demo.answer)

------------------------------------------------------------ 2. Teaching require where to look
-- require("mylib.greet") does NOT take a file path. It takes a MODULE
-- NAME, and turns it into candidate file paths using package.path —
-- a semicolon-separated list of templates where `?` is replaced by the
-- module name (dots become directory separators). Think of it as $PATH,
-- but for Lua files and with substitution instead of a fixed lookup.
print("default package.path:")
print("  " .. package.path:gsub(";", "\n  "))

-- Your CLI luajit's path starts with "./?.lua" — relative to the
-- CURRENT DIRECTORY, not to this file. If you ran this lesson from
-- somewhere else, "./mylib/greet.lua" wouldn't be found. So we compute
-- this file's directory from arg[0] (the script name luajit was given)
-- and prepend proper templates. This is the standalone-Lua equivalent
-- of Neovim putting your config's lua/ directory on the search path.
-- (One wrinkle: inside interactive nvim, :luafile does NOT set arg[0] —
-- the guard below then falls back to "./", so run :luafile from this
-- directory. `nvim -l file.lua` DOES set arg[0], like luajit.)
local here = (arg and arg[0] or ""):match("(.*[/\\])") or "./"
package.path = here .. "?.lua;" .. here .. "?/init.lua;" .. package.path
print("prepended:", here .. "?.lua  and  " .. here .. "?/init.lua")

-- Note the SECOND template: "?/init.lua". It's what makes a DIRECTORY
-- requireable: require("mylib") finds mylib/init.lua. Your Arch luajit
-- ships "?/init.lua" templates only for the system dirs, not for "./",
-- which is why we add it ourselves.

------------------------------------------------------------ 3. require in action
-- Now require the little library that ships with this lesson:
--   mylib/init.lua   ← require("mylib")
--   mylib/greet.lua  ← require("mylib.greet")
-- Watch the output: each file prints a line WHILE IT LOADS.
print("\nrequiring mylib ...")
local mylib = require("mylib")
print("banner:", mylib.banner())

print("\nrequiring mylib.greet directly ...")
local greet = require("mylib.greet")
print("hello:", greet.hello("world"))
print("shout:", greet.shout("world"))

-- Did you notice? mylib.greet did NOT print its "loaded fresh" line the
-- second time, even though we required it "directly". mylib/init.lua had
-- already required it. Which brings us to...

------------------------------------------------------------ 4. package.loaded — the cache
-- require() is roughly this pseudo-code:
--
--   function require(name)
--     if package.loaded[name] ~= nil then
--       return package.loaded[name]          -- cache hit: file NOT re-run
--     end
--     local chunk = find_and_compile(name)   -- search package.path etc.
--     local result = chunk(name)             -- run the file ONCE
--     package.loaded[name] = result or true  -- cache whatever it returned
--     return package.loaded[name]
--   end
--
-- Consequences:
--   • The file's top-level code runs exactly ONCE per session.
--   • Every require() of the same name returns the SAME table object.
print("\ncache check:")
print("  package.loaded['mylib.greet'] exists:", package.loaded["mylib.greet"] ~= nil)
local greet2 = require("mylib.greet")
print("  same table both times:", greet == greet2)   -- true: identical object

-- Proof they share identity: mutate through one reference, observe
-- through the other. (This is also why one plugin can monkey-patch a
-- module and every other plugin sees the change.)
greet.extra = "added later"
print("  greet2.extra:", greet2.extra)

------------------------------------------------------------ 5. Why your nvim edits "don't take effect"
-- THE practical payoff: you edit ~/.config/nvim/lua/me/opts.lua, then
-- `:source ~/.config/nvim/init.lua` (or re-run require("me")) and...
-- nothing changes. Why? Because package.loaded["me.opts"] is still
-- populated from startup — require returns the stale cached table and
-- never re-reads your edited file.
--
-- The fix: evict the cache entry, then require again:
package.loaded["mylib.greet"] = nil
print("\nafter evicting the cache, requiring again re-RUNS the file:")
local greet3 = require("mylib.greet")            -- prints "loaded fresh" again!
print("  fresh table (old one is stale):", greet3 ~= greet)
-- In nvim that's:  :lua package.loaded["me.opts"] = nil  then  :lua require("me.opts")
-- (Restarting nvim obviously also works — it empties the cache the hard way.)
-- Caveat: anything still holding the OLD table (greet, above) keeps the
-- old one. Reload gives you a new table; it doesn't chase down old refs.

------------------------------------------------------------ 6. How Neovim maps require("me.opts") to a file
-- Neovim wires require() into its runtimepath ('rtp'). For every
-- directory on rtp, it effectively searches:
--   <rtp-entry>/lua/me/opts.lua
--   <rtp-entry>/lua/me/opts/init.lua
-- Your config directory ~/.config/nvim is on rtp, so:
--   require("me")        → ~/.config/nvim/lua/me/init.lua
--   require("me.opts")   → ~/.config/nvim/lua/me/opts.lua
--   require("plugins.telescope") → ~/.config/nvim/lua/plugins/telescope.lua
-- That's also why your init.lua PREPENDS lazy.nvim to rtp before
-- require("lazy") — until the plugin's dir is on rtp, require can't
-- find it. Same idea as our package.path surgery in section 2.
print("\n(see comments: rtp/lua/?.lua is nvim's version of package.path)")

------------------------------------------------------------ 7. When require fails
-- If no candidate file exists, require raises an error listing every
-- path it tried — you have seen this wall of "no file ..." lines in
-- nvim error popups. Read it top to bottom: it IS package.path.
local ok, err = pcall(require, "does.not.exist")
print("\nrequire failure caught by pcall; first lines of the error:")
-- gmatch: like string.match (module 01 §7) but returns an ITERATOR over
-- every match, made for `for` loops. Full patterns tour: module 05.
for line in tostring(err):gmatch("[^\n]+") do print("  " .. line) end

----------------------------------------------------------------------
-- TRY IT
-- 1. Add a function M.wave(name) to mylib/greet.lua that returns
--    "o/ <name>", then use it here. Remember: just re-running this file
--    is a fresh session, so no cache eviction needed.
-- 2. Comment out the two package.path lines in section 2, run the file
--    from your HOME directory (luajit personal/tutorials/lua_tutorial/.../01_modules.lua)
--    and read the error you get. Then un-comment and run from home again.
-- 3. In nvim, run :lua print(vim.inspect(vim.tbl_keys(package.loaded)))
--    and find your own "me.*" modules in the cache.
-- 4. Create mylib/math.lua with an add(a, b) function; require it from
--    mylib/init.lua and expose it as mylib.math.
----------------------------------------------------------------------
